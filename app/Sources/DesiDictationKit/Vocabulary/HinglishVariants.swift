import Foundation

/// Roman-Hinglish spelling variants of *one* word (AUTO_VOCABULARY.md §2d).
///
/// There is no standard Hinglish spelling, and each person is self-consistent
/// (P1_HINGLISH_ACCURACY.md §4). Automatic normalizers get ~1 word in 4
/// wrong, so this key is deliberately strict. It folds only vowel length and
/// doubled letters:
///   nahin/nahi stay different (a final nasal changes the word: hai ≠ hain)
///   kyaa → kya, theek → thik, accha → acha, bahoot → bahut
/// It never drops an h (bhai ≠ bai).
public enum HinglishVariants {
    public static func key(_ word: String) -> String {
        var s = word.lowercased().filter { $0.isLetter }
        for (long, short) in [("aa", "a"), ("ee", "i"), ("ii", "i"), ("oo", "u"), ("uu", "u")] {
            s = s.replacingOccurrences(of: long, with: short)
        }
        var out = ""
        for c in s where out.last != c { out.append(c) }
        return out
    }

    /// True when two spellings are the same word in different styles.
    public static func areVariants(_ a: String, _ b: String) -> Bool {
        a.lowercased() != b.lowercased() && !a.isEmpty && key(a) == key(b)
    }

    /// Looser test, used only to *propose* a pair the user then confirms: an
    /// edit like nahin → nahi, nhi → nahi or acha → achha is a style fix.
    /// The last letter must match, because Hindi inflects at the end
    /// (raha/rahi/rahe, tha/thi), and those edits are grammar, not style.
    public static func isStyleEdit(_ a: String, _ b: String) -> Bool {
        let x = styleNormal(a), y = styleNormal(b)
        guard a.lowercased() != b.lowercased(), !x.isEmpty, !y.isEmpty else { return false }
        if grammarPairs.contains([a.lowercased(), b.lowercased()].sorted().joined(separator: "/")) {
            return false
        }
        if x == y { return true }
        // Texting drops inner vowels: nhi ≈ nahi, bht ≈ bahut.
        return x.last == y.last && skeleton(x) == skeleton(y)
            && IndicPhonetics.spellingSimilarity(a, b) >= 0.5
    }

    /// Same letters, different word: number and person, not style.
    private static let grammarPairs: Set<String> = ["hai/hain", "hain/he", "hai/he", "ho/hu", "mai/main"]

    private static func styleNormal(_ word: String) -> String {
        var s = Array(key(word))
        // h after a consonant is spelling style here (acha/achha), not a sound.
        s = s.enumerated().filter { i, c in
            !(c == "h" && i > 0 && !"aeiou".contains(s[i - 1]))
        }.map { $0.1 }
        // A final nasal is style: nahin/nahi, kahan/kaha.
        if s.count > 2, s.last == "n", "aeiou".contains(s[s.count - 2]) { s.removeLast() }
        return String(s)
    }

    private static func skeleton(_ s: String) -> String {
        String(s.filter { !"aeiouh".contains($0) })
    }

    /// The field's spelling for `word`, if the user already writes it another
    /// way in the text they're editing. Needs ≥ 2 uses there, and the model's
    /// spelling must not appear there at all, so one stray "pita" can't turn
    /// every "peeta" into it.
    public static func preferredSpelling(for word: String, fieldCounts: [String: Int]) -> String? {
        let lower = word.lowercased()
        guard lower.count >= 2, fieldCounts[lower, default: 0] == 0 else { return nil }
        let wanted = key(lower)
        let candidates = fieldCounts.filter { $0.value >= 2 && $0.key != lower && key($0.key) == wanted }
        // Two different field spellings of the same word: no clear style.
        guard candidates.count == 1 else { return nil }
        return candidates.first?.key
    }

    /// Lowercased word counts of a field's text.
    public static func counts(of words: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for word in words { counts[word.lowercased(), default: 0] += 1 }
        return counts
    }
}
