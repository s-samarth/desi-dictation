import Foundation

/// What an underlined word could be instead, and which other words to
/// underline because they sound like a word the user uses.
///
/// Candidates come only from the user's own words: the dictionary (its
/// "heard → written" pairs and written forms) and the words on screen. Nothing
/// is invented. With the context checker installed, candidates are ordered by
/// how well each fits the sentence (ContextFit's scoring); otherwise by sound.
public enum ReviewAlternatives {
    /// Looser than the auto-corrector (0.2): these are offered, not applied.
    public static let maxSoundDistance = 0.35
    /// Keys 1–5 pick one.
    public static let limit = 5

    /// Everything a dictation's review can draw on.
    public struct Sources: Sendable {
        public var entries: [DictionaryEntry]
        public var screenTerms: [String]
        /// Words the context checker already judged in this sentence ("cloud"
        /// of a When it fits pair): not underlined again just for sounding alike.
        public var judged: Set<String>

        public init(entries: [DictionaryEntry] = [], screenTerms: [String] = [], judged: Set<String> = []) {
            self.entries = entries
            self.screenTerms = screenTerms
            self.judged = judged.reduce(into: []) { $0.insert($1.lowercased()) }
        }

        var terms: [String] {
            var seen = Set<String>()
            return (entries.map(\.written) + screenTerms).filter { seen.insert($0.lowercased()).inserted }
        }
    }

    /// Alternatives for `word`, best first, never the word itself.
    public static func candidates(for word: String, sources: Sources) -> [String] {
        let lower = word.lowercased()
        var out: [String] = sources.entries
            .filter { $0.heard.lowercased() == lower && $0.written.lowercased() != lower }
            .map { PersonalDictionary.casedLike(word, replacement: $0.written) }
        let key = IndicPhonetics.key(word)
        guard !key.isEmpty else { return unique(out) }
        // Onsets compared on the keys, where "Cavya" and "Kavya" both start with k.
        let sounding = sources.terms
            .filter { !OrdinaryWords.sameWord($0, lower) }     // "Models" isn't another word for "model"
            .map { (term: $0, key: IndicPhonetics.key($0)) }
            .filter { IndicPhonetics.sameOnset(key, $0.key) }
            .map { (term: $0.term, distance: IndicPhonetics.distance(key, $0.key)) }
            .filter { $0.distance <= maxSoundDistance }
            .sorted { $0.distance < $1.distance }
        out += sounding.map(\.term)
        return Array(unique(out).prefix(limit))
    }

    /// Words with a sound-alike in the user's words, for engines that give no
    /// confidence (Qwen3-ASR) and to catch confident mistakes ("cloud").
    /// Everyday words are left alone unless the dictionary names them: a
    /// screen full of headings would otherwise underline "model" for "Models".
    public static func soundAlikes(in text: String, sources: Sources) -> [UnsureWord] {
        UnsureWords.pieces(of: text).compactMap { piece in
            let word = String(text[piece.range])
            guard !sources.judged.contains(piece.key) else { return nil }
            let named = sources.entries.contains { $0.heard.lowercased() == piece.key }
            guard named || !OrdinaryWords.contains(piece.key) else { return nil }
            let alternatives = candidates(for: word, sources: sources)
            guard !alternatives.isEmpty else { return nil }
            return UnsureWord(range: piece.range, word: word, reason: .soundsLike,
                              confidence: nil, alternatives: alternatives)
        }
    }

    /// Orders alternatives by how well each fits the sentence (best first).
    /// The word as written is the baseline; the order only changes, nothing is dropped.
    public static func ranked(_ unsure: UnsureWord, in text: String, scorer: ContextScorer) -> [String] {
        let (before, after) = ContextFit.window(around: unsure.range, in: text)
        let scored = unsure.alternatives.map { alt in
            (alt, scorer.logProbability(of: before + alt + after, after: ContextFit.prompt) ?? -.infinity)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private static func unique(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.filter { seen.insert($0.lowercased()).inserted }
    }
}
