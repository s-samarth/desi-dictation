# User Personas

The shared core across all personas: **an average Indian user who understands English well but isn't fluent producing it, and naturally mixes Hindi (or their mother tongue) into everything.** English comprehension in India runs far ahead of English production — people read, watch, and evaluate English comfortably, but writing it is slow, effortful, and socially risky (a wrong sentence to the wrong person costs face). That asymmetry is our product: they can *verify* good English instantly; we make *producing* it as easy as talking.

One structural note: Mac ownership skews these personas urban and upper-income today. Tier-2/3 personas matter less for the current TAM and more for (a) where the product's *empathy* must sit, and (b) an eventual Windows/iOS future. Don't design them out.

---

## P1 · Rohan, 29 — Tier-1 (Bengaluru), software engineer

**Life**: B.Tech from a tier-2 college, five years at a product company, M2 MacBook Air (company-adjacent purchase). Codes in English, thinks in Hinglish, texts in Hinglish, Insta-comments in Hinglish. Uses ChatGPT/Claude daily.

**English**: reads/writes work English fine but it's *formal-mode* — turning it on takes energy. Slack messages to his US counterparts take 3× longer than the same message to his Indian teammates. Speaking English aloud in meetings still spikes his heart rate slightly, seven years into his career.

**Voice-tool history**: tried macOS dictation (mangles every Hindi word into surreal English), tried Wispr Flow trial (good English, useless Hinglish, and he read their privacy policy — audio goes to servers; his employer's IP paranoia killed it).

**Pain points**:
- Long ChatGPT prompts: he *knows* detailed context gets better answers, but typing 200 words of context is friction, so he sends lazy prompts and gets lazy answers. → *Transcribe→Translate is built for him.*
- Standup notes, PR descriptions, incident writeups — all "formal-mode English" chores.
- WhatsApp side: types Hinglish all day; dictation that gets "scene kya hai" right is instantly delightful.

**What wins him**: speed + privacy story + it working in his IDE. He's also our **evangelist persona** — if it's good, he demos it to his team unprompted.

**What loses him**: latency worse than typing; any suspicion of cloud calls (he *will* run Little Snitch).

---

## P2 · Rekha, 41 — Tier-1 (Gurgaon), boutique owner / D2C seller

**Life**: runs a saree business on Instagram + WhatsApp Business; her college-going son handed her his old MacBook Air for "business work". Hindi-dominant, English-capable. Types with two fingers on the laptop; on the phone she's fast, but the laptop is where invoices, supplier emails, and the Shopify dashboard live.

**English**: understands customer messages, YouTube tutorials, and news in English completely. Writing a supplier complaint or a courier-escalation email takes her twenty minutes and she still asks her son to check it. Her spoken thoughts come out 70% Hindi, 30% English nouns ("courier waale ne fir se galat pin code pe bhej diya, refund ka process batao").

**Pain points**:
- **The escalation email** — courier companies, payment gateways, Instagram support: all demand written English. This is real money stuck behind English production. → *Speak-Hinglish-get-English is not a convenience for her; it's access.*
- Customer replies: she voice-notes customers today because typing is slow — but voice notes look unprofessional to newer/premium customers.
- Product descriptions: 40 sarees a week need English captions.

**What wins her**: it must work the first time and every time; one flaky experience and the tool is "kharab" forever. The son sets it up (our onboarding's real user is the son); she just holds a key. Trust language in Hindi helps ("aapki awaaz laptop se bahar nahi jaati").

**What loses her**: any error message in technical English; setup requiring the Terminal *without her son around*; features that need choosing between models (Auto mode exists for her).

---

## P3 · Aman, 22 — Tier-2 (Indore), final-year student / aspirant

**Life**: preparing for CAT and applying for MBA programs + off-campus jobs simultaneously. Bought a refurbished M1 Air after months of saving because "placement ke liye laptop chahiye". Consumes enormous amounts of English content (lectures, Reddit, YouTube) but grew up in Hindi-medium schooling until class 8.

**English**: his *reading* English is genuinely strong — he clears RC sections fine. His *written* English is where SOPs, cover letters, and cold emails to recruiters expose him: grammatically shaky, stiff, obviously effortful. He knows it and it eats at his confidence. He speaks fluid Hinglish and "broken but brave" English.

**Pain points**:
- **The SOP/cover-letter loop**: thinks rich thoughts in Hinglish → produces thin English paragraphs → asks ChatGPT to fix them → the fix loses his voice. If he could *speak* his story and get faithful English, the pipeline collapses to one step. → *Transcribe→Translate + Structure-Your-Thoughts, chained, is his dream tool.*
- Interview prep: rambles answers aloud while pacing; nothing captures and organizes them.
- Money: he will not pay during student life, but he is the highest-word-count user we'll have and the loudest on Twitter/X when something delights him.

**What wins him**: free beta, visible respect for "broken English is normal, not shameful" in our copy, and outputs that sound like *him*, upgraded — not like ChatGPT.

**What loses him**: 1 GB+ downloads on hostel Wi-Fi without a resume-on-failure download; RAM pressure on his 8 GB machine (he runs 40 Chrome tabs).

---

## P4 · Suresh, 52 — Tier-3 (Sitapur, UP), government school teacher

**Life**: teaches social science; increasingly required to submit reports, training feedback, and scheme documentation online — often in English. His daughter (engineering student in Lucknow) left her Intel MacBook at home; **today he literally cannot run our app** (Intel — unsupported, final). He's here as the *empathy horizon*, and as the person tier-2 personas become in twenty years.

**English**: reads government circulars in English (slowly, fully). Produces English only via fixed templates he's memorized. Everything real he thinks and says is in Hindi/Awadhi-inflected Hindi.

**Pain points**:
- Mandatory English/online paperwork with zero institutional support — the gap between "digital India requires it" and "nobody taught me to produce it".
- Deep, earned distrust of apps: OTP scams in his circle; "data kahan jaata hai?" is his first question, and he's *right* to ask. Our on-device answer is the only one he'd ever accept — that's worth internalizing even before we can serve him.
- Devanagari matters to him: for school notices he wants शुद्ध हिन्दी output, not Hinglish — our Vaani mode is the persona fit, translation-to-English the aspiration.

**Design lesson he encodes**: every trust claim must be verifiable and stated in plain words; every feature must degrade gracefully to "your words are safe on the clipboard".

---

## P5 · Priya, 34 — Tier-1 (Mumbai), content-adjacent freelancer

**Life**: social media manager for three D2C brands; M1 Pro from her agency days. Fluent-ish English writer, *fast* Hinglish thinker. Deadline-driven, tool-promiscuous (has tried every AI app, kept four).

**English**: production is fine but slow relative to her thinking; her real constraint is **volume** — captions, scripts, client emails, briefs, all day.

**Pain points**:
- Draft-zero problem: staring at a blank doc for a client brief when she could *talk* the brief in 90 seconds. → *Structure-Your-Thoughts is her feature; translation less so.*
- Voice memos graveyard: 200 recordings she'll never replay.
- Client confidentiality: she's contractually barred from putting client info into cloud tools — on-device is a *compliance* feature for her, not just a preference.

**What wins her**: output styles (notes/email/outline), speed, and reliability at volume. She's the persona most likely to **pay** — she monetizes saved time directly, and she's used to ₹500–1500/mo tool subscriptions.

**What loses her**: anything that adds review overhead — if structured output needs heavy editing twice, she's gone (she has alternatives, English-only but polished).

---

## Cross-persona pain-point matrix

| Pain | Rohan (T1 dev) | Rekha (T1 biz) | Aman (T2 student) | Suresh (T3 teacher) | Priya (T1 creator) |
|---|---|---|---|---|---|
| Producing formal English | ● | ●●● | ●●● | ●●● | ● |
| Speed of getting thoughts out | ●●● | ●● | ●● | ● | ●●● |
| Hinglish typed output (chat) | ●●● | ●● | ●●● | ○ | ●● |
| Privacy / distrust of cloud | ●●● | ● | ● | ●●● | ●●● (contractual) |
| Structuring rambled thoughts | ●● | ● | ●●● | ○ | ●●● |
| Setup ability (solo) | ●●● | ○ (proxy: son) | ●●● | ○ | ●●● |
| Willingness to pay | ●● | ●● | ○ | ○ | ●●● |

**Reading of the matrix**: Transcribe→Translate serves the widest, deepest pain (English production). Structure-Your-Thoughts serves the payers (Priya, Rohan). Core Hinglish dictation is the wedge that gets everyone in the door. Setup friction must assume a *proxy installer* exists (Rekha's son) — the beta guide should be written so the helper can hand the laptop back and never be needed again.
