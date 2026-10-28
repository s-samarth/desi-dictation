import Foundation

/// Review before paste (REVIEW_BEFORE_PASTE.md): the last stop before the
/// paste. The kit decides whether to open and what to underline; the app's
/// panel shows it and calls back once, and `commit` does the rest.
extension DictationController {
    /// True when the panel took this dictation.
    func review(text: String, mode: LanguageMode, copyOnly: Bool, raw: String?) -> Bool {
        let words = reviewWords
        reviewWords = []
        guard let onReview, SettingsStore.shared.reviewMode != .off else { return false }
        let entries = PersonalDictionary.shared.entries(for: mode)
        let judged = mode == .english && ContextChecker.isReady
            ? entries.filter { $0.mode == .whenItFits }.map(\.heard) : []
        let sources = ReviewAlternatives.Sources(
            entries: entries, screenTerms: VocabularySession.shared.currentScreenTerms, judged: Set(judged))
        let threshold = resolvedModelPath(for: mode).flatMap { UnsureWords.threshold(forModel: $0) }
        let unsure = ReviewPlanner.unsure(in: text, words: words, threshold: threshold, sources: sources)
        guard ReviewPlanner.opens(SettingsStore.shared.reviewMode, unsure: unsure) else { return false }
        controllerLog.info("review: \(unsure.count, privacy: .public) unsure words")
        let scope = WordScope(mode: mode)
        let present: ([UnsureWord]) -> Void = { [weak self] unsure in
            onReview(ReviewRequest(
                text: text, unsure: unsure, scope: scope,
                offerWhenItFits: scope == .english && ContextChecker.isReady) { outcome in
                    switch outcome {
                    case .paste(let final): self?.commit(text: final, mode: mode, copyOnly: copyOnly, raw: raw)
                    case .copy(let final): self?.commit(text: final, mode: mode, copyOnly: true, raw: raw)
                    }
                })
        }
        // English with the context checker: best-fitting alternative first.
        guard mode == .english, ContextChecker.isReady,
              unsure.contains(where: { $0.alternatives.count > 1 }) else {
            present(unsure)
            return true
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var ranked = unsure
            if let scorer = ContextChecker.shared.loaded() {
                for i in ranked.indices where ranked[i].alternatives.count > 1 {
                    ranked[i].alternatives = ReviewAlternatives.ranked(ranked[i], in: text, scorer: scorer)
                }
            }
            DispatchQueue.main.async { present(ranked) }
        }
        return true
    }
}
