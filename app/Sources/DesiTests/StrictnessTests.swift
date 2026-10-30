import Foundation
import DesiDictationKit

/// A scorer that finds one word odd: every token gets −1 nat except `odd`'s.
private final class OddWordScorer: ContextScorer {
    let odd: String
    init(odd: String) { self.odd = odd }

    func logProbability(of text: String, after prefix: String) -> Double? { nil }

    /// One token per space-led word, like a BPE vocabulary of whole words.
    func tokenLogProbabilities(of text: String, after prefix: String) -> [(end: Int, logprob: Double)]? {
        var out: [(end: Int, logprob: Double)] = []
        var end = 0
        for (n, word) in text.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            end += word.utf8.count + (n == 0 ? 0 : 1)
            out.append((end, word.hasPrefix(odd) ? -12 : -1))
        }
        return out
    }
}

/// Review strictness and "odd in context" (REVIEW_BEFORE_PASTE.md "Strictness").
func runStrictnessTests() {
    T.begin("Review — strictness levels are ordered")
    for model in ["/m/ggml-parakeet-tdt-0.6b-v3-q4_k.bin", "/m/ggml-hinglish-prime-q5_0.bin", "/m/ggml-vaani-hindi-q5_0.bin"] {
        let t = ReviewStrictness.allCases.map { $0.confidenceThreshold(forModel: model) ?? 0 }
        T.expect(t[0] >= t[1] && t[1] >= t[2], "conservative ≥ moderate ≥ liberal confidence bar: \(model)")
    }
    T.equal(ReviewStrictness.moderate.confidenceThreshold(forModel: "/m/ggml-qwen3-asr-1.7b-q8_0.bin"), nil,
            "Qwen3-ASR gives no confidence")
    for mode in LanguageMode.allCases {
        for model in ["/m/ggml-parakeet-tdt-0.6b-v3-q4_k.bin", "/m/ggml-qwen3-asr-1.7b-q8_0.bin"] {
            let s = ReviewStrictness.allCases.map { $0.surpriseThreshold(forModel: model, mode: mode) }
            guard let c = s[0], let m = s[1], let l = s[2] else { continue }
            T.expect(c <= m && m <= l, "conservative ≤ moderate ≤ liberal surprise bar: \(mode)")
        }
    }
    T.equal(ReviewStrictness.moderate.surpriseThreshold(forModel: "/m/ggml-hinglish-prime-q5_0.bin", mode: .hinglish),
            nil, "Hinglish: the checker doesn't help, so it isn't asked")

    T.begin("Review — Bindaas shows only purple words")
    T.equal(ReviewStrictness.bindaas.confidenceThreshold(forModel: "/m/ggml-hinglish-prime-q5_0.bin"), nil,
            "low confidence alone underlines nothing")
    T.equal(ReviewStrictness.bindaas.surpriseThreshold(forModel: "/m/ggml-parakeet-tdt-0.6b-v3-q4_k.bin", mode: .english),
            ReviewStrictness.liberal.surpriseThreshold(forModel: "/m/ggml-parakeet-tdt-0.6b-v3-q4_k.bin", mode: .english),
            "odd at Liberal's bar, so never more than Liberal")
    T.equal(ReviewStrictness.bindaas.surpriseThreshold(forModel: "/m/ggml-hinglish-prime-q5_0.bin", mode: .hinglish),
            nil, "Hinglish isn't checked, so nothing is purple")
    let said = "Pay Claude for one PC"
    let scoredWords = ["Pay", "Claude", "for", "one", "PC"].map { ScoredWord(text: $0, confidence: $0 == "Pay" ? 0.3 : 0.99) }
    let mixed = ReviewPlanner.unsure(
        in: said, words: scoredWords, threshold: 0.5,
        odd: SentenceSurprise.words(in: said, scorer: OddWordScorer(odd: "PC")) ?? [], oddAbove: 10,
        suggested: [WordFix(from: "Claude", to: "cloud", source: .context)], sources: .init())
    T.equal(mixed.map(\.word), ["Pay", "Claude", "PC"], "unclear, suggested and odd words are all found")
    T.equal(ReviewPlanner.shown(mixed, strictness: .bindaas).map(\.word), ["PC"], "Bindaas: only the odd word")
    T.equal(ReviewPlanner.shown(mixed, strictness: .liberal).count, 3, "other levels show everything")
    T.expect(!ReviewPlanner.opens(.unsure, unsure: ReviewPlanner.shown(Array(mixed.prefix(1)), strictness: .bindaas)),
             "nothing purple: the panel stays shut and it pastes")

    T.begin("Review — surprise lands on whole words")
    let text = "watch one PC Luffy"
    let scored = SentenceSurprise.words(in: text, scorer: OddWordScorer(odd: "PC")) ?? []
    T.equal(scored.map { String(text[$0.range]) }, ["watch", "one", "PC", "Luffy"], "one score per word")
    T.equal(scored.map(\.total), [1, 1, 12, 1], "a word's tokens, summed")
    T.expect(SentenceSurprise.words(in: text, scorer: FailingScorer()) == nil, "no token scores: nil")
    let long = String(repeating: "This is fine. ", count: 200)
    let chunks = SentenceSurprise.chunks(of: long)
    T.expect(chunks.count > 1 && chunks.allSatisfy { long.utf8.distance(from: $0.lowerBound, to: $0.upperBound) <= 1200 },
             "long text is scored in sentence groups that fit the context")

    T.begin("Review — odd words are underlined, never our own")
    let line = "Pay 50,000 to Claude for one PC"
    let odd = (SentenceSurprise.words(in: line, scorer: OddWordScorer(odd: "PC")) ?? []).map {
        WordSurprise(range: $0.range, total: line[$0.range] == "PC" || line[$0.range] == "50,000"
                     || line[$0.range] == "Claude" ? 20 : 1, peak: 1)
    }
    let unsure = ReviewPlanner.unsure(in: line, words: [], threshold: nil, odd: odd, oddAbove: 10,
                                      sources: .init(entries: [DictionaryEntry(heard: "cloud", written: "Claude")]))
    T.equal(unsure.map(\.word), ["PC"], "numbers and dictionary words are left alone")
    T.equal(unsure.first?.reason, .odd, "…and it says why")
    T.equal(ReviewPlanner.unsure(in: line, words: [], threshold: nil, odd: odd, oddAbove: nil, sources: .init()).count, 0,
            "no surprise bar: nothing odd is underlined")

    T.begin("Review — everyday words need to be much odder")
    let casual = "I would want you to update Prabjot"
    let flat = (SentenceSurprise.words(in: casual, scorer: OddWordScorer(odd: "-")) ?? [])
        .map { WordSurprise(range: $0.range, total: casual[$0.range] == "want" ? 15 : casual[$0.range] == "Prabjot" ? 12 : 1, peak: 1) }
    T.equal(ReviewPlanner.unsure(in: casual, words: [], threshold: nil, odd: flat, oddAbove: 10, sources: .init()).map(\.word),
            ["Prabjot"], "casual grammar (\"want\", 15) stays; a name (12) is underlined")
    T.expect(OrdinaryWords.contains("models") && OrdinaryWords.contains("reasoning") && OrdinaryWords.contains("running"),
             "everyday words in any form")
    T.expect(!OrdinaryWords.contains("Prabjot") && !OrdinaryWords.contains("PC") && !OrdinaryWords.contains("Luffy"),
             "names and acronyms aren't everyday words")
    T.expect(OrdinaryWords.sameWord("model", "Models") && !OrdinaryWords.sameWord("cloud", "Claude"), "forms of one word")

    T.begin("Review — screen words don't underline everyday words")
    let screen = ReviewAlternatives.Sources(screenTerms: ["Models", "General", "Kavya"])
    T.equal(ReviewAlternatives.soundAlikes(in: "the model is general, ask Cavya", sources: screen).map(\.word), ["Cavya"],
            "\"model\" ~ \"Models\" isn't underlined; a misheard name still is")
}

private final class FailingScorer: ContextScorer {
    func logProbability(of text: String, after prefix: String) -> Double? { nil }
}
