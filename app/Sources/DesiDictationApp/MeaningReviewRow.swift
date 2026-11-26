import DesiDictationKit
import SwiftUI

/// Only the selected occurrence gets scored. The keyboard and Paste button
/// stay responsive even while the model loads or a previous score finishes.
private actor MeaningRanker {
    static let shared = MeaningRanker()

    func predict(_ context: MeaningContext) -> String? {
        guard !Task.isCancelled, ContextChecker.isReady else { return nil }
        return ContextChecker.shared.meaningHint(for: context)
    }
}

struct MeaningReviewRow: View {
    @ObservedObject var model: ReviewModel
    let item: UnsureWord
    let context: MeaningContext

    @State private var recommendation: String?
    private var existingRule: DictionaryEntry? {
        PersonalDictionary.shared.entries.first {
            $0.scope == .hinglish && $0.mode == .always && $0.heard.lowercased() == context.other
                && $0.written.lowercased() == context.current
        }
    }

    var body: some View {
        // Key the row by occurrence so a late hint never labels the next word.
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Which meaning?").font(.caption).foregroundStyle(.secondary)
                choice(item.word, key: 0) { model.looksRight?() }
                if let other = item.alternatives.first {
                    choice(other, key: 1) { model.pick?(0) }
                }
                if let rule = existingRule {
                    Toggle(
                        "Suggest instead of Always",
                        isOn: Binding(
                            get: { model.contextualRuleIDs.contains(rule.id) },
                            set: {
                                if $0 {
                                    model.contextualRuleIDs.insert(rule.id)
                                } else {
                                    model.contextualRuleIDs.remove(rule.id)
                                }
                            })
                    )
                    .toggleStyle(.checkbox).font(.caption)
                    .help("After this review, keep both spellings available for future dictations.")
                }
            }
            if item.alternatives.count > 1 {
                HStack {
                    ForEach(Array(item.alternatives.dropFirst().enumerated()), id: \.offset) { i, word in
                        Button("\(i + 2)  \(word)") { model.pick?(i + 1) }
                    }
                }
            }
        }
        .buttonStyle(.bordered).controlSize(.small)
        .task(id: context) {
            recommendation = nil
            if let known = model.learningStore.meaningChoices.preferred(for: context) {
                recommendation = known
            } else {
                let result = await MeaningRanker.shared.predict(context)
                if !Task.isCancelled { recommendation = result }
            }
        }
    }

    private func choice(_ word: String, key: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Keycap(label: "\(key)")
                Text(HinglishMeanings.label(word))
                if recommendation == word.lowercased() {
                    Image(systemName: "sparkles").accessibilityLabel("Suggested here")
                }
            }
        }
        .help(recommendation == word.lowercased() ? "Suggested in this sentence" : HinglishMeanings.label(word))
    }
}
