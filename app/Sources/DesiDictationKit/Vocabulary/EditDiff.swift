import Foundation

/// "It wrote X, the user changed it to Y": one word-level edit of our paste.
public struct EditPair: Equatable, Sendable {
    public let heard: String
    public let typed: String

    public init(heard: String, typed: String) {
        self.heard = heard
        self.typed = typed
    }
}

/// Finds which of our pasted words the user retyped (AUTO_VOCABULARY.md §2a),
/// from two snapshots of the same field: right after the paste and once the
/// user stopped typing. Pure, so every case is testable without AX.
public enum EditDiff {
    /// Above this many changed words it's a rewrite, not a spelling fix.
    static let maxChangedWords = 4

    /// `caretUTF16` is where the caret sat right after the paste (AX ranges
    /// are UTF-16). It picks the right copy when our text appears twice.
    public static func pairs(before: String, after: String, inserted: String,
                             caretUTF16: Int? = nil) -> [EditPair] {
        guard before != after, !inserted.isEmpty,
              let start = locate(inserted, in: before, caretUTF16: caretUTF16) else { return [] }
        let b = Array(before), a = Array(after)
        let end = start + inserted.count
        var prefix = 0
        while prefix < min(b.count, a.count), b[prefix] == a[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(b.count, a.count) - prefix,
              b[b.count - 1 - suffix] == a[a.count - 1 - suffix] { suffix += 1 }
        // The edit must lie inside our words; text before/after them stays put.
        guard prefix >= start, prefix < end, suffix >= b.count - end else { return [] }
        let editedEnd = a.count - (b.count - end)
        guard editedEnd >= start else { return [] }
        let edited = String(a[start..<editedEnd])
        return align(words(inserted), words(edited))
    }

    /// Word runs that differ between the two word lists (LCS alignment).
    static func align(_ x: [String], _ y: [String]) -> [EditPair] {
        guard !x.isEmpty, !y.isEmpty else { return [] }
        var lcs = [[Int]](repeating: [Int](repeating: 0, count: y.count + 1), count: x.count + 1)
        for i in stride(from: x.count - 1, through: 0, by: -1) {
            for j in stride(from: y.count - 1, through: 0, by: -1) {
                lcs[i][j] = x[i] == y[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var pairs: [EditPair] = []
        var changed = 0
        var i = 0, j = 0
        var runX: [String] = [], runY: [String] = []
        func flush() {
            changed += max(runX.count, runY.count)
            // Only substitutions; words the user just added or deleted aren't fixes.
            if runX.count == 2, runY.count == 2 {
                // Two neighbours both retyped — a first name and surname
                // ("Samar Saraswath" → "Samarth Saraswat"): word by word.
                // Treating it as a rewrite missed every full-name fix (FM#37).
                pairs += zip(runX, runY).map { EditPair(heard: $0, typed: $1) }
            } else if (1...2).contains(runX.count), (1...2).contains(runY.count) {
                pairs.append(EditPair(heard: runX.joined(separator: " "), typed: runY.joined(separator: " ")))
            } else if !runX.isEmpty && !runY.isEmpty {
                changed += maxChangedWords   // a rewritten phrase: give up
            }
            runX = []; runY = []
        }
        while i < x.count || j < y.count {
            if i < x.count, j < y.count, x[i] == y[j] {
                flush(); i += 1; j += 1
            } else if j < y.count, i == x.count || lcs[i][j + 1] >= lcs[i + 1][j] {
                runY.append(y[j]); j += 1
            } else {
                runX.append(x[i]); i += 1
            }
        }
        flush()
        return changed > maxChangedWords ? [] : pairs
    }

    /// Whitespace-separated words with surrounding punctuation trimmed.
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Character offset of our pasted text in the field: the copy ending at
    /// the caret, else the last copy.
    static func locate(_ inserted: String, in text: String, caretUTF16: Int?) -> Int? {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while let r = text.range(of: inserted, range: searchStart..<text.endIndex) {
            ranges.append(r)
            searchStart = r.upperBound
        }
        guard !ranges.isEmpty else { return nil }
        var chosen = ranges[ranges.count - 1]
        if let caretUTF16,
           let hit = ranges.first(where: { text.utf16.distance(from: text.startIndex, to: $0.upperBound) == caretUTF16 }) {
            chosen = hit
        }
        return text.distance(from: text.startIndex, to: chosen.lowerBound)
    }
}
