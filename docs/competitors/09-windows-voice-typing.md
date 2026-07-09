# Windows 11 Voice Typing

> **Layer:** Platform-native default (free) · **Verdict:** the free default on our first desktop expansion target (Windows) — weak on Hindi today, which is exactly the opening we'd exploit when we port.

## Snapshot

| | |
|---|---|
| **Vendor** | Microsoft, built into Windows 11 (Win + H) |
| **Category** | OS-level voice typing into any text field |
| **Platforms** | Windows 10/11 |
| **Engine** | Microsoft speech models (cloud + on-device depending on setting/language) |
| **Pricing** | **Free** (bundled with the OS) |
| **Confidence** | Medium — Microsoft support docs + 2026 guides + user complaint threads |

## What it is

The Windows equivalent of Apple Dictation: press Win + H, speak, it types. Supports 46 languages/dialects including Hindi, Marathi, Tamil, Telugu, Bengali, Gujarati, Kannada, Malayalam, Punjabi. It's the free baseline any dictation app on Windows is measured against — and Windows is the dominant desktop OS in India, making this the default we'd face the day we port.

## The India / Hindi reality

- Hindi *is* listed as supported — but **quality varies dramatically by language**, and Indian languages fall in the "less-resourced, weaker model" tier (English-US, French, German, Spanish, Mandarin, Japanese get the best models).
- Documented user frustration: people trying to dictate Hindi in Word via Win+H report it effectively only working well for English despite Hindi being "supported."
- **No Hinglish / Roman code-mix** concept at all — same fundamental gap as Apple.

So on Windows, the free default is *weaker* on Indian languages than Apple's, which makes the Hinglish wedge even sharper there.

## Features

System-wide voice typing (Win + H); dictation toolbar; auto-punctuation (toggleable); 46 languages; some on-device support. Basic — no AI cleanup, no per-app modes, no personalization, no Hinglish.

## Strengths

Free, preinstalled on the majority of India's computers, zero-install, familiar. For English on Windows, "good enough" for many.

## Weaknesses

- Weak on Hindi/Indian languages (under-resourced tier); no Hinglish/code-mix.
- No AI polish, modes, personalization, or history.
- Inconsistent on-device vs. cloud behavior by language.
- No Roman-script Indian output.

## Threat to us & how we differentiate

**Threat: low now, relevant at Windows-port time.** Windows Voice Typing isn't a competitor *today* (we're Mac-only), but it defines the free floor on the platform we most need to reach for India's desktop users. Its weakness on Hindi is a gift: the same "speak Hinglish → get garbage from the default → get real text from us" demo works even better on Windows than on Mac.

**Porting implication (feeds A3):** whisper.cpp runs on Windows (Vulkan/CPU), our models and the Hinglish convention are 100% portable, and the desktop UX shell is the main new work. When we port, the competitive framing is identical to Apple's — own the code-mixed Indian-speech niche the OS default fails at — with the bonus that Microsoft's Hindi is *worse* than Apple's, widening our visible advantage.

Sources: [Use voice typing on your PC (Microsoft)](https://support.microsoft.com/en-us/windows/use-voice-typing-to-talk-instead-of-type-on-your-pc-fec94565-c4bd-329d-e59a-af033fa5689f), [Enabling Hindi voice typing frustration (Microsoft Q&A)](https://learn.microsoft.com/en-us/answers/questions/5432432/), [Windows 11 voice dictation guide 2026](https://weesperneonflow.ai/en/blog/2026-02-08-voice-dictation-windows-11-complete-setup-guide-2026/).
