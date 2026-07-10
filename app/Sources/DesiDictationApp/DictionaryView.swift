import SwiftUI
import DesiDictationKit

/// Personal dictionary management (P4-S1): the list of "always write it as"
/// rules. Lives in the Text tab; entries are also added from History.
struct DictionarySettings: View {
    @ObservedObject var dictionary = PersonalDictionary.shared
    @State private var showAdd = false

    var body: some View {
        Section {
            if dictionary.entries.isEmpty {
                Text("Teach it your words: names, brands, code terms. Right-click any dictation in History, or add one here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(dictionary.entries) { entry in
                HStack {
                    Text(entry.heard).strikethrough().foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(entry.written).fontWeight(.medium)
                    Spacer()
                    Button {
                        dictionary.remove(entry)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this rule")
                }
            }
            Button("Add word…") { showAdd = true }
        } header: {
            Text("Personal dictionary — always write it as…")
        } footer: {
            Text("Applied to every dictation, whole words only, keeps capitalization. Stays on your Mac.")
                .font(.caption)
        }
        .sheet(isPresented: $showAdd) { AddDictionaryEntrySheet() }
    }
}

/// Two fields, one job: "it wrote X → always write Y". Prefill `heard` when
/// launched from a history entry so the user only types the correct form.
struct AddDictionaryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var heard: String = ""
    @State var written: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Always write it as…").font(.headline)
            Text("Next time dictation writes the left word, it becomes the right one.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("It wrote (e.g. Saraswath)", text: $heard)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                TextField("Always write (e.g. Saraswat)", text: $written)
            }
            .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    PersonalDictionary.shared.add(heard: heard, written: written)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(heard.trimmingCharacters(in: .whitespaces).isEmpty
                          || written.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
