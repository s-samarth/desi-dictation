import Foundation

/// Post-transcription correction against this dictation's vocabulary — the
/// path for models that can't be biased (Parakeet, Hinglish Apex), and the
/// safety net after Qwen3-ASR's hotwords (AUTO_VOCABULARY.md §2c).
///
/// The standard recipe from the named-entity-correction literature: phonetic
/// key → weighted distance → threshold, with every guard from §3. A wrong
/// replacement costs more trust than a missed one, so every doubt means
/// "leave it".
public enum VocabularyCorrector {
    /// Max normalized phoneme distance (0 = same sound).
    public static let maxSoundDistance = 0.2
    /// Min spelling similarity (1 = identical) — sound alone is not enough.
    public static let minSpelling = 0.5

    public struct Result: Equatable {
        public let text: String
        public let fixes: [WordFix]
    }

    public static func correct(
        _ text: String, mode: LanguageMode, snapshot: VocabularySnapshot,
        lexicon: WordLexicon = .system
    ) -> Result {
        guard mode != .hindi, !text.isEmpty, !snapshot.isEmpty else { return Result(text: text, fixes: []) }
        let context = Context(
            index: TermIndex(snapshot.terms), rejected: snapshot.rejected, lexicon: lexicon,
            hinglish: mode == .hinglish || mode == .anyToEnglish,
            fieldCounts: HinglishVariants.counts(of: snapshot.fieldWords))
        let tokens = WordTokens.tokens(in: text)
        var edits: [(Range<String.Index>, String, WordFix)] = []
        var i = 0
        while i < tokens.count {
            if i + 1 < tokens.count, WordTokens.onlySpaceBetween(text, tokens[i], tokens[i + 1]),
               let term = context.matchPair(tokens[i].word, tokens[i + 1].word) {
                let from = "\(tokens[i].word) \(tokens[i + 1].word)"
                let to = PersonalDictionary.casedLike(tokens[i].word, replacement: term.text)
                edits.append((tokens[i].range.lowerBound..<tokens[i + 1].range.upperBound, to,
                              WordFix(from: from, to: to, source: term.source)))
                i += 2
                continue
            }
            if let term = context.matchWord(tokens[i].word) {
                let to = PersonalDictionary.casedLike(tokens[i].word, replacement: term.text)
                edits.append((tokens[i].range, to,
                              WordFix(from: tokens[i].word, to: to, source: term.source)))
            }
            i += 1
        }
        var result = text
        for (range, replacement, _) in edits.reversed() {
            result.replaceSubrange(range, with: replacement)
        }
        return Result(text: result, fixes: edits.map { $0.2 })
    }

    /// The rules, with the per-dictation state they need.
    struct Context {
        let index: TermIndex
        let rejected: Set<String>
        let lexicon: WordLexicon
        let hinglish: Bool
        let fieldCounts: [String: Int]

        func matchWord(_ word: String) -> VocabularyTerm? {
            let lower = word.lowercased()
            guard lower.count >= 3, !index.containsExact(lower) else { return nil }
            // Hinglish: the user's own spelling in this field wins (§2d).
            if hinglish, let spelling = HinglishVariants.preferredSpelling(for: lower, fieldCounts: fieldCounts),
               !rejected.contains(WordFix.pairKey(from: lower, to: spelling)) {
                return VocabularyTerm(spelling, source: .fieldSpelling)
            }
            // Common words are never replaced without a confirmed pair (§3.4).
            guard !CommonWords.contains(lower) else { return nil }
            // A real word ("rowan") needs the term visible right now; in
            // Hinglish every word that isn't a typo-looking English word may
            // be real Hindi, so the same rule applies to all of them.
            let realWord = hinglish || lexicon.isRealWord(lower)
            return best(for: lower, maxDistance: maxSoundDistance, minSpelling: minSpelling) {
                !realWord || $0.source.isOnScreen
            }
        }

        /// "Sara swat" → "Saraswat": two words that join into one term.
        func matchPair(_ a: String, _ b: String) -> VocabularyTerm? {
            let la = a.lowercased(), lb = b.lowercased()
            guard la.count >= 2, lb.count >= 2, !CommonWords.contains(la), !CommonWords.contains(lb)
            else { return nil }
            let joined = la + lb
            guard joined.count >= 5 else { return nil }
            // An exact join is strong evidence; anything fuzzier must be on screen.
            if let exact = index.exact(joined), exact.source != .contacts,
               !rejected.contains(WordFix.pairKey(from: "\(la) \(lb)", to: joined)) {
                return exact
            }
            return best(for: joined, maxDistance: 0.15, minSpelling: 0.6, originalForReject: "\(la) \(lb)") {
                $0.source.isOnScreen
            }
        }

        private func best(
            for lower: String, maxDistance: Double, minSpelling: Double,
            originalForReject: String? = nil, allowed: (VocabularyTerm) -> Bool
        ) -> VocabularyTerm? {
            let key = IndicPhonetics.key(lower)
            let from = originalForReject ?? lower
            let scored = index.near(key).compactMap { entry -> (VocabularyTerm, Double, Double)? in
                guard allowed(entry.term), IndicPhonetics.sameOnset(key, entry.key),
                      !rejected.contains(WordFix.pairKey(from: from, to: entry.term.text))
                else { return nil }
                let sound = IndicPhonetics.distance(key, entry.key)
                let spelling = IndicPhonetics.spellingSimilarity(lower, entry.lower)
                guard sound <= maxDistance, spelling >= minSpelling else { return nil }
                return (entry.term, sound, spelling)
            }.sorted { ($0.1, -$0.2) < ($1.1, -$1.2) }
            guard let top = scored.first else { return nil }
            // Two near-equal candidates: no clear winner, so no change (§3.3).
            if scored.count > 1, scored[1].1 - top.1 < 0.05, top.2 - scored[1].2 < 0.1 { return nil }
            return top.0
        }
    }
}
