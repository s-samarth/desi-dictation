import SwiftUI
import DesiDictationKit

/// Dictation page: filler clean-up (FILLERS_AND_CORRECTIONS.md). What these
/// switches allow is the only clean-up that happens on its own; the rest is
/// offered in Review before paste.
struct CleanupSection: View {
    @ObservedObject var cleanup = CleanupSettings.shared
    @ObservedObject var models = ModelManager.shared

    var body: some View {
        Section {
            Toggle(isOn: $cleanup.removeSounds) {
                Text("Remove um and uh")
                Text("Also hmm and er. They're never words, so they just go.")
            }
            Toggle(isOn: $cleanup.removeSureFillers) {
                Text("Remove fillers when sure (English)")
                Text("\"like\", \"you know\", \"I mean\"… only when the context checker is sure they're filler. The rest are offered in Review.")
            }
            if cleanup.removeSureFillers, LlamaContextScorer.isAvailable,
               !models.isInstalled(ModelManager.contextCheckerEntry) {
                ContextCheckerRow(adds: "judging which words are filler")
            }
        } header: {
            Text("Clean-up")
        } footer: {
            Text("With Review before paste on, likely fillers and spoken corrections (\"2, no, make it 3\", \"scratch that\") are underlined for you to accept. Nothing else is changed.")
                .footnote()
        }
    }
}
