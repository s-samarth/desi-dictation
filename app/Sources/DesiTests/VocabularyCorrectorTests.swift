import Foundation
import DesiDictationKit

/// Auto vocabulary, part 1: the post-transcription corrector
/// (AUTO_VOCABULARY.md §3). False positives first — a wrong replacement
/// costs more trust than a missed one.
func runVocabularyCorrectorTests() {
    // A fixed lexicon so tests never depend on /usr/share/dict.
    let lexicon = WordLexicon(words: ["rowan", "cavia", "swat", "sara", "uncut", "origin", "rise"])
    func fix(_ text: String, _ terms: [VocabularyTerm], mode: LanguageMode = .english,
             field: String = "", rejected: Set<String> = []) -> VocabularyCorrector.Result {
        let snapshot = VocabularySnapshot(
            terms: terms, fieldWords: WordTokens.words(in: field), rejected: rejected)
        return VocabularyCorrector.correct(text, mode: mode, snapshot: snapshot, lexicon: lexicon)
    }
    let dict = { (t: String) in VocabularyTerm(t, source: .dictionary) }
    let screen = { (t: String) in VocabularyTerm(t, source: .screen) }

    T.begin("Vocabulary — phonetics")
    T.equal(IndicPhonetics.key("Saraswath"), IndicPhonetics.key("Saraswat"), "th ≈ t")
    T.equal(IndicPhonetics.key("Kavya"), IndicPhonetics.key("Cavia"), "Kavya ≈ Cavia")
    T.equal(IndicPhonetics.key("Vikram"), IndicPhonetics.key("Wikram"), "v ≈ w")
    T.expect(IndicPhonetics.distance(IndicPhonetics.key("Rohan"), IndicPhonetics.key("Rowan")) <= 0.2,
             "Rohan ≈ Rowan (weak h)")
    T.expect(IndicPhonetics.distance(IndicPhonetics.key("Priya"), IndicPhonetics.key("Rohan")) > 0.4,
             "Priya ≠ Rohan")

    let stems = WordLexicon(words: ["defeat", "meet", "study", "run", "call"])
    T.expect(["defeating", "meetings", "studies", "running", "called"].allSatisfy(stems.isRealWord),
             "inflected forms count as real words")
    T.expect(!stems.isRealWord("saraswath"), "a misspelled name is not a real word")
    T.expect(WordLexicon.system.isRealWord("meetings"), "system lexicon knows 'meetings'")

    T.begin("Vocabulary — false positives (must NOT change)")
    T.equal(fix("we will rise and shine", [screen("Rishi")]).text,
            "we will rise and shine", "common word never replaced, even with screen term")
    T.equal(fix("the origin of the bug", [screen("Arjun")]).text,
            "the origin of the bug", "common word vs screen term")
    T.equal(fix("a rowan tree", [dict("Rohan")]).text,
            "a rowan tree", "real word: dictionary term alone can't overrule (no confidence yet)")
    T.equal(fix("an uncut gem", [screen("Ankit")]).text,
            "an uncut gem", "sound-alike but spelling too far")
    T.equal(fix("we are defeating them", [dict("Feeting")]).text,
            "we are defeating them", "no partial-word edits")
    T.equal(fix("mail john.doe@kavia.com now", [dict("Kavya")]).text,
            "mail john.doe@kavia.com now", "emails and URLs untouched")
    T.equal(fix("ask Kavia", [dict("Kavya"), dict("Kaviya")]).text,
            "ask Kavia", "near-tie between two terms → no change")
    T.equal(fix("ask Kavia", [dict("Kavya")], rejected: [WordFix.pairKey(from: "kavia", to: "Kavya")]).text,
            "ask Kavia", "rejected pair is never applied")
    T.equal(fix("kal tum aana", [screen("Kalam"), screen("Tumul")], mode: .hinglish).text,
            "kal tum aana", "Hinglish common words untouched")
    T.equal(fix("rahul ne bola", [dict("Raahul")], mode: .hinglish).text,
            "rahul ne bola", "Hinglish: a dictionary term alone can't change a word")
    T.equal(fix("नमस्ते Kavia", [dict("Kavya")], mode: .hindi).text,
            "नमस्ते Kavia", "हिन्दी mode is skipped")
    T.equal(fix("API and SDK", [screen("Apee")]).text, "API and SDK", "acronyms untouched")

    T.begin("Vocabulary — true positives")
    T.equal(fix("call Saraswath tomorrow", [dict("Saraswat")]).text,
            "call Saraswat tomorrow", "misspelled name → dictionary term")
    T.equal(fix("tell Kavia hi", [screen("Kavya")]).text,
            "tell Kavya hi", "non-word → name on screen")
    T.equal(fix("send it to Rowan today", [screen("Rohan")]).text,
            "send it to Rohan today", "real word → name visible on screen")
    T.equal(fix("Rowan's deck", [screen("Rohan")]).text,
            "Rohan's deck", "possessive kept")
    T.equal(fix("meet Sara swat at 5", [dict("Saraswat")]).text,
            "meet Saraswat at 5", "split name joined")
    let result = fix("ping Wikram", [screen("Vikram")])
    T.equal(result.fixes, [WordFix(from: "Wikram", to: "Vikram", source: .screen)],
            "the fix is reported with its source")

    T.begin("Vocabulary — Hinglish spelling style")
    T.equal(fix("kyaa haal hai", [], mode: .hinglish, field: "kya scene hai? kya bolta").text,
            "kya haal hai", "field's spelling wins (kyaa → kya)")
    T.equal(fix("kyaa haal hai", [], mode: .hinglish, field: "kya scene hai").text,
            "kyaa haal hai", "one use in the field isn't enough")
    T.equal(fix("woh hain", [], mode: .hinglish, field: "hai hai hai").text,
            "woh hain", "hai/hain are different words, never folded")
    T.equal(fix("peeta hai", [], mode: .hinglish, field: "pita ji, pita ji, peeta").text,
            "peeta hai", "model's spelling already used in the field → leave it")
    T.expect(HinglishVariants.isStyleEdit("nahin", "nahi"), "nahin → nahi is a style edit")
    T.expect(HinglishVariants.isStyleEdit("nhi", "nahi"), "nhi → nahi is a style edit")
    T.expect(HinglishVariants.isStyleEdit("acha", "achha"), "acha → achha is a style edit")
    T.expect(!HinglishVariants.isStyleEdit("raha", "rahi"), "raha → rahi is grammar")
    T.expect(!HinglishVariants.isStyleEdit("hai", "hain"), "hai → hain is grammar")
}
