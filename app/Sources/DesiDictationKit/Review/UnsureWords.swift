import Foundation

/// Review before paste (REVIEW_BEFORE_PASTE.md): when the panel opens.
public enum ReviewMode: String, CaseIterable, Codable, Sendable {
    case off, unsure, always

    public var label: String {
        switch self {
        case .off: return "Off"
        case .unsure: return "Only when unsure"
        case .always: return "Always"
        }
    }
}

/// A word of the final text the panel underlines, with what it could be instead.
public struct UnsureWord: Equatable, Sendable {
    /// Why it's underlined; the panel says so.
    public enum Reason: Sendable {
        /// The speech model wasn't sure what it heard.
        case unclear
        /// Heard clearly, but odd in its sentence (the context checker).
        case odd
        /// Sounds like one of the user's words.
        case soundsLike
        /// The vocabulary corrector would have changed it (a name on screen,
        /// a near-miss of a dictionary word); it's offered, never applied.
        case suggested
    }

    public let range: Range<String.Index>
    public let word: String
    public let reason: Reason
    /// The engine's confidence; nil when the word is flagged for another reason.
    public let confidence: Float?
    public var alternatives: [String]
}

/// Finds the words of the text about to be pasted that the speech model was
/// least sure of. The text has been through numbers, replacements and
/// vocabulary since the model wrote it, so model words are matched to final
/// words by an alignment; words our own rules wrote match nothing and are
/// never flagged (we chose them on purpose).
public enum UnsureWords {
    /// A word of `text` with its range, split at whitespace.
    struct Piece {
        let range: Range<String.Index>
        let key: String
    }

    static func pieces(of text: String) -> [Piece] {
        var out: [Piece] = []
        var start: String.Index?
        var i = text.startIndex
        while i <= text.endIndex {
            let atEnd = i == text.endIndex
            if !atEnd, !text[i].isWhitespace {
                if start == nil { start = i }
            } else if let s = start {
                let range = trimmed(s..<i, in: text)
                let key = comparable(String(text[range]))
                if !key.isEmpty { out.append(Piece(range: range, key: key)) }
                start = nil
            }
            if atEnd { break }
            i = text.index(after: i)
        }
        return out
    }

    /// Lowercase, punctuation off: "Symbolize?" and "symbolize" are one word.
    static func comparable(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }

    /// The range without leading/trailing punctuation, so only the word is underlined.
    static func trimmed(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        let strip = CharacterSet.punctuationCharacters.union(.symbols)
        var lower = range.lowerBound, upper = range.upperBound
        while lower < upper, text[lower].unicodeScalars.allSatisfy(strip.contains) {
            lower = text.index(after: lower)
        }
        while upper > lower, text[text.index(before: upper)].unicodeScalars.allSatisfy(strip.contains) {
            upper = text.index(before: upper)
        }
        return lower..<upper
    }

    /// Ranges of `text` whose model word scored below `threshold`.
    public static func find(in text: String, scored: [ScoredWord], threshold: Float) -> [UnsureWord] {
        let final = pieces(of: text)
        let model = scored.map { (key: comparable($0.text), confidence: $0.confidence) }
        var flagged: [UnsureWord] = []
        for (f, m) in matches(final.map(\.key), model.map(\.key)) {
            let confidence = model[m].confidence
            guard confidence.isFinite, confidence < threshold else { continue }
            let range = final[f].range
            flagged.append(UnsureWord(range: range, word: String(text[range]), reason: .unclear,
                                      confidence: confidence, alternatives: []))
        }
        return flagged
    }

    /// Index pairs (final, model) of equal words, by longest common subsequence.
    static func matches(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        guard !a.isEmpty, !b.isEmpty else { return [] }
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var pairs: [(Int, Int)] = []
        var i = 0, j = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] { pairs.append((i, j)); i += 1; j += 1 }
            else if lcs[i + 1][j] >= lcs[i][j + 1] { i += 1 }
            else { j += 1 }
        }
        return pairs
    }
}
