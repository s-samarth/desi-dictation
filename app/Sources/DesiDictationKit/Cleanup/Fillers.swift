import Foundation

/// Filler words (FILLERS_AND_CORRECTIONS.md). Two kinds:
///
/// - **Sounds** (um, uh, hmm, er): never words, removed when "Remove um and
///   uh" is on (the default).
/// - **Sometimes fillers** (like, you know, I mean, basically…): real words
///   that are often filler. The context checker judges each one: if the rest
///   of the sentence reads more naturally without it, it's likely filler.
///   Review offers to remove it; "Remove fillers when sure" removes the
///   clear ones itself.
public enum Fillers {
    /// One filler sound: um, umm, uh, uhh, uhm, hmm, hm, mm, er, erm. Not
    /// "huh" or "uh-huh", which mean something.
    static let soundPattern = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\-'])(?:u+m+|u+h+m*|h+m+|m{2,}|e+r+m*)(?![\p{L}\-'])"#,
        options: [.caseInsensitive])

    /// Words that are filler only sometimes, longest first so "you know"
    /// wins over "know". English only (the checker reads English).
    public static let sometimes = ["you know", "i mean", "kind of", "sort of",
                                   "basically", "literally", "actually", "like", "yeah"]

    /// At a sentence start the checker can't tell (every opener looks odd
    /// there), so only these, followed by a comma, are offered.
    static let openers: Set<String> = ["you know", "i mean", "like", "basically"]

    /// Measured on evals/fillers/cases.tsv (FILLERS_AND_CORRECTIONS.md):
    /// how much more likely the rest of the sentence is without the word.
    public static let askAbove = -1.5
    public static let removeAbove = 2.0

    /// The text with every filler sound taken out.
    public static func removeSounds(_ text: String) -> String {
        var out = text
        let matches = soundPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: out) else { continue }
            out = TextSpans.removing(range, from: out)
        }
        return out
    }

    /// A sometimes-filler in `text`, with the checker's verdict.
    public struct Candidate: Sendable {
        public let range: Range<String.Index>
        public let phrase: String
        /// How much more likely the rest is without it (nats); nil at a sentence start.
        public let score: Double?
    }

    /// Sometimes-fillers worth asking about, judged by `scorer`.
    public static func candidates(in text: String, scorer: ContextScorer) -> [Candidate] {
        var out: [Candidate] = []
        for phrase in sometimes {
            for range in TextSpans.matches(of: phrase, in: text)
            where !out.contains(where: { $0.range.overlaps(range) }) {
                let (pre, rest) = split(text, around: range)
                if pre.isEmpty || ".!?".contains(pre.last!) {
                    let comma = range.upperBound < text.endIndex && text[range.upperBound] == ","
                    if comma, openers.contains(phrase) {
                        out.append(Candidate(range: range, phrase: String(text[range]), score: nil))
                    }
                    continue
                }
                guard !rest.isEmpty,
                      let without = scorer.logProbability(of: rest, after: ContextFit.prompt + pre),
                      let with = scorer.logProbability(of: rest, after: ContextFit.prompt + pre + " " + text[range])
                else { continue }
                let score = without - with
                if score > askAbove { out.append(Candidate(range: range, phrase: String(text[range]), score: score)) }
            }
        }
        return out.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The text with the fillers the checker is sure of taken out.
    public static func removeSure(_ text: String, scorer: ContextScorer) -> (text: String, removed: [String]) {
        let sure = candidates(in: text, scorer: scorer).filter { ($0.score ?? -.infinity) > removeAbove }
        var out = text
        for candidate in sure.reversed() {
            guard let range = Range(NSRange(candidate.range, in: text), in: out) else { continue }
            out = TextSpans.removing(range, from: out)
        }
        return (out, sure.map(\.phrase))
    }

    /// Words before the filler (up to the sentence's start, at most 12) and
    /// the words after it (at most 8), without the commas around it.
    static func split(_ text: String, around range: Range<String.Index>) -> (String, String) {
        let before = text[..<range.lowerBound].trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        let after = text[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        let pre = before.split(separator: " ").suffix(12).joined(separator: " ")
        let rest = after.split(separator: " ").prefix(8).joined(separator: " ")
        return (pre, rest.isEmpty ? "" : " " + rest)
    }
}
