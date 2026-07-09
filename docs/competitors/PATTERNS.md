# Corroborated & Resurfaced Patterns

> The cross-competitor synthesis — what recurs across the standalone files. If you read one doc in this folder, read the standalone for whoever you care about; if you read two, read this one second. Written 2026-07-09.

## 1 · Feature convergence: the app layer has agreed on a spec

Across MacWhisper, Wispr Flow, Superwhisper, VoiceInk (and echoed by Willow/Raycast), the same features recur so consistently they're now **table stakes**:

| Converged feature | Who has it | Our status |
|---|---|---|
| **Personal dictionary / custom vocabulary** | Wispr (auto-learn), Superwhisper, VoiceInk, Raycast | ❌ **We're the only serious app without it.** P4-S1 is overdue, not optional. |
| **Per-app modes / auto behavior switching** | MacWhisper, Wispr, Superwhisper, VoiceInk (4/4) | ❌ IDEAS #4 should jump the queue. |
| **LLM post-processing** (cleanup/tone/structure) | All four majors | 🔜 Our LLM layer is catching up to consensus — but ours is *on-device*, which none of the quality versions are. |
| **Modes-as-bundles** (Formal/Casual/Email/Chat) | Superwhisper, VoiceInk converged on identical UX | 🔜 Build our tone dial *as modes*, not a toggle. |
| **Push-to-talk + toggle, hotkey, Esc, sound cues** | Everyone | ✅ We have it. |

**Implication:** two features (personal dictionary, per-app modes) are places we're now *behind the category*, not ahead. They should move up the roadmap purely to reach parity, independent of their own merit.

## 2 · The white space nobody occupies (our moat, restated with evidence)

**Not one competitor at any layer ships polished Roman-script code-mixed Indian consumer dictation.**
- App layer (MacWhisper/Wispr/Superwhisper/VoiceInk/Willow): English-first, no Hinglish; their translation paths are generic-Whisper, weak on code-mix.
- Platform defaults (Apple/Windows): Hindi = Devanagari-only, no code-mix; Apple mangles, Windows is weaker still.
- Indian model layer (Sarvam/AI4Bharat/Bhashini/Gnani): real code-mix capability, but **enterprise/API/Devanagari-oriented, not consumer Roman-script apps.**
- Every converged feature in §1 is **orthogonal to language** — meaning we can adopt the whole consensus layer *and* keep the moat.

**But the moat is time-boxed** (see §4). It's real today; it's not permanent.

## 3 · The trust playbook — what reviews punish (and our positioning writes itself)

Competitor failures cluster into a repeatable list of trust violations. Each is a competitor wound we're already positioned against:

| Violation | Culprit | Our stance |
|---|---|---|
| Cloud screenshots of your screen for "context" | Wispr Flow | On-device; P4 §4c already refused this. |
| Rewriting what you actually said as "polish" | Wispr Auto Edits | Faithfulness-first, edit-distance-leashed. |
| Re-adding itself to Login Items | Wispr Flow | Honor the toggle, always. Never re-add. |
| Perceived quality-drop after trial | Wispr (perceived) | Feature-gate, never quality-gate. |
| Usage caps on a habit tool | Wispr (words/wk), Superwhisper (15-min history) | Full free core; gate features, not usage. |
| Even *anonymous* telemetry | MacWhisper (TelemetryDeck) | Zero telemetry — out-privacy the privacy king. |
| Audio leaves the device at all | All cloud players (Wispr/Willow/Deepgram/Sarvam) | Nothing leaves. "There is nothing to audit." |

**This is marketing, not just ethics:** every row is a line in our launch copy, backed by a named competitor's real review pain.

## 4 · The commoditization thesis — the most important strategic pattern

Read across the model/infra files and one conclusion dominates: **the model layer is commoditizing fast, from three directions at once.**
- **Google** is putting Hinglish + code-switching + ramble-cleanup ("Rambler," Gemini) into the free default keyboard on Android — our exact feature, our exact market, zero price, infinite distribution.
- **Sarvam** ($1.5B) and **cloud APIs** (Deepgram/Speechmatics with Hindi code-switching) make code-mixed ASR a rentable commodity.
- **NVIDIA Parakeet/Canary** beat Whisper on English at 10× speed; **AI4Bharat** gives Indic ASR away permissively.

**Therefore our long-term defensibility cannot be "we have the best Hinglish model."** We don't even train our model (Oriserve does — [oriserve.md](15-oriserve.md)), and the model layer will be owned by giants. Our durable moat has to be **everything around the model**:
1. **On-device privacy** — the one thing cloud giants (Google/Sarvam/Wispr) structurally cannot match.
2. **Consumer product craft** — the infra players don't build for Rekha.
3. **Personalization** (your Hinglish, your lexicon) — per-user state that compounds and doesn't live in a shared cloud model.
4. **The feature layer** (translation-to-English, structuring, tone) — as a focused product.
5. **India-native GTM & pricing** — one-time/UPI/₹ psychology the global players ignore.
6. **Cross-platform continuity** — the same experience on Mac + Windows + Android, which a keyboard feature or an API isn't.

## 5 · The platform gap is the clock on the moat

Every direct app rival except MacWhisper/VoiceInk is **already cross-platform including Android/Windows** (Wispr, Willow, Superwhisper-on-Windows). We are Apple-Silicon-Mac-only. Meanwhile **India runs on Android**, and Google's free Android default is about to get good at our feature. The pattern is unambiguous:

- **Android is not "expansion," it's survival of the thesis.** The moat (Roman-script Hinglish) means little if we can't reach it where Indians actually text.
- **Windows is the desktop follow-on** — free default there is *weaker* on Hindi than Apple's, so the wedge is even sharper, and our stack (whisper.cpp, models, convention) is ~fully portable.
- **The timeline compresses** against Google's flagship-gated Rambler rollout: we have roughly the window before Google's default becomes universally good (~2–3 years, as it reaches mid-market devices) to establish "Desi Dictation = best Hinglish" as a brand and get onto Android.

## 6 · Business-model corroboration (see ../MONETIZATION.md)

The survivors of this niche **all use one-time psychology or offer it**: MacWhisper (€59 lifetime), VoiceInk ($25–39 one-time), Superwhisper (lifetime alongside sub), AudioPen (prepaid no-auto-renew). The **only pure-subscription players are the VC-funded cloud ones** (Wispr, Willow) whose recurring COGS justify it. Our COGS≈0 → we copy the survivors, not the venture case. This pattern independently confirms MONETIZATION.md's prepaid-pass recommendation.

## 7 · The three things to actually do about all this

1. **Reach parity fast** on the two converged features we lack: personal dictionary (P4-S1) and per-app modes (IDEAS #4). We're behind, not ahead, here.
2. **Nail Hinglish quality and get to Android** before Google's default closes the window (the clock in §5). These are the two existential moves; everything else is secondary.
3. **Stop pitching the model as the moat** — internally and externally. The model is Oriserve's, commoditizing, and shared. Pour strategy into the six durable differentiators in §4, all of which are things giants won't or can't copy for a niche.

Sources: synthesized from all standalone files in this directory; primary citations live in each.
