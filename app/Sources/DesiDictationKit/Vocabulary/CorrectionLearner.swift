import Foundation

/// Decides which edits deserve an "Always write X as Y?" proposal
/// (AUTO_VOCABULARY.md §2a). Proposals only, never silent learning
/// (PERSONAL_DICTIONARY.md). A wrong proposal is cheap, because the user
/// says no, but a pointless one trains people to dismiss them all.
public enum CorrectionLearner {
    public static func proposal(
        for pair: EditPair, mode: LanguageMode,
        dictionary: [DictionaryEntry], rejected: Set<String>,
        lexicon: WordLexicon = .system
    ) -> EditPair? {
        let heard = pair.heard, typed = pair.typed
        guard heard != typed, isWordy(heard), isWordy(typed),
              !rejected.contains(WordFix.pairKey(from: heard, to: typed)),
              !dictionary.contains(where: { $0.heard.lowercased() == heard.lowercased() && $0.written == typed })
        else { return nil }

        let heardWords = heard.split(separator: " ").map(String.init)
        let typedWords = typed.split(separator: " ").map(String.init)
        let allCommon = (heardWords + typedWords).allSatisfy(CommonWords.contains)

        // "rohan" → "Rohan" / "jira" → "Jira": capitalizing a name is worth
        // remembering; "the" → "The" at a sentence start is not.
        if heard.lowercased() == typed.lowercased() {
            return CommonWords.contains(heard) ? nil : pair
        }
        // Hinglish spelling style: nahin → nahi, kyaa → kya (§2d), even
        // though both are everyday words.
        if mode != .english, heardWords.count == 1, typedWords.count == 1,
           HinglishVariants.isStyleEdit(heard, typed) {
            return pair
        }
        // their → there, a → the: grammar, not vocabulary.
        guard !allCommon else { return nil }
        // deploy → deployed: an inflection, not a spelling.
        if heardWords.count == 1, typedWords.count == 1, isInflection(heard, typed) { return nil }

        let x = heard.replacingOccurrences(of: " ", with: "")
        let y = typed.replacingOccurrences(of: " ", with: "")
        let sound = IndicPhonetics.distance(IndicPhonetics.key(x), IndicPhonetics.key(y))
        let spelling = IndicPhonetics.spellingSimilarity(x, y)
        // Looser than auto-correction (0.2 / 0.5): the user confirms these.
        // Same first sound, like the corrector: Sharma → Verma is a different
        // name, not a mishearing.
        let similar = IndicPhonetics.sameOnset(x.lowercased(), y.lowercased())
            && ((sound <= 0.35 && spelling >= 0.4) || spelling >= 0.6)
        return similar ? pair : nil
    }

    /// The user typed one of our automatic fixes back ("Rohan" → "Rowan"):
    /// their edit wins. That fix goes on the reject list without a question,
    /// because undoing a change is an answer already. It only ever *stops*
    /// a change, so this is never silent learning of a new word.
    public static func revertedFix(_ pair: EditPair, fixes: [WordFix]) -> WordFix? {
        fixes.first {
            $0.to.lowercased() == pair.heard.lowercased() && $0.from.lowercased() == pair.typed.lowercased()
        }
    }

    private static func isWordy(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 40 && s.allSatisfy { $0.isLetter || $0 == " " || $0 == "'" || $0 == "-" }
    }

    private static func isInflection(_ a: String, _ b: String) -> Bool {
        let x = a.lowercased(), y = b.lowercased()
        let xs = WordLexicon.stems(of: x), ys = WordLexicon.stems(of: y)
        return xs.contains(y) || ys.contains(x) || !Set(xs.dropFirst()).isDisjoint(with: ys.dropFirst())
    }
}
