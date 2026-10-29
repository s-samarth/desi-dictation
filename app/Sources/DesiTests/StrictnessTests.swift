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
}

private final class FailingScorer: ContextScorer {
    func logProbability(of text: String, after prefix: String) -> Double? { nil }
}
