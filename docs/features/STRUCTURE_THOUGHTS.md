# Feature: Structure Your Thoughts

> **Status (2026-07-10): BUILT (beta)** — thinking sessions + review window with
> style picker, zero-loss raw transcript, 👍/👎 feedback. Known limit: hard
> backtracking can still leak both versions (repro + mitigations:
> [implementation/STRUCTURE_THOUGHTS_IMPL.md](implementation/STRUCTURE_THOUGHTS_IMPL.md)).
> The §4 30-clip human-rated gate still applies before it loses the (beta) label.

## 1 · Explainer

A long-form dictation mode for *thinking out loud*. The user rambles — repeats themselves, backtracks ("nahi wait, pehle wala point better tha"), jumps topics — for as long as they want. When they stop, the app hands back a **structured document**: headings, bullet points, action items, in clean text. The mumbling is the input; the structure is the output.

A small local language model does the structuring. Combined with transcribe→translate, the full pipeline can be: *ramble in Hinglish → organized English document*. That's dictation as a thinking tool, not a typing replacement — closer to "brain dump → notes" than "speech → text".

## 2 · The user

Anyone whose thoughts run faster than their typing and messier than their final document needs to be:

- **The founder/manager** after a call: 3 minutes of rambling → meeting notes with decisions and action items.
- **The student** planning an assignment: scattered points → an outline.
- **The overthinker** (all of us) at 11 pm: circular worries → a clear list, which is half the therapy.
- The persona fit is broad, but the *unlock* is strongest for Hinglish speakers: structuring tools exist (cloud, English-only); nobody structures code-mixed rambling, and nobody does it on-device.

Pain today: voice memos that are never replayed; notes apps full of half sentences; or paying for cloud tools (Voicenotes, AudioPen) that upload everything.

## 3 · User flow

1. Menu bar mic → **"Structure my thoughts"** (or a dedicated hotkey / toggle-mode session flagged as a "thinking session").
2. Overlay switches to a distinct look ("🧠 Thinking session — take your time"). Toggle mode is forced here — you don't hold a key for 5 minutes.
3. User rambles. Chunked transcription runs as usual; pauses are fine (VAD); a running word count on the overlay reassures them it's listening.
4. User taps the key again to finish. Overlay: "Organizing your thoughts…"
5. A window opens (not a paste — this output deserves review) with the structured result:
   - a one-line **summary**,
   - **sections with headings**,
   - **action items** pulled out (if any),
   - and, collapsible below, the **raw transcript** — nothing is hidden, trust requires seeing what was heard.
6. Output style picker in that window: *Notes / Action list / Email draft / Outline* — reruns the LLM with a different template, seconds not minutes.
7. Copy / paste buttons; entry saved to History (both raw + structured).

Failure handling: structuring fails or produces junk → show the raw transcript with a "couldn't structure this — here's everything you said" banner. Rambling is never lost.

## 4 · Technical plan

- **Same LLM as the translation features** — this is the third feature riding one llama.cpp integration and one downloaded model (~1–2 GB instruct model, Qwen2.5-1.5B/3B class). The spike for all three features is shared; structuring is the most demanding of the three, so it sets the model floor. If 1.5B structures poorly but 3B works, ship 3B and let translation share it.
- `ThoughtStructurer` in DesiDictationKit: `structure(_ transcript: String, style: OutputStyle) async throws -> String`. Prompt templates per style in a resource file; each template demands markdown output and *forbids adding facts not in the transcript* (hallucination is the #1 risk — a structurer that invents action items is worse than useless).
- Long inputs: a 10-minute ramble ≈ 1,300 words ≈ fits in a 4k context with the template — fine. Cap sessions at ~15 min in v1; beyond that, map-reduce (structure per 5-min block, then merge) — v2 problem.
- `DictationController`: a session flag `thinkingSession`; on finish, route transcript to `ThoughtStructurer` instead of `TextInserter`, open `ThoughtsWindow` via `AppWindows`.
- Latency: 1,300-word input, ~400-word output at 40–80 tok/s → **5–10 s**. Acceptable for this use case (the user just spoke for 10 minutes), but the overlay must show progress; consider streaming tokens into the window so text appears live — much better perceived latency and llama.cpp gives us streaming for free.
- Memory note: the structuring session doesn't need Whisper after transcription finishes → free to unload Whisper before loading the LLM on 8 GB machines if needed.

## 5 · Rollout & feedback

- Ship **after** translation features prove the llama.cpp integration (this feature has the widest quality variance, so it benefits from a hardened engine).
- Beta as a clearly-labeled experiment: menu item "Structure my thoughts (experimental)". The review-window design already sets a "check this" expectation.
- Demo-driven adoption: record one 90-second screen capture (ramble → document) for the WhatsApp group; this feature demos better than it describes.
- Feedback: window gets a "How did it do? 👍 / 👎 → email" affordance — 👎 opens the standard mailto pre-filled with raw + structured (visible before sending, as always). Ask testers one question: **"did you actually use the structured output somewhere, or just admire it?"** Novelty features get admiration; good features get usage.

## 6 · What makes it good

- **Zero-loss guarantee**: everything said is either in the structure or visible in the raw transcript below it. Users must never wonder "did it drop my third point?"
- **No invention**: it never adds an action item, name, or fact that wasn't said. This is the gate; test with adversarially rambly inputs.
- The structured output is used *as-is* in a real place (Notion, email, todo app) by beta testers — same "sent it unedited" bar as translation.
- Handles real rambling: repetition collapsed, backtracking respected ("actually forget X" means X is dropped), topic jumps become separate sections.
- A user comes back to it unprompted within a week. This feature either becomes a habit or it's dead weight — measure by asking, honestly, in the group.
