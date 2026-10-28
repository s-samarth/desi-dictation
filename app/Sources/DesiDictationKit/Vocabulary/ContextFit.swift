import Foundation

/// How a dictionary pair is applied. "Always" is the exact-pair rule;
/// "when it fits" asks the sentence first (cloud → Claude only when the
/// sentence is about Claude). VOCABULARY_NEXT.md §1, CONTEXT_FIT.md.
public enum EntryMode: String, Codable, CaseIterable, Sendable {
    case always, whenItFits

    public var label: String {
        switch self {
        case .always: return "Always"
        case .whenItFits: return "When it fits"
        }
    }
}

/// Scores text with a small local language model. It never writes text: it
/// only says how likely a sentence is, so it can't invent words.
public protocol ContextScorer: AnyObject {
    /// Natural-log probability of `text` following `prefix`; nil on failure.
    func logProbability(of text: String, after prefix: String) -> Double?
}

/// Signals besides the model: the written form is visible on screen, or the
/// dictation is going into an app of that name ("Claude").
public struct FitCues: Sendable {
    public var screenTerms: Set<String>
    public var appName: String?

    public init(screenTerms: [String] = [], appName: String? = nil) {
        self.screenTerms = Set(screenTerms.map { $0.lowercased() })
        self.appName = appName
    }
}

/// One "keep or swap?" call, for the activity list and `desi-cli fit`.
public struct FitDecision: Equatable, Sendable {
    public let heard: String
    public let written: String
    /// log P(swapped) − log P(kept), nats; nil when no model scored it.
    public let modelDelta: Double?
    public let cueBonus: Double
    public let swapped: Bool
}

public enum ContextFit {
    /// A swap must beat keeping the word by this many nats (model + cues).
    /// Starting value; tune with `desi-cli fit` on the Mac (handoff doc).
    public static let margin = 0.0
    /// Nats added when the written form is on screen / is the app's name.
    public static let screenBonus = 3.0
    public static let appBonus = 3.0
    /// Words of context on each side of the word being judged.
    public static let windowWords = 12
    /// The prompt stays compact: at most this many of the user's words.
    public static let maxPrefixTerms = 10

    /// The model's whole prompt: the user's own words, then the sentence.
    /// "Words I use: Claude, Kavya, Tazapay.\n" — or a neutral header.
    public static func prefix(terms: [String]) -> String {
        var seen = Set<String>()
        let unique = terms.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard !unique.isEmpty else { return "Message:\n" }
        return "Words I use: " + unique.prefix(maxPrefixTerms).joined(separator: ", ") + ".\n"
    }

    /// Applies the "when it fits" pairs whose swap wins. Without a model,
    /// only a cue (on screen, app name) can swap; with neither, nothing does.
    public static func apply(_ text: String, entries: [DictionaryEntry], cues: FitCues,
                             scorer: ContextScorer?, prefix: String,
                             rejected: Set<String> = [])
    -> (text: String, fixes: [WordFix], decisions: [FitDecision]) {
        var result = text
        var fixes: [WordFix] = []
        var decisions: [FitDecision] = []
        for entry in entries where entry.mode == .whenItFits {
            for range in matches(of: entry.heard, in: result).reversed() {
                let heard = String(result[range])
                let written = PersonalDictionary.casedLike(heard, replacement: entry.written)
                guard heard != written,
                      !rejected.contains(WordFix.pairKey(from: heard, to: written)) else { continue }
                let bonus = cueBonus(for: entry.written, cues: cues)
                var delta: Double?
                if let scorer {
                    let (before, after) = window(around: range, in: result)
                    if let kept = scorer.logProbability(of: before + heard + after, after: prefix),
                       let swapped = scorer.logProbability(of: before + written + after, after: prefix) {
                        delta = swapped - kept
                    }
                }
                let swap = delta.map { $0 + bonus > margin } ?? (bonus > 0)
                decisions.append(FitDecision(heard: heard, written: written, modelDelta: delta,
                                             cueBonus: bonus, swapped: swap))
                guard swap else { continue }
                result.replaceSubrange(range, with: written)
                fixes.append(WordFix(from: heard, to: written, source: .context))
            }
        }
        return (result, Array(fixes.reversed()), decisions)
    }

    static func cueBonus(for written: String, cues: FitCues) -> Double {
        var bonus = 0.0
        if cues.screenTerms.contains(written.lowercased()) { bonus += screenBonus }
        if let app = cues.appName, app.range(of: written, options: .caseInsensitive) != nil {
            bonus += appBonus
        }
        return bonus
    }

    /// Whole-word, case-insensitive matches ("cloud" never matches "clouds").
    static func matches(of word: String, in text: String) -> [Range<String.Index>] {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        guard !word.isEmpty, let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text) }
    }

    /// Up to `windowWords` words either side, so the model judges the
    /// sentence the word is in, not the whole dictation.
    static func window(around range: Range<String.Index>, in text: String) -> (String, String) {
        var start = range.lowerBound
        var words = 0
        while start > text.startIndex {
            let previous = text.index(before: start)
            if text[previous].isWhitespace, start < range.lowerBound, !text[start].isWhitespace {
                words += 1
                if words == windowWords { break }
            }
            start = previous
        }
        var end = range.upperBound
        words = 0
        while end < text.endIndex {
            if text[end].isWhitespace, end > range.upperBound, !text[text.index(before: end)].isWhitespace {
                words += 1
                if words == windowWords { break }
            }
            end = text.index(after: end)
        }
        return (String(text[start..<range.lowerBound]), String(text[range.upperBound..<end]))
    }
}
