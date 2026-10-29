import SwiftUI
import DesiDictationKit

/// Vocabulary page: the optional context checker behind "When it fits"
/// (CONTEXT_FIT.md). Hidden when this build has no llama runtime.
struct ContextCheckerSection: View {
    @ObservedObject var models = ModelManager.shared
    private let item = ModelManager.contextCheckerEntry

    var body: some View {
        if LlamaContextScorer.isAvailable {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
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
            } header: {
                Text("Context checker (English, Hindi)")
            } footer: {
                Text("Some words are right only sometimes: Claude, not cloud, but only when you mean Claude. With this small model on your Mac, a word set to When it fits is written only when the sentence is about it. It also underlines words that are odd in their sentence (purple) in Review before paste. It reads the sentence, never writes or sends it anywhere, and adds about 0.4 GB of memory while in use. Also on the Models page.")
                    .footnote()
            }
        }
    }
}
