# P1 · Hinglish transcription isn't reliable enough — and it's the whole product

## 1 · Problem definition

Hinglish mode — our headline, our differentiator, the reason the app exists — makes too many word-level errors. Wrong words picked up, spellings that don't match how anyone texts, occasional whole phrases lost. Our own eval numbers say the same thing the gut does: hinglish crWER sits far above the english (4.2%) and hindi (10.8%) suites — the *worst* number belongs to the *best-offering* mode. A user can forgive a rough edge in a bonus feature; they will not forgive it in the one thing the app is named for. **This product depends on solving this problem.**

## 2 · The user & what they face

Every persona hits this, because Hinglish is the wedge for all of them (PERSONAS.md matrix). Concretely:

- **Rohan** dictates a WhatsApp reply, gets "scene kya he" / "sin kya hai" / "seen kya hai" on different days for the same phrase — he stops trusting it for anything he won't proofread, which defeats the point of dictation.
- **Rekha** says a supplier's name and a quantity; one wrong word in an order message is a real-money error, so after one bad experience the tool is "kharab".
- **Aman** dictates fast, colloquial, heavily code-mixed speech — exactly the input where the model is weakest — and he's our highest-volume user.

The cruel part: these users *can* judge output quality instantly (it's their own words), so every error is visible. There is no "close enough" hiding.

## 3 · Impact on the journey

- **First-run moment of truth**: onboarding → first dictation → the user reads the output. If 2 of 20 words are wrong, the verdict forms in ten seconds and the app becomes a novelty they demo once, not a habit.
- **The correction tax**: each error converts dictation (fast, flow-state) into editing (slow, cursor-hunting). Above roughly 1 correction per 2–3 sentences, dictation is *slower than typing* for a decent typist — the value proposition inverts.
- **Trust decay is asymmetric**: ten perfect dictations build less trust than two bad ones destroy. Errors early in a user's life are ~fatal; the same error rate after a month of good service is tolerated.
- It also poisons downstream features: translation and structuring both consume the transcript — every transcription error propagates into them (garbage in, garbage out; TRANSLATION.md's edit-first flow exists precisely because of this problem).

## 4 · Why it's this bad — the root-cause dig

**(a) Hinglish is not a language; it's an unstandardized *practice*.**
Your interpretation is correct and it's the deepest cause. Hinglish is Hindi phonology carried into Latin script by ad-hoc, per-person convention. There is no orthography — no dictionary, no academy, no spell-checker ever enforced one. "नहीं" is texted as *nahi, nahin, nhi, nai, nhi.* by different people from the *same* city, same age, same friend group. Crucially, each individual is fairly self-consistent, but the population is wildly inconsistent. So "correct Hinglish spelling" is not a fact about the world — it's a fact about *a person*. Any single model output is therefore guaranteed to look "wrong" to a large share of users even when it's phonetically faithful. This is a problem no amount of raw model scale fixes, because the target itself is ill-defined.

**(b) Therefore the training data is inconsistent by construction.**
Whatever Hinglish data exists (transcribed YouTube, crowdsourced labels, synthetic transliteration) embeds each labeler's personal orthography. The model learns a *superposition* of spelling conventions and samples from it — which is exactly the "nahi today, nahin tomorrow" instability users see. Worse, much "Hinglish" training data is machine-transliterated from Devanagari, which produces stiff academic romanization (ITRANS-ish *nahiin*) that no human texts. Low data volume compounds it: code-mixed Hindi-English speech with Roman-script labels is one of the scarcest resource categories in speech ML — that's *why* only a handful of models (Oriserve's) exist at all, and why our model research found so few.

**(c) Code-switching is intrinsically the hardest ASR setting.**
Mid-sentence language switches break the assumptions monolingual models optimize for: the acoustic model must track two phone inventories, and the implicit language model must accept sequences that are ungrammatical in *both* languages. Errors concentrate exactly at switch points ("deck ready rakhna") — which in Hinglish is every few words.

**(d) Ambiguity is genuinely unresolvable at the acoustic level.**
"He/hai", "may/mein/main", "the/de/dhe": phonetically near-identical, only disambiguated by which language the *next* word turns out to be in. Whisper-class models have limited context and no user-specific prior. Some Hinglish error rate is irreducible without context modeling — worth knowing so we aim at the reducible part.

**(e) Accents are real but secondary.** Indian-accent robustness is a universal ASR problem (you're right), and our Hindi-centric fine-tune already handles it better than stock Whisper. It amplifies (a)–(d) but isn't the distinctive cause. Parking it.

**(f) Our measurement inherits the disease.** crWER's collapse rules (long vowels, VARIANTS map) paper over *some* spelling variance, but the eval references themselves (CS-FLEURS labels) embed labeler orthography — part of our "bad numbers" is the metric punishing legitimate variants. We can't trust improvement claims until the yardstick is clean. (Also why turbo "beat" Apex on read-speech CS-FLEURS — domain and orthography mismatch, not model truth.)

## 5 · Severity

**Existential.** Not "high" — existential. English dictation is a commodity (Apple, MacWhisper, Wispr Flow all do it); shuddh Hindi is niche. Hinglish is the entire moat. If Hinglish reliability stays where it is, the honest product is "a free English dictation app with a flaky Hindi gimmick", and that product loses. Every other problem in this folder matters only if this one is solved. Priority: above all features, including the translation suite.

## 6 · Proposed solutions

Ordered from foundation to moonshot. They are **not alternatives** — S1 is a prerequisite for S3–S5 to even be evaluable, and the realistic plan is S1 → S2 → S4 in sequence, with S3 continuous.

---

### S1 · Define the standard: the Desi Dictation Hinglish Convention ("one true spelling")

Your instinct, formalized: since no global Hinglish orthography exists, **we publish one** — a documented convention (a few hundred high-frequency Hindi words + rules for the tail: no doubled long vowels, `aa` not `a` for आ, `nahi` canonical, `kyunki` canonical, etc.). Biased by you — fine; a benevolent, *consistent* dictator is exactly how orthographies have always formed (Johnson's dictionary, Webster's spellings). Consistency beats correctness, because correctness doesn't exist here.

It becomes the spine of everything: eval references get re-labeled to the convention (fixing 4f), fine-tuning targets get normalized to it (fixing 4b *for our model*), and a post-processing normalizer enforces it at runtime.

- **Trade-offs**: our canon *will* differ from any given user's habits — "consistent but not mine" replaces "random". That's a strict improvement (predictable errors are learnable and, crucially, fixable by P4 personalization — S1 makes P4's job finite). Cost is mostly careful linguistic judgment work: ~2–3 days for the top-500 word list + rules doc, then ongoing accretion.
- **Complexity**: Low. The runtime piece is a deterministic normalizer (extend the existing PostProcessor + VARIANTS machinery into a proper canonical map). No model changes.
- **UX change**: none visible except *stability* — the same phrase always comes out the same way. That alone reads as a big accuracy jump to users, because "differently wrong each time" feels broken while "consistently spelled" feels intentional.
- **Solves**: spelling instability (the largest *perceived* error class), measurement trustworthiness, and it defines the target for everything downstream.
- **Doesn't solve**: genuinely wrong words (acoustic errors), dropped phrases, code-switch-point errors. A normalizer can't fix hearing "sin" for "scene".

---

### S2 · Runtime context & decoding fixes (squeeze the current model)

Before touching training: exploit whisper.cpp's levers. (i) **initial-prompt biasing** — feed a Hinglish-convention seed prompt (and later, P4's user lexicon) so decoding priors favor our spellings; (ii) beam search vs. greedy A/B on the eval set; (iii) temperature/entropy-threshold tuning for code-switch stability; (iv) test whether feeding the previous *final* sentence as prompt context helps mid-conversation dictations (we disabled cross-chunk context to stop degradation — but a *curated* prompt is different from raw rolling context).

- **Trade-offs**: bounded upside (maybe 10–20% relative on spelling-adjacent errors, little on hard acoustic errors); risk of prompt-induced hallucination on silence (must re-run the silence/NaN gauntlet); beam search costs latency (~1.3–2× decode time — measure against the perceived-speed work we already did).
- **Complexity**: Low-Medium. Days, all in `WhisperCppEngine`, fully eval-measurable.
- **UX change**: none, or slight latency increase if beam wins on quality — expose nothing, decide by eval + feel.
- **Solves**: a slice of spelling variance and some switch-point flips, cheaply and immediately.
- **Doesn't solve**: the data problem. This is optimization, not repair.

---

### S3 · Fix the yardstick: convention-based eval + personal eval set

Re-label a 200–500 utterance eval set to the S1 convention (mix: CS-FLEURS re-normalized + your own ~20 real-dictation personal set + beta-donated clips from P3's pipeline when it exists). Add an error *taxonomy* to the report: spelling-variant vs. wrong-word vs. dropped vs. switch-point — because the fix differs per class and today one number blurs four diseases.

- **Trade-offs**: labeling is tedious human work (~1–2 days for 200 utterances); a self-labeled set risks overfitting to your own speech — mitigate with 2–3 friends' voices. Zero user-facing risk.
- **Complexity**: Low. Extends existing evals/ tooling; the taxonomy is a classifier over alignment diffs (mostly the existing normalizer machinery run in "diagnose" mode).
- **UX change**: none. Pure instrument.
- **Solves**: knowing whether anything else in this doc actually works. Currently we cannot distinguish "model got better" from "metric got kinder".
- **Doesn't solve**: nothing user-visible by itself. It's the prerequisite for honest iteration — skipping it means flying blind through S4/S5.

---

### S4 · Fine-tune on convention-normalized data (the probable centerpiece)

FINETUNING.md's plan, now with a target worth training toward: take Apex (or its base), build a training set where **every label is normalized to the S1 convention**, and fine-tune. Data sources: (a) existing open Hinglish/Hindi sets re-transliterated through our normalizer; (b) synthetic — Devanagari Hindi corpora transliterated to convention-Hinglish, paired with TTS or existing audio; (c) the P3 opt-in donation pipeline (real usage audio+corrections — small but gold); (d) your own dictation history, self-corrected (free, perfectly in-domain).

- **Trade-offs**: real cost (cloud GPU, ~$50–300 per serious run per FINETUNING.md estimates) and real time (data prep dominates — weeks of calendar, not compute); risk of regression on English-mixed segments (must gate on the english suite too); synthetic transliteration data can teach transliteration artifacts if over-weighted. Also a maintenance commitment: we become a *model producer*, not just a consumer — every future improvement cycle repeats this.
- **Complexity**: High — the highest-effort item here, but the machinery mostly exists (conversion pipeline, quantization, HF publishing, evals). The new muscle is training-data engineering.
- **UX change**: none in flow; one more "model update available" moment (needs a lightweight in-app model-update path — small feature, worth building anyway for P3).
- **Solves**: this is the only lever that attacks wrong-*word* errors and switch-point errors at the source, and it bakes the convention into the model instead of patching it after.
- **Doesn't solve**: per-user spelling identity (that's P4), slang drift (P3), and it won't reach English-suite numbers — code-switching keeps an irreducible penalty. Success = "reliably good", not "4%".

---

### S5 · Two-stage rescoring: small LLM cleans the transcript (moonshot, shared engine)

Once the translation/structuring LLM ships (features docs), add a "Hinglish repair" pass: the 1.5–3B model gets the raw transcript + convention rules + user lexicon and fixes spellings, switch-point confusions, and obvious mis-hearings using sentence-level context Whisper lacks ("sin kya hai" → "scene kya hai" is trivial for an LLM with context).

- **Trade-offs**: latency (+1–2 s per message — directly fights our speed promise; may need to be opt-in or only-above-N-words); hallucination risk (an LLM that "fixes" your words can also rewrite them — needs a strict edit-distance leash and the no-invention gate from STRUCTURE_THOUGHTS.md); memory pressure on 8 GB machines during dictation (unlike translation, this runs on *every* dictation).
- **Complexity**: Medium once the LLM engine exists (it's a prompt + guardrails), High before it.
- **UX change**: visible added latency per dictation, or a toggle ("Extra polish — slower"). Toggles are defeat, so target: fast enough to be default or don't ship.
- **Solves**: contextual disambiguation — the error class S1–S4 can't reach (the 4d irreducible slice becomes reducible).
- **Doesn't solve**: anything if the base transcript is too wrong (rescoring amplifies a good model, can't resurrect a bad one) — hence it's sequenced last.

---

## The recommended line of attack

**S1 (convention) → S3 (honest eval) → S2 (cheap decoding wins) → S4 (fine-tune) → S5 (rescoring)**, with P3's data pipeline started early because S4 starves without data. First milestone that matters: *the same 20-sentence personal test read on three different days produces byte-identical output for ≥90% of words.* Consistency first; accuracy follows the flywheel.
