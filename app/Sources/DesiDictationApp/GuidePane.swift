import SwiftUI
import DesiDictationKit

/// Guide page: every feature in plain words, in the order you'd meet them,
/// with its switch beside the explanation. It's the first page until it has
/// been opened once (MainNav), then stays one click away in the sidebar.
struct GuidePane: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var vocab = AutoVocabularyStore.shared

    var body: some View {
        Form {
            Section {
                Text("Desi Dictation types what you say into any app. Everything runs on this Mac. Sections 1 and 2 are all you need. Everything after them is optional and **off until you turn it on**: read what each does and switch on only what helps you. Nothing changes your words unless you told it to (your own word list).")
            }

            GuideFeature(
                number: 1, title: "Dictate anywhere",
                summary: "Click into any text field, then speak.",
                steps: ["\(settings.activationMode == .pushToTalk ? "**Hold**" : "**Tap**") \(settings.hotkey.displayName) and talk. Pauses are fine.",
                        settings.activationMode == .pushToTalk
                            ? "**Release** and your words appear where the cursor is."
                            : "**Tap again** and your words appear where the cursor is.",
                        "**Esc** throws the dictation away. The last one is always on the clipboard too."])

            GuideFeature(
                number: 2, title: "Pick your language",
                summary: "Menu bar mic → Language: Hinglish, English or हिन्दी. The right model loads by itself. For English you can pick Parakeet (fastest) or Qwen (most accurate) from the menu bar's Model item or the Models page.")

            GuideFeature(
                number: 3, title: "Teach it your words",
                summary: "A name it keeps getting wrong? Teach it once and every dictation writes it your way, in every app. There are two lists: Hinglish dictations use your Hinglish words, English dictations your English words, so a Hinglish spelling like \"nahi\" never touches English. हिन्दी uses neither.",
                steps: ["**Fastest:** select the wrong word in any app, right-click → **Services → Always write as… (Desi Dictation)**, type the right spelling, Save.",
                        "Or fix it in the text right after dictating (section 4), or add it in Vocabulary → Your words."])

            learnSection

            GuideFeature(
                number: 5, title: "Suggest near-misses of your words",
                summary: "When a dictated word sounds and looks almost like one of your words, it's underlined in the review panel with your word as choice 1: \"Saraswath\" → 1 Saraswat. It's never changed for you; only words you've told it to always write are written automatically.",
                steps: ["Needs **Review before paste** on (section 9). Press 1 to take the suggestion, or just carry on.",
                        "Want it written every time? Keep the fix as **Always** in the panel."],
                turnOnIf: "you've added names to Your words (or let it learn some) and want them right the first time.",
                skipIf: "you don't use Review before paste. Everyday words like \"there\" or \"hai\" are never suggested either way.",
                isOn: $vocab.fixNearMisses)

            GuideFeature(
                number: 6, title: "Use names on screen",
                summary: "When you start dictating, it reads the names visible in that window (the chat, the email thread), so \"Rowan\" in a reply to Rohan is underlined with \"Rohan\" in the review panel. Never changed for you.",
                steps: ["The text is kept in memory for that one dictation, then dropped. Never saved, never sent anywhere."],
                turnOnIf: "you mostly dictate replies in chats and email, where the names are already on screen.",
                skipIf: "you don't want any window text read, even locally.",
                isOn: $vocab.readScreen,
                disabledNote: vocab.fixNearMisses ? nil : "Needs “Suggest near-misses” (5) on.")

            GuideFeature(
                number: 7, title: "Hinglish: match my spelling",
                summary: "Hinglish has no fixed spelling. If the text you're writing in already uses \"nahi\" (twice or more), a dictated \"nahin\" is underlined with \"nahi\" in the review panel, so the message can stay consistent. Only for that dictation.",
                turnOnIf: "you dictate Hinglish into ongoing chats or notes.",
                skipIf: "you only dictate English or हिन्दी.",
                isOn: $vocab.hinglishFieldSpelling)

            GuideFeature(
                number: 8, title: "History",
                summary: "The last 24 hours of dictations, on this Mac only. Search, copy, or right-click one to add a word, undo an automatic fix, or copy what it heard before any fixes. Turn it off on the History page.")

            GuideFeature(
                number: 9, title: "Check before pasting",
                summary: "Off by default. Dictation → Review. \"Only when unsure\" opens a panel before pasting when a word looks wrong. Nothing is changed for you.",
                steps: ["**Orange:** the speech model wasn't sure what it heard, or the word sounds like one of your words or a name on screen.",
                        "**Purple:** heard clearly but odd in its sentence (\"one PC Luffy\", a misheard name). Only with the context checker (section 10).",
                        "**Tab** jumps to an underline, **1–5** picks a suggestion, **0** says it looks right, or just type. **Enter** pastes, **Esc** copies.",
                        "A word you fix is remembered **When it fits** unless you pick **Always** or **Just this once**.",
                        "\"Underline words\": **Moderate** (default) suits most people; Liberal marks only likely mistakes; Conservative marks more. Everyday words said casually are left alone."],
                turnOnIf: "you want to check names and odd words before they're sent.",
                skipIf: "you'd rather fix things after pasting; section 4 still learns from that.")

            GuideFeature(
                number: 10, title: "Context checker (optional download)",
                summary: "A small language model (397 MB) that reads your sentence on this Mac and scores how expected each word is. It never writes words or sends anything. Get it on the Models page, or from the Context checker rows on Dictation and Vocabulary.",
                steps: ["**Needs it:** purple underlines in Review (English, हिन्दी), and **When it fits** words judged by the sentence (English).",
                        "**Works without it:** everything else. A When it fits word without the checker changes only when its written form is on screen or is the app you're in.",
                        "Uses about 0.4 GB of memory while a feature that needs it is on."])

            GuideFeature(
                number: 11, title: "Fillers and spoken corrections",
                summary: "Dictation → Clean-up. \"Remove um and uh\" is on: um, uh, hmm and er are never words, so they just go. Everything else is only offered in Review before paste, unless you switch it on.",
                steps: ["**Sometimes fillers** (like, you know, I mean, basically…) are underlined as **Filler?** when the context checker thinks they are: press **1** to remove, **0** to keep. \"I like the design\" is left alone; \"we should like ship it\" is offered.",
                        "**Remove fillers when sure** (off by default) takes out the clear ones without asking. On test sentences it removed 8 of 21 fillers and none of 20 real uses.",
                        "**Spoken corrections:** \"meet at 2, no, make it 3\" is underlined with **You probably meant: 3**; \"Rohan, sorry, Rahul\" with Rahul; \"plan A, scratch that, plan B\" offers to remove what you took back. Never applied on its own."],
                turnOnIf: "you think out loud while dictating.",
                skipIf: "you want every word exactly as said: turn \"Remove um and uh\" off.")
        }
        .formStyle(.grouped)
        .onAppear { UserDefaults.standard.set(true, forKey: MainNav.guideSeenKey) }
    }

    private var learnSection: some View {
        GuideFeature(
            number: 4, title: "Learn from my corrections",
            summary: "Instead of typing a list, just fix mistakes where they land. It notices and offers to remember.",
            steps: ["Dictate as usual. Say it writes \"Call Rowan at 5\".",
                    "Within **2 minutes**, fix the word right there in the text: Rowan → Rohan.",
                    "Stop typing for **2 seconds** (or just press Enter). A small popup asks **Always write Rowan as Rohan in English?** Click **Add** and it's in that language's list for good.",
                    "Missed the popup? It waits in Vocabulary → Waiting for you. **Not now** waits until you make the same fix a few more times; only **Never** stops it for good.",
                    "Right only sometimes, like Claude vs cloud? Pick **When it fits** in the popup: each English sentence decides, using the context checker (section 10).",
                    "Want proof it's working? Vocabulary → **What it's been doing** lists what it saw after each dictation, what it suggested and what it learned. Learned words appear under **Your words**."],
            turnOnIf: "it keeps mishearing the same names, brands or terms.",
            skipIf: "you'd rather add words yourself. It only ever asks; nothing is learned without your yes. It watches just the field you dictated into, for 2 minutes, and ignores rewrites and grammar fixes like their → there.",
            isOn: $vocab.learnFromEdits,
            example: AnyView(LearnExample()))
    }
}
