import SwiftUI
import DesiDictationKit

/// Review before paste settings (REVIEW_BEFORE_PASTE.md): when the panel
/// opens, and how readily it underlines words.
struct ReviewSection: View {
    @ObservedObject var settings = SettingsStore.shared

    var body: some View {
        Section {
            Picker("Review before paste", selection: $settings.reviewMode) {
                ForEach(ReviewMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            if settings.reviewMode != .off {
                Picker("Underline words", selection: $settings.reviewStrictness) {
                    ForEach(ReviewStrictness.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                if LlamaContextScorer.isAvailable {
                    ContextCheckerRow(adds: "purple underlines for words odd in their sentence (English, हिन्दी)")
                }
            }
        } header: {
            Text("Review")
        } footer: {
            Text(line).footnote()
        }
    }

    private var line: String {
        mainLine + (settings.reviewStrictness.onlyOdd && !ContextChecker.isReady
            ? " Bindaas needs the context checker below: without it nothing is underlined." : "")
    }

    private var mainLine: String {
        switch settings.reviewMode {
        case .off:
            return "Off: words go straight into your app. Optional; nothing else needs it."
        case .unsure:
            return "A small panel opens only when a word looks wrong. Tab jumps to it, 1–5 picks a suggestion, Enter pastes. "
                + settings.reviewStrictness.detail
        case .always:
            return "Every dictation opens a small panel first. Edit anything, then Enter pastes and Esc copies. "
                + settings.reviewStrictness.detail
        }
    }
}
