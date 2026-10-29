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
                Text("Desi Dictation types what you say into any app. Everything runs on this Mac. The extras below are all optional: read what each does and switch on only what helps you.")
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
                summary: "Menu bar mic → Language: Hinglish, English or हिन्दी. The right model loads by itself; you never pick a model unless you want to (Models page).")

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
                summary: "Dictation → Review. \"Only when unsure\" opens a panel when a word looks wrong: the speech model wasn't sure of it (orange), it's odd in its sentence (purple, needs the context checker), or it sounds like one of your words. \"Underline words\" sets how readily: Moderate (default) suits most people, Liberal only marks likely mistakes, Conservative marks more. Everyday words said casually are left alone. Nothing is changed for you. Tab jumps to it, 1–5 picks a suggestion, or just type. Enter pastes, Esc copies. A word you fix there can be remembered: Always, When it fits, or Just this once. Off by default.")
        }
        .formStyle(.grouped)
        .onAppear { UserDefaults.standard.set(true, forKey: MainNav.guideSeenKey) }
    }

    private var learnSection: some View {
        GuideFeature(
            number: 4, title: "Learn from my corrections",
            summary: "Instead of typing a list, just fix mistakes where they land. It notices and offers to remember.",
            steps: ["Dictate as usual. Say it writes \"Call Rowan at 5\".",
                    "Within **30 seconds**, fix the word right there in the text: Rowan → Rohan.",
                    "Stop typing for **2 seconds** (or just press Enter). A small popup asks **Always write Rowan as Rohan in English?** Click **Add** and it's in that language's list for good.",
                    "Missed the popup? It waits in Vocabulary → Waiting for you. **Not now** waits until you make the same fix a few more times; only **Never** stops it for good.",
                    "Right only sometimes, like Claude vs cloud? Get the small model under Vocabulary → **When it fits**, then pick **Only when it fits**: each English sentence decides.",
                    "Want proof it's working? Vocabulary → **What it's been doing** lists what it saw after each dictation, what it suggested and what it learned. Learned words appear under **Your words**."],
            turnOnIf: "it keeps mishearing the same names, brands or terms.",
            skipIf: "you'd rather add words yourself. It only ever asks; nothing is learned without your yes. It watches just the field you dictated into, for 30 seconds, and ignores rewrites and grammar fixes like their → there.",
            isOn: $vocab.learnFromEdits,
            example: AnyView(LearnExample()))
    }
}
