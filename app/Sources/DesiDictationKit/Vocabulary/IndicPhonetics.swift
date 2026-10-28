import Foundation

/// Sound-alike matching tuned for Indian English (AUTO_VOCABULARY.md §3.2).
///
/// The standard recipe for correcting names after ASR is: a phonetic key to
/// find candidates, edit distance to rank them, a threshold to accept
/// (Double Metaphone + Levenshtein in most papers). Double Metaphone is
/// ~1k lines of Anglo spelling rules and treats v/w, t/th and d/dh as
/// different sounds — exactly the merges an Indian accent produces. So this
/// is a small key of our own plus a weighted distance where those merges are
/// cheap.
public enum IndicPhonetics {
    /// "Saraswath" and "Saraswat" → the same key; "Kavya" and "Cavia" too.
    /// Vowels fold to one class because vowel quality is what accents (and
    /// Hinglish spelling) vary most.
    public static func key(_ word: String) -> String {
        var s = Array(word.lowercased().filter { $0.isASCII && $0.isLetter })
        guard !s.isEmpty else { return "" }
        s = replaceDigraphs(s)
        var out: [Character] = []
        for (i, c) in s.enumerated() {
            var mapped = c
            switch c {
            case "w": mapped = "v"
            case "z": mapped = "j"
            case "q": mapped = "k"
            case "c":
                let next = i + 1 < s.count ? s[i + 1] : " "
                mapped = "eiy".contains(next) ? "s" : "k"
            case "C": mapped = "c"          // from "ch"
            case "y": mapped = i == 0 ? "y" : "a"
            case "a", "e", "i", "o", "u": mapped = "a"
            default: break
            }
            if mapped == "x" { out += ["k", "s"]; continue }
            if out.last != mapped { out.append(mapped) }   // collapse doubles
        }
        return String(out)
    }

    /// Weighted Levenshtein on two keys, normalized by the longer key.
    /// 0 = same sound, 1 = nothing alike.
    public static func distance(_ a: String, _ b: String) -> Double {
        let x = Array(a), y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return 1 }
        var prev = [Double](repeating: 0, count: y.count + 1)
        for j in 1...y.count { prev[j] = prev[j - 1] + indelCost(y[j - 1]) }
        for i in 1...x.count {
            var cur = [Double](repeating: 0, count: y.count + 1)
            cur[0] = prev[0] + indelCost(x[i - 1])
            for j in 1...y.count {
                cur[j] = min(prev[j] + indelCost(x[i - 1]),
                             cur[j - 1] + indelCost(y[j - 1]),
                             prev[j - 1] + substitutionCost(x[i - 1], y[j - 1]))
            }
            prev = cur
        }
        return min(1, prev[y.count] / Double(max(x.count, y.count)))
    }

    /// Same opening sound (or an accent merge of it). Names misheard by an
    /// accent keep their first sound (Vikram/Wikram, Tarun/Darun), and
    /// Soundex-style blocking relies on it. It stops "defeating" → "Feeting".
    public static func sameOnset(_ a: String, _ b: String) -> Bool {
        guard let x = a.first, let y = b.first else { return false }
        return substitutionCost(x, y) < 1
    }

    /// Plain Levenshtein similarity on the spelling: 1 = identical.
    public static func spellingSimilarity(_ a: String, _ b: String) -> Double {
        let x = Array(a.lowercased()), y = Array(b.lowercased())
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        var prev = Array(0...y.count)
        for i in 1...x.count {
            var cur = [i] + [Int](repeating: 0, count: y.count)
            for j in 1...y.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1,
                             prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return 1 - Double(prev[y.count]) / Double(max(x.count, y.count))
    }

    // MARK: - Costs

    /// Pairs an Indian-English accent (or Hinglish spelling) merges: व sits
    /// between v and w, retroflex ट/ड blur t and d, ज covers j and z, and
    /// "s"/"sh" are commonly swapped.
    private static let cheapPairs: Set<String> = ["bv", "dt", "js", "gj", "gk", "fp", "mn", "lr", "cs", "cj"]

    private static func substitutionCost(_ a: Character, _ b: Character) -> Double {
        if a == b { return 0 }
        if a == "h" || b == "h" { return 0.5 }   // h is weak: Rohan ≈ Rowan
        let pair = String([a, b].sorted())
        return cheapPairs.contains(pair) ? 0.3 : 1
    }

    /// Dropping a vowel or an h is a half-step; any other consonant is a full one.
    private static func indelCost(_ c: Character) -> Double {
        return (c == "a" || c == "h") ? 0.5 : 1
    }

    private static func replaceDigraphs(_ s: [Character]) -> [Character] {
        let pairs: [(String, Character)] = [
            ("ph", "f"), ("bh", "b"), ("dh", "d"), ("th", "t"), ("kh", "k"),
            ("gh", "g"), ("sh", "s"), ("ch", "C"), ("ck", "k"), ("wh", "v"),
        ]
        var out: [Character] = []
        var i = 0
        while i < s.count {
            if i + 1 < s.count, let hit = pairs.first(where: { $0.0 == String(s[i...i + 1]) }) {
                out.append(hit.1)
                i += 2
            } else {
                out.append(s[i])
                i += 1
            }
        }
        return out
    }
}
