import SwiftUI
import DesiDictationKit

/// Setup: which language, and which others to set up too.
struct LanguageStep: View {
    @ObservedObject var flow: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(title: "Which language will you speak most?",
                      subtitle: "You can switch any time from the menu bar.")
            VStack(spacing: 10) {
                choice(.english, "textformat", "English",
                       "Emails, notes, messages, code. Very accurate, Indian accents included.")
                choice(.hinglish, "bubble.left.and.text.bubble.right", "Hinglish",
                       "“kal meeting hai, deck ready rakhna” in Roman letters. Our specialty. Mixed speech is the hardest kind, so expect a few more fixes than in English.")
                choice(.hindi, "character.textbox", "हिन्दी",
                       "Pure Hindi, written in Devanagari: “कल मीटिंग है”.")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("I also speak").font(.title3.weight(.semibold))
                HStack(spacing: 20) {
                    ForEach([LanguageMode.english, .hinglish, .hindi].filter { $0 != flow.language }, id: \.self) { mode in
                        Toggle(mode.displayName, isOn: Binding(
                            get: { flow.alsoFor.contains(mode) },
                            set: { if $0 { flow.alsoFor.insert(mode) } else { flow.alsoFor.remove(mode) } }))
                    }
                }
                .font(.body)
            }
        }
    }

    private func choice(_ mode: LanguageMode, _ symbol: String, _ title: String, _ detail: String) -> some View {
        ChoiceCard(symbol: symbol, title: title, detail: detail, selected: flow.language == mode) {
            flow.language = mode
            flow.alsoFor.remove(mode)
        }
    }
}

/// Setup: the models those languages need. English offers speed or accuracy.
struct ModelsStep: View {
    @ObservedObject var flow: OnboardingModel
    @ObservedObject private var models = ModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(title: "Download your models",
                      subtitle: "They run on your Mac, so what you say never leaves it. Download once, then it works offline.")
            if flow.languages.contains(.english) {
                Text("English: pick speed, accuracy, or both").font(.title3.weight(.semibold))
                ChoiceCard(symbol: "hare", title: "Parakeet", detail: "Words appear in about a fifth of a second. Best for everyday dictation.",
                           tag: "Fastest · default", selected: flow.englishFast,
                           action: { flow.englishFast.toggle() }) { status(ModelManager.catalogEntry(for: .english)) }
                ChoiceCard(symbol: "scope", title: "Qwen", detail: "About one in six fewer mistakes when you speak clearly in Indian English. Words take about half a second longer.",
                           tag: "Most accurate", selected: flow.englishAccurate,
                           action: { flow.englishAccurate.toggle() }) { status(ModelManager.qwenEntry) }
                Tip(symbol: "arrow.left.arrow.right",
                    text: "Pick both to switch any time from the menu bar. With both, Parakeet is used until you choose Qwen.")
                if !flow.englishFast && !flow.englishAccurate {
                    Text("Pick at least one English model.").font(.callout).foregroundStyle(.red)
                }
            }
            let others = flow.wanted.filter { $0.category != "English" }
            if !others.isEmpty {
                Text(flow.languages.contains(.english) ? "Also downloading" : "Downloading").font(.title3.weight(.semibold))
                VStack(spacing: 8) {
                    ForEach(others) { item in
                        HStack {
                            Text(item.label).font(.body)
                            Spacer()
                            status(item)
                        }
                        .card()
                    }
                }
            }
        }
    }

    /// Ready, a progress bar, or the size, plus any error.
    private func status(_ item: DownloadableModel) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if models.isInstalled(item) {
                Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if let progress = models.downloadProgress[item.id] {
                ProgressView(value: progress).frame(width: 100)
            } else {
                Text(item.approxMB >= 1000 ? String(format: "%.1f GB", Double(item.approxMB) / 1000) : "\(item.approxMB) MB")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            if let error = models.downloadErrors[item.id] {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .font(.callout)
    }
}
