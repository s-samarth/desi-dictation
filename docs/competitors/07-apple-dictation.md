# Apple Dictation (built-in macOS/iOS)

> **Layer:** Platform-native default (free, OS-level) · **Verdict:** the "good enough and free" gravity we must *visibly* beat — and the exact product whose Hinglish failure created the opening for us.

## Snapshot

| | |
|---|---|
| **Vendor** | Apple, built into macOS + iOS |
| **Category** | OS-level dictation into any text field |
| **Platforms** | macOS, iOS, iPadOS (system-wide) |
| **Engine** | Apple's on-device speech framework (Neural Engine); newer OSes run many languages fully on-device |
| **Pricing** | **Free** (bundled with the OS) |
| **Privacy** | On-device for supported languages; strong Apple privacy brand |
| **Confidence** | Medium — general platform knowledge + 2026 review roundups; not re-verified hands-on this week |

## What it is

The dictation everyone already has. Double-tap Fn (or the mic key), speak, and it types — free, integrated, on-device, no install. For English it is genuinely decent (reviews cite ~90–97% in ideal conditions, dropping to ~75–85% with heavy accents or noise). It is the baseline every paid dictation app — including us — is implicitly measured against, and the reason "why would I pay when my Mac already does this?" is the first objection in the category.

## The India / Hinglish reality (our whole thesis)

- Apple Dictation supports Hindi — but as **Devanagari only**, with **no code-mixing**. Speak Hinglish and you get either English soup (English mode mangling Hindi words) or Devanagari nobody texts in (Hindi mode). This gap *is* Desi Dictation's founding premise.
- Indian-accented English also degrades it (the accent penalty above).
- So for our exact user — a Hinglish speaker wanting Roman-script output — the free default *fails*, and fails visibly, which is the only reason a paid app can exist here.

## Features

System-wide dictation; auto-punctuation; continuous dictation; on-device for major languages; multilingual support (one language at a time, user-selected); tight OS integration (works everywhere by default).

## Strengths

Free, zero-install, always present, on-device, trusted brand, no setup, good English. The definition of "good enough" for the median English task — which is a real competitive moat for the *English* use case.

## Weaknesses

- **Hinglish/code-mixing: broken** (Devanagari-only Hindi, no Roman code-mix).
- Accent penalty on Indian English.
- No AI polish/cleanup, no per-app tone, no custom vocabulary learning, no personalization to *your* spellings.
- Basic UX (no history, no modes, no LLM layer).
- Locked to Apple platforms (irrelevant to our Android future).

## Threat to us & how we differentiate

**Threat: high for English, ~zero for Hinglish — today.** For a user who only dictates English, Apple's free default is a genuine reason not to pay anyone. Our answer is *not* to out-English Apple; it's to own the thing Apple can't do — Roman-script Hinglish — and use that as the wedge, then offer a better *overall* experience (personalization, faithfulness, history, modes) as the reason to stay.

**The differentiation demo writes itself:** speak one Hinglish sentence into Apple Dictation and into Desi Dictation, side by side. Apple produces garbage; we produce what they'd have typed. That single screenshot is our most honest marketing (mirrors Willow's "3× more accurate than Apple" frame, but on the axis where Apple is *actually* broken for our user).

**The long-term risk:** Apple could improve Hinglish/code-mixing in a future OS (they have the data and the on-device silicon). It would erase the wedge for casual users. Mitigation is the same as everywhere: build the *rest* of the stack (personal lexicon, OOD/slang, the LLM feature layer, Android reach) so we're not a one-feature app when the default catches up. Watch WWDC speech-framework release notes yearly.

Sources: [macOS speech-to-text guide 2026 (AI Dictation)](https://aidictation.com/blog/macos-speech-to-text), review roundups on Apple Dictation accuracy; general Apple platform documentation.
