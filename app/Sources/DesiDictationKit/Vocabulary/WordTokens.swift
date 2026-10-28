import Foundation

/// A word inside a transcript, with the exact range to replace.
public struct WordToken: Equatable {
    public let range: Range<String.Index>
    public let word: String
}

/// Splits text into the words the vocabulary code may touch.
///
/// Whole words only (§3.1): letters, plus a possessive "'s" that stays
/// outside the replaced range ("Rowan's" → "Rohan's"). Contractions,
/// ALL-CAPS acronyms and anything inside an email, URL, handle or dotted
/// identifier are skipped: "john.doe@x.com" is never a name to fix.
public enum WordTokens {
    private static let pattern = try! NSRegularExpression(
        pattern: "[A-Za-z]+(?:['’][A-Za-z]+)*")

    public static func tokens(in text: String) -> [WordToken] {
        let ns = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: ns).compactMap { match in
            guard var range = Range(match.range, in: text) else { return nil }
            var word = String(text[range])
            if word.contains("'") || word.contains("’") {
                let lower = word.lowercased()
                guard lower.hasSuffix("'s") || lower.hasSuffix("’s") else { return nil }
                word = String(word.dropLast(2))
                range = range.lowerBound..<text.index(range.upperBound, offsetBy: -2)
            }
            guard !insideIdentifier(text, range) else { return nil }
            if word.count > 1, word == word.uppercased() { return nil }   // acronym
            return WordToken(range: range, word: word)
        }
    }

    /// The words alone, as written — for field text and term counting.
    public static func words(in text: String) -> [String] {
        tokens(in: text).map { $0.word }
    }

    /// True when only plain spaces separate two tokens (a split name).
    public static func onlySpaceBetween(_ text: String, _ a: WordToken, _ b: WordToken) -> Bool {
        let gap = text[a.range.upperBound..<b.range.lowerBound]
        return !gap.isEmpty && gap.allSatisfy { $0 == " " }
    }

    private static func insideIdentifier(_ text: String, _ range: Range<String.Index>) -> Bool {
        let before = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : " "
        let after = range.upperBound < text.endIndex ? text[range.upperBound] : " "
        if "@#/\\_".contains(before) || "@/\\_".contains(after) { return true }
        if before.isNumber || after.isNumber { return true }
        if before == ".", range.lowerBound > text.index(after: text.startIndex) {
            let prev = text[text.index(range.lowerBound, offsetBy: -2)]
            if prev.isLetter || prev.isNumber { return true }
        }
        if after == ".", text.index(after: range.upperBound) < text.endIndex {
            let next = text[text.index(after: range.upperBound)]
            if next.isLetter || next.isNumber { return true }
        }
        return false
    }
}
