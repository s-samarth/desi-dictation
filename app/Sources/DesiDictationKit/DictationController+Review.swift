import Foundation

/// Review before paste (REVIEW_BEFORE_PASTE.md): the last stop before the
/// paste. The kit decides whether to open and what to underline; the app's
/// panel shows it and calls back once, and `commit` does the rest.
extension DictationController {
    /// True when review took this dictation: the panel will show it, or the
    /// context checker is scoring it first and will commit it if all is well.
    func review(text: String, mode: LanguageMode, copyOnly: Bool, raw: String?) -> Bool {
        let words = reviewWords
        reviewWords = []
        let suggested = VocabularySession.shared.takeSuggestions()
        let settings = SettingsStore.shared
        guard let onReview, settings.reviewMode != .off else { return false }
        let entries = PersonalDictionary.shared.entries(for: mode)
        let judged = mode == .english && ContextChecker.isReady
            ? entries.filter { $0.mode == .whenItFits }.map(\.heard) : []
        let sources = ReviewAlternatives.Sources(
            entries: entries, screenTerms: VocabularySession.shared.currentScreenTerms, judged: Set(judged))
        let strictness = settings.reviewStrictness
        let modelPath = resolvedModelPath(for: mode) ?? ""
        let threshold = strictness.confidenceThreshold(forModel: modelPath)
        let oddAbove = ContextChecker.isReady ? strictness.surpriseThreshold(forModel: modelPath, mode: mode) : nil
        let reviewMode = settings.reviewMode
        let scope = WordScope(mode: mode)
        let present: ([UnsureWord]) -> Void = { [weak self] unsure in
            controllerLog.info("review: \(unsure.count, privacy: .public) unsure words")
            onReview(ReviewRequest(
                text: text, unsure: unsure, scope: scope,
                offerWhenItFits: scope == .english && ContextChecker.isReady) { outcome in
                    switch outcome {
                    case .paste(let final): self?.commit(text: final, mode: mode, copyOnly: copyOnly, raw: raw)
                    case .copy(let final): self?.commit(text: final, mode: mode, copyOnly: true, raw: raw)
                    }
                })
        }
        let ranks = mode == .english && ContextChecker.isReady
        guard oddAbove != nil || ranks else {
            let unsure = ReviewPlanner.unsure(in: text, words: words, threshold: threshold,
                                              suggested: suggested, sources: sources)
            guard ReviewPlanner.opens(reviewMode, unsure: unsure) else { return false }
            present(unsure)
            return true
        }
        // The checker reads the sentence off the main thread (~50–150 ms):
        // which words are odd in context, and the best-fitting alternative first.
        DispatchQueue.global(qos: .userInitiated).async {
            let scorer = ContextChecker.shared.loaded()
            let odd = oddAbove == nil ? [] : scorer.flatMap { SentenceSurprise.words(in: text, scorer: $0) } ?? []
            var unsure = ReviewPlanner.unsure(in: text, words: words, threshold: threshold,
                                              odd: odd, oddAbove: oddAbove, suggested: suggested, sources: sources)
            if ranks, let scorer {
                for i in unsure.indices where unsure[i].alternatives.count > 1 {
                    unsure[i].alternatives = ReviewAlternatives.ranked(unsure[i], in: text, scorer: scorer)
                }
            }
            DispatchQueue.main.async { [weak self] in
                if ReviewPlanner.opens(reviewMode, unsure: unsure) {
                    present(unsure)
                } else {
                    self?.commit(text: text, mode: mode, copyOnly: copyOnly, raw: raw)
                }
            }
        }
        return true
    }
}
