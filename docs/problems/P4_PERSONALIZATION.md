# P4 · Users can't make the output *their* Hinglish without manual drudgery

## 1 · Problem definition

Everyone's Hinglish is personal (P1's root cause): *nahi* vs *nhi*, *kyunki* vs *kyuki*, *bhai* vs *bhy*. Today, a user who wants the app to match their spellings must open the app → Text tab → type `nahin=nahi` rules by hand, one per line. That is: they must (a) realize the feature exists, (b) leave their flow, (c) formalize their own habits as substitution rules — something nobody does for more than three words. The result: output that's *phonetically right but personally wrong*, forever, with the fix hidden behind clerical work.

The model to beat is **keyboard autocomplete**: it also started wrong for everyone, but it learned from each correction *in place*, invisibly, until one day it just knew you. Nobody ever "configured" their autocorrect dictionary. That's the bar: **whatever you spoke should read like you texted it — with your spellings — and getting there should require zero administration.** Corrections may be frequent at the start; they must *decay* to rare. Today they never decay, because nothing learns.

## 2 · The user & what they face

- **Rohan** types *nhi* and *kya scene*; the app writes *nahi* and *kya scene hai*. Every dictation needs three micro-edits that are individually trivial and collectively the reason he types instead.
- **Aman** has the most idiosyncratic spellings (youth orthography: *bhut*, *smjha*, *acha*) — the convention (P1-S1) will feel most "off" to him even when it's consistent.
- **Rekha** will never open a settings tab, let alone write replacement rules. For her, either the product learns invisibly or it never fits her.
- **Priya** hits it on brand names and campaign terms — she'd use an explicit "always spell it this way" if it were one click, never if it's a settings chore.

The emotional core: seeing your own words in someone else's spelling feels like reading a transcript of yourself with an accent you don't have. It's *almost right*, which is worse than wrong — it keeps reminding you a machine wrote it.

## 3 · Impact on the journey

- The correction tax (P1 §3) never amortizes. With P1 solved, errors become *consistent* — but consistently-not-mine still means the same fixed set of edits on every single dictation, forever. Consistency without personalization converts P1's win into a plateau.
- It blocks the identity moment that creates love for the product: the first time the app writes *bhut acha bhai* exactly as you'd have typed it is the moment it stops being a tool and becomes *yours*. No personalization = that moment never arrives.
- The current Replacements UI actively harms: users who find it and invest effort feel the product outsourced its job to them; users who don't find it think the product can't do it at all. Both readings lose.

## 4 · Why it's this bad — root causes

**(a) Personal orthography is unconscious knowledge.** Users cannot enumerate their own spellings — they *recognize* "that's not how I write it" instantly but can't list their rules upfront. Any solution demanding declaration-in-advance (the current UI) fights human nature; learning must happen at the moment of recognition (the correction) or from evidence of habit (their actual texting).

**(b) There's no correction surface.** The transcript is pasted into *another app* and edited there — outside our sight. The one place the user naturally fixes our output is the one place we can't see it. This is the structural reason nothing learns today, and every solution below is fundamentally a different answer to "where do we legitimately witness corrections?"

**(c) The tempting shortcut is a trap — the Input Monitoring question, answered.**
We hold Input Monitoring permission (for the hotkey). Could we use it to watch the user's post-paste edits, or their normal typing, and learn their spellings? Technically partially (our CGEventTap sees keystrokes; reconstructing edit *semantics* — what replaced what, in which text field — would additionally need Accessibility content-reading and serious engineering). But the answer is **no, and it should stay no**:
  - It is keylogging. Not "like" keylogging — literally capturing keystrokes beyond our stated purpose. The permission was granted for "detect your dictation hotkey"; using it to harvest typing violates the exact consent we asked for, in an app whose brand *is* "we don't take what you didn't hand us" (P3 guardrail).
  - Discovery is guaranteed eventually (open codepaths, curious users like Rohan, or a security researcher having a normal Tuesday), and the resulting story — *"privacy-first dictation app reads your keystrokes"* — is unrecoverable. It converts our strongest asset into our obituary.
  - It's also *bad data*: keystroke streams are noisy (typos, rewrites, autocorrect fights), and attributing edits to "spelling preference" vs "changed my mind" is unsolvable without content context we shouldn't read.
  - Verdict: the advantage is real, modest, and poisoned. All solutions below get the same data through channels the user knowingly participates in. (One legitimate crumb: we *may* use the tap to notice "user pressed Cmd+Z within 5 s of paste" as an anonymous, local-only signal that a dictation was bad — an event about *our own output*, no content captured. Even this: local only, documented.)

**(d) We do have legitimate evidence lying around**: History (our transcripts), the clipboard we ourselves populated, and — once the translation feature ships — the edit-before-translate window where users fix transcripts *inside our app*. The raw material exists; it's the loop that's missing.

## 5 · Severity

**High.** It gates retention (the correction tax decides typing-vs-dictating every day) and it's the necessary second half of P1: convention gives everyone the *same* starting point; personalization walks each user from there to *their* point. It is not existential alone — the app functions without it — but P1 without P4 undershoots the promise ("likha waisa hi jayega" implies *your* waisa). It's also a durable moat: on-device personal lexicons are per-user state cloud competitors can't easily replicate under their compliance models, and it deepens with usage — switching costs that grow daily.

## 6 · Proposed solutions

### S1 · One-click "always write it my way" — the explicit fast path

> **Status (2026-07-10): BUILT** — `PersonalDictionary` (local JSON lexicon,
> first-class UI in Settings → Text) + History right-click "always write a word
> as…", word-boundary + casing-aware, applied before every LLM stage. The
> token-context guards ("main"→"mai" inside English) remain open — see
> [implementation doc](../features/implementation/PERSONAL_DICTIONARY.md).

Kill the settings-tab data entry; move correction capture to the moment of recognition. Surfaces: (a) History entries and the last-dictation window get *tap-a-word → "always write it as…"* (pre-filled with an edit box); (b) after the translation feature's edit-window ships, any word the user edits there offers a one-tap "remember this spelling". Each acceptance writes to a **personal lexicon** (local file, user-viewable, user-deletable — a first-class object, not a buried setting), which feeds both the PostProcessor (deterministic rewrite) and the prompt-bias subsystem (P1-S2/P2-S2).

- **Trade-offs**: still requires a deliberate act per word (but *one tap in-flow* vs. *form-filling out-of-flow* — autocorrect-exception-level friction, which history shows people do accept); word-level rules are context-blind ("main"→"mai" must not fire inside English "main street" — rules need token-context guards, same machinery as P2-S3).
- **Complexity**: Low-Medium. Lexicon store + two UI touchpoints + PostProcessor/prompt integration. The guards are the only subtle part.
- **UX change**: additive; History becomes a place you *teach*, not just browse. Discoverability solved by a one-time coach mark after the user's ~5th dictation ("see a spelling you'd write differently? tap it").
- **Solves**: the top-20 personal words — which, given Zipf, is most of the *felt* problem — with user-legible control (they can audit the lexicon: trust-compatible).
- **Doesn't solve**: the long tail; users who won't do even one tap (Rekha); learning without teaching.

### S2 · Implicit learning from in-app edits (the autocomplete move)

Wherever the user edits our transcript *inside our surfaces* (last-dictation editor, pre-translate editor, structured-thoughts window), diff original vs. final locally. Recurring word-level substitutions (same A→B seen ≥3 times across sessions) get auto-promoted into the personal lexicon — with a gentle disclosure ("Learned: you write *nahi* as *nhi* — undo"). Pure local computation on text we generated and they fixed in our own windows: consent-clean by construction.

- **Trade-offs**: only sees edits made in-app — coverage depends on those surfaces being used (translation's edit-first flow suddenly does double duty; this is an argument for shipping it earlier); mis-generalization risk (user fixed a *transcription error*, not a spelling preference — the ≥3-occurrences threshold plus notify-with-undo is the guardrail); silent learning, even local, must be disclosed in plain words or it reads as spooky when discovered ("how did it know?" cuts both ways).
- **Complexity**: Medium. Local diff/alignment (machinery exists in evals' normalizer), promotion logic, the disclosure UX.
- **UX change**: near-zero interaction cost — the product *quietly becomes yours*, with a visible ledger of what it learned. This is the autocomplete experience, done with receipts.
- **Solves**: the decay curve — corrections genuinely decrease over weeks without administration; serves Rekha-class users *if* they ever edit in-app.
- **Doesn't solve**: users who edit only in the target app post-paste (structurally invisible, see 4b — mitigation: make in-app editing attractive, e.g. the last-dictation window one hotkey away).

### S3 · Import your existing Hinglish — cold-start from owned text

The user's spelling habits already exist in text *they own*: WhatsApp chat exports (Settings → Export Chat → no media → a .txt), notes, sent emails. Offer a one-time "Teach it your Hinglish" import: user drops a chat export; we locally extract *their* messages (parseable by sender name), frequency-count their Hindi-word spellings, and seed the personal lexicon — with a review screen ("you write: nhi, kyuki, bhut — apply?"). File processed in memory, discarded after; nothing uploaded, stated loudly.

- **Trade-offs**: handling a user's chat history is peak sensitivity even locally — the UX must radiate care (explicit "this file never leaves; deleted after") and one bug here is catastrophic reputationally, so the code must be boringly auditable; WhatsApp export format shifts occasionally (parser maintenance); only seeds *spellings of words they type*, not speech-specific patterns; group chats mix languages/people — sender filtering must be solid.
- **Complexity**: Medium. Parser + extractor + review UI; the extractor is basically the P1 normalizer run in reverse (detect which variant a user prefers per canonical word).
- **UX change**: a powerful onboarding-adjacent moment: *day-one output in your spellings* — the identity moment (§3) moved from week 3 to minute 10. Optional, clearly skippable.
- **Solves**: cold start — the "corrections frequent at the start" phase largely disappears for importers.
- **Doesn't solve**: drift after import; non-importers; speech-only vocabulary never texted.

### S4 · Personal fine-tuning / voice-adapted models (the horizon, not the plan)

The maximal version: per-user model adaptation (LoRA-style on their donated corrections + voice). Listed for completeness and as the P3-flywheel endgame — **not proposed now**: training on-device is impractical on an M1 Air; training server-side requires exactly the data-custody we refuse; and S1–S3 capture most of the value (spelling identity) at ~zero risk, because spelling lives in the *text* layer where deterministic + prompt-bias methods already reach.

- **Trade-offs/complexity**: High/very High; privacy-model redesign required.
- **Solves**: acoustic personalization (accent, cadence) that text-layer methods can't touch.
- **Doesn't solve**: the actual near-term problem any faster than S1–S3.

## Recommended attack

**S1 first** (it's small, and it creates the lexicon subsystem everything else writes into) → **S2 as soon as the in-app edit surfaces exist** (ship translation's editor early partly *for this*) → **S3 as the wow-onboarding upgrade** once the lexicon machinery is proven. S4 stays on the horizon. Input Monitoring stays exactly what we said it was: a hotkey listener.

Success bar, stated as the user feels it: **week 1: a few taps; week 4: output pastes unedited and reads like their own texting.** Measurable proxy (local, honest): average edits-per-dictation on in-app surfaces trending toward zero — the autocomplete curve, reproduced.
