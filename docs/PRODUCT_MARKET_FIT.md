# Product-Market Fit — First Principles (private)

> Written 2026-07-09. A concept-first, exhaustive treatment of PMF for Desi Dictation: what PMF actually is, whether we have it (no), how to define our market and product, what the real MVP is, which metrics matter, **how to measure any of it while keeping a no-telemetry on-device promise** (the hard part), how we'll *decide* we've found PMF, and what to do — with time windows — if we haven't. Gitignored. Companion to STRATEGY.md, problems/, features/, MONETIZATION.md.
>
> This is a living reasoning document, not a plan of record. Where it says "target," treat it as a hypothesis to test, not a commitment.

---

## 0 · How to read this

PMF is the most abused phrase in startups. This doc refuses the buzzword and rebuilds it from first principles for *our specific, unusual situation*: a single-purpose, on-device, privacy-absolutist tool for a linguistically messy market, sold by someone who is himself the archetypal user. Our constraints (no telemetry, niche, indie) make the *standard* PMF playbook partly unusable — so half this doc is about **how to find PMF blind**, without the analytics dashboards every other founder leans on. That constraint is the interesting part.

---

## 1 · What PMF actually is (first principles)

Strip everything away. A product exists to do a **job** for a **person** better than their **alternatives**. PMF is the state where:

> A well-defined group of people reliably get enough value from your product that they keep using it, resist giving it up, and tell others — *without you pushing them*.

That's it. Three testable claims hide inside it:

1. **Retention** — they *come back on their own*. Not "tried it once." A tool people stop using has no PMF regardless of how many downloaded it.
2. **Resistance to loss** — taking it away would genuinely upset them (Sean Ellis's "very disappointed" test). This is the emotional signature of a solved problem.
3. **Pull, not push** — the market starts doing your work: word of mouth, unprompted evangelism, "how do I get this." Marc Andreessen's felt definition — "you can always feel PMF when it's happening… customers are buying as fast as you can make it; usage is growing; money piles up." The inverse ("word of mouth isn't spreading, usage isn't growing, press reviews are kind of 'blah'") is *the absence* of PMF, and it's where most products live.

**What PMF is NOT** (all traps we could fall into):
- **Not** "the product works." A working product is a *precondition*, not PMF. We have a working product. That is a PoC, not PMF.
- **Not** "my friends love it." Friends are a biased, non-representative, socially-obligated sample. Friend enthusiasm is the *most common false positive* in early-stage PMF and it is exactly the signal we currently have. Treat it as near-zero evidence.
- **Not** downloads, signups, or press. Those are top-of-funnel vanity; they measure *curiosity*, not *value delivered*. A viral spike with no retention is anti-PMF (you burned awareness on a leaky bucket).
- **Not** a single moment. PMF is a *degree* and it *decays* (Rambler could erode ours). It's a curve you stay on, not a line you cross once.

**The deepest first-principle:** PMF is fundamentally about **retention driven by value**, and everything else (growth, revenue, virality) is downstream of it. If people stay, you can figure out growth. If people leave, no growth tactic saves you — you're pouring water into a bucket with a hole. So the entire PMF hunt reduces to one question we must answer honestly: **do people keep dictating with us, month after month, because it's genuinely better for them than the alternative — and would they be upset to lose it?**

---

## 2 · Where we actually are (honest)

- **Product state:** a working, usable, on-device Hinglish/English/Hindi dictation app (v0.5.1). This is a **Proof of Concept that has matured into an early product** — it proves the thing is *possible and usable*. It does **not** prove anyone *needs* it.
- **Evidence state:** a friends-and-family beta with warm reactions and the founder's own love of the tool. **This is pre-PMF, and the current signal is the classic false positive.** Friends and the founder are the least representative users alive.
- **What we do NOT yet have** (i.e., all the actual PMF evidence): retention data from strangers, any payment/willingness-to-pay signal, a measured "very disappointed" rate, organic pull, or a defined beachhead we've saturated.

**Verdict: we are pre-PMF and don't yet know if we can get there. That's normal and fine — but we must stop mistaking "it works and my friends like it" for "the market wants it."** The rest of this doc is how to actually find out.

---

## 3 · Define the market (first principles)

You cannot have *product-market* fit without naming the *market* precisely. "Indians who speak Hinglish" is not a market — it's a demographic, too broad to fit anything. PMF is found in the **narrowest segment that is most desperate for the solution**, then expanded outward. First-principles method: find the people whose **hair is on fire** — for whom the problem is acute, frequent, and unsolved by alternatives — because desperate users forgive rough edges, stick despite bugs, and give you the clean retention signal broad users never will.

### 3.1 · Segmenting by desperation (not by demography)

Rank our personas by *intensity of pain × frequency × poverty of alternatives*:

| Segment | Pain intensity | Frequency | Alternatives | Hair-on-fire? |
|---|---|---|---|---|
| **Heavy AI-prompt users** who think in Hinglish (dev/founder/creator) — need rich English context fast | High | Many times/day | Type slowly / lazy prompts | **YES — sharpest wedge** |
| **Hinglish-heavy knowledge workers** who hate laptop typing (WhatsApp Web/Slack all day) | High | All day | Type; phone voice notes | **YES** |
| **"Understand English, can't produce it"** professionals needing English output (emails, SOPs, escalations) | Very high (access-level) | Weekly–daily | Google Translate dance / ask someone | **YES — deepest pain** |
| Casual mobile texters | Medium | High | Gboard (free, Android) | No — served by free default |
| Devanagari-first users | Medium | Varies | OS Hindi dictation | No — adequately served |

**The beachhead hypothesis:** the first market to fit is not "all Hinglish speakers" — it's the **desktop knowledge worker who produces a high volume of text, thinks/speaks in Hinglish or broken English, and is failed by both typing and the free defaults.** Sub-wedge candidates to test: (a) the AI-power-user who wants to speak context into ChatGPT/Claude, (b) the "needs polished English output but can't type it fast" professional. Both are dense on laptops (our current platform), both pay for productivity, both have no good alternative today.

### 3.2 · The Job To Be Done (why they'd hire us)

People don't want "dictation." They hire a tool to accomplish something. Our candidate JTBDs, most-to-least compelling:

1. *"When I have thoughts in Hindi/Hinglish but need them as text (especially English) for work or AI, help me get them out fast and correct, without my voice leaving my laptop."*
2. *"When typing on my laptop is slow and my natural speech is code-mixed, let me talk instead and get exactly what I'd have typed."*

The first JTBD (voice → correct text, esp. English) is likely the stronger, more differentiated hire — it's the one the free defaults and cloud tools serve *worst*, and it maps to the deepest persona pain.

### 3.3 · Market size reality (for PMF, small is fine)

For *finding* PMF, the market only needs to be big enough to contain ~100 true fans — PMF is proven in the small before it's scaled. The grand-vision TAM (STRATEGY.md) is irrelevant here. What matters: is there a reachable group of a few hundred desperate users we can get in front of and delight? Almost certainly yes.

---

## 4 · Define the product (the concept, first)

Per your ask — build the *concept* before worrying about implementation. The concept has three layers:

### 4.1 · The product concept statement

> **Desi Dictation is the on-device voice tool that lets Indians speak the way they actually talk — Hinglish, broken English, mixed — and get back exactly the text they meant, including polished English, without a single word ever leaving their laptop.**

Every word is load-bearing: *on-device* (the moat), *the way they actually talk* (the wedge the defaults fail), *exactly the text they meant* (quality + personalization + faithfulness), *including polished English* (the deepest-pain JTBD), *never leaving their laptop* (trust).

### 4.2 · The core loop (what "using the product" is)

1. Hold a key (or toggle) anywhere on the Mac.
2. Speak naturally — code-mixed, paused, imperfect.
3. Release → text appears at the cursor, in the register/language/script you chose, correct enough to send without editing.
4. Optionally: it becomes polished English / structured / your-exact-spelling.

The loop's value = **(time saved vs. typing) × (frequency) × (times it's the *only* way to get that output)**. PMF lives or dies on whether that loop is reliably better than typing for a frequent, real task.

### 4.3 · The "minimum lovable" spine

Three things must be true or nothing else matters — these are the product's spine:
1. **Quality high enough that the correction tax is below the typing cost** (P1). If they fix more than they save, the loop inverts and they churn. This is the #1 determinant of PMF.
2. **Reliability — it never bricks, never eats their words, never pastes in the wrong window** (A5/A6). A daily tool that fails 1-in-20 is not a daily tool. Trust in the loop is the habit's foundation.
3. **One undeniable reason it beats the free default** — for us, Roman-script Hinglish and/or speak-Hinglish-get-English. The wedge that makes "why not just use Apple's?" answer itself.

Everything else (history, modes, 10 languages, meetings) is *expansion*, not spine.

---

## 5 · PoC vs MVP vs where "viable" sits

These get conflated; the distinction is the whole point of your question.

- **Proof of Concept:** proves it's *possible* — "an on-device app can transcribe Hinglish into Roman text." ✅ **We have this.** A PoC's job is to de-risk feasibility. Done.
- **MVP (Minimum *Viable* Product):** the smallest thing that delivers **enough recurring value that a stranger keeps using it** — "viable" = *survives contact with a real user's daily life*. Not "minimum to demo," but "minimum to **stick**."
- **MLP (Minimum *Lovable* Product):** one notch up — the smallest thing people *love*, not just tolerate. For a market with a strong free default (Apple/Google), **tolerable isn't enough — we likely need lovable**, because "slightly better than free" doesn't move habits; "I can't go back" does.

### 5.1 · What "viable" means for us, precisely

Viable = **a stranger, not a friend, dictates with it for their real work, most days, for a month, without quitting — because it's genuinely better than their alternative.** That single sentence is the MVP bar. Everything in the MVP spec exists to make that sentence true; anything that doesn't serve it is out of scope for MVP.

### 5.2 · Our MVP spec (in / out)

**IN (the spine + the wedge + trust):**
- Rock-solid Hinglish dictation with correction tax < typing cost (P1 progress — *the* gating item).
- Bulletproof reliability: never brick, never lose words, never wrong-window paste, restore clipboard (A5/A6). Failures degrade gracefully to "your words are on the clipboard."
- The one wedge feature that makes it undeniable — strongest candidate: **speak-Hinglish → get-English** (the deepest-pain JTBD, and the thing no free default does). Alternatively, if quality-first, just *excellent* Roman Hinglish.
- Frictionless daily loop: fast enough, works in their top 3 apps (WhatsApp Web, Slack/Mail, editor/ChatGPT), sensible defaults (Auto), no config required to get value.
- The personalization *starter* (P4-S1 one-tap "always write it my way") so the correction tax *visibly decreases* — the "it's learning me" hook that creates attachment.

**OUT (expansion, not MVP — resist building these to feel productive):**
- Structure-your-thoughts, meeting notes, 10 languages, tone dial, cross-platform, enterprise features, the model-layer ambition. All real (features/), none needed to prove a stranger will stick.

**The discipline:** if a proposed piece of work doesn't move "a stranger sticks for a month," it's not MVP — it's a distraction wearing a roadmap costume.

---

## 6 · The measurement problem — the crux of doing this on-device & private

Here is where our situation is genuinely unusual and most of the standard PMF playbook breaks. Every normal founder measures PMF with **telemetry**: retention cohorts, funnels, session analytics, A/B tests, all streaming off users' devices into a dashboard. **We have promised the opposite — zero telemetry, nothing leaves the device.** That promise is our brand and our moat (competitors/PATTERNS §3). So we must find PMF **partially blind**, without the instrument every other founder relies on.

This is not a footnote — it is *the* methodological challenge of this document. The resolution has four pillars.

### 6.1 · Pillar 1 — Payment is the truest signal, and it's server-side (no privacy cost)

The single most honest PMF signal is **people paying and renewing**, and it lives on the *payment processor's* server (Gumroad/Razorpay), not the user's device. Measuring it violates no promise. Conversion rate, renewal rate, and refund rate are clean, ungameable truth: **a renewal is a user voting, with money, that the value recurred.** For a no-telemetry product, payment becomes *disproportionately* important as a metric precisely because it's the richest signal we can ethically collect. (Caveat: only exists once we charge — Phase 1 of monetization. Pre-payment, we lean on the other pillars.)

### 6.2 · Pillar 2 — Consent-based, user-initiated sharing (the "Copy my stats" pattern)

The app can compute **rich analytics locally** — days active, dictations/day, words, correction rate, feature use, retention streak — and keep them on-device by default. The privacy-preserving move: let the **user choose to share** them. Concretely:
- A **"Copy my stats"** button (roadmap-noted already): the app assembles a local usage summary; the user pastes it into a survey or feedback email *they* send. Nothing is transmitted without a human hitting send and seeing the payload. Same consent model as P3 donations.
- **Opt-in periodic check-in**: the app can *locally* prompt "You've dictated 40 times this week — mind sharing anonymous stats to help improve it?" → shows the exact payload → user sends or declines.
This converts telemetry-shaped data into consented, visible, user-driven disclosure. It's lower-volume and self-selection-biased (enthusiasts over-share, quitters vanish) — but it's *honest*, and the bias is *knowable* and correctable.

### 6.3 · Pillar 3 — Ambient / external signals (no device data at all)

Signals that live entirely outside the user's machine:
- **Download counts** (GitHub Releases, Gumroad, HF model downloads) — top-of-funnel *curiosity* (weak, but a trend).
- **Renewal/refund/conversion** (Pillar 1).
- **Organic growth rate** — are downloads accelerating without us pushing? (Andreessen's "usage growing" felt-signal.)
- **Word of mouth in the wild** — unprompted mentions on X/Reddit/WhatsApp forwards; "where did you hear about us" on a purchase survey; referral-code usage.
- **Review sentiment / support-request themes** — what breaks, what's loved, in the users' own words.

### 6.4 · Pillar 4 — Qualitative depth over quantitative breadth (our superpower, forced)

Because we *can't* lazily A/B our way to answers, we're forced into the highest-signal PMF activity that most founders skip: **actually talking to users.** For a pre-PMF product this is *better* than analytics anyway (analytics tell you *what*, interviews tell you *why*). Our toolkit:
- **Deep 1:1 interviews** (JTBD-style: "walk me through the last time you used it / didn't use it when you could have").
- **Churn interviews** — the goldmine: every user who *stops* is a lesson; ask them why, specifically.
- **The super-user cohort** — track a small panel of real (non-friend) heavy users longitudinally; their behavior *is* the leading indicator.
- **The Sean Ellis survey** (§8) — the one quant instrument that works over email/in-app link with no telemetry.

### 6.5 · The philosophy, stated plainly

**We trade the *breadth* of telemetry for the *depth* of consented + qualitative signal, and we anchor on *payment* as truth.** We will have fewer numbers and more *understanding*. The risk is slower, fuzzier measurement; the compensation is that PMF is ultimately a *qualitative* state (do they love it, would they miss it) that interviews + payment capture better than any funnel. **Our privacy constraint forces us into good PMF hygiene.** The one discipline required: correct constantly for **survivorship/self-selection bias** — the users who share and answer are the fans; the silent majority and the churned are where the truth about *lack* of fit hides, so we must hunt those deliberately (churn interviews, not just fan love).

---

## 7 · The metrics that actually matter (and how to get each, privately)

Ordered by importance for a daily-use tool. For each: what it is, why it matters, how we measure it without telemetry, rough target.

### 7.1 · Retention (the #1 metric — the heart of PMF)
- **What:** of users who start in a given week, how many are still dictating N weeks later. The *shape* matters more than the level: a healthy product's retention curve **flattens** (a stable core keeps using forever); a product without PMF's curve **decays to zero**.
- **Why:** retention *is* value-delivered-over-time. Everything else is downstream. A flattening curve = PMF's fingerprint.
- **How (private):** (a) opt-in cohort via "Copy my stats" streaks; (b) **renewal rate** as the ultimate retention proxy for payers (server-side); (c) longitudinal interviews with the super-user panel (are the same people still using it in month 3?); (d) an opt-in "still using it?" email at 1/4/12 weeks.
- **Target (hypothesis):** a visible *flattening* — e.g., ≥40–50% of activated users still dictating weekly at week 8, not trending to zero. The plateau's existence matters more than its exact height early on.

### 7.2 · Activation (did they reach first value?)
- **What:** did a new user get to their first *successful, delightful* dictation (the "whoa, it wrote exactly what I said" moment) — ideally in their first session.
- **Why:** users who never feel the core value never retain. Activation is the gate to everything downstream; onboarding (A1 wall, A6 permissions, A7 download) is where we bleed people *before* value.
- **How (private):** onboarding-completion is partly inferable (download → first-week survey); qualitative ("what was your first dictation like?"); the local app can note "reached first successful dictation" and surface it in shared stats.
- **Target:** most installers who clear the setup wall reach a successful dictation within their first session; the bigger measured leak is likely *pre-activation* (the Gatekeeper/permission/download gauntlet — A1/A6/A7), which is why those problems are PMF-blockers, not just polish.

### 7.3 · Engagement depth & frequency (habit formation)
- **What:** dictations/day, words/day, days-active/week. Is it a *habit* (daily) or a *novelty* (tried twice)?
- **Why:** for a productivity tool, frequency is the PMF tell — daily-use tools with PMF get used daily. A tool used monthly has, at best, weak fit.
- **How (private):** local stats via "Copy my stats"; super-user panel observation.
- **Target:** a core of users dictating *most working days*, multiple times/day. The existence of a daily-habit core (even if small) is a stronger PMF signal than a large occasional-use base.

### 7.4 · The correction tax, decreasing over time (our special quality metric)
- **What:** edits-per-dictation (how much they fix our output), and critically its *trend* — does it fall as personalization (P4) learns them?
- **Why:** this is *the* quality signal for us and it's unique to our problem. Low-and-falling correction tax = the loop stays better than typing = they stick. Rising or high = churn. It also directly measures whether P1/P4 are working.
- **How (private):** the app can compute edit-distance between its output and what the user leaves on screen *locally* (within our own edit surfaces) — shared via opt-in stats; plus qualitative ("how often do you have to fix it?").
- **Target:** correction tax low enough that dictation beats typing on day one, and *measurably falling* over weeks 1–4 (the autocomplete curve, P4).

### 7.5 · Willingness to pay / conversion / renewal (the truth serum)
- **What:** do free users convert; do payers renew; what's the refund rate.
- **Why:** payment is the least gameable value vote (§6.1). Renewal especially — it's retention + value + willingness, in one server-side number.
- **How (private):** entirely server-side (Gumroad/Razorpay) — no privacy cost.
- **Target (hypothesis):** a healthy free→paid conversion in the low-single-digit % of *engaged* users, and — the number that matters most — **annual renewal comfortably >50–60%.** Low renewal = value didn't recur = no durable PMF, regardless of everything else.

### 7.6 · Referral / organic pull (Andreessen's felt-signal, quantified)
- **What:** are users bringing other users unprompted? Is growth organic?
- **Why:** pull is the exhaust of PMF. If people share it without being asked, the value is real.
- **How (private):** referral codes; "where did you hear about us" purchase survey; organic download-growth trend; monitoring unprompted mentions.
- **Target:** a rising share of new users citing word-of-mouth; organic growth without paid push.

### 7.7 · The single North Star (for a no-telemetry daily tool)
Pick **one** metric that best proxies delivered value, to orient everyone: candidate = **"weekly retained dictating users"** (people who dictated ≥3×/week and were also active the prior week) — it fuses retention + habit + real use. Since we can't measure it fully via telemetry, we *estimate* it from opt-in stats + payer renewal + panel + survey, and treat the **retention curve + Sean Ellis score** as its two readable faces (§8).

---

## 8 · The two readable north stars: retention curve + the Sean Ellis 40% test

These two are the instruments that *work* under our constraints and together give a clear PMF read.

### 8.1 · Retention-curve flattening
Plot cohort retention (from opt-in stats + renewal + panel). **PMF's signature is a curve that decays then *plateaus*** — a stable core that keeps using it indefinitely. No plateau (decay to zero) = no PMF, full stop. This is the most trustworthy behavioral signal we can assemble, because it's about what people *do*, not say.

### 8.2 · The Sean Ellis test (the one survey that matters)
Ask engaged users: **"How would you feel if you could no longer use Desi Dictation?"** — *Very disappointed / Somewhat disappointed / Not disappointed.*
- **≥40% "very disappointed" is the empirical PMF threshold** (Ellis's benchmark across ~100 startups). Below ~25–30%, you're clearly pre-PMF.
- **Why it works for us:** it's a survey (email/in-app link) — **no telemetry needed** — and it directly measures "resistance to loss," the emotional core of PMF (§1). It also segments: analyze *who* says "very disappointed," and you've found your true beachhead (§9's follow-the-lovers method).
- **Cadence:** run it every ~4–8 weeks on users with ≥N dictations; watch the *trend*.

**When retention flattens AND ≥40% would be very disappointed AND renewal >50–60% AND organic pull appears — that's PMF.** Any one alone can mislead; the convergence is the signal.

---

## 9 · How we decide we've found PMF — the scorecard

PMF is a degree, so we use a **convergence scorecard**, not a single gate. Declare "PMF found (for this beachhead)" when *most* of these hold simultaneously, on **real strangers, not friends**:

| Signal | Pre-PMF | PMF-ish | Strong PMF |
|---|---|---|---|
| Retention curve | decays to ~0 | flattens, low plateau | flattens, healthy plateau |
| Sean Ellis "very disappointed" | <25% | ~30–40% | **≥40%** |
| Weekly-active habit core | novelty use | small daily core | growing daily core |
| Correction tax trend | high/flat | falling | low & falling |
| Renewal rate (once paid) | <40% | ~50–60% | **>60%** |
| Organic pull | none | occasional WoM | self-sustaining WoM |
| Qualitative "can't go back" | rare | some | common & unprompted |

**Decision rule:** ≥5 of 7 in the "PMF-ish" column or better, sustained over ≥2 cohorts, on non-friend users → declare beachhead PMF and shift energy from *finding* fit to *scaling* it (growth, expansion vectors, STRATEGY.md rungs). Fewer than that → keep iterating (§10). **Crucially: friend/founder enthusiasm scores zero on this card.** Only strangers count.

---

## 10 · If we haven't found PMF — the playbook

Most likely outcome for a while. Do **not** thrash randomly or chase growth (scaling a non-fitting product just spends money faster). The disciplined loop, in order:

### 10.1 · Follow the lovers (Ellis's method — highest leverage)
Segment the "very disappointed" minority. **Who are they? What do they have in common? What do they use it for?** That subgroup is your *real* beachhead hiding inside your fuzzy one. Then: (a) reposition and rebuild *for them specifically*, (b) get *more people like them*, (c) ignore the "not disappointed" crowd entirely. This is how you *convert* weak fit into strong fit — narrow until a segment loves you, then widen.

### 10.2 · Fix the spine before adding anything (§4.3)
If retention is bad, the cause is almost always the spine, not missing features:
- **Quality (P1)** — if the correction tax > typing, nothing else matters. This is the most probable PMF blocker and the reason P1 is "existential." Fixing Hinglish quality is likely the highest-leverage PMF work, period.
- **Reliability (A5/A6)** — if it breaks/eats words/wrong-window-pastes, trust never forms.
- **Activation (A1/A6/A7)** — if strangers can't get past the install wall to first value, you're bleeding pre-value; fixing the funnel may matter more than any feature.
Resist adding features to a leaky spine — it's the most common way to *feel* productive while PMF stays broken.

### 10.3 · Test the wedge
If quality/reliability are fine but people still drift, the *wedge* may be wrong — maybe "excellent Roman Hinglish" isn't enough over free defaults and **speak-Hinglish-get-English** is the real hook (or vice-versa). Ship the alternate wedge to a cohort; measure whether it moves retention/Sean-Ellis.

### 10.4 · Re-segment or, last, pivot
If no version of the wedge lands on any narrowed segment after honest iteration, the problem may be the *market* (this segment isn't desperate enough) — move to an adjacent segment (e.g., from casual texters to AI-power-users, or toward the enterprise/privacy slice). A true *pivot* (different product/problem) is the last resort, taken only after the follow-the-lovers + spine + wedge + re-segment loop has genuinely failed — not from impatience.

### 10.5 · The loop, summarized
**Talk to churned users → find who loves it and why → narrow to them → fix spine → sharpen wedge → re-measure → repeat.** Deepen before broadening. Every cycle should raise the Sean Ellis score and the retention plateau, or teach us why not.

---

## 11 · Time windows (how long to give it)

PMF can't be rushed (you need cohorts to *age* to see retention) but also can't be indefinite (thrashing forever burns life). Realistic, honest windows — leading indicators inside each, go/no-go at the end:

- **Now → ~3 months (get *real* users):** exit the friends bubble. Get the product in front of *strangers* in the beachhead segment (small paid ads, communities, Product Hunt, targeted outreach). Goal: not growth — **a clean, unbiased retention + Sean Ellis read.** Gate: are non-friends even activating and returning at all? Leading indicator: week-4 retention of stranger cohorts.
- **~3 → ~9 months (iterate to fit):** run the §10 loop on real cohorts. Ship P1 quality + reliability + the wedge; run Sean Ellis every ~6 weeks; watch the retention plateau and correction-tax trend. **This is the real PMF hunt.** Gate at ~9 months: is the scorecard (§9) trending toward "PMF-ish," cohort over cohort? *Trend matters more than absolute level* — improving each cohort = on track; flat-bad across cohorts = warning.
- **~9 → ~15 months (decide):** by here we should either have **beachhead PMF** (scorecard ≥5/7, sustained) → shift to scaling + expansion (STRATEGY rungs), **or** a clear-eyed verdict that this segment/wedge doesn't fit → execute a §10.4 re-segment/pivot with what we've learned. **Avoid the two failure modes:** declaring PMF too early on friend-love (false positive → scaling a leaky bucket), and iterating forever without a decision gate (thrash → burnout).
- **Ongoing after PMF:** PMF decays (Rambler, OS defaults). Re-run Sean Ellis + retention quarterly forever; treat a falling score as an early-warning to re-earn fit.

**The founder-specific caution:** because *you* love it and your friends do, your personal risk is the **false positive** — over-reading warm signals and scaling too early. Weight stranger data heavily; discount friend/founder love to ~zero; let the churn interviews and the Sean Ellis score from people who owe you nothing be the arbiters.

---

## 12 · Good ways to find PMF — the methods toolkit (recap, actionable)

1. **Sean Ellis 40% survey** — the one quant instrument that works telemetry-free; run on engagement, segment the lovers.
2. **Retention cohorts** — assembled from opt-in "Copy my stats" + payer renewal + super-user panel; watch for the *plateau*.
3. **JTBD / deep user interviews** — the highest-signal activity we have; "walk me through the last time…"; do these weekly, they're not optional for a no-telemetry product.
4. **Churn interviews** — talk to everyone who stops; the truth about lack-of-fit lives here, not in fan love.
5. **The super-user panel** — a longitudinal cohort of real heavy users; their month-3 behavior is your leading indicator.
6. **Payment as truth** — conversion + renewal + refund, server-side, once monetized; the least gameable vote.
7. **"Do things that don't scale"** (PG) — hand-hold early users, watch them use it live (screen-share, with consent — no telemetry needed when you're literally watching); find every friction.
8. **Concierge / follow-the-lovers** — over-serve the "very disappointed" segment, learn what makes them love it, manufacture more of them.
9. **Ambient monitoring** — organic growth, unprompted mentions, "where did you hear about us."
10. **The honest-bias correction** — always hunt the silent and the churned, because our sharing/answering users are self-selected fans; PMF *absence* hides in who didn't show up.

---

## 13 · The one-page version

- **PMF = a defined group keeps using us, would be upset to lose us, and tells others — unprompted.** We don't have it; we have a working PoC and biased friend-love (a false positive).
- **Market (beachhead):** desktop knowledge workers who think in Hinglish/broken English, produce lots of text, and are failed by both typing and free defaults — sharpest sub-wedge: those who need **fast, correct English out of messy Hinglish speech.**
- **Product concept:** speak the way you actually talk → get exactly the text you meant (incl. polished English) → nothing leaves your laptop.
- **MVP (not PoC):** the smallest thing a *stranger* sticks with for a month — spine (quality below correction-tax breakeven + bulletproof reliability + one undeniable wedge) + the "it's learning me" personalization starter. Everything else is expansion.
- **Measurement under no-telemetry:** payment (truth) + consented "Copy my stats" + ambient signals + deep qualitative — trading telemetry's breadth for interview depth, anchored on renewal; always correcting for fan self-selection.
- **Metrics that matter:** retention (plateau), activation, habit frequency, falling correction-tax, renewal, organic pull — north stars: **retention-curve flattening + Sean Ellis ≥40%.**
- **Decide PMF:** convergence scorecard (§9), ≥5/7 sustained over 2+ cohorts, **on strangers only.**
- **If not:** follow the lovers → fix spine (P1 quality first) → sharpen wedge → re-segment → (last) pivot. Deepen before broadening.
- **Time:** ~3 mo to real users, ~9 mo to iterate, ~15 mo to decide; trend over absolute level; guard hardest against the founder's false-positive.

---

*Living document — revise as we get real cohorts. When we have first stranger-retention and first Sean Ellis numbers, append a dated "PMF read" section with the actuals.*
