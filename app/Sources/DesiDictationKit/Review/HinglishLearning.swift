import Foundation

/// How Review before paste treats Hinglish (HINGLISH_LEARNING.md).
public enum HinglishReview: String, CaseIterable, Sendable {
    /// Opens on every Hinglish dictation and asks which spelling is yours.
    case learning
    /// Uses the same underline level as English and हिन्दी.
    case standard

    public var label: String {
        switch self {
        case .learning: return "Learning"
        case .standard: return "Same as above"
        }
    }
}

/// Learning mode for Hinglish: the user's chosen spellings, the style habits
/// they agreed to, and the streak that says learning is done. Everything is
/// local, in UserDefaults.
@MainActor
public final class HinglishLearning: ObservableObject {
    public static let shared = HinglishLearning()
    /// Clean Learning dictations in a row before the panel suggests stopping.
    public static let graduateAfter = 10
    /// Fixes showing one habit before the panel asks about it.
    public static let habitAfter = 2

    @Published public var review: HinglishReview { didSet { d.set(review.rawValue, forKey: Key.review) } }
    @Published public private(set) var style: HinglishStyle
    @Published public private(set) var cleanStreak: Int
    private var evidence: [String: Int]
    private var declined: Set<String>
    private let d: UserDefaults

    private enum Key {
        static let review = "hinglish.review", preferred = "hinglish.preferred", rules = "hinglish.rules"
        static let evidence = "hinglish.evidence", declined = "hinglish.declined", streak = "hinglish.streak"
    }

    public init(defaults: UserDefaults = .standard) {
        d = defaults
        review = HinglishReview(rawValue: d.string(forKey: Key.review) ?? "") ?? .standard
        let rules = (d.stringArray(forKey: Key.rules) ?? []).compactMap(HinglishStyleRule.init(rawValue:))
        style = HinglishStyle(preferred: d.dictionary(forKey: Key.preferred) as? [String: String] ?? [:],
                              rules: Set(rules))
        evidence = d.dictionary(forKey: Key.evidence) as? [String: Int] ?? [:]
        declined = Set(d.stringArray(forKey: Key.declined) ?? [])
        cleanStreak = d.integer(forKey: Key.streak)
    }

    public var isLearning: Bool { review == .learning }
    public var isDone: Bool { isLearning && cleanStreak >= Self.graduateAfter }

    /// Spelling-list words whose spelling the user hasn't chosen yet, each
    /// with the other spellings to pick from. Pure, for the work queue.
    nonisolated public static func spellingWords(in text: String, style: HinglishStyle) -> [UnsureWord] {
        var out: [UnsureWord] = []
        var start: String.Index?
        for i in Array(text.indices) + [text.endIndex] {
            let letter = i < text.endIndex && text[i].isLetter
            if letter, start == nil { start = i }
            guard !letter, let s = start else { continue }
            start = nil
            let word = String(text[s..<i])
            guard let group = HinglishSpellings.group(of: word), let head = group.first,
                  style.preferred[head] == nil else { continue }
            let others = group.filter { $0 != word.lowercased() }.map { HinglishSpellings.cased($0, like: word) }
            out.append(UnsureWord(range: s..<i, word: word, reason: .spelling, confidence: nil,
                                  alternatives: Array(others.prefix(ReviewAlternatives.limit))))
        }
        return out
    }

    /// Habits the user's fixes in this panel show often enough to ask about.
    public func habits(in kept: [EditPair]) -> [HinglishStyleRule] {
        var counts = evidence
        for pair in kept { for rule in HinglishStyleRule.shown(by: pair) { counts[rule.rawValue, default: 0] += 1 } }
        return HinglishStyleRule.allCases.filter {
            counts[$0.rawValue, default: 0] >= Self.habitAfter
                && !style.rules.contains($0) && !declined.contains($0.rawValue)
        }
    }

    /// The end of a Hinglish review. `changes` are all word swaps made in
    /// the panel, `kept` the ones the user chose to always keep.
    public func finish(underlined: [UnsureWord], changes: [EditPair], kept: [EditPair],
                       adopt: [HinglishStyleRule], decline: [HinglishStyleRule]) {
        var next = style
        for pair in kept where HinglishSpellings.sameWord(pair.heard, pair.typed) {
            if let head = HinglishSpellings.head(of: pair.heard) { next.preferred[head] = pair.typed.lowercased() }
        }
        // A spelling left as it was, when asked, is the user's spelling.
        let changed = Set(changes.map { $0.heard.lowercased() })
        for word in underlined where word.reason == .spelling && !changed.contains(word.word.lowercased()) {
            if let head = HinglishSpellings.head(of: word.word) { next.preferred[head] = word.word.lowercased() }
        }
        for pair in kept { for rule in HinglishStyleRule.shown(by: pair) { evidence[rule.rawValue, default: 0] += 1 } }
        for rule in adopt {
            next.rules.insert(rule)
            if let opposite = rule.opposite { next.rules.remove(opposite) }
        }
        declined.formUnion(decline.map(\.rawValue))
        style = next
        if isLearning { cleanStreak = changes.isEmpty ? cleanStreak + 1 : 0 }
        save()
    }

    /// "Keep learning": ask again after another full streak.
    public func keepLearning() { cleanStreak = 0; save() }

    /// "Stop learning": Hinglish goes back to the same level as English.
    /// Chosen spellings and habits stay.
    public func stopLearning() { review = .standard; cleanStreak = 0; save() }

    /// Settings → Forget my Hinglish spellings.
    public func forgetAll() {
        style = HinglishStyle()
        evidence = [:]; declined = []; cleanStreak = 0
        save()
    }

    private func save() {
        d.set(style.preferred, forKey: Key.preferred)
        d.set(style.rules.map(\.rawValue).sorted(), forKey: Key.rules)
        d.set(evidence, forKey: Key.evidence)
        d.set(declined.sorted(), forKey: Key.declined)
        d.set(cleanStreak, forKey: Key.streak)
    }
}
