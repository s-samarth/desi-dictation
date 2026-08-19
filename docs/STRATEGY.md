# Desi Dictation — Strategy Log (private)

> **This is a dated snapshot, not a permanent verdict.** Strategy will change as the product, the market, and the competitive field move. Each major reassessment should be appended as a new entry below, newest first, so we keep a *history* of what we believed and why. Rambler (Google's Gemini dictation) is one input here — the real subject is overall positioning.
>
> Gitignored — stays local.

---

## Entry 002 — 2026-07-09, 18:06 IST

**Author:** strategy session with Claude — pushback on "not venture scale," plus model-build feasibility, expansion/scope, and bootstrap-vs-funding.
**Trigger:** "Why isn't this venture scale? What's the upside, and how big can the scope go?" Supersedes Entry 001's blunt "not venture-scale" framing — corrected below.

### A · Correction to Entry 001

Entry 001 scored the **current shape** (solo, Mac-only, free beta, one third-party model) and called it "not venture scale." That was right *for that shape* and wrong as a statement about the ceiling. Properly separated: **the base-rate outcome is a strong niche/mid business; the venture-scale outcome is a real but low-probability upside tail that requires going well beyond the Mac-indie shape** (cross-platform + own model + enterprise + likely raising). Don't read Entry 001 as "this can't be big" — read it as "the current trajectory isn't big; the ambition can exceed it."

### B · Revenue & valuation scenarios (5-yr, if cross-platform + enterprise, monetization ≈ MONETIZATION.md)

All estimates, assumptions stated inline.

| Case | Shape | Users / accounts | ARR | Valuation |
|---|---|---|---|---|
| **Worst / base** | Strong Mac-centric indie, little enterprise | 20–50k paying + a few small deals | **$0.3–1M** | $1–5M (or just great cashflow) |
| **Decent / average** | Cross-platform, modest enterprise land-and-expand | 100–300k paying ($15–25 blended) + 50–200 team/enterprise ($2–10k) | **$3–8M** | **$20–60M** (5–8× ARR) |
| **Best** | *The* Indic on-device voice layer, consumer + enterprise + API | 1M+ paying + real enterprise | **$30–80M** | **$300M–1B+** |

- **Venture scale lives in the *best* row**, which VCs fund on plausibility. The **median** is the decent row — a $20–60M company, life-changing but sub-unicorn.
- **Valuation ceiling ≈ a few hundred million to ~$1B**, and why it's not higher: we're **application-layer**, not a foundational-model company (Sarvam's $1.5B is a different animal — full-stack sovereign-AI, $200M+ raised); SaaS multiples (5–10× ARR); low Indian ARPU; the model layer is commoditizing (Google/Sarvam), capping value capture.
- I overstated "can't sell to both people and enterprises." You **can** — **land-and-expand** (consumer → team → enterprise) is a strong model. Caveat: two different motions; the enterprise wedge is narrow-but-sharp (on-device, zero-integration, per-seat, "nothing to audit"), and the big enterprise-voice deals are Sarvam/Gnani turf to avoid.

### C · Can we build a SOTA model? Yes — for our niche.

These are ~800M–1.5B-param ASR models, **not** LLM-scale. Feasible for a skilled DL person + 1–2 DS.

| Path | Verdict | Cost | Time |
|---|---|---|---|
| **Fine-tune** (Whisper/IndicWhisper/Apex on convention-normalized + in-domain data) | **Do this** | Compute ~$400–1,200/run; ~$5–25k full project. **Data labeling $10–60k** (or less-money-more-time via P3 donation + synthetic TTS + self-labeling) — the real cost | **3–9 months**, dominated by *data*, not training |
| **From scratch** | **Don't** | $50k–500k+ compute, ~hundreds-of-thousands of audio hours | Not worth it — fine-tuning inherits the acoustic backbone |

- We will **not** beat Sarvam/Google on *general* Indic benchmarks. We **can** be SOTA on **our specific problem** (Roman-script, convention-normalized, dictation-domain, personalized), because we *define and own the target* (the convention) and the domain. The moat is convention + owned in-domain data + eval discipline — not compute.
- Owning our model also raises the defensibility score (Entry 001 §E, the 55) and removes the Oriserve single-supplier risk.

### D · How to make it venture scale — the reframe

**Stop being a "dictation app." Become "the on-device voice input & output layer for Indic languages — private, personalized, cross-platform."** Dictation is the beachhead. Pitch rung 5, execute rung 0.

| Rung | What you are |
|---|---|
| 0 | Hinglish dictation for Mac (indie) |
| 1 | Cross-platform Indic voice input (Mac/Win/Android/iOS) |
| 2 | Voice-to-*intent* layer: dictation + translate-to-English + structure + tone (the small-LLM layer; ARPU engine) |
| 3 | Own the on-device Indic code-mix **model layer** — use in-app *and* license/SDK |
| 4 | Voice interface for Indic across consumer + enterprise + developers |
| 5 (the pitch) | "The input layer for the next billion" — voice replaces the keyboard for non-English-fluent users |

Rung 5 is what Google's Rambler chases — validation *and* threat. We win only where Google structurally can't: on-device privacy, personalization to your register, cross-platform continuity, depth across code-mixed Indic.

### E · Expansion vectors, prioritized (cheap-highest-leverage first)

1. **Workflow layer (small-LLM features)** — ARPU + differentiation, cheap. First.
2. **Windows** — portable stack, weaker Hindi default → sharper wedge.
3. **Own model + data** — start now in parallel; moat + future B2B/API line; own the data pipeline before scale (it compounds).
4. **Android + iOS** — where India is; the land grab; hardest engineering (on-device ASR+LLM on a mid phone) and the head-on Google fight. The "raise to go fast" inflection.
5. **Language expansion** (Tanglish/Tenglish/Manglish/Benglish…) — "Desi" ≠ "Hindi"; same pipeline; turns Hindi-belt into billion-user story.
6. **Verticals + enterprise** (legal/medical/education) — later, land-and-expand; verticalizing charges 3–5×.
7. **Distribution/integration** (SDK, OEM/IME deals) — moonshot, later-stage.

### F · The small-LLM bet (the most important tech insight)

A 1–3B on-device LLM (llama.cpp, LoRA) is the Pro tier: Hinglish→English translation, structuring, tone/register styling, cleanup, voice-command editing, lexicon-aware rewriting. It turns a commodity dictation app into a moat with pricing power.

**The "you can wait a couple of seconds, we'll style it exactly the way you want" framing is a strategic repositioning** — it changes the Google fight from **speed** (we lose) to **quality + control + privacy** (we can win). Rambler is fast+automatic; we are "worth the two seconds because it comes out exactly as you meant, in your voice, and never left your laptop."

- Fine-tune a small LLM for Hinglish-in/English-out (cheap — LoRA, few hundred $, days).
- **The real technical crux: fitting ASR + small LLM in memory on an 8GB Mac and a mid Android phone.** Prove it runs well on a ₹25k phone → you have a company. If it can't → you're a great desktop-niche product. This is the make-or-break of the venture-scale vision.

### G · Bootstrap vs funding — staged hybrid

Both of your fears are valid and point to the same answer: **bootstrap the wedge, raise for the land grab.**

- **Bootstrap through PMF + early revenue.** Costs are low now (on-device ≈ no COGS, cheap fine-tuning, small team). Prove Hinglish quality (own model), prove people pay, prove retention, own the data — on Mac + Windows. Protects the vision (no early investor pressure to add cloud/telemetry/growth-hacks — the things that would gut the privacy brand) and buys leverage.
- **Then raise from strength** to fund the capital-intensive, time-sensitive phase: mobile/Android eng, language expansion, data-at-scale + model, enterprise GTM. Raise for the land grab against the Rambler clock — *not* to find PMF. Pick mission-aligned investors; keep control because you're not desperate.
- **Vision-friendly capital during bootstrap:** Indic-AI/deep-tech **grants** (IndiaAI-mission/sovereign-AI money), revenue-based financing, super-user/operator angels. A hybrid.
- **Raise trigger:** retention + willingness-to-pay proven; a model/data plan that clearly needs capital; evidence the window is closing.

### H · Team

- **Now:** you (product + super-user + DL) + 1–2 DS on model/data.
- **Gating hire: a strong on-device mobile ML engineer (iOS + Android)** — the hard skill, the gate to rungs 4–5; start looking early.
- **Then:** data/ML engineer (pipeline + fine-tune ops); designer (consumer craft is a moat vs. infra players); GTM/enterprise when B2B pulls.
- **Co-founder question:** solo + venture is harder, and you lack mobile-ML and later GTM. A DS friend → co-founder, or a mobile/business co-founder, strengthens build *and* fundability. Worth serious thought.

### I · Headwinds & tailwinds

**Tailwinds:** next-half-billion coming online who understand > they can type (voice is the interface); on-device AI getting better+cheaper (phone NPUs) makes the privacy bet *more* viable yearly; sovereign-Indic-AI momentum (grants, open models, talent, political priority); small LLMs getting good+fast; rising Big-Tech-data distrust; code-mixing entrenched + growing; the understand-but-can't-produce English gap is huge and durable.

**Headwinds:** Google/Apple/Microsoft free on-device defaults improving in our lane (Rambler = the clock); funded Sarvam/Gnani owning model + enterprise layers; model commoditization; India low ARPU + subscription fatigue; on-device mobile engineering difficulty; consumer paid-vs-free-default conversion; two-motion complexity for a small team.

### J · How to approach it (sequenced)

1. Reframe the company as the voice layer; write rung-5, execute rung-0.
2. Win the wedge decisively: Hinglish quality (own model + convention + owned data) + small-LLM workflow layer + on-device privacy + "worth-the-two-seconds" positioning. Super-users love *and pay*.
3. Bootstrap through PMF + first revenue; take grants/angel money to go faster without growth-VC strings.
4. Expand cheap-first: workflow layer → Windows, training own model in parallel.
5. Hit the mobile/model inflection → raise mission-aligned from strength; hire mobile ML + data eng; consider a co-founder.
6. Then language expansion + enterprise/verticals, land-and-expand.

**One-line verdict:** it *can* be venture scale, and the path is real — but it runs through two hard things: making the stack fly on a cheap phone, and out-crafting Google on the axes Google won't optimize for (privacy, personalization, your-exact-register). Bootstrap until those are proven; then raise hard to win the window.

*(Score note: this doesn't change Entry 001's ~58/100 for the current shape — it clarifies that the shape, not the opportunity, is what's capped. Executing §D–§F is what would move the ceiling.)*

---

## Entry 001 — 2026-07-09, 15:55 IST

**Author:** strategy session with Claude, off the back of the competitor-intelligence build.
**Trigger:** "If Google's Rambler ships, are we over?" — widened into a full positioning + honest-scoring pass.

### A · Where the product actually is, as of this writing

So the scoring below is anchored to a real, not imagined, state:

- **Shipped:** `v0.6.1`, GitHub release **v0.6.1** (2026-08-19) — signed with a stable identity, so updates no longer reset testers' permissions. Private friends-and-family beta; everything free, `LicenseManager.gatingEnabled = false`. (Earlier: v0.5.1 / beta-0.5.1, 2026-07-08, hand-delivered ad-hoc DMGs.)
- **Platform:** macOS 14+, **Apple Silicon only** (Intel permanently unsupported). Not notarized (no $99 Developer ID yet → the Gatekeeper/`xattr` wall, ADDITIONAL_PROBLEMS A1).
- **What works today:** system-wide push-to-talk + toggle dictation; three modes (Hinglish→Apex, English→large-v3-turbo, हिन्दी→Vaani) with Auto model selection; VAD/pause handling; chunked-while-speaking transcription; warm-mic with cool-down; 24 h local history; replacements; hotkey choices; first-launch onboarding; menu-bar-first controls; transparent mailto feedback. Zero telemetry.
- **Model reality:** core Hinglish capability is **Oriserve Apex** (Apache-2.0, *their* fine-tune, not ours) run in whisper.cpp. We own the stack around it, not the model (competitors/15-oriserve).
- **No update channel yet** (A2), **no automated tests** (A9), **no monetization live** (A10).

### B · What's planned (so the score reflects trajectory, not just today)

- **Features** (docs/features/): translate-on-demand + speak-desi-write-English (the LLM layer), structure-your-thoughts; then tone dial, reply mode, personal dictionary, app-aware modes, Indian-number intelligence, quick-capture, read-back, meeting notes, language expansion.
- **Problems** (docs/problems/): P1 Hinglish accuracy (existential) via a published spelling *convention* → honest eval → fine-tune; P2 OOD/profanity; P3 freshness + consent-based data; P4 personalization; plus the 10 additional (A1 unsigned wall, A2 no updates, A3 TAM, A4 moat fragility, A5 clipboard/insertion, A6 permissions, A7 download resume, A8 diagnostics, A9 tests, A10 monetization).
- **Monetization** (docs/MONETIZATION.md): freemium + prepaid annual Pro pass (no auto-renew) + capped lifetime + self-serve team packs; Pro = the LLM feature layer; enterprise via productized self-serve.

**Read the score as: "given this shipped reality and this plan, here is the honest standing."**

### C · The Rambler question, answered honestly

**Not over — but the fantasy version is.** What a competent Rambler kills is *"free Hinglish dictation for every Indian on their phone."* That was never winnable by a solo dev regardless of Rambler — you can't out-distribute, out-data, or out-price Google on Android for the median user. A3 already told us the mass-consumer TAM was small. Grieve that version; it was a mirage.

What Rambler does **not** take, because it structurally can't or won't:

1. **The laptop.** Rambler is a phone keyboard; real work (emails, docs, code, AI prompts, client messages) happens on Mac/Windows, where Google's keyboard isn't the competitor.
2. **On-device privacy — the moat with Google's name carved in it.** Google is the data company; it can never say "nothing leaves your device, there is nothing to audit." Enterprises (law/CA/clinics) and privacy-conscious professionals are a real, monetizable niche Google cannot serve.
3. **Transcribe→translate-to-English** — the sleeper wedge. Our deepest persona insight (*Indians understand English but can't produce it*) → "speak messy Hinglish, get fluent professional English." Rambler *cleans up* speech; it doesn't deliberately turn broken Hinglish into polished English. A workflow, not a dictation mode — harder for a keyboard to own.
4. **Roman-script output** (narrow, risky — Google could close it; don't bet the company on it) and **personalization + cross-platform continuity** (per-user assets not in Google's shared cloud model).

Two honest counters so this isn't cope: Rambler's flagship-gating spares mid-market India for ~2–3 years, but **that segment has near-zero willingness to pay** — "we serve the phones Google can't" is a trap. And the Roman-vs-Devanagari gap is real today but not guaranteed tomorrow.

**Net:** the realistic prize — a few thousand paying professionals + a few dozen small enterprises, a sustainable indie business, ₹-real not venture-scale — barely shrinks under Rambler, because it was always held down by TAM and platform, not by the absence of a competitor.

### D · Positioning: refocus, not pivot

Everything built serves the narrower target; a pivot would waste it. What changes is **emphasis**:

- **Lead with transcribe→translate-to-English and the privacy/enterprise story** — not "free consumer Hinglish."
- **Be the deliberate workflow app, not the casual keyboard.** On Android (when we get there) we're what someone *opens* for real output, not what they text friends with — so we're not fighting Gboard on its turf.
- **Get to Windows** (weaker Hindi default than Apple → sharper wedge; stack is ~portable) and **Android** as reach-for-the-workflow.
- **Accept the shape:** a good small business serving professionals + enterprises, not a billion-user capture.
- **Stop pitching the model as the moat** (it's Oriserve's, commoditizing). The durable six: on-device privacy · consumer craft · personalization · the feature layer · India-native GTM · cross-platform continuity.
- **Reach feature parity fast** where we're *behind* the category (personal dictionary, per-app modes — competitors/PATTERNS §1).

The one condition under which the answer flips to *pivot*: if the only version worth your years is the billion-user consumer prize. Then Rambler is the signal to point this skillset elsewhere. If a defensible ₹-generating indie product for professionals/enterprises is worth building, it's mostly built already.

### E · The scoring (honest, anchored to §A/§B)

| Dimension | Score | Rationale |
|---|---|---|
| Realness of the pain | **85** | Hinglish-production gap is genuinely painful and unmet. |
| Realistic market size (TAM) | **40** | Mac-only today, Android needed, Google looming; willingness-to-pay concentrated in a thin professional/enterprise slice. The weak leg. |
| Defensibility / moat | **55** | On-device privacy + craft + personalization are real; the *model* isn't ours and is commoditizing. |
| Timing | **45** | Early, but a giant is entering the same door. |
| Founder–product fit | **85** | A real, thoughtful, working product shipped solo. Strongest card. |
| What's already built | **78** | Good bones; refocus needs positioning, not a rebuild. |
| Monetization clarity | **50** | Path exists (prepaid pass + enterprise per-seat) but Indian pricing is hard and the niche is narrow. |

**Overall: ~58 / 100.**

Read it correctly: not "drop this," not "rocket." It's **"real, hard, niche, sustainable-if-refocused, not-venture-scale"** — and Rambler barely moves it, because the number was always held down by TAM and platform, not by competitor absence.

- **Moves toward ~70:** nail transcribe-to-English as the wedge; land 3–5 paying small enterprises on the privacy story; ship on Windows/Android as the deliberate workflow app; execute P1 (Hinglish quality) so "best Hinglish" is defensible brand-truth.
- **Drags toward ~40:** insisting on the free-mass-consumer-Android fight, where we lose to Google on every axis that matters; or P1 stalling so quality never separates us from the free defaults.

### F · What this implies for near-term priorities (this snapshot's opinion)

1. **A1 + A2 first** (Developer ID + update channel) — monetization and iteration prerequisites; nothing else compounds without them.
2. **P1 Hinglish quality** — the whole brand truth; existential regardless of Rambler.
3. **Transcribe→translate-to-English** as the flagship feature and the wedge, not an add-on.
4. **Parity features** (personal dictionary, per-app modes) — we're behind the category here.
5. **Privacy/enterprise one-pager + first paid conversations** — validate the defensible slice early.
6. **Windows port planning** — keep the Kit/App split clean so it stays cheap.

### G · Triggers that should force a new entry in this log

- Rambler actually ships — re-rate its quality, output script, and device reach against reality (not the announcement).
- Apple/Microsoft materially improve Hinglish/code-mix in an OS release (erodes the wedge).
- Sarvam or anyone ships a *consumer* Indian dictation app (not just an API).
- We ship our *own* fine-tuned model (P1-S4) — defensibility score should rise.
- First real willingness-to-pay data (beta price question, first paid users).
- Any decision to go Windows/Android — TAM and timing scores move.

---

*Next entry goes above this line.*
