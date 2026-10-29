# Launch video

A ~75 s product launch video for Desi Dictation, built with
[Remotion](https://www.remotion.dev): React components rendered frame by frame
into an MP4. It sits apart from `app/` and `web/` and shares nothing with them
except pictures of the app.

**License:** Remotion is free for individuals and companies of up to 3 people,
including commercial use
([terms](https://github.com/remotion-dev/remotion/blob/main/LICENSE.md)). A
bigger company needs a company license.

## Run it

```bash
cd launch-video
npm i
npm run dev                                                  # Studio: live preview at localhost:3000
npx remotion render Launch out/desi-dictation-launch.mp4     # the MP4
```

Remotion's official agent skills
([remotion-dev/skills](https://github.com/remotion-dev/skills)) go in
`.claude/skills/`. They aren't committed, because the repo has no license file. Install them
with `npx skills add remotion-dev/skills`, then start Claude Code inside
`launch-video/`.

## What's in it

The video covers features that ship today. The hidden AI layer (tone,
translation, Structure my thoughts) is left out.

**Pitch:** dictation you can trust. English comes first, Hinglish is the
differentiator.

| # | Scene | File | Shows |
|---|---|---|---|
| 1 | Hook | `scenes/Opening.tsx` | Stock clip: a woman talking to her laptop. "Most dictation apps guess. And you find out after you hit send." |
| 2 | Title | `scenes/Opening.tsx` | Icon, name, "Dictation you can trust" |
| 3 | Dictate (English) | `scenes/Dictate.tsx` | Hold Right ⌥ → overlay listens → an email lands in Mail |
| 4 | Smart review | `scenes/SmartReview.tsx` | Sure → pasted, no pop-up; unsure → only 2 words to check |
| 5 | Review panel | `scenes/Review.tsx` | The real panel: underline → 1 Claude → Paste |
| 6 | Never rewrites you | `scenes/Cleanup.tsx` | um/uh fold away; "two, no, make it three" waits for your 1 |
| 7 | Your words | `scenes/Words.tsx` | Kavya always; Claude only when it fits |
| 8 | Hinglish | `scenes/Dictate.tsx` | Hinglish in a chat, with the per-app rule badge |
| 9 | Languages | `scenes/Dictate.tsx` | Hinglish / English / हिन्दी |
| 10 | On-device | `scenes/Trust.tsx` | The real Models screen + no cloud / offline |
| 11 | Promises | `scenes/Trust.tsx` | Asks / Never / Stays / Keeps |
| 12 | Outro | `scenes/Opening.tsx` | Name, GitHub link, Apple Silicon |

- **Scene order and lengths:** `SCENES` in `src/LaunchVideo.tsx`.
- **Colours and fonts:** `src/theme.ts`.
- **App screenshots:** `public/screens/` are made by the debug app itself:

  ```bash
  DESI_UI_SCALE=2 DESI_UI_SNAPSHOTS=$PWD/launch-video/public/screens app/.build/debug/desi-dictation
  ```

  Never add `main-history.png`: it shows your own dictations.

## Your voice on the dictated lines

Three dictation scenes play your real voice. Record
every line in `voice-lines.tsv` (id, language, text) with:

```bash
./scripts/record-voice.sh          # every line in order; play back, keep or redo
./scripts/record-voice.sh chat     # redo one line
```

Takes go to `public/voice/<id>.wav`, which Git ignores. The prepared takes the
video plays (`public/voice/mix/`) are committed, so anyone can render it.

**Recording setup:**
- **Mic:** it records the Mac's input device (System Settings → Sound → Input).
- **Recorder:** it uses macOS's own recorder (`scripts/rec.swift`, built on
  first use). ffmpeg's mic capture spliced its 512-sample buffers on this Mac,
  and the voice crackled and broke.
- **Level check:** after each take it prints the loudest moment. Aim for -6 to
  -3 dB, and turn up the mic's own gain knob if it says "too quiet".

**Which takes play:** only three, in the scenes where the app is seen
listening:

- `mail` in Dictate (English);
- `fillers` in Never rewrites you;
- `chat` in Hinglish.

The words on screen stay the script's; your voice is the sound of saying them.
Playing all eleven felt like too much.

**To change a take:**

1. Re-record it with `./scripts/record-voice.sh <id>`.
2. Prepare it with `./scripts/prepare-voice.sh mail fillers chat`, which cuts
   each take to its speech and levels it to -17 LUFS in `public/voice/mix/`.
3. Copy the printed speech length into `src/voiceover.ts`. The key-down
   timing and the scene's animation follow from it.

**Music under the voice:** the music dips from 0.8 to 0.2 while you speak (`Soundtrack.tsx`).
Dictate (English) and Never rewrites you got a fifth bar each: the email has
time to be read once it lands, and you finish the sentence before the ums fold
away.

## Real recordings (to replace scenes 3 and 4)

Scenes 3 and 4 redraw the app's overlay. Real screen recordings would be more
convincing. Record with **⌘⇧5 → Record Selected Portion**, 1080p or bigger,
mic sound off (the video has its own). Put the files in `public/clips/` with
these names:

| File | App | Language | Say |
|---|---|---|---|
| `dictate-chat.mov` | Messages, or any chat | Hinglish | "Haan, kal 5 baje milte hain. Main Rahul ko bhi bol deta hoon." |
| `dictate-mail.mov` | Mail, with a Mail → English rule | English | "Hi Priya, can we move the review to Thursday at 3 pm? I'll send the deck tonight." |
| `review.mov` | Notes, review set to Always | English | "Ask cloud to send the deck to Kavya before the review." Then press 1, then Enter. |
| `fillers.mov` | Notes | English | "Um, so we should, uh, meet at two. No, make it three tomorrow." |

Keep each one 5–10 s: start just before the key goes down, stop a second
after the text lands. Use made-up names and messages only. Hide notifications
(Focus → Do Not Disturb) and anything personal in the menu bar.

## Stock media

| File | Source | License |
|---|---|---|
| `public/clips/hook-woman-laptop.mp4` | [Pexels 7251216](https://www.pexels.com/video/woman-in-a-video-call-indoors-7251216/), re-encoded to 30 fps with no sound | Pexels license: free, commercial use OK, no credit needed |

| `public/music/retro-funky-groove.mp3` | [Retro Funky Groove (Lightweight Funk), BombinSound, Pixabay 622862](https://pixabay.com/music/funk-retro-funky-groove-lightwight-funk-622862/) | [Pixabay license](https://pixabay.com/service/license-summary/): free, commercial use OK, no credit needed |

## Cut on the beat

The track runs at **122.09 BPM**: a beat every 0.491 s and a bar every
1.966 s. Its first beat is 0.464 s in. These are measured with an
onset-envelope autocorrelation (a small numpy script, not part of the
project).

- **Music start:** `Soundtrack` skips to that first beat, so frame 0 is beat 1.
- **Scene lengths:** each scene is a whole number of **bars** (`SCENES` in
  `LaunchVideo.tsx`), so every transition starts on a bar line. Starts are
  rounded once from the bar count, so there's no drift.
- **Transitions:** 15 frames, about one beat.
- **Tempo:** `BPM` and `MUSIC_START` in `theme.ts`. Change them if you swap
  the track.

The video is 38 bars (74.7 s), and the music fades out over the last 2 s.
