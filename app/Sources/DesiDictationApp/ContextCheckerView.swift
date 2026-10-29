import SwiftUI
import DesiDictationKit

/// The optional context checker (CONTEXT_FIT.md): one row that says whether
/// it's installed and what it adds, with a Get button. Shown wherever a
/// feature needs it, so nothing silently depends on a download.
struct ContextCheckerRow: View {
    @ObservedObject var models = ModelManager.shared
    /// What this page's feature gets from it, e.g. "purple underlines".
    let adds: String
    private let item = ModelManager.contextCheckerEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Context checker")
                Text(models.isInstalled(item)
                     ? "Installed. Adds \(adds)."
                     : "Optional, \(item.approxMB) MB, stays on your Mac. Adds \(adds).")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = models.downloadErrors[item.id] {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if models.isInstalled(item) {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            } else if let progress = models.downloadProgress[item.id] {
                ProgressView(value: progress).frame(width: 90)
            } else {
                Button("Get · \(item.approxMB) MB") {
                    Task {
                        await models.download(item)
                        ContextChecker.shared.reset()
                    }
                }
            }
        }
    }
}

/// Vocabulary page: what the context checker does for your words.
struct ContextCheckerSection: View {
    var body: some View {
        if LlamaContextScorer.isAvailable {
            Section {
                ContextCheckerRow(adds: "\"When it fits\" words and purple underlines in Review")
            } header: {
                Text("Context checker (optional)")
            } footer: {
                Text("Some words are right only sometimes: Claude, not cloud, but only when you mean Claude. Set such a word to When it fits and this small model reads the sentence to decide. Without it, only names on screen and the app you're in decide. It also underlines words that are odd in their sentence (purple) in Review before paste. It reads, never writes or sends anything, and uses about 0.4 GB of memory while in use. Everything works without it.")
                    .footnote()
            }
        }
    }
}
