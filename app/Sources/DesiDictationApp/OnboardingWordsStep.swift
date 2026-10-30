import SwiftUI
import DesiDictationKit

/// Setup: the optional vocabulary features (AUTO_VOCABULARY.md), each with
/// what it does, an example, and who should turn it on.
struct WordsStep: View {
    @ObservedObject var flow: OnboardingModel
    @ObservedObject private var store = AutoVocabularyStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(title: "Teach it your names",
                      subtitle: "Optional. Every switch starts off, and nothing leaves your Mac. Skip this if you're not sure: they're all in Settings later.")
            FeatureCard(symbol: "arrow.uturn.backward.circle", title: "Learn from my corrections",
                        what: "Fix a word after it's typed, say “Kartick” to “Kartik”, and it asks: “Always write Kartik?”",
                        turnOnIf: "Turn on if it keeps getting names, brands or jargon wrong.",
                        isOn: $store.learnFromEdits)
            FeatureCard(symbol: "text.badge.checkmark", title: "Spot near-misses of my words",
                        what: "When a word sounds like one you've taught it, the review panel underlines it and offers your spelling. Never changed without you.",
                        turnOnIf: "Turn on if you'll use Review before paste (next page).",
                        isOn: $store.fixNearMisses)
            FeatureCard(symbol: "macwindow", title: "Use names on screen",
                        what: "Looks at the window you're dictating into, like an email thread or a chat, for names to suggest. Only for that dictation; never saved.",
                        turnOnIf: "Turn on if you reply to people whose names it misspells. Needs the switch above.",
                        isOn: $store.readScreen, enabled: store.fixNearMisses)
            if flow.languages.contains(.hinglish) {
                FeatureCard(symbol: "character.bubble", title: "Hinglish: match the chat's spelling",
                            what: "If the chat already says “kya” and “thik”, a dictated “kyaa” or “theek” is underlined with your spelling.",
                            turnOnIf: "Turn on if you dictate Hinglish into chats and care how words are spelled.",
                            isOn: $store.hinglishFieldSpelling)
            }
        }
        .onChange(of: store.fixNearMisses) { _, on in if !on { store.readScreen = false } }
    }
}

/// Setup: Review before paste, with a picture of the panel and the two
/// settings that matter: when it opens, and how much it underlines.
struct ReviewStep: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(title: "Check before it pastes",
                      subtitle: "Optional. A small panel shows your words first, with the ones that might be wrong underlined. You pick a fix or press Enter.")
            ReviewSketch()
            VStack(alignment: .leading, spacing: 8) {
                Text("When should the panel open?").font(.title3.weight(.semibold))
                Picker("", selection: $settings.reviewMode) {
                    ForEach(ReviewMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                Text(modeLine).font(.body).foregroundStyle(.secondary)
            }
            if settings.reviewMode != .off {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How much should it underline?").font(.title3.weight(.semibold))
                    Picker("", selection: $settings.reviewStrictness) {
                        ForEach(ReviewStrictness.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    Text(settings.reviewStrictness.detail).font(.body).foregroundStyle(.secondary)
                }
                Tip(symbol: "slider.horizontal.3",
                    text: "**Feel it's poking you too often? Switch to Liberal.** Missing mistakes? Try Conservative. You can change this any time under Dictation in the app.")
            }
            if LlamaContextScorer.isAvailable {
                ContextCheckerCard()
            }
        }
    }

    private var modeLine: String {
        switch settings.reviewMode {
        case .off: return "Your words go straight into the app, as now."
        case .unsure: return "Recommended. It opens only when a word looks wrong, so most dictations paste straight away."
        case .always: return "Every dictation waits for you to check it. Good for long, important messages."
        }
    }
}

/// A drawing of the review panel: one unclear word (orange), one odd one
/// (purple), and the suggestions for the first.
struct ReviewSketch: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) {
                Text("Send the deck to")
                marked("Kartick", .purple)
                Text("before the")
                marked("hakka", .orange)
                Text("review")
            }
            .font(.title3)
            HStack(spacing: 8) {
                Text("Kartick →").foregroundStyle(.secondary)
                Chip(text: "1  Kartik", color: Theme.accent)
                Chip(text: "2  Karthik", color: Theme.accent)
                Spacer()
                Text("Enter pastes").foregroundStyle(.secondary)
            }
            .font(.body)
            HStack(spacing: 18) {
                legend(.orange, "the audio was unclear")
                legend(.purple, "odd in its sentence")
            }
            .font(.body)
        }
        .card()
    }

    private func marked(_ word: String, _ color: Color) -> some View {
        Text(word).fontWeight(.semibold)
            .overlay(alignment: .bottom) {
                Capsule().fill(color).frame(height: 3).offset(y: 4)
            }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 18, height: 3)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

/// The optional context checker as a setup card: what it adds, and a Get
/// button, whether or not Review is on (it also powers "When it fits").
struct ContextCheckerCard: View {
    @ObservedObject private var models = ModelManager.shared
    private let item = ModelManager.contextCheckerEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.magnifyingglass").font(.title2).foregroundStyle(.purple).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text("Context checker (optional)").font(.title3.weight(.semibold))
                Text("A small model, \(item.approxMB) MB, that reads the whole sentence. It adds the purple underlines, and lets “cloud” become “Claude” only when you mean Claude.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
                if let error = models.downloadErrors[item.id] {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            Spacer(minLength: 8)
            if models.isInstalled(item) {
                Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if let progress = models.downloadProgress[item.id] {
                ProgressView(value: progress).frame(width: 90)
            } else {
                Button("Get") {
                    Task {
                        await models.download(item)
                        ContextChecker.shared.reset()
                    }
                }
                .controlSize(.large)
            }
        }
        .card()
    }
}
