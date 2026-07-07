# Voice AI Market Study — 2026

Deep market research: who's building what, how they monetize, how they crack
B2B and B2C, and what it means for Desi Dictation's roadmap and pricing.
Compiled 2026-07-07 from investor theses (a16z, AssemblyAI's industry series),
funding data (Tracxn/Sacra/press), company pricing pages, and prior model-layer
research (MODEL_RESEARCH.md). Sources at bottom.

---

## 1. Executive summary

- Voice AI is a **$18–22B market growing ~35% CAGR**; $1.8B+ of equity closed
  across the segment in 2025–26. Two big structural facts matter to us:
  1. **Raw transcription is a commodity** — Whisper killed ASR-API margins;
     Deepgram/AssemblyAI moved up-stack into agents. Value now lives in the
     application layer and verticals.
  2. **Our exact category (B2C dictation) has a proven breakout**: Wispr Flow —
     $81M raised, ~$700M→$2B valuation talks, ~$10M ARR at $15/mo, 2.5M
     downloads, 70% 12-month retention. The category works. Nobody in it
     owns code-mixed languages.
- The India layer is its own story: government-backed sovereign AI (Sarvam,
  Gnani got IndiaAI compute), BFSI-first enterprise GTM, and a widely-cited
  Arkam prediction that **the first 200M-user AI app in India will be
  voice-led**. Nobody there is building consumer dictation either — they're
  all B2B/GovTech.
- For us: local-first + one-time pricing is not just ideology — it's the one
  cost structure where **lifetime pricing is actually sustainable** (zero
  marginal inference cost), unlike every cloud competitor. Details in §8.

---

## 2. The taxonomy — six layers of the market

```
┌─ L1 Models/weights (open: Whisper, Parakeet, Oriserve · closed: Saaras, Avalon, Scribe)
├─ L2 STT/TTS APIs (Deepgram, AssemblyAI, ElevenLabs, Gladia, Speechmatics, Sarvam)
├─ L3 Agent infra/orchestration (Vapi, Retell, Bland, LiveKit, Pipecat)
├─ L4 Horizontal apps
│    ├─ Dictation (Wispr Flow, Superwhisper, Aqua, MacWhisper, **us**)
│    └─ Meeting notes (Granola, Otter, Fireflies, Fathom)
├─ L5 Vertical apps (Abridge/Suki/Freed health · legal · sales intelligence)
└─ L6 Voice-native agents/assistants (Sierra; 11.ai — voice as MCP control surface)
```

## 3. Layer analyses

### L2 — STT APIs: the commodity war
Pricing collapsed: AssemblyAI Universal-2 from **$0.15/hr**, ElevenLabs Scribe
$0.22–0.48/hr, Deepgram Nova-3 $0.46/hr, volume discounts 20–67%. Sarvam
Saaras at ₹30/hr sits right in this band for Indic. Everyone is fleeing
up-stack (Deepgram bought OfOne, raised $130M @ $1.3B to chase agents;
AssemblyAI bundles sentiment/topics/moderation). **Lesson: never compete
here.** Selling Hinglish STT as an API means a price war against funded
commodity sellers.

### L3 — Voice agents: where the funding went
~87% of "builders" survey as actively building agents; BFSI is the largest
vertical (32.9%), healthcare the fastest-growing (37.8% CAGR). ElevenLabs
raised $500M @ $11B. GTM here is enterprise-direct or platform-for-agencies.
Crowded, capital-intensive, latency-obsessed. Not our war either.

### L4a — Dictation (our category) — full competitive table

| Player | Model/infra | Pricing | Traction | GTM signature |
|---|---|---|---|---|
| **Wispr Flow** | cloud (server-side) | **$15/mo / $144/yr only**; free = 2,000 words/week | ~$10M ARR, 2.5M downloads, **270 F500 orgs**, 70% 12-mo retention, $81M raised, ~$2B talks | B2C polish → bottom-up into enterprise; "context-aware formatting" as moat |
| **Superwhisper** | on-device (Whisper/Parakeet) | $9.99/mo; lifetime **$249→$849** (240% hike!) | strong Mac niche | privacy/on-device angle; lifetime repricing shows lifetime+cloud-features tension |
| **Aqua Voice** (YC) | own cloud model "Avalon" (#1 proprietary on OpenASR at Oct-25 debut) | $8/mo annual; **Team $12/user/mo**; free 1,000 words once | YC-backed, fast pipeline | accuracy benchmark marketing; team tier = SMB wedge |
| **MacWhisper** | on-device | €59 lifetime (Gumroad) | ~300k copies, solo dev | the indie/lifetime/privacy playbook (our closest analog) |
| **Desi Dictation** | on-device (Apex/Vaani/turbo) | ₹999–1,499 lifetime (planned) | pre-launch | **only player with code-mixed Hinglish as the core feature** |

Category dynamics: free tiers are **word-capped** (Wispr's 2k words/week burns
out in ~4 days — deliberate); retention is the metric VCs cite; the fault line
is **cloud-accuracy vs on-device-privacy**, and each side is racing to blunt
the other's advantage (Aqua publishes accuracy numbers; Superwhisper adds
Parakeet for speed).

### L4b — Meeting notetakers: a cautionary adjacent tale
14+ tools in mainstream use (from 1 in 2025); Fathom weaponized an unlimited
free tier; Granola differentiated on **bot-free/invisible capture**; Otter on
accuracy; Fireflies on sales intelligence. The analyst consensus:
**"transcription + summary as a standalone product is over — winners are
defined by the non-obvious layer on top."** Any expansion we make into meetings
must bring the Hinglish layer, or it's a me-too in a 14-player knife fight.

### L5 — Vertical scribes: where the real money is
Healthcare ambient scribing is the proof that voice + vertical = enterprise
gold: **Abridge — $800M+ raised, $100M+ ARR ($117M contracted), ~$2,500 per
clinician per year**, 250+ health systems, #1 KLAS two years running. Suki
($168M raised, 300+ systems), Freed at $39–119/mo self-serve for individual
docs. Sales pattern: land a marquee system (Mayo/Kaiser), compliance +
EHR-integration as the moat, price per-seat-per-year.
**India angle nobody has taken: Indian clinical conversations are heavily
code-mixed.** An "Abridge for India" needs exactly the Hinglish competence
we're building — at Indian price points, greenfield.

### L6 + trend — voice as a control surface
11.ai (ElevenLabs, Mar-26) is the first mainstream MCP-native voice assistant:
voice driving the whole tool stack, not just producing text. Dictation apps
sit one feature away from "voice commands" — a likely convergence point.

### The India layer (distinct GTM culture)
- **Sarvam** — sovereign-AI play: $53M Series A, IndiaAI Mission compute, open
  LLMs as brand, **closed ASR as revenue** (₹30/hr API). Enterprise + govt.
- **Gnani** — BFSI-first: voice biometrics/fraud + agents; 100+ enterprises
  (TVS Credit, Muthoot). Vachana STT. IndiaAI compute recipient.
- **CoRover** — GovTech scale: AskDisha for Indian Railways (hundreds of
  millions of users), airports, state portals.
- **Smallest.ai** — TTS infra.
- Pattern: **all B2B/Gov, vernacular-first, none consumer.** The consumer
  voice-AI shelf in India is empty while the Arkam thesis says India's first
  200M-user AI app will be voice-led. That's our white space.

## 4. GTM patterns decoded

**B2C (our launch motion):**
1. Free tier capped by *usage* (words/week), not features — converts habitual
   users, filters tourists.
2. Privacy/on-device as a marketable feature, not a footnote (Granola's
   bot-free positioning; Superwhisper's offline pitch).
3. Distribution = build-in-public + PH + niche communities; category winners
   all had a signature demo GIF/video.
4. Lifetime pricing works **only** when marginal cost ≈ 0 (MacWhisper: yes;
   Superwhisper: broke when cloud features crept in → $849 lifetime).

**B2B (how dictation cracks enterprise — the Wispr playbook):**
1. Individual pros adopt the B2C product at work (bottom-up).
2. Champions request team billing/admin → team tier ($12–15/user/mo).
3. Security review artifacts (SOC2, DPA, on-prem/on-device story) unlock
   procurement. *On-device is a security-review cheat code — nothing leaves
   the laptop.*
4. Verticals (health/legal) instead need direct enterprise sales + compliance
   + integrations — a different company, effectively.

## 5. Pricing reference table (2026)

| Segment | Typical price |
|---|---|
| STT API | $0.15–0.48/hr (Sarvam ₹30/hr) |
| B2C dictation sub | $8–15/mo |
| B2C dictation lifetime | €59 (MacWhisper) … $849 (Superwhisper post-hike) |
| Team dictation | $12–15/user/mo |
| Meeting notes | free-tier war; $10–34/user/mo paid |
| Health scribe (enterprise) | ~$2,500/clinician/yr |
| Health scribe (self-serve) | $39–119/mo |

## 6. Where the space is heading (12–24 mo)

1. **App-layer capture of commodity ASR** — model quality converges; UX,
   context-awareness, and distribution decide winners.
2. **Verticalization** — every high-stakes conversation domain gets its scribe.
3. **Voice → action** (MCP/agents): dictation apps grow command palettes.
4. **On-device renaissance** — Apple-silicon NPUs + privacy regulation favor
   local; cloud players will ship "local modes."
5. **India: voice-led mass adoption** — but built by B2B/Gov players; consumer
   remains open.
6. **Consolidation** — expect dictation apps to be acquired by agent/notes
   platforms wanting the input wedge.

## 7. Threat matrix for us

| Threat | Likelihood | Note |
|---|---|---|
| Wispr/Aqua add Hindi-Hinglish | Medium | cloud models can fine-tune fast; our moats: on-device, India pricing, orthography/dictionary layer, community |
| Apple ships good Hinglish dictation | Low-Med (years) | existential long-term; move fast, own the niche + power features |
| Sarvam goes consumer | Low | counter-positioned (enterprise/sovereign); watch anyway |
| MacWhisper adds Hinglish model | Medium | trivially possible (Apex is open!) — our defense is focus: evals, dictionary, India GTM |

## 8. Implications for Desi Dictation

### Pricing (the math that matters)
- Our marginal cost per user ≈ **zero** (their hardware runs the model). Wispr
  pays inference on every word. **Lifetime ₹999–1,499 is sustainable for us
  and impossible for them** — keep it; it's a structural advantage, not a
  discount. Anchor: ₹1,499, launch ₹999.
- Add a **Team pack** early (5× ₹749/seat, one-time + priority support):
  Indian startups expense one-time purchases far more easily than
  subscriptions; mirrors MacWhisper's volume packs, undercuts Aqua's
  $144/user/yr.
- Subscriptions ONLY if/when we ship features with real recurring cost
  (hosted best-model API for low-RAM devices, cloud sync). Price as add-on
  (₹99–199/mo), never gate the core. Superwhisper's $849-lifetime mess is the
  cautionary tale of mixing models.

### Feature roadmap, market-informed (ordered)
1. **Win dictation completely first** (Wispr proves depth > breadth: 70%
   retention on ONE feature done excellently).
2. **Voice commands / MCP-lite** ("nayi line", "bhej do") — rides trend #3,
   deepens moat, still dictation-adjacent.
3. **Team pack + admin page** — bottom-up B2B revenue with zero new product.
4. **Windows port** — Wispr is cross-platform; India is Windows-heavy; biggest
   TAM unlock on the list (whisper.cpp is portable; the OS layer is the work).
5. **Meeting notes (Hinglish)** — only after PMF, and only bot-free
   Granola-style with the Hinglish layer as the differentiator.
6. **"Abridge for Bharat" (clinics)** — the big vertical option: code-mixed
   clinical scribing at Indian price points (₹500–1,500/doctor/mo). Different
   company eventually; keep as expansion thesis, not roadmap.
7. **Never**: sell Hinglish STT as a raw API (commodity war vs funded players).

### The one-line strategy this study supports
**Be the MacWhisper of India first (lifetime, local, loved), with Wispr's
retention discipline, and keep the clinic-scribe vertical in the back pocket.**

---

# PART II — Deep dives

## 10. History: three eras of dictation, and the lesson each left

**Era 1 — Dragon (1982–2022):** Dragon Systems founded 1982; Dragon
NaturallySpeaking (1997) was the first usable consumer dictation and *owned*
the category for two decades — $60–500 licenses, per-user voice profiles,
15-minute training sessions. The corporate saga is instructive: acquired by
Lernout & Hauspie in 2000, L&H collapsed in an accounting-fraud bankruptcy,
ScanSoft (later renamed Nuance) bought the assets for **$39.5M** in 2001 — and
Microsoft acquired Nuance in 2022 for **$19.7B**, its second-largest deal ever
at the time. What Microsoft wanted was *healthcare* (Dragon Medical/DAX —
today's Copilot in Epic), not consumers: **Dragon Home was discontinued in
2023 and the consumer desktop product is no longer updated.**
→ *Lesson 1: the incumbent formally abandoned consumer dictation. The
category's leader walked away right as Whisper made the tech free. Wispr,
Superwhisper, Aqua — and us — exist in that vacuum.*
→ *Lesson 2: voice value concentrates in verticals over time (Dragon's
terminal form was a medical scribe at a $19.7B price tag — the same shape
Abridge is now growing into).*

**Era 2 — Assistants (2011–2022):** Siri/Alexa/Google Assistant made speech
input ubiquitous but shallow (commands, not composition), trained a billion
people to *tolerate* voice UIs, and plateaued — the hardware assistants never
found a business model (Alexa's multi-billion-dollar losses are public
record). → *Lesson: voice for CONTROL undermonetizes; voice that produces
WORK-PRODUCT (text, notes, documents) monetizes.*

**Era 3 — Whisper (2022–now):** open weights at near-human accuracy reset the
cost of entry to zero, commoditized the model layer, and moved all
differentiation up-stack. Every company in Part I §3 is a child of this event.

## 11. Unit economics — the spreadsheet view

**Cloud dictation (Wispr-shaped):** Assume an active user dictates 30–60
min/day. At even $0.15–0.45/hr STT cost (before LLM formatting passes,
storage, egress), that's roughly **$1.5–8/user/month of COGS** against $15
revenue — a real but manageable 10–50% gross-margin drag that *scales with
engagement* (your best users cost the most). This is why: free tiers are
word-capped; why "unlimited" cloud plans quietly rate-limit; and why lifetime
pricing is impossible for them (unbounded liability).
**On-device (us/MacWhisper-shaped):** COGS per user-month ≈ **₹0** (their
silicon, our zero servers). Costs are all fixed (dev time) or per-transaction
(Gumroad ~10%). Lifetime ₹999 at 90% margin is durable at any engagement
level; heavy users cost the same as light ones. *The pricing model isn't a
choice, it's a consequence of the architecture.* Corollary: any feature we
ship that requires OUR servers (sync, hosted models) breaks this and must be
priced as a subscription add-on — never bundled into lifetime.
**The Superwhisper case study in numbers:** lifetime $249 → $849 (+240%) while
monthly stayed $9.99. Read: cloud/AI features crept into a lifetime SKU,
making early buyers permanently unprofitable; repricing was the only exit.
**LTV/CAC sanity for our launch:** ₹999 one-time, near-zero CAC channels
(organic content, PH, communities) → contribution-positive from the first
sale. The trap to avoid is the "lifetime revenue ceiling": no recurring base
means growth must come from *new* users forever — mitigations: team packs,
future paid major versions (v2 upgrade pricing, the classic indie-Mac model:
what Sketch/Things do), and optional recurring add-ons.

## 12. The distribution meta-game: the SEO comparison war

A striking find while researching: most "X vs Y" and "best dictation apps
2026" content is published *by the competitors themselves* (spokenly.app,
getvoibe.com, aquavoice.com/vs/, superwhisper.com/vs/, wisprflow.ai/best-…,
weesperneonflow.ai — all vendor blogs). The category's real battleground is
**owning the comparison query**. Implications for us: (a) publish honest
`/vs/macwhisper`, `/vs/wispr-flow` pages at launch — it's table stakes, not
spam; (b) there is NO existing content for "hinglish dictation" queries — we
can own the entire query space cheaply before anyone knows it exists; (c)
vendor benchmarks (Aqua's "97.3% on technical terms") are marketing artifacts —
our published evals with open methodology (evals/) can be a *credibility*
weapon the indie tier rarely deploys.

## 13. Hardware voice — the adjacent category that keeps burning money

Humane AI Pin (dead, ~$700M burned), Rabbit R1 (irrelevant within months),
**Limitless Pendant: acquired by Meta Dec-2025 and being sunset** — existing
users parked on a free plan, device EOL by late 2026. The survivor is
**Plaud** (NotePin, ~$160 + subscription, 112-language transcription,
polished hardware+AI loop), plus open-source Omi absorbing orphaned Limitless
users. → *Readings: (1) hardware is where voice startups go to die — phones
and laptops already have the mic; (2) the acquisition wave (Meta/Limitless)
signals big platforms buying always-on-audio expertise — expect more
consolidation up the stack; (3) for us: never hardware; but Plaud's "custom
vocabulary" and template-summaries validate our dictionary/post-processing
direction.*

## 14. Regulation — privacy law just became a GTM asset

**India's DPDP Act 2023 + Rules 2025** are phasing in NOW: consent managers
operational Nov-2026, full compliance ~May-2027. Any app processing Indians'
personal data is a "data fiduciary": granular consent (in Indian languages!),
breach notification, data-rights handling. Voice recordings are personal data.
**A cloud dictation product serving India will need a consent/compliance
apparatus; a local-first product that never transmits audio mostly designs
the problem away.** Same story with the EU AI Act's transparency obligations.
→ For enterprise sales this converts from ideology to checkbox: "on-device =
your DPDP/GDPR surface is ~zero" is a *procurement argument*. Bake it into
the landing page and future team-plan collateral. (Bhashini — the government's
language-AI platform — is also becoming the consent/multilingual rails; a
future "works with Bhashini" story is available to us if GovTech ever matters.)

## 15. Defensibility: what actually compounds here

Ranked for our situation:
1. **The orthography/dictionary layer** (VARIANTS map, user dictionaries,
   normalization) — small, unsexy, and *cumulative*; it encodes thousands of
   micro-decisions competitors must rediscover.
2. **The personal/community eval corpus** — real Hinglish dictation
   distribution; no benchmark exists, so whoever HAS the data defines quality.
3. **Distribution/brand in the niche** — owning "hinglish dictation" queries
   + community trust (privacy stance is verifiable: it's open behavior, not
   promises).
4. **The opt-in correction flywheel** (FINETUNING.md Part 9) — eventually
   yields training data nobody can buy.
5. NOT defensible: the models themselves (Apex is public, whisper.cpp is MIT —
   anyone can clone our stack in a week; see Threats §7). Speed and the four
   above are the game.

## 16. M&A / consolidation map (who buys whom)

Observed pattern 2025–26: **platforms buy input wedges** (Meta↔Limitless;
Deepgram↔OfOne to go up-stack; ElevenLabs building 11.ai to own the surface).
Plausible acquirers for dictation apps: notes/productivity suites (Notion,
Grammarly — Grammarly already ships voice features), agent platforms wanting
input distribution, and in India specifically: Zoho (privacy-aligned,
India-proud, owns Writer/WorkDrive), Sarvam (consumer distribution gap),
Krutrim/Ola (consumer AI ambitions). Not a plan — but it prices the option:
niche ownership + retention is what gets bought, revenue multiple second.

## 17. The long tail of our category (know thy cohort)

Beyond the big four: Voibe, Spokenly, Willow, VoiceInk, Typeless, Voicy,
BetterDictation, Whisper Notes, MacParakeet, Dictato — a dozen indie
Mac/Windows dictation apps, mostly $5–10/mo or small lifetime, mostly
whisper.cpp or Parakeet wrappers, differentiating on micro-features (offline,
vocabularies, app modes) and SEO. Two readings: (1) low barrier to entry is
real — see §15 for what actually defends; (2) every one of them targets
English; the code-mixed gap is category-wide, not just among the leaders.
Accessibility deserves note: Talon Voice (hands-free coding) has a devoted
paying community — dictation tools have an under-served accessibility segment
whose loyalty is extreme (relevant to us later: Hinglish-speaking users with
RSI/motor constraints have literally zero options today).

## 18. India deep-dive addendum

- **Bhashini** (National Language Translation Mission): government rails for
  22-language ASR/TTS/MT — free API tiers for startups, becoming the consent/
  language infrastructure of DPDP compliance. Watch: if Bhashini's Hindi ASR
  gets good + free, the *API* layer for Indic speech commoditizes even faster
  (fine for us; fatal for API-sellers).
- **IndiaAI Mission compute** went to Sarvam, Gnani, Soket, Gan — sovereign
  models are politically funded; consumer apps are not. The state is
  effectively subsidizing our model-layer inputs (open Indic models keep
  improving on public money).
- **Krutrim (Ola)**: consumer-AI ambitions + assistant plays; the most
  plausible Indian big-co to wander into consumer voice. Monitor.
- **Buying behavior**: India's B2C software willingness-to-pay is low BUT
  one-time ₹999 sits under the UPI impulse threshold and avoids subscription
  fatigue (the #1 stated reason for churn in Indian consumer SaaS surveys).
  PPP pricing + lifetime is not just viable here, it's the culturally correct
  model. For B2B: Indian SMEs pay for WhatsApp-adjacent productivity;
  team-pack GTM through founder/CTO communities (SaaSBoomi, Headstart) is the
  wedge.

## 9. Sources
[a16z voice agents thesis](https://a16z.com/ai-voice-agents/) · [a16z 2025 update](https://a16z.com/ai-voice-agents-2025-update/) · [AssemblyAI: Voice AI in 2026](https://www.assemblyai.com/blog/voice-ai-in-2026-series-1) · [b2venture call-center map](https://www.b2venture.vc/stories/the-market-map-of-ai-voice-call-center-agents) · [Wispr pricing](https://wisprflow.ai/pricing) · [Wispr funding/traction (Tracxn)](https://tracxn.com/d/companies/wispr-flow/__XTPty9fIPUjngX0uMeYcKZnHJVG4WCoPwSamLLI2QjE) · [Aqua Voice](https://aquavoice.com/#pricing) · [Superwhisper vs Aqua](https://superwhisper.com/vs/aqua-voice) · [STT API benchmarks/pricing](https://futureagi.com/blog/speech-to-text-apis-in-2026-benchmarks-pricing-developer-s-decision-guide/) · [AssemblyAI vs Deepgram pricing](https://brasstranscripts.com/blog/assemblyai-vs-deepgram-pricing-high-volume-comparison) · [Abridge breakdown (Contrary)](https://research.contrary.com/company/abridge) · [Abridge revenue (Sacra)](https://sacra.com/c/abridge/) · [Abridge $300M E](https://www.fiercehealthcare.com/ai-and-machine-learning/ambient-ai-startup-abridge-scores-300m-series-e-backed-a16z-and-khosla) · [Scribe funding overview](https://www.iatrox.com/blog/healthcare-ai-scribe-funding-kin-abridge-suki) · [Granola pricing comparison](https://www.granola.ai/blog/meeting-note-tool-pricing-granola-vs-fireflies-fathom-otter) · [Notetaker landscape](https://www.useluminix.com/reports/industry-analysis/ai-meeting-notes-comparison-granola-vs-otter-vs-fireflies-vs-fathom-2026) · [India voice AI surge](https://www.whalesbook.com/news/English/tech/Indias-Voice-AI-Surge-Startups-Transform-Communication-Build-New-Infrastructure/69672eca7f43a0ac03d334e2) · [India AI funding Q1-26](https://drudhh.com/ai-startup-funding-india-q1-2026/) · [Tracxn India voice AI](https://tracxn.com/d/explore/voice-ai-startups-in-india/__s7thq7EI12tPI5Mmcnok_iuzpK5VWI3-4ZhUxzXfMmA/companies) · plus MODEL_RESEARCH.md sources
**Part II additions:** [Dragon NaturallySpeaking history (Wikipedia)](https://en.wikipedia.org/wiki/Dragon_NaturallySpeaking) · [Microsoft–Nuance 8-K](https://www.sec.gov/Archives/edgar/data/0000789019/000119312521112687/d171120dex991.htm) · [Forbes on the Nuance deal](https://www.forbes.com/sites/enriquedans/2021/04/13/theres-nothing-nuanced-about-microsofts-plans-for-voice-recognition-technology/) · [Limitless→Meta sunset / wearables 2026 (TechTimes)](https://www.techtimes.com/articles/314655/20260216/best-ai-notetaking-devices-2026-comparing-rewind-pendant-plaud-ai-recorder-other-wearable-mics.htm) · [Plaud NotePin](https://www.plaud.ai/products/notepin) · [EY: DPDP Act + Rules guide](https://www.ey.com/en_in/insights/cybersecurity/decoding-the-digital-personal-data-protection-act-2023) · [Fisher Phillips: DPDP deadlines](https://www.fisherphillips.com/en/insights/insights/indias-new-data-privacy-rules-are-here) · [DLA Piper India data law](https://www.dlapiperdataprotection.com/?t=law&c=IN)
