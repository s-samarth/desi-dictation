# Ideal Customer Profiles (private)

> Written 2026-07-09. An exhaustive, first-principles map of *who we should sell to and why* — B2C, B2B, and the other models (B2G, platform/API, OEM, developer channel) — with a scoring framework, a beachhead pick, a deliberate **anti-ICP**, and prioritization. Gitignored. Companion to features/PERSONAS.md (the faces), PRODUCT_MARKET_FIT.md (the beachhead logic), MONETIZATION.md (who pays what), STRATEGY.md (the rungs), and competitors/ (where we win).

---

## 0 · ICP vs. personas — why this is a separate doc

Personas (PERSONAS.md) are *faces* — Rohan, Rekha, Aman, individual humans with stories. An **ICP is a *segment* defined strategically**: the *type* of customer (or account) that is not just willing to buy but is **ideal** — high value, reachable cheaply, retains, expands, and evangelizes. Personas answer "what does a user feel"; ICPs answer "who do we hunt, in what order, and why." A B2B ICP isn't even a person — it's an *account* with a buyer, a champion, and a budget. This doc is the targeting layer above the personas.

---

## 1 · First principles — what makes a customer "ideal" (not just willing)

A customer is *ideal* when they score high across these, because these are what actually compound into a business:

1. **Acute, frequent pain** — the problem is on-fire and recurs daily (drives retention; PMF lives here).
2. **Poor alternatives** — the free defaults (Apple/Google) and cloud tools fail *them specifically* (drives switching + differentiation).
3. **Ability + willingness to pay** — has budget and a reason to spend it (money, not just love).
4. **Reachable cheaply** — findable through channels an indie/small team can afford (low CAC; no enterprise sales army).
5. **Retains** — the value recurs, so they stay (renewal, the truest signal).
6. **Expands** — one seat becomes a team, one feature becomes the Pro tier (land-and-expand; ARPU growth).
7. **Evangelizes** — tells others unprompted (organic pull; free growth).
8. **Strategically aligned** — using them well *strengthens the moat* (privacy-valuing, Hinglish-native, data-donating).

**For us specifically, three extra filters matter above all:** they must (a) genuinely value **on-device privacy** (our moat vs. Google/cloud), (b) have real **Hinglish/code-mix or Indian-English** need (our wedge), and (c) be sellable **without a sales team** (productized/self-serve — solo-dev constraint). A customer who wants cloud, speaks pure English, and needs a 6-month enterprise sale is a *bad* fit even if they'd pay — they pull us off our advantages.

---

## 2 · The scoring framework

Each ICP scored 1–5 on: **Pain · Alt-gap** (how badly alternatives fail them) **· Pay** (willingness×ability) **· Reach** (cheap to acquire) **· Retain · Expand · Evangelize · Moat-fit**. Summary table in §8. Used to pick the beachhead and the sequencing.

---

## 3 · B2C / prosumer ICPs

### C1 · The AI-power-user ("vibe worker") — **the beachhead**
*Devs, founders, PMs, indie hackers, creators who live inside ChatGPT/Claude/Cursor and think in Hinglish.* (Persona: Rohan.)
- **Pain & JTBD:** they *know* rich context = better AI output, but typing 200 words of context is friction, so they send lazy prompts. JTBD: *"speak two minutes of Hinglish about my problem, paste clean English context into the LLM."* Also: Hinglish Slack/WhatsApp/PR-description chores.
- **Why ideal:** highest *frequency* (all day), highest *evangelism* (they post on X, demo to teams — free growth), value privacy (Little-Snitch crowd), early-adopter (forgive rough edges), and their need is the one the free defaults fail worst. Cheapest to reach (dev communities, X, HN, Product Hunt, Reddit).
- **Pay:** used to $10–20/mo dev tools; will pay for real time saved.
- **Reach:** dev/AI communities, X, HN, Product Hunt, Reddit, YouTube dev creators, word-of-mouth. **Lowest-CAC segment we have.**
- **Must-have:** rock-solid Hinglish + **speak-desi-write-English** (the transcribe→translate wedge), works in their IDE/browser/ChatGPT, fast, on-device.
- **Expand:** individual → recommends to team → team pack; free → Pro (the LLM layer they'll love most).
- **Risk:** most likely to be contested by Raycast (dev distribution) and eventually Gboard; churns fast if quality lags.
- **Priority: #1 — this is the PMF beachhead.** Narrow, desperate, reachable, evangelistic, moat-aligned.

### C2 · The high-volume communicator
*People who produce large text volumes in Hinglish all day: sales/BD, recruiters, consultants, customer-support, community managers, solo founders.* (Persona: Priya-adjacent.)
- **Pain & JTBD:** typing on a laptop is their bottleneck; they voice-note on phone but that's unprofessional on laptop. JTBD: *"talk my messages/replies/notes and have them typed, in my register."*
- **Why ideal:** high frequency + high willingness (they monetize saved time directly), and volume = they *feel* the value daily → retention.
- **Pay:** productivity budget; ₹-annual or per-seat.
- **Reach:** LinkedIn, sales/recruiting communities, creator networks, referrals.
- **Must-have:** speed, reliability at volume, per-app tone (professional vs. casual), snippets/replacements.
- **Expand:** strong land-and-expand into their team.
- **Priority: #2 — the volume-and-pay core.**

### C3 · The "understand-English-can't-produce-it" professional — **the deepest pain**
*Early-career professionals, small-business owners, tier-2/3 aspirants who read English fine but produce it slowly and self-consciously.* (Personas: Aman, Rekha.)
- **Pain & JTBD:** English production is an *access barrier* — escalation emails, SOPs, applications, supplier complaints. JTBD: *"speak my thoughts in Hindi/Hinglish, give me correct professional English I can send."* This is the deepest, most emotional pain in the whole map.
- **Why ideal:** the pain is access-level (not convenience) → very high value when solved; huge TAM; strong evangelism ("this changed how I work"). Strategically *the* mission segment.
- **Pay:** trickier — price-sensitive (students won't pay; small-biz will for a money-unblocking tool). Willingness varies wildly *within* the segment.
- **Reach:** harder — dispersed, less in tech communities; reached via YouTube (Hindi creators), WhatsApp virality, education/coaching channels, regional influencers.
- **Must-have:** transcribe→translate-to-English quality (their killer feature), honest onboarding, works despite low English confidence (read-back/TTS helps).
- **Risk:** willingness-to-pay + reachability are the weak legs; the students among them are high-volume, zero-revenue (but loud advocates).
- **Priority: #2–3 — mission-central, monetization-uneven.** Serve them, monetize the payers within them, let the rest evangelize.

### C4 · The privacy-first professional
*Anyone who refuses to put voice/data in the cloud: privacy-conscious devs, journalists, activists, individual lawyers, finance/health workers, IP-paranoid employees.*
- **Pain & JTBD:** wants dictation but *cannot* accept cloud upload. JTBD: *"dictate without a single word leaving my machine."*
- **Why ideal:** our moat is *the* reason they choose us — near-zero churn to cloud competitors, and they're the loudest privacy evangelists (they audit and vouch). Overlaps C1.
- **Pay:** privacy is worth paying for to them.
- **Reach:** privacy communities, security Twitter, HN, open-source circles; our zero-telemetry + (eventual) open-source story is the magnet.
- **Must-have:** verifiable on-device privacy, no telemetry, ideally open-source app.
- **Priority: #2 — small but sticky, evangelistic, perfectly moat-aligned.**

### C5 · The content creator / writer
*Writers, marketers, newsletter/scriptwriters, students drafting long-form.* (Persona: Priya.)
- **Pain & JTBD:** draft-zero problem; wants to *talk* a draft and get structured text. JTBD: *"ramble → structured document / styled output."* This is the Structure-Your-Thoughts + tone-dial segment.
- **Why ideal:** high willingness (₹500–1500/mo tool budget), values the *workflow layer* (our Pro tier), and confidentiality-bound freelancers value on-device (compliance).
- **Reach:** creator/marketing communities, writing tools' audiences, YouTube.
- **Must-have:** structuring, output styles, tone, reliability at volume.
- **Priority: #3 — the payer for the Pro/LLM layer (rung 2).**

### C6 · The NRI / diaspora
*Indians abroad (US/UK/Gulf/SEA) who text family/community in Hinglish and work in English.*
- **Pain & JTBD:** Hinglish texting on Western devices/keyboards is clunky; nostalgic + practical pull. JTBD: *"text my parents in proper Hinglish, work in English, on my Mac."*
- **Why ideal:** **Western purchasing power** ($ pricing, low price-sensitivity — the MONETIZATION.md international price book), reachable via diaspora communities, strong emotional hook.
- **Pay:** high — they pay $10–15/mo for tools without blinking.
- **Reach:** diaspora subreddits/FB groups, Indian-abroad influencers, university Indian associations.
- **Must-have:** Hinglish quality, cross-device (they're Apple-heavy), maybe regional-language expansion (Tamil/Telugu diaspora).
- **Priority: #2 — the high-ARPU consumer segment; disproportionate revenue per user.**

### C7 · The accessibility user
*People with RSI/typing injury, motor impairments, or for whom typing is physically hard.*
- **Pain & JTBD:** dictation is a *need*, not a convenience. Highest retention imaginable (no alternative).
- **Why ideal:** near-zero churn, deep gratitude/evangelism, and accessibility framing helps PR/press/App-Store narrative and future institutional sales.
- **Pay:** high (it's essential); sometimes employer/insurance-funded abroad.
- **Reach:** accessibility communities, disability orgs, OT/rehab networks.
- **Must-have:** reliability, hands-free operation, read-back (C3 synergy), long-form.
- **Priority: #3 — small, deeply loyal, strategically valuable for narrative + a cross-cutting need across all segments.**

---

## 4 · B2B ICPs (accounts, not individuals)

The B2B thesis (MONETIZATION.md 2.10): sell to orgs where employees speak Hinglish + write English **and** data must not leave devices. The buyer spends *company money against a compliance risk*, so per-seat prices run 2–3× consumer. **Sell productized/self-serve** — no sales army.

### B1 · Small professional-services firms (law, CA/accounting, consultancy) — **the B2B beachhead**
- **Who:** 5–50-person law firms, CA/audit firms, boutique consultancies. India has tens of thousands.
- **Pain & buyer:** Hinglish→English drafting all day + **client confidentiality is regulatory**. Buyer = a partner/office-manager; champion = a productivity-minded associate.
- **Why ideal:** on-device = **no DPDP-Act processor headache, no client-data-in-cloud** — the fastest "yes" a compliance-minded firm issues. Established dictation culture (lawyers dictated for a century). Per-seat, GST-invoiced, self-serve.
- **Pay:** ₹-per-seat annual; compliance budget; low price sensitivity.
- **Reach:** professional bodies (bar associations, ICAI networks), LinkedIn, referrals, legal-tech/CA-tech communities.
- **Must-have:** team license keys + GST invoice, offline model-preseed (skip N×1GB downloads), a compliance one-pager, per-seat admin-lite.
- **Expand:** one firm → the professional network (word-of-mouth within tight guilds is strong).
- **Priority: #1 B2B — narrowest, most compliance-driven, self-serve-able.**

### B2 · Independent healthcare practitioners & small clinics
- **Who:** solo doctors, small clinics (not hospital chains — those need integrations we won't build).
- **Pain & buyer:** Hinglish case notes/prescriptions dictated between patients; **health-data compliance** makes cloud a liability. Buyer = the doctor/clinic-owner.
- **Why ideal:** dictation is the classic voice money-maker (Dragon Medical built a business on it); on-device *sidesteps health-data compliance entirely*; high willingness (time = more patients).
- **Pay:** high — clinical time is expensive; compliance budget.
- **Reach:** medical associations, doctor communities, medical-device/EMR channels, referrals.
- **Must-have:** medical vocabulary (vertical fine-tune — a P4/vocab play), reliability, on-device compliance story.
- **Risk:** medical vocab accuracy is a real bar; verticalizing needs data.
- **Priority: #2 B2B — high-value, needs a vocab vertical, later.**

### B3 · Startups / tech companies with India offices
- **Who:** 20–500-person tech firms, Indian dev shops, global companies' India teams.
- **Pain & buyer:** productivity; employees prompt AI + write English all day. **Bottom-up** — an employee expenses it (C1!), a team lead standardizes. Their alternative (Wispr Teams) **sends audio to US clouds** → our on-device is a security-review shortcut.
- **Why ideal:** classic **land-and-expand** (consumer C1 → team → org), IT will *prefer* on-device (no data-egress review), tech-forward buyers.
- **Pay:** per-seat team/enterprise; expensable.
- **Reach:** *through C1* — individual adoption pulls the team deal. No cold sales needed.
- **Must-have:** team pack, admin-lite, the "no network calls" IT one-pager, SSO *not* required early.
- **Priority: #1–2 B2B — the natural expansion of the C1 beachhead; the cleanest B2B because it's sales-team-free.**

### B4 · Media / content houses / newsrooms
- **Who:** digital media, regional newsrooms, content agencies.
- **Pain & buyer:** Hinglish interview transcription, voice-notes-to-copy, fast English output. (MacWhisper's journalist-discount segment.)
- **Why ideal:** high-volume, values speed, journalist evangelism, press adjacency (they write about tools).
- **Pay:** moderate; org or freelancer budget.
- **Reach:** journalism networks, media-tech, freelancer communities.
- **Must-have:** transcription volume, speed, Hinglish, export.
- **Priority: #3 B2B.**

### B5 · Coaching centers / ed-tech / institutions
- **Who:** test-prep/coaching chains, colleges, ed-tech firms serving English-production learners (C3 at scale).
- **Pain & buyer:** students need English-production help (SOPs, applications, communication). Buyer = institution; users = students.
- **Why ideal:** institutional licenses = many seats per deal; mission-aligned (English access).
- **Pay:** institutional budget (but Indian-education price-sensitive).
- **Reach:** ed-tech partnerships, coaching-chain BD.
- **Risk:** slower institutional sales; price sensitivity; edges toward B2B2C.
- **Priority: #3–4 — later, partnership-driven.**

### B6 · BPO / customer-support / sales floors (handle with care)
- **Who:** support/sales teams writing English responses from Hinglish thoughts, at scale.
- **Why *not* straightforwardly ideal:** big seat counts, *but* this edges into the **enterprise-voice-platform** market (Sarvam/Gnani turf) — cloud, integration-heavy, sales-cycle-driven, and often agent-*assist*/automation, not dictation. A dictation-per-seat play here is possible but competes on their terms.
- **Priority: watch, don't chase early.** A trap disguised as a whale — see anti-ICP.

---

## 5 · Other models (beyond simple B2C/B2B)

### O1 · B2B2C / Platform (API / SDK) — the biggest long-term prize
*Indian app-makers who want on-device Indic voice input **inside their product** (chat apps, productivity apps, super-apps, keyboards).*
- **Why it matters:** this is STRATEGY rung 3–4 — you become *the voice-input layer* others embed, reaching millions of end-users without owning the consumer relationship. Potentially the largest scale.
- **Pay:** SDK license / per-MAU / per-device.
- **Ideal-fit:** requires our own model (so we can license it) + a real SDK — a *later* motion, but the one that could make it venture-scale.
- **Priority: someday (rung 3+), but design the model/data ownership now so it's *possible*.**

### O2 · OEM / device embedding — the distribution moonshot
*Indian Android OEMs (Lava, Micromax, regional brands), laptop makers, or IME/keyboard partnerships.*
- **Why it matters:** pre-install/embed = distribution rivaling Google's, on the devices mid-market India actually buys (the segment Google's flagship-gated Rambler *won't* reach for years — a real window).
- **Pay:** licensing / revenue-share / per-device.
- **Risk:** long deals, needs a company + funding + mobile stack; high effort.
- **Priority: moonshot, later — but the mid-market-Android gap is a genuine strategic opening worth a bet if we get to Android.**

### O3 · B2G / public sector
*Government departments, public services, sovereign-AI / Bhashini-adjacent Indic-accessibility programs.*
- **Why it matters:** huge scale, sovereign-AI tailwind, mission-aligned (Indic-language access to services), potential grants/partnerships.
- **Why *not* early:** procurement-heavy, slow, relationship-driven, Devanagari/formal orientation (far from our consumer register), and a solo dev can't run gov sales.
- **Priority: someday / partnership — but the sovereign-AI narrative + grants (YC_CREDITS_PLAN §5) are worth riding *now* for credibility and non-dilutive money, even before any B2G revenue.**

### O4 · Developer / open-source community (a channel, not a customer)
*Not a paying ICP — a distribution + credibility + hiring channel* (the VoiceInk model: GitHub stars = marketing, code = privacy proof).
- **Why it matters:** feeds C1/C4, builds trust, could attract contributors and the mobile-ML co-founder you need.
- **Priority: cultivate as a channel** if/when we open-source the app (MONETIZATION.md 2.9).

---

## 6 · The anti-ICP — who we deliberately do NOT serve (defining this is half the value)

Chasing these *loses*, so we say no on purpose:

- **Casual mobile-only texters** who want free Hinglish on a phone → **Gboard/Rambler serve them free.** Unwinnable, unmonetizable. Not our customer.
- **Pure-English dictation users** with no Indian-language need → served by Apple/Wispr/free defaults; we have no wedge; commodity fight.
- **Big-enterprise voice-bot / call-center-automation buyers** → Sarvam/Gnani turf; cloud, integration projects, sales cycles; a trap disguised as a whale (B6). Different company.
- **Cloud-wanting buyers** (want the audio in the cloud for their own pipeline) → contradicts our moat; sends us to compete with cloud APIs on their terms.
- **Free-only, never-pay, never-evangelize users** in segments with no expansion path → fine as goodwill, but not a segment to *build for*.
- **Deep-vertical enterprise needing SSO/HIPAA-BAA/MDM now** → premature; that's VC-funded Wispr-Enterprise's game (MONETIZATION.md said don't build it early).

**The discipline:** every "no" here protects focus. An indie dies by trying to serve everyone; we win by being *undeniable* for a few desperate segments before widening.

---

## 7 · Prioritization — the sequence

**The beachhead (find PMF here first, per PRODUCT_MARKET_FIT.md):**
> **C1 (AI-power-users) + C4 (privacy-first) overlap**, with **C2 (high-volume communicators)** as the immediate widen. Reason: sharpest pain, lowest CAC (dev/privacy communities), highest evangelism, perfect moat-fit, and reachable *today* on Mac. Land the wedge (speak-desi-write-English + rock-solid Hinglish + on-device) with them.

**Then, in order:**
1. **C1/C4/C2** consumer beachhead → prove PMF, get to revenue.
2. **B3 (India-office startups)** — the *natural* land-and-expand from C1 (individual → team), the sales-team-free B2B.
3. **C6 (diaspora)** — high-ARPU consumer revenue via the international price book.
4. **B1 (law/CA firms)** — the compliance-driven B2B beachhead; productized self-serve + GST + one-pager.
5. **C5/C3** — the Pro/LLM-layer payers + the mission-deepest segment (monetize the payers, let the rest evangelize).
6. **B2 (clinics)** — after a medical-vocab vertical exists.
7. **C7 (accessibility)** — cultivate throughout for loyalty + narrative.
8. **O1 (API/SDK), O2 (OEM), O3 (B2G)** — the rung-3+ scale plays; enable them by owning the model/data now, execute later (with funding).

---

## 8 · Scoring summary

Scale 1–5 (5 = best). "Reach" = cheap for an indie to acquire.

| ICP | Pain | Alt-gap | Pay | Reach | Retain | Expand | Evangelize | Moat-fit | Priority |
|---|---|---|---|---|---|---|---|---|---|
| **C1 AI-power-user** | 5 | 5 | 4 | 5 | 4 | 4 | 5 | 5 | **1 (beachhead)** |
| C2 High-volume comm. | 4 | 4 | 4 | 4 | 5 | 4 | 3 | 4 | 2 |
| C3 Can't-produce-English | 5 | 5 | 2 | 2 | 4 | 3 | 4 | 5 | 2–3 |
| C4 Privacy-first | 4 | 5 | 4 | 4 | 5 | 3 | 5 | 5 | 2 |
| C5 Creator/writer | 4 | 3 | 4 | 3 | 4 | 3 | 3 | 4 | 3 |
| C6 Diaspora | 4 | 4 | 5 | 3 | 4 | 3 | 4 | 4 | 2 |
| C7 Accessibility | 5 | 4 | 4 | 2 | 5 | 2 | 4 | 4 | 3 |
| B1 Law/CA firms | 4 | 5 | 5 | 3 | 5 | 4 | 3 | 5 | **1 (B2B)** |
| B2 Clinics | 4 | 5 | 5 | 2 | 5 | 3 | 3 | 5 | 2 |
| B3 India-office startups | 4 | 4 | 5 | 4* | 5 | 5 | 4 | 4 | **1–2** |
| B4 Media | 3 | 3 | 3 | 3 | 4 | 3 | 4 | 3 | 3 |
| B5 Ed-tech/coaching | 4 | 4 | 3 | 3 | 4 | 4 | 3 | 4 | 3–4 |
| O1 API/SDK | 4 | 4 | 4 | 2 | 5 | 5 | 3 | 4 | someday |
| O2 OEM | 3 | 4 | 4 | 1 | 5 | 5 | 2 | 4 | moonshot |
| O3 B2G | 3 | 4 | 4 | 1 | 4 | 4 | 2 | 3 | someday |

*B3 "Reach" is high *because* it's reached *through* C1, not cold.

---

## 9 · How the ICP wires into everything

- **PMF (PRODUCT_MARKET_FIT.md):** find fit on **C1/C4** first; the Sean-Ellis "very disappointed" lovers should cluster there — if they cluster *elsewhere*, that's a signal to re-pick the beachhead.
- **Monetization (MONETIZATION.md):** C6 + B1/B3 justify the international/enterprise price books; C1/C5 buy the Pro LLM layer; C3's students are the free-tier evangelists, not the payers.
- **Product (features/, problems/):** C1 needs transcribe→translate (build first) + reliability; B1/B2 need vertical vocab + compliance packaging; C3/C7 need read-back; everyone needs P1 quality.
- **Strategy (STRATEGY.md rungs):** C1→C2→C6 (rung 1–2 consumer) → B3→B1 (SMB) → O1/O2 (rung 3–4 platform/OEM) is the ladder from indie to venture-scale.
- **Competitors (competitors/):** every ICP is chosen partly *because* a specific competitor fails them — C1/C4 because cloud tools (Wispr) breach privacy; C3 because free defaults mangle Hinglish; B1/B2 because cloud STT can't make the "nothing leaves the device" promise.

**One-line summary:** hunt **AI-power-users + privacy-first pros** first (sharpest pain, lowest CAC, best moat-fit, most evangelism), expand naturally into **their startups' team deals** and **the diaspora's dollars**, land **law/CA firms** as the compliance-driven B2B, and keep **API/SDK/OEM** as the rung-3+ scale prize you *enable now* (by owning model + data) and *execute later* — while deliberately **not** fighting Google for casual mobile texters or Sarvam for enterprise voice-bots.
