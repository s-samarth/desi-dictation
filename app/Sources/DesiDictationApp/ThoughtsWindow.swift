import SwiftUI
import DesiDictationKit

/// The thinking-session review window (STRUCTURE_THOUGHTS.md §3): structured
/// output on top, raw transcript always reachable below (zero-loss guarantee —
/// trust requires seeing what was heard), restyle in seconds, copy/paste out.
@MainActor
final class ThoughtsSession: ObservableObject {
    static let shared = ThoughtsSession()
    @Published var transcript = ""
    @Published var structured = ""
    @Published var style: OutputStyle = .notes
    @Published var working = false
    @Published var failed = false

    /// Entry point wired to DictationController.onThinkingTranscript.
    func begin(transcript: String) {
        self.transcript = transcript
        structured = ""
        failed = false
        AppWindows.shared.showThoughts()
        run()
    }

    func run() {
        let text = transcript, style = style
        working = true
        failed = false
        Task { @MainActor in
            defer { working = false }
            do {
                let result = try await LLMServices.shared.structurer
                    .structure(text, style: style)
                structured = result.structured
                HistoryStore.shared.add(text: result.structured,
                                        mode: SettingsStore.shared.languageMode,
                                        raw: text)
            } catch {
                // Rambling is never lost: the raw transcript is right below.
                failed = true
            }
        }
    }
}

struct ThoughtsView: View {
    @ObservedObject var session = ThoughtsSession.shared
    @State private var showRaw = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Style", selection: $session.style) {
                    ForEach(OutputStyle.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: session.style) { session.run() }
                if session.working { ProgressView().controlSize(.small) }
            }

            if session.failed {
                Label("Couldn't structure this — here's everything you said.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                TextEditor(text: .constant(session.transcript))
                    .font(.body).frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(LocalizedStringKey(session.structured.isEmpty && session.working
                                            ? "Organizing your thoughts…" : session.structured))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
                .frame(maxHeight: .infinity)
            }

            DisclosureGroup("Everything you said (raw transcript)", isExpanded: $showRaw) {
                ScrollView {
                    Text(session.transcript)
                        .textSelection(.enabled)
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
            }
            .font(.caption)

            HStack {
                Button("👍") { Feedback.compose() }
                Button("👎 Report…") { Feedback.compose(includeLastTranscript: true) }
                    .help("Opens a pre-filled email — you see everything before sending")
                Spacer()
                Button("Copy structured") {
                    TextInserter.insert(session.structured, copyOnly: true)
                }
                .disabled(session.structured.isEmpty)
                Button("Copy raw") {
                    TextInserter.insert(session.transcript, copyOnly: true)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 440)
    }
}
