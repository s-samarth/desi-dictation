import SwiftUI
import DesiDictationKit

/// The four opt-in switches (AUTO_VOCABULARY.md), shared by the Vocabulary
/// page and onboarding. Each carries one short line on what it reads or
/// changes, so turning a switch on is an informed choice.
struct SmartVocabularyToggles: View {
    @ObservedObject var store = AutoVocabularyStore.shared

    var body: some View {
        toggle("Suggest words from my corrections", $store.learnFromEdits,
               "Retype a word it got wrong and it asks \"Always write X as Y?\"")
        toggle("Fix near-misses of my words", $store.fixNearMisses,
               "\"Saraswath\" becomes \"Saraswat\". Everyday words are never changed.")
        toggle("Use names on screen", $store.readScreen,
               "Reads the window you dictate into, for that dictation only. Never saved.")
            .disabled(!store.fixNearMisses)
        toggle("Hinglish: match my spelling in the field", $store.hinglishFieldSpelling,
               "If the text already says \"nahi\", \"nahin\" becomes \"nahi\".")
    }

    private func toggle(_ title: String, _ isOn: Binding<Bool>, _ note: String) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
            Text(note)
        }
    }
}

/// Vocabulary page: the words it should always write, how it learns more,
/// and anything waiting for a yes.
struct VocabularyPane: View {
    @ObservedObject var store = AutoVocabularyStore.shared
    @ObservedObject var settings = SettingsStore.shared
    @State private var showReplacements = false

    var body: some View {
        Form {
            if !store.suggestions.isEmpty {
                Section("Waiting for you") {
                    ForEach(store.suggestions) { SuggestionRow(suggestion: $0) }
                }
            }

            VocabularyActivitySection()

            DictionarySettings()

            Section {
                SmartVocabularyToggles()
            } header: {
                HStack {
                    Text("Learn automatically")
                    Spacer()
                    Button("How does this work?") { MainNav.shared.selection = .guide }
                        .buttonStyle(.link).font(.callout)
                }
            } footer: {
                Text("Off until you turn them on. Nothing leaves your Mac, and every automatic fix shows in History.")
                    .footnote()
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $showReplacements) {
                    Text("Replacements, one per line: find=replace")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $settings.replacementRules)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                    if !store.rejected.isEmpty {
                        HStack {
                            Text("\(store.rejected.count) fixes you turned down are never applied.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Allow again") { store.clearRejections() }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
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
