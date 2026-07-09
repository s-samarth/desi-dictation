# Additional Problems — top 10, beyond P1–P4

Method: the product was walked end-to-end (discover → download → install → onboard → daily dictation → correction → update → pay) and piecewise (audio capture, engine, text insertion, model pipeline, distribution, app lifecycle, business/legal). Anything that is a variant of P1 (Hinglish accuracy), P2 (OOD words), P3 (freshness/data), or P4 (personalization) was excluded. Ordered by severity.

---

## A1 · The unsigned-app wall: our funnel's first step is "bypass macOS security" — **Critical**

**Problem.** Every new user's first interaction with the product is macOS refusing to open it, followed by us asking them to run a Terminal command. Inside a hand-held friends beta this works (with humor, even). At any scale beyond people-who-trust-Samarth-personally, it's a funnel massacre: for every Rohan who runs `xattr`, there are ten Rekhas who see *"can't be opened"*, feel the fear Apple engineered that dialog to produce, and delete the DMG. We've already had exactly one external installer and exactly one "can't be opened" incident — a 100% hit rate on the wall.

**Why it's worse than it looks.** (a) It filters the audience *against* our personas — precisely the less-technical users we claim to serve are the ones the wall stops. (b) It contaminates trust at the worst moment: our whole pitch is "trust us with your microphone", delivered seconds after the OS said "don't trust this". (c) We're training users to bypass Gatekeeper — normalizing the exact behavior that gets people malware; morally awkward for a privacy-first brand and a gift to any critic. (d) Word-of-mouth breaks: a delighted user forwards the DMG, the recipient hits the wall with no guide and no Samarth, and the recommendation dies — our only growth channel has a hole in it.

**Mitigations.** The $99 Developer ID + notarization simply has to happen before any public-facing distribution (it's already in LAUNCH.md as pre-Gumroad — the real decision is *pulling it forward*: the wall is a beta-growth problem too, not just a launch problem). Until then: guide + humor (done), and keeping distribution strictly to hand-held channels. Note the coupled trap: switching signing identity will invalidate every beta user's TCC grants (see A6) — plan the cert transition as an event, not a patch.

---

## A2 · No way to update the app on users' machines — every install is a dead end — **Critical**

**Problem.** We can ship model *downloads* in-app, but the app binary itself has no update channel: no Sparkle, no update check, not even an in-app "a newer version exists" notice. Every bug we fix reaches exactly zero existing users unless they (a) hear about it, (b) re-download the DMG, (c) re-run the Gatekeeper dance (A1 again — each update repays the unsigned-app toll!). We built our iteration speed as a core advantage — "complaints ship features within days" — and then shipped those features to nobody.

**Why it's severe.** The beta's entire purpose is a feedback loop; the loop's return path is broken. Worse: known-buggy old versions stay alive indefinitely, generating bad word-of-mouth for problems we solved weeks earlier. For a product whose reputation must be built person by person, *stale bad versions are reputation debt compounding silently*. This also caps P3's model-update strategy: no delivery pipe (P3 root cause c) starts here.

**Mitigations.** Near-term (days): app checks GitHub's releases API for the latest `beta-*` tag once a day (a public HTTPS *read* — disclose it, toggleable, same rule as P3-S2) and shows a menu-bar badge + "Download update" link. Real fix (with A1's certificate): Sparkle 2 — signed delta updates, one-click, the industry standard for exactly our situation. Sequencing insight: the update checker should ship in the *next* release, because every release without it grows the unreachable installed base.

---

## A3 · The TAM problem: macOS-on-Apple-Silicon India is a niche of a niche — **High (strategic)**

**Problem.** The product is India-focused but Mac-only — and India is one of the most Windows/Android-dominant markets on earth (Mac laptop share in India is low single digits; Apple-Silicon-only, macOS-14+ narrows further). The personas most defined by our mission (Rekha, Aman, Suresh) mostly *don't own Macs* — we noted this honestly in PERSONAS.md ("Mac ownership skews these personas urban and upper-income") but haven't confronted the strategic consequence: **the moral core of the product and its addressable market barely overlap today.** Meanwhile the whisper.cpp/Metal stack we've invested in is macOS-shaped.

**Why it matters now (not later).** It caps outcomes: even total category victory on Indian Macs is a small business — fine for a solo dev's first product, fatal if unexamined ambitions assume otherwise. It also shapes near decisions: how much to invest in Mac-specific polish vs. keeping the core (engine, models, evals, convention — which are all portable) cleanly separated from the AppKit shell for an eventual Windows port. whisper.cpp itself runs on Windows (Vulkan/CPU); the models and the P1 convention are 100% reusable — the moat we're building is mostly *not* Mac-specific, which is the good news worth acting on deliberately.

**Mitigations.** Keep the Kit/App split disciplined (it already is — protect it). Treat Mac as the *proving ground*: small, high-trust, high-willingness-to-pay early market to validate Hinglish quality and the convention. Write the Windows decision down as an explicit milestone gate (e.g., after N paying Mac users or a fine-tune that clearly wins), not a someday-dream. iOS keyboard is the other giant door (where Indians actually text) — different constraints, same models; deserves a page in PRODUCT_VISION.md.

---

## A4 · Moat fragility: one Apple keynote or one Sarvam release from commoditization — **High (strategic)**

**Problem.** Our differentiation is (Hinglish quality) × (on-device privacy) × (Mac UX). Every term is attackable by someone bigger: **Apple** ships on-device dictation and has shipped Hinglish-adjacent keyboard features — one WWDC "Hinglish dictation in macOS" slide erases the standalone need for most users. **Wispr Flow / MacWhisper** could bolt on an Indian-language model (MacWhisper already runs any whisper.cpp model — a user can load *our own published Apex* into MacWhisper today; we published the moat's crown jewel under Apache 2.0). **Sarvam/AI4Bharat** could release a strong open Hinglish ASR at any time, leveling the model layer we differentiate on.

**Why it's real, not paranoia.** Our model research already showed the whole edifice rests on essentially one third-party fine-tune (Oriserve's) that we neither trained nor control — if a better open model drops, *everyone* gets it the same day we do. What compounds in our favor and is genuinely hard to copy: the P1 convention (an asset the moment it has adopters), the P3 donated-data corpus (consent-based, unreplicable by big-co compliance), P4 personal lexicons (per-user switching costs), and the evals that let us *prove* superiority per release. Notice all four moats are things from our problem docs — the moat is the roadmap, executed fast.

**Mitigations.** Speed as strategy (solo dev's only structural advantage over Apple's release cycle). Consider license/positioning for future *self-trained* models (a fine-tune trained on donated data need not be Apache-2.0'd on day one — decide per release, it's our first real IP decision). Watch-list discipline: Sarvam, AI4Bharat, Apple Speech framework release notes — 30 min/month, so a commoditization event is a pivot trigger we see coming, not a surprise.

---

## A5 · Text insertion is a house of cards: clipboard clobbering and paste fragility — **High**

**Problem.** Insertion works by putting the transcript on the clipboard and synthesizing Cmd+V — with the deliberate rule that the transcript *stays* on the clipboard. Two costs: **(a) we destroy the user's clipboard on every single dictation.** Whatever they had copied — a link, a password from a manager, an image, a paragraph they were moving — is gone, silently, every time they speak. Power users copy dozens of times a day; this is a recurring, invisible data-loss we inflict by design (the stash rule was right for *failure* recovery; applying it on *every success* overcorrects). **(b) Synthetic-paste insertion fails structurally in real places**: secure input fields (paste blocked), apps with paste interception/format quirks (some Electron apps, terminals with bracketed paste), focus lost mid-dictation → text lands in the wrong app or nowhere — the user's words go somewhere unintended, which at best confuses and at worst *pastes a private rant into the wrong chat window*.

**Why it's severe.** Both failure modes attack trust in the muscle-memory loop — the thing that makes dictation habitual. Wrong-window paste is a privacy incident *we* cause. And clipboard clobbering is the kind of thing that gets a scathing tweet from exactly the power users (Rohan, Priya) we need as evangelists.

**Mitigations.** Restore-clipboard-after-paste as the default for *successful* insertions (keep the stash only on failure — the original intent), with the old behavior as an option. Focus-guard: remember the frontmost app at dictation *start*; if frontmost changed at insertion time, don't paste — notify + keep on clipboard. Longer-term: Accessibility-API direct insertion (AXUIElement setValue) as a first path with paste as fallback — harder, but bypasses the clipboard entirely for compliant apps.

---

## A6 · The permission/restart minefield will resurface for every real user — **High**

**Problem.** Our own build log is a museum of TCC pain (FM#6, FM#8): grants that need app restarts, stale grants after signing changes, toggles that show ON while the system says no, "app won't open" from stale processes. We fixed these *for our machine* via the dev cert + tccutil + guides — but the causes ship to users: onboarding asks for three permissions and then requires a quit-and-relaunch ritual (the #1 spot where a Rekha-class user ends up in a half-working state: mic granted, accessibility not, restart skipped, "app is broken"). And the A1 certificate transition will reset *every* beta user's grants at once — a support wave with our name on it, schedulable but currently unscheduled.

**Why it's severe.** Permission limbo is our most likely "it doesn't work" category for non-technical users, it's invisible remotely (see A8), and each incident consumes the scarcest resource (A9: founder time). The app can't fix macOS's model — but today it doesn't even fully *diagnose* it: the checklist shows red/green, yet a user can dictate with accessibility missing and get a confusing partial failure (transcribes, doesn't paste) instead of being pre-empted.

**Mitigations.** Hard-gate dictation on the permission checklist (if accessibility is missing, say *exactly* that at hotkey press, not a generic error). Make the post-grant restart automatic: detect grant changes (poll on window focus) → offer one-click "Restart now" (the relauncher exists — AppRelauncher). Write the cert-transition playbook *before* buying the Developer ID: release notes + in-app notice + guide section ("macOS will re-ask permissions once — here's why").

---

## A7 · Model downloads: a 500 MB–1 GB single-shot download with no resume — **High**

**Problem.** Onboarding's critical step is downloading 0.5–1 GB from Hugging Face, and the Downloader has no resume-on-failure — any network blip at 90% restarts from zero (verified: no `resumeData` handling in ModelManager). Our personas live on Indian internet: hostel Wi-Fi (Aman), Jio hotspots, metered connections, evening congestion. HF's CDN also throttles/hiccups from India at times. The single most fragile technical step of the funnel sits inside the single most fragile *motivational* step (first-run, pre-value, patience thinnest) — and Finish is gated on it.

**Why it's severe.** A failed 500 MB download that restarts from scratch reads as "the app is broken", at minute 5 of the relationship, *after* the user already fought through A1's wall. Data cost is real money for some users; wasting 400 MB of a metered plan is a tangible harm, not just UX friction.

**Mitigations.** `URLSession` resume support (downloadTask resumeData on failure + `Range` revalidation with the SHA check we already have) — a contained, testable change. Show MB-of-MB progress (we show a bar; add numbers — on slow links a moving number is the difference between "working" and "stuck"). Consider a smaller "starter" option later only if evidence demands it (we deliberately trimmed the catalog; resuming beats re-complicating). Mirror strategy if HF-from-India proves flaky in beta reports: GitHub Releases can host model binaries as a fallback URL list per catalog entry.

---

## A8 · When it breaks remotely, we're blind: no diagnostics, no logs, debugging by WhatsApp — **Medium-High**

**Problem.** No telemetry (correct, by promise) — but also no *local* diagnostics: no log file, no "copy diagnostic info" button, no version/permission/model-state snapshot a user can send. Every remote failure becomes twenty questions over WhatsApp with a non-technical human ("which macOS? click the apple… no, the *other* top-left"). Our one external user incident (friend's "can't be opened") already demonstrated the pattern: we triaged by *photograph*. That doesn't scale past ~10 users, and every unsolved mystery is a churned user plus an unlearned lesson.

**Why it matters.** It multiplies A6/A7 (both produce exactly the remote-mystery failures we can't see), it burns founder hours (A9), and it wastes the beta: each failure we can't diagnose is feedback we solicited and then dropped. Privacy-first makes *silent* telemetry off-limits — it doesn't forbid a **user-initiated, user-visible** diagnostic report; that's the same consent model as P3's donations.

**Mitigations.** Local ring-buffer log (os.Logger + a rotating file, no transcript content — events and states only). Menu-bar "Copy diagnostics" → version, macOS, chip, RAM, permission states, model inventory + hashes, last 50 log events — as text on the clipboard, user pastes it into the feedback email *they* send. In-app self-checks that turn mystery states into named errors (model file corrupt → say so; mic device changed → say so). Cheap (days), and it converts the support channel from interrogation to diagnosis.

---

## A9 · Solo-dev sustainability: zero tests, hand-run pipeline, bus-factor one — **Medium-High (compounding)**

**Problem.** There is not a single automated test in the repo; every release is hand-verified by dictating at the machine ("the same 20 sentences" is a *plan*, not a script). The build/release pipeline is local shell scripts on one laptop with a Homebrew-toolchain quirk (the CI workflow exists but is deliberately unused for betas since it lacks the signing cert). Support, triage, data labeling, model training, marketing: one person. The failure-mode history (16 FMs, including regressions like "downloads broke", "no output at all") shows the codebase *already* bites when changed — and the roadmap (translation, LLM engine, structuring) roughly doubles the surface.

**Why it matters.** Velocity is our declared moat (A4), and velocity without a safety net decays into regression whack-a-mole precisely as the product grows. Every hour spent re-verifying by hand or debugging a regression is an hour not spent on P1 — the compounding tax is invisible until it isn't. Bus-factor-one also has a mundane edge: an ill week during beta = product goes dark mid-launch.

**Mitigations.** Not "adopt enterprise QA" — targeted nets where regressions actually happened: (a) an XCTest target for the pure logic (normalizer, PostProcessor, HotkeyChoice masks, ModelManager resolution scoring — all deterministic, all previously broken at some point); (b) a scripted smoke run — `desi-cli --batch` over 10 fixed clips with expected-output diffs, run before every release (the eval infra already 90% is this); (c) the release checklist as a literal script that fails loudly. Days of work total, paid back by the second prevented regression.

---

## A10 · The free beta has no bridge to a business — and the bridge burns behind us — **Medium (rising at launch)**

**Problem.** Everything is free, gating is off, and nothing in the current motion validates that anyone will *pay*: no price signal, no "would you pay ₹X" conversations, no Pro boundary sketched. Meanwhile obligations accumulate that make the flip harder: beta users acquired at free will experience *any* future gate as taking something away (loss-aversion pricing 101); the models are public Apache-2.0 downloads anyone can use in MacWhisper (A4) — so what exactly is *paid*, the app shell? And the cost side is already real (Developer ID $99/yr, future GPU fine-tuning $50–300/run, a P3 endpoint) against revenue of zero. LicenseManager exists but Gumroad product, price, and the free/paid line are all TBD.

**Why it's a problem now, not at launch.** The free/paid boundary silently shapes *today's* architecture and messaging: if fine-tuned models become the paid tier, publishing every future model publicly (current default) forecloses it; if the app is paid, "everything free forever" vibes in the beta guide write checks launch must honor. Every week of undesigned monetization narrows the options later — this is a decision decaying, not a task waiting.

**Mitigations.** Decide the *shape* now, even if enforcement stays off: leading candidate given constraints — app free forever + core models free (grows the wedge, honors beta vibes), **Pro = the P4/feature layer** (personal lexicon sync/import, translation suite, structuring — the LLM features conveniently cost us real work and don't retroactively take away anything beta users have). Put one price question in the beta group at the right moment ("if the English-from-Hinglish mode were ₹499/year…") — five answers beat zero. Write the launch pricing note in GTM.md *before* the Developer ID purchase, so spending and earning plans meet each other.

---

## Cross-cutting observations

- **Two problems gate all others**: A1 (wall) and A2 (no update path) throttle the feedback loop that every other fix depends on. They're also the two with known, bounded, mostly-money-shaped solutions. Buy the certificate; ship the update check.
- **The trust theme repeats**: A1, A5, A6, A8 are all moments where the product risks the *brand's* core asset through mechanics, not intent. The privacy promise is only as strong as its least careful subsystem.
- **The strategic pair (A3, A4)** doesn't need code — it needs a written decision each (platform gate, moat/licensing stance) so day-to-day choices stop silently deciding them.
