import SwiftUI
import DesiDictationKit

/// The four opt-in switches (AUTO_VOCABULARY.md), shared by the Vocabulary
/// pane and onboarding. Each one carries its own privacy line, so turning a
/// switch on is an informed choice.
struct SmartVocabularyToggles: View {
    @ObservedObject var store = AutoVocabularyStore.shared

    var body: some View {
        toggle("Suggest words from my corrections", $store.learnFromEdits,
               "After a paste, if you retype a word it wrote, it asks: \"Always write X as Y?\". Nothing is added until you say yes.")
        toggle("Fix near-misses of my names and words", $store.fixNearMisses,
               "\"Saraswath\" → \"Saraswat\" when it sounds and looks almost the same. Everyday words are never touched. Every fix shows on screen and in History.")
        toggle("Read names from the window I'm dictating into", $store.readScreen,
               "Names on screen are read when you start dictating, kept in memory for that one dictation, then dropped. Never saved.")
            .disabled(!store.fixNearMisses)
        toggle("Hinglish: match the spelling already in the text I'm editing", $store.hinglishFieldSpelling,
               "If the field already writes \"nahi\" (twice or more), \"nahin\" becomes \"nahi\" in this dictation only.")
    }

    private func toggle(_ title: String, _ isOn: Binding<Bool>, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: isOn)
            Text(note).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Settings → Vocabulary: the switches plus the review queue of proposals.
struct SmartVocabularyView: View {
    @ObservedObject var store = AutoVocabularyStore.shared

    var body: some View {
        Form {
            Section {
                SmartVocabularyToggles()
            } header: {
                Text("Smart vocabulary — teach it your names without typing a list")
            } footer: {
                Text("Everything here is off until you turn it on, and nothing leaves your Mac. Accepted words go into your Personal dictionary (Text).")
                    .font(.caption)
            }
            Section("Suggestions waiting for you (\(store.suggestions.count))") {
                if store.suggestions.isEmpty {
                    Text("When you retype a word it got wrong, the fix shows up here.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(store.suggestions) { SuggestionRow(suggestion: $0) }
            }
            if !store.rejected.isEmpty {
                Section("Fixes you turned down") {
                    Text("\(store.rejected.count) word pairs will never be suggested or applied.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Allow them again") { store.clearRejections() }
                }
            }
        }
        .padding()
    }
}

/// "Rowan → Rohan   Add · Not now · Never" — one proposal.
struct SuggestionRow: View {
    let suggestion: VocabularySuggestion
    var compact = false
    private var store: AutoVocabularyStore { .shared }

    var body: some View {
        HStack(spacing: 8) {
            Text(suggestion.heard).strikethrough().foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Text(suggestion.written).fontWeight(.semibold)
            Spacer(minLength: 8)
            Button("Add") { store.accept(suggestion) }
                .buttonStyle(.borderedProminent).controlSize(.small)
            Button("Not now") { store.dismiss(suggestion) }
                .controlSize(.small)
            if !compact {
                Button("Never") { store.never(suggestion) }
                    .controlSize(.small)
            }
        }
    }
}
