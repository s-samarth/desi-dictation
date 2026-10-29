import Foundation

/// Spoken self-corrections (FILLERS_AND_CORRECTIONS.md): "meet at 2, no,
/// make it 3" → "meet at 3"; "send it to Rohan, sorry, Rahul" → "Rahul";
/// "Monday, scratch that, Tuesday works" → "Tuesday works". Only offered in
/// review, never applied. Conservative on purpose: "no" counts only after a
/// comma, or at a sentence start when "make it" or "wait" follows ("two. No,
/// make it three", as the engine often writes it); and without "make it"
/// the replacement must be the same kind of thing as what it replaces (a
/// number, a weekday, a name).
public enum Corrections {
    public struct Correction: Sendable {
        /// What would go: the old words, the trigger and the new words.
        public let range: Range<String.Index>
        /// What would stay; empty = remove (scratch that).
        public let replacement: String
    }

    static let replace = try! NSRegularExpression(pattern:
        #"([,.!])\s*(?:(no)(?:,\s*|\s+)(?:(wait),?\s*)?(make (?:it|that)\s+)?|(sorry|actually|i mean)(?:,\s*|\s+)(make (?:it|that)\s+)?)"#,
        options: [.caseInsensitive])
    static let scratch = try! NSRegularExpression(pattern: #"[,.]?\s*\bscratch that\b[,.]?\s*"#, options: [.caseInsensitive])

    public static func find(in text: String, scorer: ContextScorer? = nil) -> [Correction] {
        var out: [Correction] = []
        let ns = NSRange(text.startIndex..., in: text)
        for m in replace.matches(in: text, range: ns) {
            guard let trigger = Range(m.range, in: text) else { continue }
            let explicit = m.range(at: 4).location != NSNotFound || m.range(at: 6).location != NSNotFound
            // After "." or "!", "No," may just be an answer: only with "make it" or "wait".
            let afterComma = (text as NSString).substring(with: m.range(at: 1)) == ","
            guard afterComma || explicit || m.range(at: 3).location != NSNotFound else { continue }
            if let c = replacement(after: trigger, in: text, explicit: explicit, scorer: scorer) { out.append(c) }
        }
        for m in scratch.matches(in: text, range: ns) {
            guard let trigger = Range(m.range, in: text), let c = scratched(trigger, in: text) else { continue }
            out.append(c)
        }
        return out.filter { c in !out.contains { $0.range != c.range && $0.range.overlaps(c.range) && $0.range.lowerBound < c.range.lowerBound } }
    }

    /// The new words after the trigger, and which old words they replace.
    static func replacement(after trigger: Range<String.Index>, in text: String, explicit: Bool,
                            scorer: ContextScorer?) -> Correction? {
        let tail = text[trigger.upperBound...]
        let newEnd = tail.firstIndex(where: { ".,!?;".contains($0) }) ?? text.endIndex
        let newWords = text[trigger.upperBound..<newEnd].split(separator: " ")
        guard !newWords.isEmpty, newWords.count <= (explicit ? 4 : 2) else { return nil }
        let new = newWords.joined(separator: " ")
        // Old words: in the same clause, before the trigger.
        let clauseStart = text[..<trigger.lowerBound].lastIndex(where: { ".!?;\n".contains($0) })
            .map { text.index(after: $0) } ?? text.startIndex
        let old = words(in: text, from: clauseStart, to: trigger.lowerBound)
        guard !old.isEmpty else { return nil }
        let kind = Kind(newWords[0])
        var choices: [Range<String.Index>] = []
        if kind != .other, let same = old.last(where: { Kind(text[$0]) == kind }) {
            choices = [same]                          // "2" ← "3", "Monday" ← "Tuesday", "Rohan" ← "Rahul"
        } else if explicit {
            choices = (1...min(3, old.count)).map { old[old.count - $0].lowerBound..<old.last!.upperBound }
        }
        guard !choices.isEmpty else { return nil }
        // Several readings: the checker picks the one that reads best.
        let best = scorer.flatMap { s in
            choices.max { a, b in
                (s.logProbability(of: rewrite(text, a, newEnd, new), after: ContextFit.prompt) ?? -.infinity)
                    < (s.logProbability(of: rewrite(text, b, newEnd, new), after: ContextFit.prompt) ?? -.infinity)
            }
        } ?? choices[0]
        return Correction(range: best.lowerBound..<newEnd, replacement: new)
    }

    /// "Monday, scratch that, Tuesday works": the taken-back words go. Mid-
    /// sentence: the sentence so far; at a sentence start: the sentence before.
    static func scratched(_ trigger: Range<String.Index>, in text: String) -> Correction? {
        let before = text[..<trigger.lowerBound]
        let sentenceStart = before.lastIndex(where: { ".!?\n".contains($0) }).map { text.index(after: $0) } ?? text.startIndex
        var start = sentenceStart
        if text[sentenceStart..<trigger.lowerBound].trimmingCharacters(in: .whitespaces).isEmpty {
            // "Monday works. Scratch that." takes back the previous sentence.
            let earlier = text[..<sentenceStart].dropLast()
            start = earlier.lastIndex(where: { ".!?\n".contains($0) }).map { text.index(after: $0) } ?? text.startIndex
        }
        while start < trigger.lowerBound, text[start].isWhitespace { start = text.index(after: start) }
        guard start < trigger.lowerBound else { return nil }
        return Correction(range: start..<trigger.upperBound, replacement: "")
    }

    static func rewrite(_ text: String, _ old: Range<String.Index>, _ end: String.Index, _ new: String) -> String {
        String(text[..<old.lowerBound]) + new + String(text[end...])
    }

    static func words(in text: String, from: String.Index, to: String.Index) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var i = from
        while i < to {
            while i < to, !text[i].isLetter, !text[i].isNumber { i = text.index(after: i) }
            var j = i
            while j < to, text[j].isLetter || text[j].isNumber || text[j] == ":" || text[j] == "'" { j = text.index(after: j) }
            if i < j { out.append(i..<j) }
            i = j
        }
        return out
    }

    /// What kind of thing a word is, for "same kind replaces same kind".
    enum Kind: Equatable {
        case number, weekday, month, name, other

        static let numberWords: Set<String> = ["one", "two", "three", "four", "five", "six", "seven", "eight",
                                               "nine", "ten", "eleven", "twelve", "noon", "midnight"]
        static let weekdays: Set<String> = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
                                            "sunday", "today", "tomorrow", "tonight", "yesterday"]
        static let months: Set<String> = ["january", "february", "march", "april", "may", "june", "july",
                                          "august", "september", "october", "november", "december"]

        init<S: StringProtocol>(_ word: S) {
            let lower = word.lowercased()
            if word.first?.isNumber == true || Self.numberWords.contains(lower) { self = .number }
            else if Self.weekdays.contains(lower) { self = .weekday }
            else if Self.months.contains(lower) { self = .month }
            else if word.first?.isUppercase == true, word != "I" { self = .name }
            else { self = .other }
        }
    }
}
