# Go-To-Market v2 — Desi Dictation

Aligned with the product as actually built (v0.4.x: free-for-all beta,
on-device, lifetime-pricing architecture) and with the feedback/measurement
system below. Strategy rationale lives in MARKET_STUDY.md; this is the
operating plan.

## 0. The strategy in one paragraph

Own "Hinglish dictation" before anyone knows it's a category. Free beta →
friends/community (weeks 1–4) → public free launch with the demo GIF as hero
asset (weeks 4–8) → paid Pro on Gumroad ₹999 lifetime once retention proves
itself. Local-first is the brand: it's simultaneously the privacy story, the
DPDP-compliance story, the lifetime-pricing story, and the reason our COGS is
zero (MARKET_STUDY §11, §14). Feedback runs on a privacy-consistent system
(§4) — we measure without surveilling.

## 1. Phases

### Phase A — Friends beta (now → +3 weeks) · Goal: 20 users, 10 activated
- Prereqs: models on HF (`publish_models.sh`), DMG + SETUP_GUIDE link.
- Hand-picked: Mac-using Indian devs/PMs who chat in Hinglish daily.
- Personal onboarding (5-min call or WhatsApp voice note walkthrough) — at
  this stage every install is a user-research session, not distribution.
- **Activation metric: 3 dictations on 3 separate days** (self-reported / seen
  in their shared stats — §4). Below 50% activation = fix onboarding before
  widening.

### Phase B — Public free beta (+4 → +8 weeks) · Goal: 500 installs, community formed
- Launch surfaces in order: X thread (build-in-public story + the WhatsApp-Web
  Hinglish GIF), r/developersIndia, Product Hunt, Show HN (engineering angle:
  local Hinglish ASR on whisper.cpp), LinkedIn.
- Comparison/SEO pages live at launch (MARKET_STUDY §12): /vs/wispr-flow,
  /vs/macwhisper, /vs/superwhisper + "best hinglish dictation" — we can own
  the entire query space for ~zero cost.
- **Community = WhatsApp group** (not Discord — meet Indian users where they
  are; Discord later for devs). This is the qualitative feedback engine.
- Beta covenant, stated publicly: free during beta, whatever you use stays
  yours; Pro tier later funds development.

### Phase C — Paid launch (when, not date-driven)
Triggers: ≥40% of beta users active in week 4 (per shared stats + community
signal), insertion bugs at zero for 2 weeks, notarized build, license flow
tested. Then: Gumroad ₹999 launch (anchor ₹1,499), `DESILAUNCH` -20% week-one
code, students/journalists 25%, Team pack 5×₹749. Free tier remains genuinely
useful forever (Swift model + core dictation) — the MacWhisper trust playbook.

## 2. Positioning & message house

**Roof:** *"Boliye jaise bolte ho — likha waisa hi jayega."* (Speak how you
actually speak.)
**Pillars:** (1) Hinglish that finally works — WhatsApp-style Roman output;
(2) 100% on your Mac — audio never leaves, verifiably (open architecture);
(3) Yours forever — ₹999 once, no subscription.
**Proof points:** the GIF; open evals methodology (evals/) vs marketing
benchmarks; DPDP-friendly by architecture (MARKET_STUDY §14).

## 3. Getting users: channel playbook (effort-ranked)

| Channel | Play | Success signal |
|---|---|---|
| X build-in-public | weekly artifact (eval tables, failure-mode stories from BUILD_LOG — devs love honest engineering) | saves/bookmarks, DMs |
| Reddit r/developersIndia | story post + AMA in comments | upvote ratio, installs day-of |
| Product Hunt | India-morning launch, hunter with voice-AI audience | top-5 day |
| Show HN | "Local-first Hinglish dictation (whisper.cpp + open Indic models)" | front page or not, either fine |
| WhatsApp/Telegram dev groups | founders' communities (SaaSBoomi, Headstart adjacents) | group forwards |
| SEO comparison pages | §12 war — publish honest, data-backed pages | "hinglish dictation" #1 in 60 days |
| Instagram Reels (@samcatchesup synergy) | dictation-fail vs Desi-Dictation-win skits | saves, profile clicks |

Explicitly NOT: paid ads (niche too tight, LTV math wrong pre-PMF), cold
outreach, App Store (sandbox kills the product).

## 4. Feedback & measurement — privacy-consistent by design

Constraint (non-negotiable, it IS the brand): no audio ever leaves; no
background telemetry; nothing sent without an explicit user action. Within
that, four layers:

### 4.1 Explicit feedback (user-initiated, ships in-app)
- **"Send Feedback…" in the menu bar + main window**: opens a pre-filled email
  (app version, macOS version, selected model/mode — all visible to the user
  in the draft they're sending; no hidden payload).
- **"Report last transcription"**: puts the last transcript + what-you-expected
  template into the same email draft. Audio attach = manual, user's choice,
  never automatic.
- WhatsApp community as the low-friction channel; email as the durable one.

### 4.2 Implicit signal WITHOUT telemetry: local stats + voluntary share
The app already stores history locally; extend to a **local-only stats view**
("Your dictation stats": dictations/day, minutes dictated, words inserted,
mode/model mix, error-message counts, esc-cancel rate). Then one button:
**"Copy my stats"** → anonymized plaintext summary on the clipboard the user
can paste into the community/form *if they choose*. We get cohort insight;
they get a nice stats screen and total control. (Precedent: how privacy-first
tools like Obsidian gather insight — ask, don't siphon.)

### 4.3 Ambient signals that require zero app changes (and zero privacy cost)
- **Model downloads by file on HF** → which models/modes people actually pull
  (Apex vs Swift vs Vaani = language-mode demand mix!).
- **Gumroad**: free-tier downloads, later sales/refunds/geo mix.
- **GitHub**: release download counts per version = adoption + upgrade rate;
  stars/issues = engagement.
- **Sparkle appcast hits** (once auto-update ships): rough weekly-active proxy
  from standard webserver logs, IP-truncated, no client code needed. Disclose
  it in the privacy note anyway.
- Landing page: Plausible/GoatCounter (cookieless) for query/conversion data.

### 4.4 Turning it into decisions (the loop)
Weekly, 30 minutes: community messages + feedback emails → tag into
{bug, model-quality, feature-ask, onboarding} → counts appended to
`docs/PRODUCT.md` backlog scores → BUILD_LOG records what shipped in response.
Model-quality reports additionally become **eval clips**: ask the reporter
"can you re-record that sentence and share it?" → grows `evals/data/personal/`
with exactly the failures that matter. The eval suite is our analytics where
the audio can't be.

### What we will NEVER do (write it on the tin)
No keystroke logging, no audio retention, no background network calls, no
third-party SDKs in the app binary, no dark-pattern consent. If a future
feature needs a server (sync), it ships opt-in, documented, and priced
separately (MARKET_STUDY §11).

## 5. Retention (the metric that decides Phase C)

Dictation lives or dies on habit (Wispr's 70%/12-mo is the bar). Levers, in
our control: time-to-first-dictation < 5 min (SETUP_GUIDE path, measured in
Phase A walkthroughs); the "aha" = first perfect Hinglish paragraph — the
onboarding should engineer it (suggest dictating a WhatsApp reply as step 1);
weekly "what improved" changelogs to the community (visible momentum);
dictionary/replacements as sunk-cost personalization (users who customize
stay).

## 6. Anti-goals

No meeting-bot pivot pre-PMF; no API business (MARKET_STUDY §3/L2); no
Windows port before Mac retention proves the category (§8 sequencing); no
influencer spend; no "AI" maximalism in copy — the word is "dictation that
speaks desi," not "AI-powered voice intelligence."
