# Structure My Thoughts (beta) — implementation

**Spec:** features/STRUCTURE_THOUGHTS.md. **The pitch:** ramble for minutes —
repeats, backtracks, topic jumps — tap finish, get a structured document in a
review window. Dictation as a thinking tool.

## The session flow, end to end

1. Menu: **"🧠 Structure my thoughts (beta)…"** →
   `DictationController.startThinkingSession()`: sets `thinkingSessionArmed`,
   starts recording. Capture is toggle-style regardless of the push-to-talk
   setting (nobody holds a key for five minutes); a hotkey tap or the menu's
   "🧠 Finish thinking session — organize now" ends it. Esc cancels and
   disarms.
2. On finish, `finishPipeline` sees the armed flag and routes the transcript to
   **`onThinkingTranscript`** instead of pasting — a closure the app layer sets
   in `AppDelegate` (the kit stays UI-free; this is the same inversion used for
   overlay/phase).
3. `ThoughtsSession.begin(transcript:)` (ThoughtsWindow.swift) opens the review
   window and runs `LLMServices.shared.structurer.structure(text, style:)`.
4. **The review window** (`ThoughtsView`): segmented style picker
   (Notes / Action list / Email draft / Outline — restyling reruns the LLM on
   the same transcript in seconds), the structured markdown (rendered,
   selectable), a **DisclosureGroup with the full raw transcript** (the
   zero-loss guarantee, always one click away), 👍/👎 feedback buttons (👎
   pre-fills the standard report email), Copy structured / Copy raw.
5. History stores the structured output with `raw:` = the transcript.

## Failure handling

Structuring fails → the window shows "*Couldn't structure this — here's
everything you said*" over the raw transcript. Rambling is never lost —
same house rule as everywhere.

## Long inputs

`ThoughtStructurer` caps input at ~12k chars (~15 min of speech) at a word
boundary; the overflow is appended to the output verbatim under "**Beyond the
15-minute mark (unprocessed)**". Map-reduce structuring is the documented v2.

## Known quality limit (with repro — keep testing this one)

Adversarial backtracking is NOT fully solved. Repro input:

> "…dusra pricing wala slide hatana hai kyunki legal ne bola hai… nahi wait,
> pricing wala rakhna hai bas disclaimer add karna hai…"

gemma3:4b (2026-07-10) still lists both "Remove the pricing slide" and "Add a
disclaimer" — the final intent was *keep it, with disclaimer*. Two prompt
iterations helped (attribution errors fixed; "two silent steps" instruction
added) but didn't eliminate it. This is why the feature is labeled **(beta)**,
opens in a *review* window rather than pasting, and shows the raw transcript.
The 30-clip human-rated eval gate (spec §4) remains the ship-to-default bar.

## Changing it

- Prompts: `PromptTemplates.structure(style:)` — four templates sharing a
  common no-invention/backtracking preamble; all overridable via prompts.json.
- New output style: add an `OutputStyle` case + template; the picker and
  restyle logic pick it up automatically.
- Streaming tokens into the window (spec's perceived-latency idea): blocked on
  a streaming backend (Ollama streaming or future LlamaCppLLM) — the UI seam
  is `ThoughtsSession.run()`.
- Word-count reassurance on the overlay while recording (spec §3.3): not built;
  would need sample-count → word estimate plumbed into `OverlayView`.
