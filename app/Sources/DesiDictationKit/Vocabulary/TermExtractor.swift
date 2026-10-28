import Foundation

/// Picks the likely names and terms out of on-screen text (§2b): the words a
/// model would get wrong. "Rohan said the Figma file is ready" → Rohan, Figma.
public enum TermExtractor {
    /// Enough for a long chat thread; the corrector only compares against the
    /// few that sound like a transcript word, so a longer list costs little.
    public static let maxTerms = 150

    public static func terms(from texts: [String], limit: Int = maxTerms) -> [String] {
        var counts: [String: (word: String, count: Int, first: Int)] = [:]
        var order = 0
        for text in texts {
            let tokens = WordTokens.tokens(in: text)
            let label = isNameLabel(tokens)
            for token in tokens {
                let word = token.word
                guard word.count >= 3, word.allSatisfy({ $0.isASCII }) else { continue }
                let lower = word.lowercased()
                guard !CommonWords.contains(lower) else { continue }
                let capitalized = word.first?.isUppercase == true
                let camel = word.dropFirst().contains { $0.isUppercase }   // iPhone, McKinsey
                let startsSentence = isSentenceStart(text, before: token.range.lowerBound)
                // A capital mid-sentence marks a name; at a sentence start it
                // marks nothing ("Milenge kal" is Hinglish, not a name), unless
                // the whole text is a name label: a chat's sender, a title.
                // Lowercase words never count, since that would bias Hinglish
                // spelling toward whatever other people typed.
                let keep = camel || (capitalized && (!startsSentence || label))
                guard keep else { continue }
                if let existing = counts[lower] {
                    counts[lower] = (existing.word, existing.count + 1, existing.first)
                } else {
                    counts[lower] = (word, 1, order)
                    order += 1
                }
            }
        }
        return counts.values
            .sorted { ($0.count, -$0.first) > ($1.count, -$1.first) }
            .prefix(limit)
            .map { $0.word }
    }

    /// "Rohan Mehta", "Priya (Design)": 1–4 words, every one capitalized.
    private static func isNameLabel(_ tokens: [WordToken]) -> Bool {
        (1...4).contains(tokens.count) && tokens.allSatisfy { $0.word.first?.isUppercase == true }
    }

    private static func isSentenceStart(_ text: String, before index: String.Index) -> Bool {
        var i = index
        while i > text.startIndex {
            i = text.index(before: i)
            let c = text[i]
            if c == " " || c == "\t" || c == "\"" || c == "(" { continue }
            return ".!?\n\r:•-".contains(c)
        }
        return true
    }
}
