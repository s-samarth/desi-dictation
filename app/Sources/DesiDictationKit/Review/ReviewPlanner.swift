import Foundation

/// How the user left the review panel.
public enum ReviewOutcome: Equatable, Sendable {
    /// Enter: paste this text into the app the user dictated into.
    case paste(String)
    /// Esc (or a new dictation started): put it on the clipboard instead.
    case copy(String)
}

/// One dictation waiting in the review panel. The panel (app target) shows
/// it, then calls `complete` exactly once.
public struct ReviewRequest {
    public let text: String
    public let unsure: [UnsureWord]
    /// Which word list a fix made here joins; nil for हिन्दी (no vocabulary).
    public let scope: WordScope?
    /// "When it fits" can be offered (English, checker installed).
    public let offerWhenItFits: Bool
    public let complete: @MainActor (ReviewOutcome) -> Void

    public init(text: String, unsure: [UnsureWord], scope: WordScope?, offerWhenItFits: Bool,
                complete: @escaping @MainActor (ReviewOutcome) -> Void) {
        self.text = text
        self.unsure = unsure
        self.scope = scope
        self.offerWhenItFits = offerWhenItFits
        self.complete = complete
    }
}

/// The pure decisions behind Review before paste (REVIEW_BEFORE_PASTE.md).
public enum ReviewPlanner {
    /// Unsure words of `text`: low confidence (if the engine gives it) plus
    /// words that sound like one of the user's words, each with alternatives.
    public static func unsure(in text: String, words: [ScoredWord], threshold: Float?,
                              sources: ReviewAlternatives.Sources) -> [UnsureWord] {
        var flagged = threshold.map { UnsureWords.find(in: text, scored: words, threshold: $0) } ?? []
        for i in flagged.indices {
            flagged[i].alternatives = ReviewAlternatives.candidates(for: flagged[i].word, sources: sources)
        }
        let taken = Set(flagged.map(\.range.lowerBound))
        flagged += ReviewAlternatives.soundAlikes(in: text, sources: sources)
            .filter { !taken.contains($0.range.lowerBound) }
        return flagged.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Whether this dictation opens the panel.
    public static func opens(_ mode: ReviewMode, unsure: [UnsureWord]) -> Bool {
        switch mode {
        case .off: return false
        case .unsure: return !unsure.isEmpty
        case .always: return true
        }
    }

    /// Word fixes the user made in the panel, offered to remember. A rewrite
    /// of more than a few words gives none (EditDiff's rule).
    public static func fixes(from original: String, to edited: String) -> [EditPair] {
        EditDiff.align(EditDiff.words(original), EditDiff.words(edited))
            .filter { !$0.heard.isEmpty && !$0.typed.isEmpty }
    }

    /// Saves the fixes the user chose to keep; nil mode = "Just this once".
    @MainActor
    public static func remember(_ choices: [(EditPair, EntryMode?)], scope: WordScope?,
                                dictionary: PersonalDictionary = .shared) {
        guard let scope else { return }
        for (pair, mode) in choices {
            guard let mode else { continue }
            dictionary.add(heard: pair.heard, written: pair.typed, scope: scope, mode: mode)
            VocabularyActivityLog.shared.add(.learned, "Learned in review: \"\(pair.heard)\" → \"\(pair.typed)\" (\(mode.label))")
        }
    }
}
