import Foundation

/// Is this an everyday word, or a name / term / garbled word? Review before
/// paste asks before underlining (REVIEW_BEFORE_PASTE.md "Ordinary words"):
/// casual speech makes everyday words look odd to the context checker, and a
/// chat full of capitalised headings offers sound-alikes for everyday words
/// ("model" ~ "Models"). Names, the words whose spelling can't be heard, are
/// almost never in a dictionary.
///
/// Source: macOS's own word list (/usr/share/dict/words, Webster's 2nd,
/// 236k words, no inflections) plus CommonWords (modern and Hinglish
/// everyday words), with the usual endings stripped.
public enum OrdinaryWords {
    static let listPath = "/usr/share/dict/words"

    /// Loaded once, off the main thread when `warmUp` runs first (~0.1 s).
    private static let dictionary: Set<String> = {
        guard let text = try? String(contentsOfFile: listPath, encoding: .utf8) else { return [] }
        var out = Set<String>(minimumCapacity: 240_000)
        text.enumerateLines { line, _ in
            // Capitalised entries are names ("Claude"); those don't count.
            if let first = line.first, first.isLowercase { out.insert(line) }
        }
        return out
    }()

    public static func warmUp() {
        DispatchQueue.global(qos: .utility).async { _ = dictionary.count }
    }

    /// True for an everyday word in any of its forms ("models", "making").
    /// Words with digits or non-Latin letters are never ordinary here.
    public static func contains(_ word: String) -> Bool {
        let w = word.lowercased()
        guard !w.isEmpty, w.allSatisfy({ $0.isASCII && ($0.isLetter || $0 == "'") }) else { return false }
        return forms(of: w).contains { CommonWords.contains($0) || dictionary.contains($0) }
    }

    /// Two words are one word in different forms ("model", "Models").
    public static func sameWord(_ a: String, _ b: String) -> Bool {
        let x = forms(of: a.lowercased()), y = forms(of: b.lowercased())
        return !Set(x).isDisjoint(with: y)
    }

    /// The word and what it may be with an ending taken off.
    static func forms(of w: String) -> [String] {
        var out = [w]
        let bare = w.hasSuffix("'s") ? String(w.dropLast(2)) : w
        out.append(bare)
        for (suffix, replacement) in [("ies", "y"), ("ied", "y"), ("es", ""), ("s", ""), ("ed", ""), ("ed", "e"),
                                      ("d", ""), ("ing", ""), ("ing", "e"), ("ers", ""), ("er", ""), ("er", "e"),
                                      ("ly", ""), ("ness", ""), ("ment", "")]
        where bare.hasSuffix(suffix) && bare.count > suffix.count + 2 {
            let stem = String(bare.dropLast(suffix.count))
            out.append(stem + replacement)
            // running → runn → run
            if replacement.isEmpty, let last = stem.last, stem.dropLast().last == last { out.append(String(stem.dropLast())) }
        }
        return out
    }
}
