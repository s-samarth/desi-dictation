# P2 · Out-of-distribution words: cuss words, slang, and names get censored or mangled

## 1 · Problem definition

Words outside the model's training distribution come out wrong or don't come out at all. Three distinct sub-classes, often conflated:

- **Deliberately suppressed vocabulary**: profanity/cuss words. Whisper-family models were trained with filtered/sanitized data and OpenAI ships suppressed-token lists; the model has learned to avoid or euphemize them ("what the f—" → "what the heck", Hindi gaalis → dropped or mangled). The AI refuses to write what the user actually said.
- **Modern slang**: "rizz", "delulu", "npc behaviour", "cooked", Hinglish internet-isms ("scene on hai", "vella") — postdate or fall outside training data; the model snaps them to the nearest in-distribution word ("rizz" → "rise").
- **Proper nouns & niche vocabulary**: names (Saraswat), brands, tech terms, local places — classic ASR OOV territory.

The user said a word; the transcript contains a different word or a hole. For a tool whose promise is *"likha waisa hi jayega"*, this is a broken promise — and uniquely infuriating because the user can't fix it by speaking more clearly. The model isn't mishearing; it's *refusing or unable*.

## 2 · The user & what they face

- **Rohan** texting his college group: half the affection in that chat is profane ("abe ch—, kahan hai tu"). Dictation that sanitizes it produces texts that don't sound like him — his friends would literally notice ("tu itna formal kyun likh raha hai?"). He stops using dictation for his most-frequent chat context.
- **Aman** speaks the freshest slang of any persona; every snapped-to-wrong-word slang term is a visible error to him and his audience.
- **Priya** writes brand names and campaign jargon all day; each mangled brand name is a correction, and corrections are her churn trigger.
- Cross-cutting: casual chat — WhatsApp, the single biggest dictation surface for every persona — is exactly where profanity and slang concentrate. **The OOD problem is worst precisely in the highest-volume use case.**

## 3 · Impact on the journey

- It caps dictation at "professional messages only". The moment a user learns the tool bowdlerizes them, they mentally file it as "for office stuff" — usage frequency collapses to a fraction of potential.
- It breaks the authenticity promise that differentiates us: we say "written the way you text your friends"; texting-with-friends is where we fail hardest. The marketing and the failure overlap perfectly, which is embarrassing in demos.
- Slang errors are *shared publicly* — a mangled message pasted into a group chat is seen by ten people. Errors in this class have social blast radius.
- Trust asymmetry again: a user who catches the tool *silently substituting words* trusts nothing afterwards — worse than an obvious mistranscription, because substitution feels like editorializing.

## 4 · Why it's this bad — root causes

**(a) Deliberate suppression baked into the model.** Whisper's training corpus was filtered, and standard decoding uses a `suppress_tokens` list. Fine-tunes (Apex) inherit the base model's learned aversion even where explicit suppression is off — the *weights* under-represent profanity. So this is partly a decoding flag and partly learned behaviour; the flag is easy, the weights are not.

**(b) Distribution lag is structural.** Slang moves in months; our model snapshot is frozen at its training cutoff and our *fine-tune* data is even narrower. (Ongoing freshness is P3; this doc owns *making today's known OOD words work*.)

**(c) Hinglish profanity is double-OOD.** Hindi gaalis in Roman script hit both the profanity filter *and* the Hinglish orthography chaos (P1): "bhoss—" has a dozen spellings, none in training data. The intersection of two hard problems.

**(d) Tokenizer granularity.** OOD words decompose into rare subtoken sequences with low prior probability — the beam prefers a common word that shares acoustics ("rizz"→"rise", "vella"→"fella"). This is the same mechanism as P1's ambiguity but with a systematic bias *against* the correct answer.

**(e) FM#16 constraint.** We can't fix OOD by adding tokens: whisper.cpp rejects models with extended vocab (Trelis lesson). Any solution must work within the existing 51,866-token vocabulary.

## 5 · Severity

**High.** Not existential like P1 — the app works without gaalis — but it's a hard ceiling on the "texting" use case, which is the highest-frequency surface and our wedge. Also, uniquely, it's a *differentiation opportunity*: every cloud competitor (Apple, Wispr) censors harder than we do, for policy reasons we don't share. An uncensored, on-device, "writes what you actually said" dictation tool is a marketable position no big company will copy. Solving P2 isn't just fixing a bug; it's claiming free territory.

## 6 · Proposed solutions

### S1 · Decoding-level un-suppression (do first, this week-class)

whisper.cpp exposes the suppression machinery: ensure `suppress_blank`/`suppress_nst` (non-speech tokens) settings aren't over-suppressing, and check whether any profanity-adjacent token suppression is active in our decode params. Add profanity-heavy test clips (record them ourselves — free, in-domain) to a small OOD eval suite to measure the actual effect.

- **Trade-offs**: might be a partial fix only (weights still biased, per 4a); zero downside otherwise — this is removing a muzzle, not adding a system.
- **Complexity**: Trivial-to-Low. Param audit + eval clips. Days.
- **UX change**: none. Words that were dropped start appearing.
- **Solves**: whatever share of censorship is decode-time. Unknown until measured — that's the point of doing it first.
- **Doesn't solve**: learned weight-level aversion; slang snapping; names.

### S2 · Lexicon biasing via initial prompt (shared with P1-S2 / P4)

Maintain an OOD lexicon — common gaalis in convention spelling, current slang top-100, plus the user's personal words (P4) — and inject it through Whisper's initial-prompt mechanism to raise those tokens' priors during decoding. One mechanism serves three problems (P1 convention seeding, P2 OOD words, P4 personal vocabulary), which is why it should be built as a proper subsystem, not a hack.

- **Trade-offs**: prompt space is finite (~224 tokens) — the lexicon must be *selected*, not exhaustive; prompt biasing can cause false positives (hearing "rizz" where "rise" was said — the inverse error); silence-hallucination risk needs re-testing (our old enemy).
- **Complexity**: Medium. Engine plumbing + lexicon curation + eval.
- **UX change**: none directly; enables P4's "it learns my words" experience later.
- **Solves**: names and bounded slang/gaali lists — the head of the OOD distribution.
- **Doesn't solve**: the unbounded tail; words whose acoustics the model genuinely can't map.

### S3 · Post-processor OOD correction map (the pragmatic hammer)

Extend PostProcessor with a curated snap-back map: known model failure → intended word ("rise"→"rizz" *only* when flagged as chat-register, "fella"→"vella", euphemism→gaali). Built from our own OOD eval failures and beta reports (P3 pipeline feeds this). Deterministic, shippable weekly *without* model releases — the correction map updates faster than any model can.

- **Trade-offs**: it's whack-a-mole by design; context-blind rules risk wrong substitutions ("rise and shine" must not become "rizz and shine" — rules need context guards or confidence gating, which caps coverage); a growing rule file is tech debt with a smell.
- **Complexity**: Low per rule, Medium to keep sane (needs tests per rule and a register/context guard concept).
- **UX change**: none; pairs naturally with a user-visible "word fixes" list (P4) so users can disable a rule that misfires for them.
- **Solves**: the recurring, reported, high-frequency failures — fast.
- **Doesn't solve**: novel words on first encounter; anything acoustic.

### S4 · Fine-tune with profanity/slang in the data (rides P1-S4)

When the P1 fine-tune happens, deliberately include profanity and slang: self-recorded gaali-rich casual speech, slang-dense clips, convention-normalized labels. Fixes the *weights*, not just the decode.

- **Trade-offs**: this data cannot be crowdsourced politely (self-record + close friends — awkward but effective); publishing an explicitly profanity-capable model needs a straight-faced model card (position: faithful transcription, standard for ASR research); small data risk of over-indexing (model starts hearing gaalis in noise — eval gate needed).
- **Complexity**: incremental on top of P1-S4 (which is High); the marginal cost is data collection, ~days.
- **UX change**: none.
- **Solves**: the learned-aversion root cause (4a) — the only solution here that does.
- **Doesn't solve**: post-training novelty (P3's territory), tail names.

### S5 · Explicit "Chat mode" register toggle (UX-level, consider carefully)

A register switch — *Professional / As-I-speak* — controlling suppression, the S3 snap-back map, and capitalization/punctuation style. Defensible logic: the same user genuinely wants both registers at different moments (Rohan's Slack vs. Rohan's college group), and app-aware modes (IDEAS.md #4) could set it automatically per target app.

- **Trade-offs**: a toggle admits the model can't infer register (true, but toggles are friction and get forgotten in the wrong state — the classic "why is my boss's email calling him bhai" incident is *caused* by this solution); auto-per-app mitigates but adds config surface.
- **Complexity**: Low mechanically; the cost is UX conceptual load.
- **UX change**: significant — a new concept in the mental model. Only worth it bundled with app-aware modes so the common case is automatic.
- **Solves**: the "wrong register at the wrong time" *social* risk that S1–S4 create once profanity flows freely.
- **Doesn't solve**: any transcription quality issue; purely a safety valve.

## Recommended attack

**S1 immediately** (audit + OOD eval suite — we may be muzzling ourselves for free), **S3 as the standing weekly mechanism**, **S2 built once properly** (it's shared infrastructure with P1/P4), **S4 folded into the P1 fine-tune**, **S5 only alongside app-aware modes**. Success bar: the gaali test set (self-recorded, ~50 utterances) transcribes verbatim ≥90%, and "it wrote exactly what I said 💀" becomes a screenshot people share — that screenshot is marketing no budget buys.
