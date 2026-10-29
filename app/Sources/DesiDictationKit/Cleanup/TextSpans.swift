import Foundation

/// Taking a word or phrase out of a sentence so the rest still reads right:
/// "I, uh, think" → "I think", "Um, I think" → "I think", "I think, um." →
/// "I think.". Shared by filler removal and the review panel's "Remove".
public enum TextSpans {
    /// What to delete for `range`, with its commas and spaces, and whether the
    /// letter that then starts the sentence should be capitalised.
    public static func removal(of range: Range<String.Index>, in text: String)
        -> (delete: Range<String.Index>, capitalizeNext: Bool) {
        var lower = range.lowerBound
        var upper = range.upperBound
        let followComma = upper < text.endIndex && text[upper] == ","
        // Back over spaces to the previous visible character.
        var back = lower
        while back > text.startIndex, text[text.index(before: back)].isWhitespace { back = text.index(before: back) }
        let previous = back > text.startIndex ? text[text.index(before: back)] : nil
        let atStart = previous == nil || ".!?\n".contains(previous!)
        let precedeComma = previous == ","

        if atStart {
            // "Um, I think" → "I think": the word, its comma and the spaces after.
            if followComma { upper = text.index(after: upper) }
            while upper < text.endIndex, text[upper].isWhitespace { upper = text.index(after: upper) }
            return (lower..<upper, true)
        }
        if followComma {
            upper = text.index(after: upper)
            // "I, uh, think" → "I think": both commas go.
            lower = precedeComma ? text.index(before: back) : back
            return (lower..<upper, false)
        }
        // "I think, um." → "I think." / "it was like really" → "it was really".
        lower = precedeComma ? text.index(before: back) : back
        return (lower..<upper, false)
    }

    /// `text` without `range` (see `removal`).
    public static func removing(_ range: Range<String.Index>, from text: String) -> String {
        let (delete, capitalize) = removal(of: range, in: text)
        var out = text
        let offset = text.distance(from: text.startIndex, to: delete.lowerBound)
        out.removeSubrange(delete)
        if capitalize, offset < out.count {
            let i = out.index(out.startIndex, offsetBy: offset)
            out.replaceSubrange(i...i, with: out[i].uppercased())
        }
        return out
    }

    /// Whole-word, case-insensitive matches of `phrase` in `text`, in order.
    static func matches(of phrase: String, in text: String) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var from = text.startIndex
        while let r = text.range(of: phrase, options: .caseInsensitive, range: from..<text.endIndex) {
            from = r.upperBound
            let okBefore = r.lowerBound == text.startIndex || !text[text.index(before: r.lowerBound)].isLetter
            let okAfter = r.upperBound == text.endIndex || !text[r.upperBound].isLetter
            if okBefore, okAfter { out.append(r) }
        }
        return out
    }
}
