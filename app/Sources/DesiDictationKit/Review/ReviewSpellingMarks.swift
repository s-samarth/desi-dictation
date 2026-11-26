import Foundation

/// Tracks the original spelling questions through NSTextStorage edits and undo.
/// A separate attribute survives “Looks right”, which removes the visible underline.
public enum ReviewSpellingMarks {
    private static let key = NSAttributedString.Key("desiOriginalSpelling")

    public static func mark(_ text: NSMutableAttributedString, questions: [UnsureWord]) {
        for (index, word) in questions.enumerated() where word.reason == .spelling {
            text.addAttribute(key, value: index, range: NSRange(word.range, in: text.string))
        }
    }

    public static func surviving(in text: NSAttributedString, questions: [UnsureWord]) -> [String] {
        let string = text.string
        var words: [String] = []
        text.enumerateAttribute(key, in: NSRange(location: 0, length: text.length)) { value, nsRange, _ in
            guard let index = value as? Int, questions.indices.contains(index),
                let range = Range(nsRange, in: string), string[range] == questions[index].word,
                string[..<range.lowerBound].last?.isLetter != true,
                string[range.upperBound...].first?.isLetter != true
            else { return }
            words.append(questions[index].word.lowercased())
        }
        return words
    }
}
