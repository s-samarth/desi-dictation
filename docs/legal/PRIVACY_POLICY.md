# Privacy Policy

**Desi Dictation**
**Effective date:** [DATE OF PUBLICATION]

Desi Dictation is a dictation app for macOS, made by Samarth Saraswat
("we", "us"). It turns your speech into text on your own Mac. This policy
explains what happens to your information when you use the app, its web
demo, and its website.

**The short version:** your voice and your words stay on your Mac. We don't
have accounts, we don't run analytics or telemetry, and we never receive your
audio or your text through the app.

## 1. What the app does on your Mac

The app does all of its work on your computer. None of the following is sent
to us or to anyone else.

| What | What happens to it |
|---|---|
| **Your voice** | Recorded into memory while you hold the dictation key, turned into text, then discarded. It is never written to disk and never sent anywhere. |
| **The text it writes** | Pasted into the app you were using and placed on your clipboard. |
| **History** | Your dictations from the last 24 hours (up to 200) are kept in a file on your Mac so you can find and copy them. Older entries are deleted. You can turn History off or clear it at any time on the History page. |
| **Your word list** | Words you add, or approve when the app suggests them, are saved on your Mac so they're written your way. You can edit or delete them on the Vocabulary page. |
| **Text on your screen** | Only if you turn on "Suggest names on screen" or "Hinglish: suggest my spelling": when you start dictating, the app reads the text in the window you are dictating into, to spot names and spellings. That text is kept in memory for that one dictation and then dropped. It is never saved or sent anywhere. |
| **Your edits after a dictation** | Only if you turn on "Suggest words from my corrections", or after the app wrote one of your "When it fits" words: for up to 2 minutes after the paste, the app reads the text field you dictated into, to notice a word you corrected (and offer to remember it) or a change you undid. The text is kept in memory only and dropped when the 2 minutes end. |
| **Settings** | Stored on your Mac in the app's preferences. |

The optional **context checker** is a small language model that runs on your
Mac. It reads a sentence to judge how well each word fits. It does not send
anything anywhere.

## 2. Permissions the app asks for

macOS asks you to approve each of these. You can withdraw them at any time in
System Settings → Privacy & Security.

- **Microphone**: to hear you while you dictate.
- **Accessibility**: to paste the text where your cursor is and, if you turn
  on the features above, to read the text field or window you're dictating
  into.
- **Input Monitoring**: to notice when you press the dictation key and Esc.
  The app looks only at those keys. It does not record or store anything
  else you type.

## 3. When the app uses the internet

The app connects to the internet only in these cases:

1. **Downloading speech models.** When you click Get on the Models page (or
   during setup), the app downloads model files from Hugging Face
   (huggingface.co). Like any website, Hugging Face can see your IP address
   and that a file was downloaded. Hugging Face's own privacy policy applies
   to that request. No audio, text or personal information is sent.
2. **Checking a license key** (only if paid licenses are enabled, and only
   when you enter a key). The app sends the key to Gumroad (gumroad.com) to
   check that it is valid. Gumroad's privacy policy applies. Paid licenses
   are not enabled in the current version.
3. **Optional local AI features** (off by default). If you set them up, they
   talk to Ollama running on your own Mac (address 127.0.0.1). That traffic
   never leaves your computer.

The app has **no analytics, telemetry, crash reporting or advertising**, and
no accounts.

## 4. Feedback and support

"Send Feedback…" opens a window. What you type is sent only when you press
Send, to our website (samarthsaraswat.com), which forwards it to our inbox
through an email service (EmailJS) and doesn't store it. Two optional parts
are shown in full before you send: a line of app details (app version, macOS
version, language, model), which you can untick, and your last dictation,
which is off unless you tick it. Your email address is sent only if you type
it, so we can reply. Nothing else is sent: no audio, no identifiers. Like any
website, ours sees the network address the request comes from; we use it
only to stop floods of reports and don't keep it.

The same window can open an email draft in your own email app instead.
Either way, we use what you send only to reply and to improve the app, and
we don't share it.

## 5. The web demo

If you try the demo in your browser, the short clip you record is uploaded to
our demo server so it can be transcribed. The server processes the clip in a
temporary folder that is deleted as soon as the text is returned. We do not
keep the audio or the text. To prevent abuse, the server counts requests per
IP address in memory for a short time. The demo may be served through a
hosting or network provider (such as Cloudflare), which handles the traffic
under its own privacy policy.

## 6. Our website

[If the website uses no cookies or analytics, keep this sentence:] Our
website does not use cookies, analytics or tracking. Your browser and our
hosting provider exchange the usual technical information (such as your IP
address) needed to deliver the page.

## 7. Buying the app

If you buy a license, the purchase is handled by our payment provider
(currently Gumroad), which collects the details needed to process payment,
such as your name, email address and payment information, under its own
privacy policy. We receive the order details the provider shares with
sellers, such as your email address and license key, and use them only to
provide your license and support.

## 8. Children

The app is not directed at children under 13, and we do not knowingly
collect personal information from anyone. Because the app doesn't send us
your data, we hold none to delete; if you believe we hold information about a
child through an email, contact us and we will delete it.

## 9. Your choices and rights

- Every optional feature that reads text is **off until you turn it on**.
- You can clear History, edit your word list, and delete the app's data at
  any time. Deleting the app and its folder at
  `~/Library/Application Support/DesiDictation` removes everything it stored.
- Because we don't collect personal data through the app, there is usually
  nothing for us to access, correct or delete. For emails you've sent us, you
  can ask us to delete them.
- Depending on where you live (for example under India's Digital Personal
  Data Protection Act, 2023, or the EU/UK GDPR), you may have rights to
  access, correct or delete personal data we hold. Contact us and we'll help.

## 10. Security

Model files are checked against a fixed fingerprint (SHA-256) after
download, and a file that doesn't match is deleted, so a tampered model
isn't loaded. Your data's security also depends on your Mac; keep macOS up to
date and use a login password.

## 11. Changes to this policy

If we change what the app sends or stores, we'll update this policy and say
so clearly in the release notes before the change ships. The effective date
at the top shows the latest version.

## 12. Contact

Samarth Saraswat
Email: samarth.iitg@gmail.com
