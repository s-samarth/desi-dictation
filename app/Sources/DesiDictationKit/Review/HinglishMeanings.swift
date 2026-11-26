import CryptoKit
import Foundation

/// One occurrence in Review. The checker sees a short, partly normalized
/// context. The only context persisted on confirmation is its fingerprint.
public struct MeaningContext: Equatable, Sendable {
    public let current: String
    public let other: String
    public let key: String?
    let before: [String]
    let after: [String]

    /// The small local checker consistently favored पर even for crossing a road.
    /// Let the user decide this pair until there is stronger evidence.
    public var supportsModelHint: Bool { current != "par" && current != "paar" }

    public func recommendation(using scorer: ContextScorer?) -> String? {
        guard supportsModelHint, let scorer, !before.isEmpty || !after.isEmpty else { return nil }
        func score(_ form: String) -> Double? {
            let words = before + [HinglishMeanings.script(form)] + after
            return scorer.logProbability(of: words.joined(separator: " "), after: ContextFit.prompt)
        }
        guard let keep = score(current), let swap = score(other),
            keep.isFinite, swap.isFinite, abs(swap - keep) > 1
        else { return nil }
        return swap > keep ? other : current
    }
}

public enum HinglishMeanings {
    private struct Form {
        let word: String
        let script: String
        let gloss: String
        let other: String
    }

    private static let forms: [String: Form] = {
        let pairs = [
            ("kam", "कम", "less", "kaam", "काम", "work"),
            ("kaha", "कहा", "said", "kahan", "कहाँ", "where"),
            ("din", "दिन", "day", "deen", "दीन", "faith"),
            ("par", "पर", "on / but", "paar", "पार", "across"),
            ("pal", "पल", "moment", "paal", "पाल", "raise / nurture"),
        ]
        var result: [String: Form] = [:]
        for (a, scriptA, glossA, b, scriptB, glossB) in pairs {
            result[a] = Form(word: a, script: scriptA, gloss: glossA, other: b)
            result[b] = Form(word: b, script: scriptB, gloss: glossB, other: a)
        }
        return result
    }()

    public static func label(_ word: String) -> String {
        guard let form = forms[word.lowercased()] else { return word }
        return "\(word) · \(form.gloss)"
    }

    public static func isMeaningChange(_ pair: EditPair) -> Bool {
        forms[pair.heard.lowercased()]?.other == pair.typed.lowercased()
    }

    static func script(_ word: String) -> String {
        forms[word.lowercased()]?.script ?? MeaningVocabulary.hindi[word.lowercased()] ?? word
    }

    /// Bound the model context to the current sentence. Use original UTF-16
    /// word ranges from the vocabulary tokenizer; email addresses are skipped.
    public static func questions(in text: String) -> [UnsureWord] {
        let tokens = WordTokens.tokens(in: text)
        let stops: Set<Character> = [".", "!", "?", "।", "\n"]
        return tokens.indices.compactMap { index in
            let token = tokens[index]
            guard let form = forms[token.word.lowercased()] else { return nil }
            var lo = index
            var hi = index
            while lo > max(0, index - 5),
                !text[tokens[lo - 1].range.upperBound..<tokens[lo].range.lowerBound].contains(where: stops.contains)
            {
                lo -= 1
            }
            while hi < min(tokens.count - 1, index + 5),
                !text[tokens[hi].range.upperBound..<tokens[hi + 1].range.lowerBound].contains(where: stops.contains)
            {
                hi += 1
            }
            let left = tokens[lo..<index].map(\.word)
            let right = tokens[(index + 1)..<(hi + 1)].map(\.word)
            // A mixed-language transcript may contain a whole English sentence.
            if ["par", "pal"].contains(form.word),
                !(left + right).contains(where: {
                    $0.lowercased() != "par" && EnglishContext.hindiWords.contains($0.lowercased())
                })
            {
                return nil
            }
            func neighbor(_ word: String) -> String {
                let lower = word.lowercased()
                return forms[lower].map { min($0.word, $0.other) } ?? lower
            }
            let context =
                left.suffix(2).map(neighbor) + ["|", min(form.word, form.other), "|"] + right.prefix(2).map(neighbor)
            let digest = SHA256.hash(data: Data(context.joined(separator: " ").utf8))
            let key = left.isEmpty && right.isEmpty ? nil : Data(digest).base64EncodedString()
            let meaning = MeaningContext(
                current: form.word, other: form.other, key: key,
                before: left.map(script), after: right.map(script))
            return UnsureWord(
                range: token.range, word: token.word, reason: .meaning, confidence: nil,
                alternatives: [HinglishSpellings.cased(form.other, like: token.word)], meaning: meaning)
        }
    }

    /// Keep cleanup actions and unrelated alternative spellings accessible.
    public static func merge(_ original: [UnsureWord], questions: [UnsureWord]) -> [UnsureWord] {
        guard !questions.isEmpty else { return original }
        var result = original
        for var question in questions {
            let overlaps = result.filter { $0.range.overlaps(question.range) }
            guard
                overlaps.allSatisfy({ $0.range == question.range && $0.reason != .correction && $0.reason != .filler })
            else { continue }
            for word in overlaps.flatMap(\.alternatives) where !question.alternatives.contains(word) {
                question.alternatives.append(word)
            }
            question.alternatives = Array(question.alternatives.prefix(ReviewAlternatives.limit))
            result.removeAll { $0.range == question.range }
            result.append(question)
        }
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
}
