import Foundation

/// "Only when it fits" (CONTEXT_FIT.md): the third answer to a proposal.
extension AutoVocabularyStore {
    /// English words only (small models are weak on Roman Hinglish), and
    /// only once the context checker is built in and downloaded.
    public static func canOfferWhenItFits(_ suggestion: VocabularySuggestion) -> Bool {
        suggestion.scope == .english && ContextChecker.isReady
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
    }
}
