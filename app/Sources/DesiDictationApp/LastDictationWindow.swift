import SwiftUI
import DesiDictationKit

/// Translate on Demand, Flow A (TRANSLATION.md §3): open the last dictation
/// (or any history entry), FIX IT FIRST — edit-then-translate is first-class,
/// garbage in garbage out — then translate. Result is editable, copyable,
/// pasteable, and attached to the history entry.
struct LastDictationView: View {
    @ObservedObject var history = HistoryStore.shared
    @ObservedObject var llm = LLMServices.shared
    @State private var entryID: UUID?
    @State private var source = ""
    @State private var translation = ""
    @State private var translating = false
    @State private var notice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fix any mishears first — the translation is built on what you meant.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $source)
                .font(.body)
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))

            HStack {
                Picker("From", selection: Binding(
                    get: { entryID }, set: { load(id: $0) })) {
                    ForEach(history.entries.prefix(20)) { entry in
                        Text(String(entry.text.prefix(40))).tag(Optional(entry.id))
                    }
                }
                .frame(maxWidth: 260)
                Spacer()
                if translating {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Translate → English") { translate(to: .english) }
                    Button("Translate → हिन्दी") { translate(to: .hindi) }
                }
            }

            if let guidance = llm.statusGuidance {
                Text(guidance).font(.caption).foregroundStyle(.orange)
            }
            if let notice {
                Text(notice).font(.caption).foregroundStyle(.orange)
            }

            if !translation.isEmpty {
                Divider()
                Text("Translation — edit freely:").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $translation)
                    .font(.body)
                    .frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                HStack {
                    Spacer()
                    Button("Copy") {
                        TextInserter.insert(translation, copyOnly: true)
                        notice = "On your clipboard — ⌘V anywhere."
                    }
                    Button("Copy & close") {
                        TextInserter.insert(translation, copyOnly: true)
                        NSApp.keyWindow?.close()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 340)
        .onAppear {
            load(id: history.entries.first?.id)
            Task { await llm.refreshStatus() }
        }
    }

    private func load(id: UUID?) {
        entryID = id
        guard let entry = history.entries.first(where: { $0.id == id }) else { return }
        source = entry.text
        translation = entry.translation ?? ""
        notice = nil
    }

    private func translate(to language: TargetLanguage) {
        let text = source
        translating = true
        notice = nil
        Task { @MainActor in
            defer { translating = false }
            do {
                let result = try await llm.translator.translate(text, to: language)
                translation = result
                if let id = entryID {
                    HistoryStore.shared.attachTranslation(result, to: id)
                }
            } catch {
                // Original words are never lost — they're right there, untouched.
                notice = error.localizedDescription
            }
        }
    }
}
