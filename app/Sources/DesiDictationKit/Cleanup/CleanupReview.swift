import Foundation

/// What clean-up offers in Review before paste (FILLERS_AND_CORRECTIONS.md):
/// spoken corrections ("2, no, make it 3"), likely fillers ("like", "you
/// know") and, when "Remove um and uh" is off, the filler sounds. All are
/// suggestions; nothing here changes the text.
public enum CleanupReview {
    public static func items(in text: String, mode: LanguageMode, scorer: ContextScorer?,
                             removeSounds: Bool) -> [UnsureWord] {
        guard mode != .hindi else { return [] }
        var out = Corrections.find(in: text, scorer: scorer).map { c in
            UnsureWord(range: c.range, word: String(text[c.range]), reason: .correction,
                       confidence: nil, alternatives: [c.replacement])
        }
        if !removeSounds {
            let ns = NSRange(text.startIndex..., in: text)
            for m in Fillers.soundPattern.matches(in: text, range: ns) {
                guard let r = Range(m.range, in: text) else { continue }
                out.append(UnsureWord(range: r, word: String(text[r]), reason: .filler, confidence: nil, alternatives: [""]))
            }
        }
        // The checker reads English only.
        if mode == .english, let scorer {
            for c in Fillers.candidates(in: text, scorer: scorer) {
                out.append(UnsureWord(range: c.range, word: c.phrase, reason: .filler, confidence: nil, alternatives: [""]))
            }
        }
        // A filler inside a correction's span goes with the correction.
        return out.filter { item in !out.contains { $0.reason == .correction && $0.range != item.range && $0.range.overlaps(item.range) } }
    }
}
