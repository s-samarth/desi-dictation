import Foundation
import DesiDictationKit

/// Hinglish Learning (HINGLISH_LEARNING.md): spelling questions, the user's
/// spellings applied, style habits, and the streak that ends learning.
func runHinglishLearningTests() {
    let english = WordLexicon(words: ["video", "send", "deck", "the", "very"])

    T.begin("Hinglish Learning — the spelling list")
    T.expect(HinglishSpellings.sameWord("chaahie", "Chahiye"), "one word, two spellings")
    T.expect(!HinglishSpellings.sameWord("wala", "wali"), "inflections are different words")
    T.equal(HinglishSpellings.group(of: "kam"), nil, "kam (less) isn't kaam (work): not listed")
    T.equal(HinglishSpellings.group(of: "main"), nil, "main (I) vs mein (in): not listed")

    T.begin("Hinglish Learning — the user's spellings are applied")
    let style = HinglishStyle(preferred: ["chahiye": "chahiye", "wala": "waala"], rules: [.wNotV])
    T.equal(style.apply("ads ko chaahie, Chahie bhi, ye vala", lexicon: english),
            "ads ko chahiye, Chahiye bhi, ye waala", "a chosen spelling wins, capitals kept")
    T.equal(style.apply("vaise video bhejo, Vikas", lexicon: english), "waise video bhejo, Vikas",
            "a habit reaches Hindi words only: not English, not names")
    T.equal(HinglishStyle().apply("vaise hi", lexicon: english), "vaise hi", "nothing learned: unchanged")

    T.begin("Hinglish Learning — habits a fix shows")
    T.equal(HinglishStyleRule.shown(by: EditPair(heard: "vaise", typed: "waise")), [.wNotV], "v → w")
    T.equal(Set(HinglishStyleRule.shown(by: EditPair(heard: "chaahie", typed: "chahiye"))), [.shortA, .iyeEnding],
            "two habits at once")
    T.equal(HinglishStyleRule.shown(by: EditPair(heard: "ladki", typed: "larki")), [], "not a habit")
    T.equal(HinglishStyleRule.wNotV.rewrite("whatsapp"), nil, "only v-words")
    T.equal(HinglishStyleRule.vNotW.rewrite("whatsapp"), nil, "wh stays")

    T.begin("Hinglish Learning — which words are asked about")
    let text = "Ads ko chaahie, kyonki vaise hi"
    let asked = HinglishLearning.spellingWords(in: text, style: HinglishStyle(preferred: ["kyunki": "kyonki"]))
    T.equal(asked.map(\.word), ["chaahie", "vaise"], "list words not settled yet; kyonki is settled")
    T.equal(asked.first?.reason, .spelling, "…as spelling questions")
    T.equal(asked.first?.alternatives.first, "chahiye", "with the other spellings to pick")
    let odd = ReviewPlanner.unsure(in: text, words: [ScoredWord(text: "vaise", confidence: 0.1)], threshold: 0.5,
                                   sources: .init())
    T.equal(ReviewPlanner.merge(odd, asked).map(\.reason), [.spelling, .unclear],
            "a mishearing wins over a spelling question on the same word")

    T.begin("Hinglish Learning — learning from the panel")
    MainActor.assumeIsolated {
        let store = HinglishLearning(defaults: UserDefaults(suiteName: "desi-tests-\(UUID().uuidString)")!)
        store.review = .learning
        store.finish(underlined: asked, changes: [EditPair(heard: "chaahie", typed: "chahiye")],
                     kept: [EditPair(heard: "chaahie", typed: "chahiye")], adopt: [], decline: [])
        T.equal(store.style.preferred["chahiye"], "chahiye", "a kept fix sets the spelling")
        T.equal(store.style.preferred["waise"], "vaise", "a spelling left alone when asked is the user's")
        T.equal(store.cleanStreak, 0, "a fix breaks the streak")
        T.equal(store.habits(in: [EditPair(heard: "vaala", typed: "waala")]), [],
                "one v → w fix: not a habit yet")
        store.finish(underlined: [], changes: [EditPair(heard: "vaala", typed: "waala")],
                     kept: [EditPair(heard: "vaala", typed: "waala")], adopt: [], decline: [])
        T.equal(store.habits(in: [EditPair(heard: "voh", typed: "woh")]), [.wNotV], "the second one asks")
        store.finish(underlined: [], changes: [], kept: [], adopt: [.wNotV], decline: [])
        T.expect(store.style.rules.contains(.wNotV), "Yes adopts the habit")
        T.equal(store.habits(in: [EditPair(heard: "voh", typed: "woh")]), [], "…and stops asking")
        for _ in 0..<HinglishLearning.graduateAfter { store.finish(underlined: [], changes: [], kept: [], adopt: [], decline: []) }
        T.expect(store.isDone, "ten clean dictations: learning is done")
        store.stopLearning()
        T.equal(store.review, .standard, "Stop learning goes back to the English level")
        T.expect(!store.style.isEmpty, "…keeping what it learned")
    }

    T.begin("Hinglish Learning — v and w are one sound")
    T.expect(HinglishVariants.isStyleEdit("vaalon", "waalon"), "vaalon → waalon is a style edit")
    T.expect(CorrectionLearner.proposal(for: EditPair(heard: "vaalon", typed: "waalon"), mode: .hinglish,
                                        dictionary: [], rejected: []) != nil, "…and is offered to learn")
}
