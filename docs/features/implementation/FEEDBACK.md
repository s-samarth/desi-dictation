# Feedback and download counts (implementation)

**Status:** built 2026-10-30 (`feat/feedback-and-download-counts`, with
s-samarth/s-samarth `feat/desi-dictation-downloads-feedback`). Tests ran on
a Mac (M3); the window was checked as a rendered picture. **Checked live
2026-10-30:** a report sent to the endpoint as the app sends it arrived
through EmailJS (history: OK). Ships in v0.7.1.

**Problem.** Feedback meant writing an email, which few people do. And there
was no way to know how many people download the app.

**Rule.** The privacy promise holds: nothing leaves the Mac unless the user
presses a button, they see what goes, and there's no telemetry. Feedback is
a user action, like a model download. Download counts need no app code at all.

## Send Feedback

Menu bar → **Send Feedback…** opens a window (`FeedbackWindow.swift`):

- a message box, and an optional reply address;
- **Include app info** (on): the exact line shown, e.g. "Desi Dictation
  0.7.0 · macOS 15.1 · english · model: auto";
- **Include my last dictation** (off), shown in full when ticked;
- **Send**, **Copy** (works offline) and **Email instead** (the old mail
  draft, `Feedback.swift`).

`FeedbackReport.body()` is the whole of what's sent: the message plus only
the ticked, non-empty parts, each cut to the endpoint's limit. There are no
IDs, no audio and no other settings. `FeedbackSender` POSTs it with an
ephemeral `URLSession` (no cookies, no cache) to
`https://www.samarthsaraswat.com/api/feedback`, with the header
`X-Desi-Dictation: feedback-1`. If it can't send, it says so and offers
Copy and Email instead. It never queues and never retries in the background.

**The endpoint** (`api/feedback.ts` in the website repo) checks the report,
rate-limits each address to 5 per 10 minutes (in memory), and forwards it to
samarthsaraswat13@gmail.com through its own EmailJS account (not the contact
form's). It stores nothing, and logs only the mail service's status, never
the report. The EmailJS template has "Do not save private data" on, so its
history keeps only that a mail went out.

**Setup (done):** the samarthsaraswat13 EmailJS account allows API calls
from non-browser applications with "Use Private Key" on, and the key is
`EMAILJS_PRIVATE_KEY` in the Vercel project. If sends start failing ("Couldn't
send it right now"), check those two first; Copy and Email instead still work.

## Download counts, without tracking

Each release carries the same DMG under three names (`release.sh`,
`release.yml`), and GitHub counts each file separately:

| File | Route |
|---|---|
| `DesiDictation-mac.dmg` | the website's Download button |
| `DesiDictation.dmg` | the one-line installer |
| `DesiDictation-<v>.dmg` | the GitHub releases page |

Both stable names sit behind `releases/latest/download/…`, so a new release
changes nothing on the website. Its version label reads the latest release
from the GitHub API when the page loads. `./scripts/download_counts.sh`
prints the counts per release and in total.

- **Before v0.7.0** the website button also fetched `DesiDictation.dmg`, so
  for older releases "terminal" includes website clicks.
- **Counts include our own test downloads.**

## Changing it

- What's sent: `FeedbackReport` (Kit, `Feedback/`); tests in
  `DesiTests/FeedbackTests.swift`.
- Endpoint and limits: `api/feedback.ts` in the website repo, which has its
  own tests in `src/test/feedback.test.ts`. Keep `FeedbackReport.limits` equal
  to the endpoint's.
- A new route to count: give it its own copy of the DMG in `release.sh` and
  `release.yml`, then a column in `download_counts.sh`.
