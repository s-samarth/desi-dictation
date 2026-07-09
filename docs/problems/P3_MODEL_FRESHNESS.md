# P3 · Language moves; our frozen models don't — and we collect no data

## 1 · Problem definition

Two coupled gaps:

1. **Staleness**: our models are snapshots. Slang, names, products, and usage patterns evolve monthly; a model frozen in 2025's data degrades *relative to the language* even while its weights stay identical. P2 fixes today's known OOD words; P3 is the machine that keeps fixing *next* year's, forever.
2. **Data blindness**: we are privacy-first by promise — no telemetry, no audio leaves the device. That promise is the brand, and it also means we have **zero visibility** into real failure modes and **zero training data** from real usage. Every competitor with a cloud pipeline gets an automatic data flywheel; we voluntarily gave ours up. The question: how does a privacy-first product build a data supply and an update loop without becoming the thing it swore not to be?

## 2 · The user & what they face

The user never experiences "staleness" as an event — they experience it as *the tool slowly falling behind their life*. New office jargon after a job switch, this season's meme vocabulary, a new city's place names: each arrives, fails to transcribe, and quietly teaches the user which topics the tool can't handle.

- **Aman** is the canary: his vocabulary refreshes fastest, so he degrades first.
- **Rohan** notices when tech vocabulary lags ("the model doesn't know 'agentic'").
- **Rekha** hits it through product/brand names each season's inventory brings.

And the flip side: these same users, when a transcription fails, currently have *one* channel — a manual mailto. Most failures are never reported; the signal evaporates at the moment of maximum information.

## 3 · Impact on the journey

- Slow-burn churn: no single bad moment, just a widening "it doesn't get me anymore" drift. Uniquely dangerous because it produces churn without complaints — nothing arrives in the feedback inbox to explain it.
- Compounding disadvantage: every month without a data loop, the gap between us and cloud competitors' flywheels widens. This problem's severity *grows over time* — it's rated Medium today and will be High in a year if unaddressed.
- It also starves P1: the fine-tune plan (P1-S4) needs real, in-domain, convention-labeled data. Without a collection mechanism, P1's centerpiece solution runs on synthetic and public data only — strictly worse.

## 4 · Why it's this bad — root causes

**(a) We made a promise that forbids the easy answer.** "Nothing leaves your Mac" is load-bearing for every persona (Rohan runs Little Snitch; Priya has contractual requirements; Suresh's entire trust model). Silent collection is not an option *even at maximum anonymization* — the brand damage of one HN post reading "Desi Dictation phones home" outweighs any dataset. The constraint is real and permanent.

**(b) ASR data has no shortcut.** Text models can learn new words from text scraped anywhere; ASR needs *paired audio+transcript*. New slang written on Twitter doesn't teach a speech model what "delulu" sounds like in an Indian accent mid-Hinglish-sentence. The pairing requirement is what makes freshness expensive.

**(c) Model updates have no delivery path yet.** Even with perfect data, we currently ship model improvements as… a new catalog entry the user must notice and manually download. No versioning, no "update available" surface, no changelog. The pipe is missing at both ends — nothing flows in (data), nothing flows out (updates).

**(d) The labeling bottleneck from P1 applies double here.** Fresh slang has *even less* orthographic consensus than established Hinglish ("riz"? "rizz"?). Whoever labels donated data must apply the P1 convention — freshness work rides on P1's standard existing.

## 5 · Severity

**Medium today, compounding toward High.** Nothing breaks this quarter if we ignore it. But it is the *only* problem in this folder that gets strictly worse with time and whose solutions have long lead times (a data pipeline takes months to accumulate anything trainable). Start the pipeline early precisely *because* the payoff is slow. Also: strategically, a consent-based data pipeline done right converts our biggest structural weakness (no flywheel) into a community asset competitors can't fake.

## 6 · Proposed solutions

### S1 · Opt-in "Donate this one" — explicit, per-item, visible (the cornerstone)

Not a checkbox that silently streams data — a **per-dictation act of donation**. After a dictation (especially a corrected one), the user can hit "Donate this recording + my correction" (menu bar + history entry action). What gets sent: that clip's audio + final text, via a visible channel (v1: the existing mailto with attachments — user literally sees the email; v2: an upload endpoint with a preview screen showing *exactly* the payload). Weekly-digest variant: app locally accumulates flagged items; once a week it asks "you flagged 6 clips this week — review & send?" — review screen, explicit send.

- **Trade-offs**: low volume by design (only motivated users donate — maybe 1–5% participation), biased toward failures (fine — failures are the valuable part) and toward extroverted personas (Rohan, Aman; Rekha never donates). Mailto-with-audio-attachment is clunky above a few MB — v2 endpoint needed fairly soon, which means running a server (first server in a serverless product; scope it to receive-only, no accounts).
- **Complexity**: Low (v1 mailto) → Medium (v2 endpoint + review UI).
- **UX change**: additive only — a new action on history entries and post-dictation. The *review-before-send* screen is the trust-preserving core; it must show the raw payload, always.
- **Solves**: legal/ethical data supply for P1-S4 and P2-S4 fine-tunes; a failure-mode signal channel richer than "report" emails.
- **Doesn't solve**: volume (never big-data scale), passive users' failure modes, and staleness *detection* (donations tell us about failures users noticed, not drift they didn't).

### S2 · Fast-lane vocabulary updates: ship the lexicon, not the model

Decouple "the model knows new words" from "we trained a new model". The OOD lexicon (P2-S2 prompt biasing) + correction map (P2-S3) become a small, versioned data file the app can refresh — slang updates ship weekly as a few-KB download, model retrains ship quarterly. Update check = fetching one static file from GitHub/HF (a *read*, no user data attached — but still disclose it and offer a manual-only mode, because Rohan's Little Snitch will see the request).

- **Trade-offs**: lexicon biasing has bounded power (P2-S2 limits apply — this freshens the *head* of new vocabulary, not deep distribution shift); introduces our first phone-home-shaped network call — must be transparent, off-by-default-checkable, and documented, or it dents the privacy story it's designed to protect.
- **Complexity**: Low-Medium. File format + fetcher + settings toggle; curation becomes a weekly human chore (30 min/week — sustainable for one person, worth automating with a slang-watch list later).
- **UX change**: a Settings line ("Check for word-list updates: weekly / manual") + occasional "New words added: rizz, delulu…" — which is *delightful*, and quietly demonstrates the product is alive.
- **Solves**: the fast half of freshness — new words working within days of appearing, no retraining.
- **Doesn't solve**: acoustic-level novelty and accumulated drift; that still needs S3.

### S3 · Scheduled retrain cadence + in-app model updates

The slow loop: quarterly-ish, fold accumulated donations (S1) + updated public data + lexicon learnings into a fine-tune refresh (P1-S4 machinery), publish to HF, and ship an **in-app update surface**: Models tab shows "Update available (v3 → v4): better slang, fixes X" with one-click download; old model kept until the new one loads clean (rollback = free).

- **Trade-offs**: recurring cost in GPU money and attention (each cycle is real work — realistic cadence for a solo dev is 2–4 retrains/year, promise nothing faster); each release needs the full eval gate or updates become regressions with release notes; version sprawl on HF needs hygiene (deprecation policy).
- **Complexity**: Medium — mostly *process*; the technical pieces (converter, publisher, ModelManager, SHA pinning) exist. New build: the update-available UI + model versioning metadata.
- **UX change**: strictly positive — the app visibly improves over time, the single strongest retention signal a tool can send.
- **Solves**: deep drift, and closes the loop that makes S1 donations *matter* (donors see their failures fixed in the next model — the flywheel's emotional engine: "I made this better").
- **Doesn't solve**: week-scale freshness (S2's job); data volume (S1's ceiling remains).

### S4 · Synthetic freshness: TTS the new vocabulary (stopgap multiplier)

For new slang with no donated audio: generate training pairs synthetically — convention-spelled sentences containing new words, spoken by Indian-accent TTS (or self-recorded 30-second sessions per word batch), fed into the retrain. A known-effective technique for vocabulary injection when paired data is scarce.

- **Trade-offs**: TTS accent/prosody ≠ real Hinglish speech — over-weighting synthetic risks teaching TTS artifacts (keep it a small % of the mix); per-word human curation still needed (what's worth injecting); Indian-accent TTS quality for *code-mixed* sentences is itself shaky — self-recording may beat TTS at our scale, and it's free.
- **Complexity**: Low-Medium as a data-prep script in the existing spike/ tooling.
- **UX change**: none.
- **Solves**: the cold-start problem for every new word (no need to wait for a donation containing it).
- **Doesn't solve**: anything about real-usage distribution; it's a supplement, not a supply.

## Recommended attack

**S2 first** (weekly lexicon updates — cheap, visible, buys time), **S1 v1 immediately after** (donation-by-mailto costs days and starts the clock on data accumulation — the thing with the longest lead time), **S3 as calendar discipline** once P1's fine-tune pipeline exists, **S4 as needed per retrain**. Guardrail on everything: every byte that leaves a user's machine was individually seen and sent by the user. Success bar: 12 months from now, a new slang word works in the app within two weeks of going mainstream, and we've shipped ≥2 model updates trained partly on donated data — while the privacy page still says, truthfully, "we never take anything you didn't hand us".
