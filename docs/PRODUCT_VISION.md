# Product Vision & Strategy — Desi Dictation

## Vision

**Every Indian should be able to talk to their computer the way they talk to
their friends.** Not textbook Hindi, not forced English — Hinglish, the real
language of Indian WhatsApp, Slack, and code reviews: *"bhai is bug ko fix karna
hai warna release slip ho jayegi."*

Dictation tools today force a false choice: English mode (mangles Hindi words)
or Hindi mode (everything becomes Devanagari nobody types). Desi Dictation's one
job: **speech in the language Indians actually speak → text in the script
Indians actually type.**

## Why now

1. **The models finally exist.** Oriserve's Hindi2Hinglish Whisper fine-tunes
   (2025) output Roman Hinglish natively, Apache 2.0, small enough for a
   MacBook Air. Two years ago this product was impossible without training runs.
2. **Dictation is having its moment.** MacWhisper, Superwhisper, Wispr Flow
   proved people pay for hold-a-key dictation. None handle code-mixed languages.
3. **AI made voice-first work normal.** Developers dictate prompts to Claude/
   ChatGPT all day (this product was conceived doing exactly that) — dictation
   volume per user is exploding.

## Positioning

> **"MacWhisper for India"** — same trusted local-first, one-time-price model;
> a language capability the incumbents don't have.

| | MacWhisper | Superwhisper/Wispr | **Desi Dictation** |
|---|---|---|---|
| Hinglish (Roman) output | ✗ | ✗ | ✅ core feature |
| Local/private | ✅ | partial | ✅ |
| One-time price | €59 | subscription | **₹999–1,499** |
| India-first pricing/GTM | ✗ | ✗ | ✅ |

**Moat honesty:** the model is open — anyone can copy this. The real moats are
(a) speed + focus on a niche the incumbents treat as an edge case, (b) the
Hinglish-specific polish layer (spelling normalization, user dictionaries,
eval sets) that compounds with users, (c) community/brand with Indian devs.

## Target users, in order

1. **Indian developers & tech workers on Macs** (beachhead — it's us; reachable
   via Twitter/X, r/developersIndia, LinkedIn)
2. Indian creators/journalists writing Hinglish content
3. Professionals messaging in Hinglish all day (founders, PMs, sales)
4. Later: other Indic code-mixed pairs — Tanglish, Manglish, Benglish (each is
   a fine-tune away; same app)

## Product principles

1. **The transcript is sacred** — never lose or over-rewrite what the user said.
2. **Invisible until summoned** — a menu bar accessory, one hotkey, no windows.
3. **Local by default, forever** — privacy is a headline feature, not a setting.
4. **Free tier must be genuinely useful** (unlimited dictation, real Hinglish
   model) — the MacWhisper playbook that earned community trust.
5. **Charge once, honestly** — subscription fatigue is real; PPP pricing for India.

## Business model

- **Free**: unlimited dictation, Hinglish Swift (72 M) + Whisper Base models.
- **Pro (one-time, ₹999–1,499 / ~$15–19)**: Apex/Prime + large stock models,
  AI cleanup, (later) app-specific profiles, priority models.
- Gumroad for payments/licensing (PPP support, license API, zero backend).
- Cost structure: ~$99/yr Apple Developer + ~10% Gumroad fees. No servers.

## Success metrics

- **North star: weekly dictations per active user** (habit = retention = WOM).
- Launch (90 days): 1,000 free installs, 100 Pro sales, 40% D30 retention.
- Quality: Hinglish preference win-rate vs MacWhisper large-v3-turbo > 80% on
  the personal eval set; expand eval set with opt-in user submissions.

## Roadmap after v1 (demand-driven)

WhisperKit/ANE backend (battery) → mixed-script mode (zero-stt-hinglish/Srota)
→ user dictionary sync → Tanglish/Manglish models → file transcription →
meeting notes. Each expands TAM without diluting the wedge: **dictation that
speaks desi.**
