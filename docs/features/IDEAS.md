# Feature Ideas Backlog — 10 candidates

Ranked by (persona pain × feasibility on current stack). The first three (translation ×2, structure-thoughts) have their own docs; these are the next ten. Each idea names its persona (see PERSONAS.md) and its cost class: **S** = days on current stack, **M** = needs the LLM engine (shared with translation/structuring), **L** = new subsystem.

1. **Tone dial (M)** — same message, rendered *casual / professional / respectful-formal*. Rekha's courier escalation and Rohan's US-team Slack are the same feature with different knobs. India-specific angle: a "respectful" register (elders, teachers, government) that Western tools don't model. Rides the LLM engine; it's one prompt template per tone.

2. **Voice replies to screenshots / "reply mode" (M)** — user copies an email/message they received, dictates a rough reply in Hinglish, LLM drafts the response *in the same tone and language as the original*. Solves the hardest part of Rekha's and Aman's email problem: not just translation but "what does a proper reply even look like".

3. **Personal dictionary that learns (S)** — today's Replacements is manual. Add "always spell it this way": names (Saraswat, not "Saraswath"), brand words, code terms. UI: after a dictation, right-click any word in History → "always write it as…". Biggest per-user accuracy win available without touching models; every persona benefits from day one.

4. **App-aware modes (S/M)** — remember language/mode per target app: WhatsApp → Hinglish, Mail → English-from-any, VS Code → English + no auto-capitalization. The frontmost-app bundle ID is already knowable at paste time. Turns five manual mode-switches a day into zero — retention feature for Rohan and Priya.

5. **Whisper-to-command / prompt hotkey (M)** — a second hotkey that sends dictated text straight into the clipboard *wrapped in a user template* ("Translate to English and expand into a polite email: {text}"). Poor-man's automations; power users (Rohan, Priya) will build things we never imagined. Cheap: it's templating, not intelligence.

6. **Meeting-notes companion (L)** — capture system audio + mic (with a large honest indicator), transcribe both sides, structure into minutes with the existing structurer. Priya's and Rohan's most-requested category in every competitor's reviews; also the most privacy-differentiated ("meeting notes that never leave the laptop"). L because system-audio capture (ScreenCaptureKit) is a new subsystem + consent design is delicate.

7. **Number & format intelligence (S)** — Indian formats done right: "do lakh pachaas hazaar" → ₹2,50,000 (lakh/crore grouping, not 250,000), dates, phone numbers, "paanch baje" → 5:00 PM. Pure post-processing rules + tests; no model needed. Small, deeply desi, and demos brilliantly to every persona.

8. **Read-back / proof-listen (S/M)** — TTS the final text back (AVSpeechSynthesizer is free and offline). Closes the loop for users whose English *reading* is slower under stress (Rekha, Suresh-class users): hearing "your" email read aloud catches errors eyes skip. Also an accessibility feature — and accessibility framing helps App Store/press narrative later.

9. **Quick capture inbox (S)** — hotkey that dictates into a persistent local scratchpad (not the frontmost app), zero UI, review later. The "voice memos graveyard" fix: unlike memos, these arrive as *text*, already searchable, and feed naturally into Structure-Your-Thoughts ("structure everything from today"). Priya's draft-zero machine.

10. **Bhasha expansion — one language at a time (L)** — Tamil→Tanglish, Telugu, Marathi, Bengali code-mixed models (IndicWhisper/Vaani-family checkpoints exist for several). Each language is a new eval suite + model conversion on the *existing* pipeline. Not a feature so much as the growth strategy: "Desi" ≠ "Hindi", and the first Tanglish dictation tool wins Chennai the way we're trying to win the Hindi belt. Sequence strictly after Hinglish quality is proven — same bar, per language.

## Suggested sequencing logic

- **Now-adjacent (S, no new engine)**: #3 personal dictionary, #7 number intelligence, #9 quick capture — cheap wins that improve the core loop while the LLM spike runs.
- **With the LLM engine (M)**: translation ×2 → structure-thoughts → #1 tone dial → #2 reply mode → #5 prompt hotkey. One engine, six features.
- **Big bets (L)**: #6 meeting notes (after trust is established), #10 language expansion (after Hinglish wins).
