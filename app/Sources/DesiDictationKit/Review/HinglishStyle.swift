import Foundation

/// The user's Hinglish spellings, as one dictation applies them
/// (HINGLISH_LEARNING.md): a spelling chosen per word, plus style habits.
/// A value, captured on main and used on the work queue.
public struct HinglishStyle: Equatable, Sendable {
    /// Group head (HinglishSpellings.head) → the user's spelling.
    public var preferred: [String: String]
    public var rules: Set<HinglishStyleRule>

    public init(preferred: [String: String] = [:], rules: Set<HinglishStyleRule> = []) {
        self.preferred = preferred
        self.rules = rules
    }

    public var isEmpty: Bool { preferred.isEmpty && rules.isEmpty }

    /// Every Hindi word written the user's way. A word with a chosen
    /// spelling gets it (any case: "Vaise" → "Waise"); another Hindi word
    /// gets the habits, but only in lowercase, because a capital may be a
    /// name ("Vikas" stays). English words are left alone, so "video" never
    /// becomes "wideo".
    public func apply(_ text: String, lexicon: WordLexicon = .system) -> String {
        guard !isEmpty else { return text }
        var out = ""
        var word = ""
        func flush() {
            out += word.isEmpty ? "" : rewrite(word, lexicon: lexicon)
            word = ""
        }
        for c in text {
            if c.isLetter { word.append(c) } else { flush(); out.append(c) }
        }
        flush()
        return out
    }

    /// One word, the user's way; unchanged when nothing applies.
    func rewrite(_ word: String, lexicon: WordLexicon) -> String {
        if let head = HinglishSpellings.head(of: word), let chosen = preferred[head] {
            return HinglishSpellings.cased(chosen, like: word)
        }
        guard !rules.isEmpty, word.allSatisfy(\.isLowercase),
              word.allSatisfy({ $0.isASCII }), !lexicon.isRealWord(word) else { return word }
        let styled = HinglishStyleRule.allCases.filter(rules.contains)
            .reduce(word) { $1.rewrite($0) ?? $0 }
        return styled
    }
}
