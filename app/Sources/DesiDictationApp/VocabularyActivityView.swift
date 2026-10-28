import SwiftUI
import DesiDictationKit

/// "Is it working?" answered on the page: the last few things smart
/// vocabulary saw, suggested, learned or couldn't do, with why.
struct VocabularyActivitySection: View {
    @ObservedObject var log = VocabularyActivityLog.shared
    @ObservedObject var store = AutoVocabularyStore.shared

    var body: some View {
        Section {
            if log.entries.isEmpty {
                Text(emptyText).foregroundStyle(.secondary)
            }
            ForEach(log.entries) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: symbol(entry.kind)).foregroundStyle(color(entry.kind))
                    Text(entry.message).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(entry.date, style: .time).font(.caption).foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("What it's been doing")
        } footer: {
            Text("Since the app started. Kept in memory only, never saved.").footnote()
        }
    }

    private var emptyText: String {
        store.learnFromEdits
            ? "Nothing yet. Dictate something, then fix a misheard word in the text within 30 seconds."
            : "Turn on “Suggest words from my corrections” below, then dictate and fix a word."
    }

    private func symbol(_ kind: VocabularyActivity.Kind) -> String {
        switch kind {
        case .info: return "eye"
        case .suggested: return "questionmark.bubble.fill"
        case .learned: return "checkmark.seal.fill"
        case .fixed: return "wand.and.stars"
        case .problem: return "exclamationmark.triangle.fill"
        }
    }

    private func color(_ kind: VocabularyActivity.Kind) -> Color {
        switch kind {
        case .info: return Theme.neutral
        case .suggested: return Theme.accent
        case .learned, .fixed: return Theme.hindi
        case .problem: return .orange
        }
    }
}
