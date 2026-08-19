# Monetization Plan (private)

> Status: strategy doc, decisions pending. Written 2026-07-09, while everything is free in beta and `LicenseManager.gatingEnabled = false`. Companion docs: GTM.md, MARKET_STUDY.md, problems/ADDITIONAL_PROBLEMS.md (A10 flagged the urgency: the free/paid boundary is being decided silently by today's defaults).

## 0 · The lay of the land: what comparable products actually charge

Before evaluating models, the real-world map — all directly comparable (Mac dictation / voice-to-text / Indian speech AI), all verified July 2026:

| Product | Model | Price | Notes |
|---|---|---|---|
| **MacWhisper** | Freemium + one-time lifetime | **€59 (~$69) lifetime Pro** on Gumroad; App Store variant $29.99/yr sub or $99.99 lifetime | The product we cloned our UX from. Solo dev (Jordi Bruin). Free tier is genuinely useful; Pro adds batch, SRT export, diarization. 25% discount for students/journalists. Famously sustainable indie business. |
| **Wispr Flow** | Freemium subscription (VC-funded) | Free: 2,000 words/week cap → **Pro $12–15/mo** ($144/yr); Teams $10–12/user/mo (3-seat min); Enterprise custom (SSO, audit logs, HIPAA BAA) | Cloud-based — must charge recurring because they pay recurring inference costs. The word-cap freemium converts on *usage*, not features. Student 50% off. |
| **Superwhisper** | Freemium + sub + lifetime, all three | Free tier; **$8.49/mo / $84.99/yr / $249.99 lifetime** | On-device like us. The triple-option structure lets users self-select; lifetime priced at ~3 years of subscription. |
| **VoiceInk** | Open source (GPL) + paid binaries, one-time | **$25 (1 Mac) / $39 (2) / $49 (3) / $159 (10 Macs)** | The closest structural comparable: indie dev, on-device whisper.cpp, code on GitHub (4,400+ stars), yet people pay for the convenient signed binary. Proof that open source + one-time works in this exact niche. |
| **AudioPen** | Prepaid pass, no auto-renew | **$99/1yr, $159/2yr, ~$33/3mo** — one-time payments for a time window | Indie voice-to-polished-text. The "subscription without the subscription": recurring revenue economics with one-time payment psychology. Very relevant to India (see §2). |
| **Voicenotes** | Freemium subscription | $14.99/mo, $99.99/yr (44% annual discount), Team $49/mo | Voice-notes/structuring space — comparable for our Structure-Your-Thoughts feature. |
| **Sarvam AI** | API pay-per-use | **₹30/hour of audio** STT (~$0.35/hr), 22 Indic languages, ₹1,000 free credits | The Indian speech-API benchmark — this is the price ceiling any API offering of ours must live under. |
| **Setapp** (channel) | Bundle marketplace | 70/30 revenue share (85/15 single-app); usage-weighted payout | A distribution channel, not a model — relevant later (§3.8). |

Reading the map: **on-device products charge one-time or cheap subs; cloud products must charge real subscriptions** (their COGS recur). Our COGS per user is ~zero after download — that's a structural pricing advantage: we can profitably sell at prices cloud competitors would bleed at. Every plan below should exploit this.

---

## 1 · Our constraints (what any plan must respect)

1. **Beta promise**: "everything free during the beta" is in writing (guide PDF). Whatever ships later must not *take away* what beta users have — grandfather or gate only new things (A10).
2. **Open models**: our models are Apache-2.0 on public HF. Anyone can load Apex into MacWhisper today. The *models* can't be the paid wall retroactively — but future self-trained models can be licensed differently (a per-release decision, flagged in A4).
3. **Privacy brand**: no ads (see §3.7 — rejected with reasons), no data monetization ever, and any license check must be privacy-respecting (Gumroad license verification is a single HTTPS call — disclose it; offline grace period).
4. **Indian context**: subscription fatigue is real — Indian consumers pay when there's continuous value, high-frequency use, and visible outcomes, but recurring charges compete psychologically with essentials; UPI is the expected rail (auto-renew card subscriptions are friction; UPI one-time payments are frictionless). One-time and prepaid-pass structures fit the market better than Western-style auto-renew.
5. **Solo dev**: no sales team, no support org. Anything enterprise must be productized, not sold via 6-month sales cycles.
6. **Two-market reality**: our buyers split into India-priced (₹ psychology, UPI) and global-Indian-diaspora/expat (US/EU purchasing power, used to $10/mo tools). Purchasing-power pricing (different price by region) is standard on Gumroad and we should use it from day one.

---

## 2 · The menu: every monetization model, evaluated

### 2.1 One-time lifetime license (the MacWhisper/VoiceInk model)

Pay once (₹X / $Y), own the app forever, free updates.

- **Why good**: perfectly matches Indian payment psychology (one UPI scan, no mandate, no recurring guilt); matches our cost structure (zero marginal cost per user); highest-trust model for a privacy product ("we don't need a relationship with your credit card"); proven *in our exact niche twice* (MacWhisper €59 sustainable for years; VoiceInk $25–39 works even with GPL source public). Simplest to implement — Gumroad license key + existing LicenseManager.
- **Why bad**: revenue is a function of *new* users only — no compounding; every sale is re-earned. Misaligned with our ongoing costs (model retraining GPU money recurs; lifetime buyers consume updates forever). "Lifetime" is a liability if the product lives 10 years. Ceiling: at ₹999 one-time × plausible Indian Mac dictation TAM, this is pocket-money-to-decent-side-income, not a company (see A3).
- **Feasibility**: trivially high. **Verdict: strong candidate for the app itself, but must be paired with something recurring for sustainability.**

### 2.2 Subscription (the Wispr Flow model)

Monthly/annual recurring (₹X/mo).

- **Why good**: compounding revenue, aligned with ongoing costs (retraining, support, new features), the only model that funds a real product roadmap; annual-billed subs (Voicenotes' 44% annual discount pattern) reduce churn.
- **Why bad**: hardest sell in India — recurring digital charges face documented resistance, auto-renew via cards is friction-heavy, and *we lack the cloud costs that justify subscriptions in users' minds*. "Why monthly? It runs on my laptop!" is a fair question we'd face in every review. Wispr Flow can charge $15/mo because it visibly does cloud AI work; an on-device app charging monthly reads as rent-seeking. Superwhisper's $8.49/mo works — but note they *also* offer lifetime, conceding that a chunk of the market refuses subs.
- **Feasibility**: medium (Gumroad supports memberships; UPI auto-pay mandates exist but are clunky). **Verdict: wrong as the primary model for the app; right for genuinely recurring value (see 2.3).**

### 2.3 Prepaid pass — subscription economics, one-time psychology (the AudioPen model) ⭐

Pay for a time window (₹X for 12 months of updates + premium features), **no auto-renew**. When it lapses: the app keeps working, premium features freeze at last state or degrade gracefully; renewing is a deliberate act.

- **Why good**: this is the India-shaped recurring model — one UPI payment, no mandate, no surprise charges, renewal is opt-in (respect, not extraction). AudioPen proves it works for an indie voice product at $99/yr. It funds recurring costs *and* keeps the trust story intact ("we never auto-charge you"). Also creates a natural annual moment to demonstrate value ("here's what shipped this year") — the anti-churn email writes itself.
- **Why bad**: renewal rates are lower than auto-renew subs (deliberate renewal = deliberate churn opportunity); revenue is lumpy; requires the year's updates to be *visibly* worth renewing for (pressure on roadmap velocity — which we claim as our advantage anyway).
- **Feasibility**: high (Gumroad supports non-renewing durations; LicenseManager checks expiry). **Verdict: the leading candidate for the Pro tier.**

### 2.4 Freemium tiering — what's free vs. paid (orthogonal to 2.1–2.3)

Not a payment model but the boundary question. Three boundary types seen in the wild:
- **Usage cap** (Wispr Flow: 2,000 words/week): converts heavy users. *Wrong for us*: enforcing a cap on an offline app is hostile (it's their CPU), trivially crackable, and poisons the "it's yours" story.
- **Feature gate** (MacWhisper: batch/export are Pro): converts by need. Right for us — gate things that cost *us* ongoing work.
- **Time gate** (trials): fine as a supplement (14-day Pro trial, à la Wispr).

**Our free/paid line (proposal)** — free tier must remain the best free Hinglish dictation on earth (it's the wedge, the moat-builder, and the beta promise):

| Free forever | Pro |
|---|---|
| Core dictation, all 3 language modes | **Translation suite** (translate-on-demand + speak-desi-write-English) |
| All current models (Apex/Parakeet/Turbo/Vaani/VAD) + updates to them | **Structure Your Thoughts** (all output styles) |
| Hotkeys, toggle mode, history 24h, replacements | Tone dial / reply mode / prompt templates (IDEAS.md #1/#2/#5) |
| Personal lexicon basics (P4-S1 one-tap corrections) | WhatsApp-import cold start (P4-S3), extended history (30d), app-aware modes |
| Weekly word-list updates (P3-S2) | Early access to new fine-tuned models (window-exclusive, then free) |

Logic: everything Pro either (a) rides the LLM engine — features that cost real development and feel "AI-premium", (b) is convenience/power layered on a complete free core, or (c) is time-windowed early access rather than permanent exclusivity (keeps the open-models promise intact). Nothing beta users currently have ever gets clawed back.

### 2.5 Selling API access (the Sarvam model)

Host our Hinglish models behind an API, charge per hour/minute.

- **Why good**: B2B revenue, uncapped by Mac TAM (A3 escape hatch); our Hinglish quality is the differentiator Sarvam's general Indic API may lack for Roman-script output.
- **Why bad**: it's an *entirely different business* — servers, GPUs, uptime SLAs, rate limiting, abuse handling, a sales motion — run by a solo dev whose product brand is literally "we run nothing in the cloud". Brand contradiction is manageable (different product line) but the ops load is not, today. And the price ceiling is brutal: Sarvam charges ₹30/hour — near-zero margin territory that only works at VC scale. Also our current best model is a third party's Apache-2.0 fine-tune — reselling it via API is legal but builds on sand until we have self-trained models (P1-S4).
- **Feasibility**: low today, medium after a successful fine-tune. **Verdict: not now; revisit when (a) we have a self-trained model that beats open alternatives and (b) inbound B2B interest actually materializes. Park it, don't build it.**

### 2.6 Licensing the models / the convention (IP licensing)

License future *self-trained* models (non-open weights) to other apps/companies; publish the Hinglish Convention openly (adoption = moat) but license the convention-normalized training pipeline or datasets.

- **Why good**: pure-margin revenue if anyone wants it; converts P1/P3 work into an asset; keeps us out of ops (buyer runs the model).
- **Why bad**: requires the thing we haven't built yet (a clearly-better self-trained model); market of buyers is thin and reaching them is a sales job; complicates the open-source goodwill story if handled clumsily.
- **Feasibility**: zero today, real in 12+ months. **Verdict: keep the door open — decide per future model release whether weights are open (growth) or licensed (revenue). Don't Apache-2.0 by reflex (A4/A10).**

### 2.7 Advertising / sponsorship — **rejected**

- **Why bad, definitively**: ads inside a privacy-first *input method* is a contradiction users would rightly torch us for (an app that sees everything you dictate, showing ads, invites exactly one interpretation); ad revenue at our user scale would be pocket change (thousands of users ≠ ad business); even "tasteful sponsorship" burns trust capital that is the entire moat. The only acceptable adjacent form: an optional "Made by a kanjoos indie dev — tip jar / buy Pro" self-promo inside our own app.
- **Verdict: never. Documented so we stop re-litigating it.**

### 2.8 Distribution-channel plays (Setapp, App Store)

- **Setapp**: 70/30 usage-weighted payout, ~30k impressions at launch on the platform. Good *supplemental* discovery + revenue for exactly our profile (indie Mac utility), but their audience is Western — the India story is diluted; also requires notarization and their SDK. **Worth doing post-launch as a bonus channel, not a strategy.**
- **Mac App Store**: MacWhisper runs a *different price structure* there ($29.99/yr sub) than Gumroad — evidence you can segment by channel. MAS gives trust + discovery + easy payment, costs 15% (small dev program) + sandboxing pain (our CGEventTap/Accessibility usage needs careful entitlement work — possibly disqualifying; MacWhisper's dictation also lives outside MAS in the Gumroad build for related reasons). **Investigate sandboxing feasibility once; don't bet on it.**

### 2.9 Donations / open-core (the VoiceInk shape)

Open the app's source (models already open), sell the signed, notarized, auto-updating binary.

- **Why good**: VoiceInk proves paying-for-the-binary works ($25–39, GPL, 4.4k stars — the stars *are* the marketing); maximal trust alignment ("audit the privacy claims yourself" becomes our strongest marketing line — Rohan's Little Snitch energy converted into advocacy); community contributions possible.
- **Why bad**: irreversible; forks could out-run a solo dev; support burden of self-builders; enterprise buyers sometimes *prefer* closed (accountability). Donations alone (`buy me a coffee`) are noise-level revenue — never a plan.
- **Feasibility**: high mechanically, but strategic one-way door. **Verdict: genuinely attractive for *this* product's trust story; decide at launch, not now. If chosen: open the app, keep future premium models + LLM prompt-packs as the paid layer.**

### 2.10 B2B / Enterprise (detailed, since you asked)

**Who would buy, and why they'd value it.** The pitch writes itself for any org where (a) employees speak Hinglish and write English, and (b) data must not leave devices:

- **Law firms & CA/accounting firms** (client confidentiality is regulatory): dictation is an established behavior (lawyers dictated to stenographers for a century); on-device = no DPDP Act processor headaches, no client-data-in-cloud memo to write. India has tens of thousands of small firms; they buy per-seat tools (Tally culture).
- **Clinics/doctors** (the global dictation money-maker — Dragon Medical built a company on it): Hinglish case notes, prescriptions dictated between patients; on-device sidesteps health-data compliance entirely. Realistic niche: independent practitioners and small clinics, not hospital chains (those need integrations we won't build).
- **Startups/tech companies with India offices** (Wispr's Teams tier is this market): productivity purchase, bought bottom-up — an employee expenses it, then a team lead standardizes. Their alternative (Wispr Teams $10–12/user/mo) *sends audio to US clouds* — our on-device story is a security-review shortcut.
- **Media/content houses**: journalists transcribing Hinglish interviews (MacWhisper's discount segment); voice-notes-to-copy workflows.

**How to sell it without a sales team — productized, self-serve:**
1. A **Team pack on Gumroad** (VoiceInk's exact move: $159/10 Macs): volume license keys, one invoice PDF, GST invoice capability (Indian B2B *requires* GST invoices — Gumroad handles this poorly; may eventually need Razorpay/Instamojo for Indian B2B rails). Zero sales calls.
2. An **"IT admin" page** in docs: deployment (copy the .app, pre-seed models from a shared drive to skip 1 GB × N downloads — an offline-deploy script is a genuinely valuable enterprise feature that costs us a weekend), license activation, what network calls exist (answer: ~none — put the Little Snitch screenshot in the sales page).
3. **Compliance one-pager**: DPDP Act stance, no-processor status ("we never process your data — there is nothing to audit"), on-device architecture diagram. For a security reviewer, *absence* of cloud is the fastest "yes" they'll issue all year.
4. Do **not** build: SSO, audit logs, MDM integrations, HIPAA BAAs — that's Wispr Enterprise's game and requires an org. If a 500-seat inbound arrives, *then* consider custom terms (champagne problem).

**Why they'd pay more than consumers**: the buyer is spending company money against a compliance risk, not personal money against a convenience — per-seat ₹ can be 2–3× consumer without friction, and annual site licenses are normal.

---

## 3 · Price points (ranges, Indian context, purchasing-power split)

Anchors: MacWhisper $69 lifetime, VoiceInk $25–39, Superwhisper $85/yr or $250 lifetime, AudioPen $99/yr, Wispr $144/yr. Indian consumer software reality: ₹500 is an impulse, ₹1,000–2,000 is a considered personal purchase, ₹3,000+/yr personal is rare-air (that's a Netflix-annual). Gumroad supports regional pricing — run two price books from day one.

| Offer | India (₹) | International ($) | Rationale |
|---|---|---|---|
| **Free tier** | ₹0 | $0 | The wedge. Best free Hinglish dictation, forever. |
| **Pro — 12-month pass** (no auto-renew) | **₹799–1,499/yr** (launch nearer the low end) | **$29–49/yr** | Under the "considered purchase" line in India; 1/3 of Wispr's price internationally with a better privacy story. AudioPen's $99 shows indie ceiling; we undercut deliberately (our COGS ≈ 0). |
| **Pro — lifetime** (optional, capped-quantity launches) | **₹2,499–3,999** | **$79–129** | ~3× annual (Superwhisper's ratio). Sell in limited batches ("first 200") — funds development bursts, creates urgency, caps the long-tail liability. |
| **Team pack (5 seats, annual)** | **₹4,999–7,999** | **$149–249** | ~30% per-seat discount vs. Pro; GST invoice; self-serve. |
| **Site/clinic license (25 seats, annual)** | **₹19,999–34,999** | custom | Priced as "one decision, one invoice"; still self-serve with an email. |
| **Early-supporter beta offer** | ₹499 lifetime-Pro for beta testers | n/a | Converts the WhatsApp group into founding customers; grandfathering as gratitude, and our first real willingness-to-pay data. |

Pricing tactics that matter in India: UPI at checkout (Gumroad's Indian UPI support is imperfect — test it; a Razorpay payment-link fallback for India is cheap insurance), ₹-ending-in-99, annual-only for Pro (monthly at these price points is pure churn admin), student discount (Aman persona — 40–50%, matches Wispr/MacWhisper precedent), and *visible* regional pricing honesty (diaspora buying at $ knows Indians pay ₹ — normal and respected, don't hide it).

---

## 4 · The recommendation, phase-wise

**Model: Freemium (feature-gated) + Pro as a 12-month prepaid pass (no auto-renew) + optional capped lifetime + self-serve team packs.** One-time psychology, recurring economics, zero take-backs from beta users, enterprise as productized self-serve only. API/model-licensing doors stay open but unbuilt.

- **Phase 0 — now → public launch (free beta continues).** Decisions, not code: adopt this doc's free/Pro line so feature work lands on the right side (translation suite = Pro from day one of its existence — never free-then-gated); ask the beta group the one price question ("English-from-Hinglish mode at ₹799/yr?"); buy the Developer ID (A1 — a monetization prerequisite: you cannot charge for an app macOS calls malware); ship the update channel (A2 — you cannot sell yearly *updates* you cannot deliver). Keep `gatingEnabled=false`.
- **Phase 1 — Pro launch (with the translation suite shipping).** The LLM features are the paywall's opening act — gating arrives *with* new value, taking nothing away. Gumroad product (India/international price books, UPI tested), LicenseManager: productID set, `gatingEnabled=true`, offline-grace license check (disclosed in privacy docs). Beta group gets the ₹499 founding-member lifetime. Success bar: 25 paying users in 90 days = signal to continue; <5 = revisit the free/Pro line, not the mission.
- **Phase 2 — widen (3–6 months post-launch).** Team packs + IT-admin page + compliance one-pager (a weekend of writing, opens B2B inbound); Setapp application (bonus channel); lifetime batch #2 if batch #1 sold out; first renewal season for annual passes — the "here's what shipped this year" email is the whole retention strategy, and our release cadence is the product's best sales pitch.
- **Phase 3 — conditional expansions.** Self-trained model that clearly beats open alternatives → per-release open-vs-licensed decision (2.6) and *maybe* hosted API (2.5) if inbound demand pulls it. Windows port (A3) → the entire pricing structure ports as-is. Open-sourcing the app (2.9) → evaluate at Phase-2 review with real revenue data in hand; it's a trust-multiplier, not a revenue decision.

**Why this beats the alternatives, in one paragraph:** pure lifetime (MacWhisper) caps us at new-sales-only revenue while our costs (retraining, support) recur; pure subscription (Wispr) fights Indian payment psychology *and* lacks cost-side justification for an on-device app; the prepaid pass threads both — and every comparable that survives as an indie in this niche (MacWhisper, VoiceInk, AudioPen, Superwhisper) either uses one-time psychology or offers it as an option, while the only pure-subscription player (Wispr) is VC-funded with real cloud COGS. We copy the survivors, not the venture case.

Sources: [MacWhisper on Gumroad](https://goodsnooze.gumroad.com/l/macwhisper), [MacWhisper pricing overview](https://www.getvoibe.com/resources/macwhisper-pricing/), [Wispr Flow pricing](https://wisprflow.ai/pricing), [Wispr plan details](https://docs.wisprflow.ai/articles/9559327591-flow-plans-and-what-s-included), [Superwhisper pricing](https://www.getvoibe.com/resources/superwhisper-pricing/), [VoiceInk](https://tryvoiceink.com/superwhisper-alternative), [VoiceInk review](https://www.getvoibe.com/resources/voiceink-review/), [AudioPen](https://www.audiopen.ai/), [Voice notes pricing compared](https://www.spokenplan.com/blog/voice-notes-pricing-compared), [Voicenotes pricing](https://aiproductivity.ai/pricing/voicenotes/), [Sarvam API pricing](https://www.sarvam.ai/api-pricing), [Subscription psychology in India](https://rizevault.razorpay.com/p/the-psychology-of-subscriptions-in), [UPI for SaaS in India](https://grow.cleverbridge.com/blog/upi-india-saas-digital-goods), [Setapp for developers](https://setapp.com/developers), [Setapp revenue distribution](https://docs.setapp.com/docs/distributing-revenue).
