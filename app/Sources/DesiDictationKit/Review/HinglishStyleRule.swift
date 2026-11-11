import Foundation

/// A spelling habit that covers many words at once (HINGLISH_LEARNING.md):
/// someone who writes "waise" for "vaise" also writes "woh", "waala" and
/// "wahan". Learned from the user's own fixes, applied only to Hindi words.
public enum HinglishStyleRule: String, CaseIterable, Codable, Sendable {
    /// vaise → waise, vaala → waala
    case wNotV
    /// waise → vaise, waala → vaala
    case vNotW
    /// chaahie → chahie, vaala → vala
    case shortA
    /// chahie → chahiye, lie → liye
    case iyeEnding

    /// The question the panel asks, in plain words.
    public var question: String {
        switch self {
        case .wNotV: return "Always write w instead of v at the start of Hindi words?"
        case .vNotW: return "Always write v instead of w at the start of Hindi words?"
        case .shortA: return "Always write a single a instead of aa in Hindi words?"
        case .iyeEnding: return "Always end Hindi words in -iye instead of -ie?"
        }
    }

    /// The two habits that can't both be on.
    public var opposite: HinglishStyleRule? {
        switch self {
        case .wNotV: return .vNotW
        case .vNotW: return .wNotV
        default: return nil
        }
    }

    /// `word` (lowercased, letters only) written this way; nil when the rule
    /// doesn't touch it.
    public func rewrite(_ word: String) -> String? {
        let out: String
        switch self {
        case .wNotV:
            guard word.hasPrefix("v"), word.count >= 2 else { return nil }
            out = "w" + word.dropFirst()
        case .vNotW:
            guard word.hasPrefix("w"), !word.hasPrefix("wh"), word.count >= 2 else { return nil }
            out = "v" + word.dropFirst()
        case .shortA:
            guard word.contains("aa") else { return nil }
            out = word.replacingOccurrences(of: "aa", with: "a")
        case .iyeEnding:
            guard word.hasSuffix("ie"), !word.hasSuffix("iye"), word.count > 3 else { return nil }
            out = String(word.dropLast(2)) + "iye"
        }
        return out == word ? nil : out
    }

    /// The habits a fix shows: chaahie → chahiye shows both shortA and
    /// iyeEnding. Only habits that alone or together explain the whole fix.
    public static func shown(by pair: EditPair) -> [HinglishStyleRule] {
        let heard = pair.heard.lowercased(), typed = pair.typed.lowercased()
        guard heard != typed, heard.allSatisfy(\.isLetter), typed.allSatisfy(\.isLetter) else { return [] }
        let rules = allCases.filter { $0.rewrite(heard) != nil }
        // Try every combination of the applicable habits, smallest first.
        for size in 1...max(1, rules.count) {
            for combo in combinations(rules, size) {
                let out = combo.reduce(heard) { $1.rewrite($0) ?? $0 }
                if out == typed { return combo }
            }
        }
        return []
    }

    private static func combinations(_ items: [HinglishStyleRule], _ k: Int) -> [[HinglishStyleRule]] {
        guard k > 0, k <= items.count else { return k == 0 ? [[]] : [] }
        guard let first = items.first else { return [] }
        let rest = Array(items.dropFirst())
        return combinations(rest, k - 1).map { [first] + $0 } + combinations(rest, k)
    }
}
