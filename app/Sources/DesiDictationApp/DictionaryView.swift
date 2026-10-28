import SwiftUI
import DesiDictationKit

/// Personal dictionary management (P4-S1): two lists, picked by the language
/// you dictate in. Hinglish dictations use the Hinglish words, English ones
/// the English words; हिन्दी has none. Lives on the Vocabulary page.
struct DictionarySettings: View {
    @ObservedObject var dictionary = PersonalDictionary.shared
    @ObservedObject var settings = SettingsStore.shared
    @State private var list: WordScope = WordScope(mode: SettingsStore.shared.languageMode) ?? .english
    @State private var showAdd = false

    private var words: [DictionaryEntry] { dictionary.entries.filter { $0.scope == list } }

    var body: some View {
        Section {
            Picker("List", selection: $list) {
                ForEach(WordScope.allCases, id: \.self) { scope in
                    Text("\(scope.label) (\(dictionary.entries.filter { $0.scope == scope }.count))").tag(scope)
                }
            }
            .pickerStyle(.segmented).labelsHidden()
            if words.isEmpty {
                Text("No \(list.label) words yet. Fix a misheard word right in the text after dictating, select it anywhere and right-click → Services → Always write as…, or add one here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(words) { entry in
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
                    .help("Remove this word")
                }
            }
            Button("Add \(list.label) word…") { showAdd = true }
        } header: {
            Text("Your words")
        } footer: {
            Text("\(list.label) dictations use the \(list.label) list, whole words only. हिन्दी dictations use neither.")
                .footnote()
        }
        .sheet(isPresented: $showAdd) { AddDictionaryEntrySheet(scope: list) { showAdd = false } }
    }
}

/// Two fields, one job: "it wrote X → always write Y", into one list.
/// Prefilled `heard` when it comes from a selection (right-click → Services)
/// or History, so the user only types the correct form.
struct AddDictionaryEntrySheet: View {
    @State var heard: String = ""
    @State var written: String = ""
    @State var scope: WordScope
    var onDone: () -> Void

    init(heard: String = "", scope: WordScope = .english, onDone: @escaping () -> Void) {
        _heard = State(initialValue: heard)
        _scope = State(initialValue: scope)
        self.onDone = onDone
    }

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
            Picker("For", selection: $scope) {
                ForEach(WordScope.allCases, id: \.self) { Text("\($0.label) dictations").tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Spacer()
                Button("Cancel") { onDone() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    PersonalDictionary.shared.add(heard: heard, written: written, scope: scope)
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(heard.trimmingCharacters(in: .whitespaces).isEmpty
                          || written.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .tint(Theme.accent)
    }
}
