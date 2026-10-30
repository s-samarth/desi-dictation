import Foundation

/// How the user left the review panel.
public enum ReviewOutcome: Equatable, Sendable {
    /// Enter: paste this text into the app the user dictated into.
    case paste(String)
    /// Esc (or a new dictation started): put it on the clipboard instead.
    case copy(String)
    /// ✕ / ⌘W: neither; it stays in History.
    case discard(String)
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
    /// Unsure words of `text`: low confidence (if the engine gives it), odd in
    /// context (if the checker scored it), and words that sound like one of
    /// the user's words, each with alternatives.
    public static func unsure(in text: String, words: [ScoredWord], threshold: Float?,
                              odd: [WordSurprise] = [], oddAbove: Double? = nil,
                              suggested: [WordFix] = [], cleanup: [UnsureWord] = [],
                              sources: ReviewAlternatives.Sources) -> [UnsureWord] {
        // The corrector's guesses first: their replacement is the first choice.
        var flagged = suggestions(suggested, in: text)
        var taken = Set(flagged.map(\.range.lowerBound))
        for word in threshold.map({ UnsureWords.find(in: text, scored: words, threshold: $0) }) ?? []
        where !taken.contains(word.range.lowerBound) {
            flagged.append(word)
            taken.insert(word.range.lowerBound)
        }
        if let oddAbove {
            let chosen = Set(sources.entries.map { $0.written.lowercased() })
            for word in odd where !taken.contains(word.range.lowerBound) {
                let piece = String(text[word.range])
                let everyday = OrdinaryWords.contains(UnsureWords.comparable(piece))
                guard word.total > oddAbove + (everyday ? ReviewStrictness.everydayExtra : 0) else { continue }
                // Numbers and dictionary words were written by our rules, on purpose.
                guard !piece.contains(where: \.isNumber), !chosen.contains(piece.lowercased()) else { continue }
                flagged.append(UnsureWord(range: word.range, word: piece, reason: .odd, confidence: nil, alternatives: []))
                taken.insert(word.range.lowerBound)
            }
        }
        for i in flagged.indices {
            let more = ReviewAlternatives.candidates(for: flagged[i].word, sources: sources)
            flagged[i].alternatives = Array((flagged[i].alternatives + more.filter { alt in
                !flagged[i].alternatives.contains { $0.lowercased() == alt.lowercased() }
            }).prefix(ReviewAlternatives.limit))
        }
        flagged += ReviewAlternatives.soundAlikes(in: text, sources: sources)
            .filter { !taken.contains($0.range.lowerBound) }
        // Corrections and fillers (CleanupReview) win where they overlap.
        flagged = cleanup + flagged.filter { f in !cleanup.contains { $0.range.overlaps(f.range) } }
        return flagged.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Where each guessed fix's word is in `text` (first unclaimed match,
    /// whole words only), with the guess as the first alternative.
    static func suggestions(_ fixes: [WordFix], in text: String) -> [UnsureWord] {
        var out: [UnsureWord] = []
        for fix in fixes {
            var from = text.startIndex
            while let range = text.range(of: fix.from, options: .caseInsensitive, range: from..<text.endIndex) {
                from = range.upperBound
                let before = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
                let after = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
                guard before, after, !out.contains(where: { $0.range.overlaps(range) }) else { continue }
                out.append(UnsureWord(range: range, word: String(text[range]), reason: .suggested,
                                      confidence: nil, alternatives: [fix.to]))
                break
            }
        }
        return out
    }

    /// What `strictness` lets through: Bindaas keeps only the checker's odd
    /// (purple) words; every other level shows them all.
    public static func shown(_ unsure: [UnsureWord], strictness: ReviewStrictness) -> [UnsureWord] {
        strictness.onlyOdd ? unsure.filter { $0.reason == .odd } : unsure
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
