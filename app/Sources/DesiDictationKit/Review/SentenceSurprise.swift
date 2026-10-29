import Foundation

/// How unexpected each word is in its sentence, read off the context
/// checker's language model (REVIEW_BEFORE_PASTE.md "Odd in context"). It
/// catches the speech model's confident mistakes ("watch one PC Luffy") and
/// unusual names. It only marks words; it never changes them.
public struct WordSurprise: Equatable, Sendable {
    public let range: Range<String.Index>
    /// Sum over the word's tokens of −log p, in nats: higher is odder.
    public let total: Double
    /// The single oddest token of the word.
    public let peak: Double

    public init(range: Range<String.Index>, total: Double, peak: Double) {
        self.range = range
        self.total = total
        self.peak = peak
    }
}

public enum SentenceSurprise {
    /// Texts longer than this are scored a sentence group at a time, so each
    /// call fits the checker's 512-token context.
    static let chunkBytes = 1200

    /// Surprise of each range of `text` (ranges must be in order and not
    /// overlap). A range no token reaches gets 0. nil if scoring failed.
    public static func scores(for ranges: [Range<String.Index>], in text: String,
                              scorer: ContextScorer) -> [WordSurprise]? {
        var tokens: [(start: Int, end: Int, surprise: Double)] = []
        for chunk in chunks(of: text) {
            let base = text.utf8.distance(from: text.startIndex, to: chunk.lowerBound)
            guard let scored = scorer.tokenLogProbabilities(of: String(text[chunk]), after: ContextFit.prompt)
            else { return nil }
            var start = 0
            for (end, logprob) in scored {
                tokens.append((base + start, base + end, -logprob))
                start = end
            }
        }
        return ranges.map { range in
            let lo = text.utf8.distance(from: text.startIndex, to: range.lowerBound)
            let hi = text.utf8.distance(from: text.startIndex, to: range.upperBound)
            // A token belongs to a word it overlaps (" Luffy" starts at the space).
            let mine = tokens.filter { $0.start < hi && $0.end > lo }.map(\.surprise)
            return WordSurprise(range: range, total: mine.reduce(0, +), peak: mine.max() ?? 0)
        }
    }

    /// Surprise of every word of `text`, split as the review panel splits it.
    public static func words(in text: String, scorer: ContextScorer) -> [WordSurprise]? {
        scores(for: UnsureWords.pieces(of: text).map(\.range), in: text, scorer: scorer)
    }

    /// Whole sentences, grouped up to `chunkBytes`; one long sentence is its own chunk.
    public static func chunks(of text: String) -> [Range<String.Index>] {
        guard text.utf8.count > chunkBytes else { return [text.startIndex..<text.endIndex] }
        var out: [Range<String.Index>] = []
        var start = text.startIndex
        var last = text.startIndex
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { _, range, _, _ in
            if text.utf8.distance(from: start, to: range.upperBound) > chunkBytes, last > start {
                out.append(start..<last)
                start = last
            }
            last = range.upperBound
        }
        if start < text.endIndex { out.append(start..<text.endIndex) }
        return out
    }
}
