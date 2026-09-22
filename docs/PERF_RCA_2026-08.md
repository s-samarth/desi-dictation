# RCA — "dictation is slow, sometimes >10 s" (2026-08-19)

Investigation, then the fix. **Everything below shipped in v0.6.1** — see
"What shipped" at the end for the measured before/after. Complements
[PERFORMANCE.md](PERFORMANCE.md) (which lists levers) — this one explains why
the shipped defaults feel slow and what our measurements were hiding.

## Verdict first

1. **It is not the AI modules.** Ollama isn't even running on this Mac, the
   default tone is `faithful` and `ollamaEnabled` defaults to false, so no LLM
   stage executes on a normal dictation. Nothing in the 0.6 wave touched the
   transcription core.
2. **It is not a memory leak.** `leaks` on the live app (up 17 d 23 h) reports
   **14 KB in 289 nodes** — system XPC noise. Six consecutive engine runs are
   flat at 1.88 s. Nothing degrades per call inside the process.
3. **It is the model tier × the per-call fixed cost × the chunker.** Whisper
   always encodes a **padded 30-second window**, so every `whisper_full` call
   costs the same ~1.5 s on an M3 whether the audio is 2 s or 30 s. The chunker
   fires one such call per ~12–20 s of speech, plus one for the tail. On an M1
   Air (~half the GPU) that fixed cost is ~3 s per call.

## Measured on this machine (M3 Air 16 GB, macOS 26.5.2, release build)

App's own engine path (`desi-cli`, VAD on, `flash_attn=false` — exactly what the
app runs), 12-second clip:

| Model | Size | Load | Per call | "RTF" |
|---|---|---|---|---|
| hinglish-swift | 141 MB | 0.15 s | **0.19–0.23 s** | ~60× |
| hinglish-apex q5_0 | 574 MB | 0.34 s | **1.72 s** | 7× |
| large-v3-turbo q5_0 *(this Mac's pinned model)* | 574 MB | 0.38 s | **1.88–2.03 s** | 6× |
| vaani-hindi q5_0 | 1.06 GB | 0.76 s | **4.83 s** | 2× |

Cost vs. audio length (turbo, same path) — note it is nearly flat:

| Audio | 2 s | 3 s | 12 s | 60 s |
|---|---|---|---|---|
| Wall time | 1.76 s | 2.29–2.82 s | 1.88–2.03 s | 3.64–3.92 s |

`whisper-cli` breakdown: **encode = 1.51 s per 30 s window**, independent of how
much of the window is real audio. A 2-second tail costs a full window.

Other measurements: flash-attn ON would save ~11 % (1.35 s vs 1.52 s encode);
thread count 4/6/8 makes no material difference (this stage is GPU-bound);
0 temperature fallbacks on the clips tested; VAD costs ~1.3 s on 60 s of audio.

**Chunking tax:** the same 60 s as 3 × 20 s calls = **7.2 s** of engine work vs
**5.8 s** as one call — and the app adds a 4th call for the tail.

## Root causes, ranked

### RC1 — The per-call floor is the product's real latency, and we never measured it
A dictation costs `(number of chunks + 1) × ~1.5 s` on M3, `× ~3 s` on M1 Air.
Our regression guard (PERFORMANCE.md) runs **one long clip** and asserts
**≥10× realtime** — a throughput metric that a 2-second-per-utterance floor
passes comfortably. We have no metric for the number users actually feel:
*release-to-paste*.

### RC2 — Chunking pays that floor several times, and the tail queues behind it
`DictationController.startChunkTicker` cuts every ≥12 s (forced at 20 s) and
enqueues each chunk on the **same serial `workQueue`** the final tail uses. If a
chunk is still decoding when the user releases, the tail waits for it: worst
case the user waits **two full calls** (~4 s M3, ~7 s M1) for a 2-second tail.
The design (PERFORMANCE.md §2) assumes chunk cost ≈ chunk length; it is actually
a constant. History shows this Mac's dictations run 130–508 characters —
40–60 s of speech, i.e. 3–5 engine calls each.

### RC3 — 0.6 removed every light model from the catalog
0.5.0 shipped `hinglish-swift` (141 MB) and `base` (148 MB) as downloads. The
0.6 catalog is Apex / Turbo / Vaani only ("deliberately minimal"). That is a
**9× per-call regression** for anyone who was on Swift, and any fresh 0.6 install
can only choose heavy models. This is the most likely mechanism behind
"0.5 felt fine" — the code path didn't get slower, the shipped model did.
Hindi is worst: Vaani is 4.83 s per call here, so **~10 s per call on an M1 Air**
— exactly the reported symptom, with no bug involved.

### RC4 — Long-idle residency, not leakage, explains "worse after it sits"
The live app holds **782 MB** (peak 2.0 GB) with the model resident by design.
**108 MB of its writable pages are currently swapped out** and the machine is
using 1.97 GB of swap. After idle hours the first dictation faults the model
back in before decoding starts. Also: nothing calls
`ProcessInfo.beginActivity`, so a windowless `LSUIElement` app is exposed to App
Nap / timer coalescing — unproven here, but it is the only plausible
"gets slower the longer it sits" mechanism left, and it is cheap to rule out.

### RC5 — Two latent bugs whose symptom would be exactly "progressively slower"
- **Chunk-ticker leak.** `enable()` (called by `reloadHotkey()` when settings
  change) resets `phase` **without** `stopChunkTicker()`. A settings change made
  *while recording* orphans a ticker that keeps polling forever; the next
  dictation starts a second one, and both cut chunks → duplicated engine work
  (and duplicated text) that persists for the life of the process, compounding
  each time it happens.
- **Model thrash on Auto.** `resolveModel` maps mode→model (Hinglish→Apex,
  English→Turbo, Hindi→Vaani). With `perAppModes` **on by default**, switching
  apps can change the mode, and the reload is lazy — it lands **inside** the
  transcribing phase (0.34–0.76 s cold on M3, seconds when the file is not in
  page cache). This Mac is insulated only because its model is pinned; default
  installs are not.

### RC6 — Where the AI modules *would* hurt (not today, but by design)
`ollamaCleanup` blocks the serial engine queue on a `DispatchSemaphore` while an
HTTP round-trip runs (30 s timeout), so enabling legacy AI cleanup serialises an
LLM call inside the transcribing phase. `anyToEnglish` and non-faithful tones add
a second full model's latency after transcription. All are opt-in and off here.

## What we're lacking

1. **A latency metric.** Nothing records release→paste, per stage. `os_log` info
   messages are not persisted, so a user complaint cannot be reconstructed after
   the fact — the 18-day-old process on this Mac has no retrievable timings.
2. **Perf gates in `preflight.sh`.** The regression guard is a manual command in
   a doc, in RTF terms, on a long clip.
3. **Hardware coverage.** Everything is measured on M3. The stated target is an
   M1 Air; no number in any doc comes from one.
4. **Docs that match the build.** SYSTEM_DESIGN §3 still says "record-then-
   transcribe, no streaming" and "39× realtime → 60 s transcribes in ~1.5 s";
   README repeats 39×, which is the **Swift 72 M** figure (SYSTEM_DESIGN §124),
   not the shipping default. Real numbers for the shipping default are 6–7×, and
   1–3× for short utterances.

## Ranked fixes (all applied except #6 — see "What shipped")

| # | Change | Expected effect | Cost |
|---|---|---|---|
| 1 | Bring back a light model (Swift 141 MB) and default to it on 8 GB / M1-class Macs | 1.9 s → 0.2 s per call | Catalog + onboarding copy |
| 2 | Don't chunk short dictations; raise the cut threshold well above the fixed cost, and skip the tail call when the tail is < ~1 s of speech | Removes 1–2 full calls from the common case | Small, in `DictationController` |
| 3 | Instrument stages (capture ms, queue-wait ms, decode ms per call, calls per dictation) behind a debug toggle | Turns future reports into data | Small |
| 4 | Re-test `flash_attn = true` (FM #12 was v0.3; upstream default is now on) | ~11 % encode | Bench + eval clips |
| 5 | Fix the `enable()`/ticker leak; preload the model when the per-app rule changes, not at dictation time | Removes the compounding path and the in-phase reload | Small |
| 6 | CoreML/ANE encoder (PERFORMANCE.md deferred #1) | ~3× on the dominant term | 1–2 days |
| 7 | Replace the RTF gate with a release→paste budget on short *and* long clips, run in preflight | Makes this class of regression impossible to ship | Small |

## How to confirm on a live machine

```bash
log stream --predicate 'subsystem == "com.desi.dictation"' --level info
```
Dictate once; the gap between each `transcribe:` line and its `segments:` line is
one engine call, and the count of those lines is the number of calls that one
dictation paid for.


## What shipped (v0.6.1, 2026-08-19)

Every ranked fix from the table above, in order:

| # | Change | Measured result |
|---|---|---|
| 1 | **Parakeet TDT 0.6B v3 (q4_k) for English**, second engine behind `EngineRouter` | 1.94 s → **0.21 s** per call, nWER 4.5 % → **4.3 %** on the English eval suite (FLEURS US English — originally mislabelled Svarah, FM#24), 574 MB → 416 MB ([research §E](MODEL_RESEARCH.md)) |
| 2 | **No chunking below 30 s of speech**; chunks ≥25 s (forced 35 s); a failed tail can no longer discard chunks already transcribed | ordinary dictations now cost exactly one engine call |
| 3 | **`DictationTimings`** — speech seconds, engine calls, engine time, release→paste; shown in the Dictation pane, logged at `.notice` | complaints are now reconstructible from `log show` |
| 4 | **Flash attention on** (FM#12 retested: 18 clips, 0 NaN) | ~11 % less encode time, kill switch in Options |
| 5 | **`enable()` tears the session down** (FM#21); **per-app rule change preloads** the model | removes the compounding path and the in-phase model load |
| 6 | CoreML/ANE encoder | **not done** — still [PERFORMANCE.md](PERFORMANCE.md) deferred #1, and now most valuable for हिन्दी (Vaani, 3.55 s/call) |
| 7 | **`scripts/latency_gate.sh` in preflight** — short clip per language, per-language budget | English 0.22 s / Hinglish 1.47 s / हिन्दी 3.58 s, gated |

Plus the UX fix that came with it: **[per-language default models](features/implementation/MODEL_ROUTING.md)** —
choosing a language now chooses its model, and pickers hide models that cannot
serve the selected language.

Still open, honestly: **हिन्दी is the slow path** (1.06 GB large-v3 Vaani,
3.55 s/call on an M3 — roughly 7 s on an M1 Air). RC4 (memory/residency after
long idles) is unaddressed by design; the model is meant to stay resident.
