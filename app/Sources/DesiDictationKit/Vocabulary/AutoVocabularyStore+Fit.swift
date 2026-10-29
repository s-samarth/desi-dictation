import Foundation

/// "Only when it fits" (CONTEXT_FIT.md): the third answer to a proposal.
extension AutoVocabularyStore {
    /// English words only (small models are weak on Roman Hinglish), and
    /// only once the context checker is built in and downloaded.
    public static func canOfferWhenItFits(_ suggestion: VocabularySuggestion) -> Bool {
        // Offered whether or not the checker is downloaded yet: the choice is
        // the user's to make now; without the checker only on-screen and
        // app-name cues decide, and the popup says how to get it.
        suggestion.scope == .english && LlamaContextScorer.isAvailable
    }

    /// The pair joins Your words as "When it fits": each sentence decides.
    public func acceptWhenItFits(_ suggestion: VocabularySuggestion,
                                 into dictionary: PersonalDictionary = .shared) {
        dictionary.add(heard: suggestion.heard, written: suggestion.written,
                       scope: suggestion.scope, mode: .whenItFits)
        remove(suggestion)
        ContextChecker.shared.warmUp()
        let line = "Learned: \"\(suggestion.heard)\" becomes \"\(suggestion.written)\" when the sentence fits"
        Task { @MainActor in VocabularyActivityLog.shared.add(.learned, line) }
        if !ContextChecker.isReady {
            liveAcknowledgement = "Added. Get the context checker on the Models page so each sentence can decide."
        }
    }
}
