import Foundation

/// "Is this a real English word?" — tells a misspelling ("Saraswath") from a
/// real-but-wrong word ("rowan") for the corrector's tiers (§3.4).
///
/// Backed by `/usr/share/dict/words` (Webster's 2nd, public domain, on every
/// Mac). If the file is missing, every word counts as real, the direction
/// that makes the corrector change *less*.
public final class WordLexicon: @unchecked Sendable {
    public static let system = WordLexicon(path: "/usr/share/dict/words")

    private let lock = NSLock()
    private let path: String?
    private var words: Set<String>?
    private let fixed: Set<String>?

    public init(path: String) {
        self.path = path
        self.fixed = nil
    }

    /// Test lexicon with a known word set.
    public init(words: Set<String>) {
        self.path = nil
        self.fixed = Set(words.map { $0.lowercased() })
    }

    /// Webster's list holds base forms ("defeat", not "defeating"), so
    /// common inflections are stripped before giving up on a word.
    public func isRealWord(_ word: String) -> Bool {
        let lower = word.lowercased()
        let set: Set<String>
        if let fixed {
            set = fixed
        } else {
            lock.lock()
            if words == nil { words = Self.load(path) }
            set = words ?? []
            lock.unlock()
            guard !set.isEmpty else { return true }
        }
        // Two rounds: meetings → meeting → meet.
        return Self.stems(of: lower).flatMap(Self.stems(of:)).contains { set.contains($0) }
    }

    /// The word and its likely base forms: meetings → meeting, meet;
    /// called → call; studies → study; running → run.
    static func stems(of word: String) -> [String] {
        var out = [word]
        let rules: [(suffix: String, replacements: [String])] = [
            ("ies", ["y"]), ("ied", ["y"]), ("ing", ["", "e"]), ("ed", ["", "e"]),
            ("es", [""]), ("s", [""]), ("ers", ["", "e"]), ("er", ["", "e"]), ("ly", [""]),
        ]
        for rule in rules where word.hasSuffix(rule.suffix) && word.count > rule.suffix.count + 2 {
            let base = String(word.dropLast(rule.suffix.count))
            for ending in rule.replacements { out.append(base + ending) }
            // running → run, stopped → stop
            if let last = base.last, base.count > 2, base.dropLast().last == last {
                out.append(String(base.dropLast()))
            }
        }
        return out
    }

    /// Loads lazily on the first dictation that needs it (~236k words, ~10 ms).
    public func warmUp() { _ = isRealWord("a") }

    private static func load(_ path: String?) -> Set<String> {
        guard let path, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        var set = Set<String>(minimumCapacity: 240_000)
        text.enumerateLines { line, _ in set.insert(line.lowercased()) }
        return set
    }
}
