import Foundation
import DesiDictationKit

/// Stands in for the llama model: scores text by the phrases it contains.
private final class FakeScorer: ContextScorer {
    var seen: [String] = []
    var fails = false

    func logProbability(of text: String, after prefix: String) -> Double? {
        seen.append(text)
        if fails { return nil }
        var score = 0.0
        if text.contains("asked Claude") || text.contains("Claude wrote") { score += 4 }
        if text.contains("the cloud") { score += 4 }
        if text.contains("the Claude") { score -= 4 }
        return score
    }
}

/// "When it fits" (CONTEXT_FIT.md): a pair applied only when the sentence
/// agrees. The model is faked here; the real one is tested with desi-cli --fit.
func runContextFitTests() {
    T.begin("Context fit — entries")
    let old = Data(#"[{"id":"7E1F2B0A-1C1D-4C3B-9F00-000000000001","heard":"cloud","written":"Claude"}]"#.utf8)
    let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: old)
    T.equal(decoded?.first?.mode, .always, "entries saved before modes stay Always")
    let fit = DictionaryEntry(heard: "cloud", written: "Claude", mode: .whenItFits)
    let roundTrip = (try? JSONEncoder().encode([fit])).flatMap { try? JSONDecoder().decode([DictionaryEntry].self, from: $0) }
    T.equal(roundTrip?.first?.mode, .whenItFits, "When it fits is saved")
    T.equal(PersonalDictionary.apply("data in the cloud", entries: [fit]), "data in the cloud",
            "the exact-pair step leaves When it fits words alone")

    T.begin("Context fit — the sentence decides")
    let scorer = FakeScorer()
    let prefix = ContextFit.prefix(terms: ["Claude"])
    var out = ContextFit.apply("I asked cloud to refactor this", entries: [fit], cues: FitCues(),
                               scorer: scorer, prefix: prefix)
    T.equal(out.text, "I asked Claude to refactor this", "swaps when the sentence is about Claude")
    T.equal(out.fixes, [WordFix(from: "cloud", to: "Claude", source: .context)], "…and records the fix")
    out = ContextFit.apply("all our data is in the cloud now", entries: [fit], cues: FitCues(),
                           scorer: scorer, prefix: prefix)
    T.equal(out.text, "all our data is in the cloud now", "keeps cloud when it means cloud")
    T.expect(out.decisions.first.map { !$0.swapped && ($0.modelDelta ?? 0) < 0 } ?? false,
             "…and says why", "\(out.decisions)")
    out = ContextFit.apply("I asked cloud about the cloud bill", entries: [fit], cues: FitCues(),
                           scorer: scorer, prefix: prefix)
    T.equal(out.text, "I asked Claude about the cloud bill", "each occurrence judged on its own")
    out = ContextFit.apply("Cloud wrote this test", entries: [fit], cues: FitCues(), scorer: scorer, prefix: prefix)
    T.equal(out.text, "Claude wrote this test", "sentence-start casing kept")
    out = ContextFit.apply("cloudy skies, clouds everywhere", entries: [fit], cues: FitCues(),
                           scorer: scorer, prefix: prefix)
    T.expect(out.decisions.isEmpty, "whole words only (cloudy, clouds untouched)")
    let always = DictionaryEntry(heard: "cloud", written: "Claude")
    T.expect(ContextFit.apply("I asked cloud", entries: [always], cues: FitCues(), scorer: scorer,
                              prefix: prefix).decisions.isEmpty, "Always entries aren't judged here")
    out = ContextFit.apply("I asked cloud to refactor this", entries: [fit], cues: FitCues(), scorer: scorer,
                           prefix: prefix, rejected: [WordFix.pairKey(from: "cloud", to: "Claude")])
    T.equal(out.text, "I asked cloud to refactor this", "a pair the user turned down isn't made")

    T.begin("Context fit — no model, or the model fails")
    let plain = "I asked cloud to refactor this"
    T.equal(ContextFit.apply(plain, entries: [fit], cues: FitCues(), scorer: nil, prefix: prefix).text,
            plain, "no model and no hint: nothing changes")
    T.equal(ContextFit.apply(plain, entries: [fit], cues: FitCues(screenTerms: ["Claude"]), scorer: nil,
                             prefix: prefix).text, "I asked Claude to refactor this", "on screen: swaps")
    T.equal(ContextFit.apply(plain, entries: [fit], cues: FitCues(appName: "Claude"), scorer: nil,
                             prefix: prefix).text, "I asked Claude to refactor this", "dictating into Claude: swaps")
    scorer.fails = true
    T.equal(ContextFit.apply(plain, entries: [fit], cues: FitCues(), scorer: scorer, prefix: prefix).text,
            plain, "a failed score never swaps on its own")
    scorer.fails = false
    T.equal(ContextFit.apply("our data sits in the cloud", entries: [fit], cues: FitCues(appName: "Claude"),
                             scorer: scorer, prefix: prefix).text,
            "our data sits in the cloud", "a strong sentence beats the app hint")

    T.begin("Context fit — compact prompt, short window")
    T.equal(ContextFit.prefix(terms: []), "Message:\n", "neutral prompt with no words")
    T.equal(ContextFit.prefix(terms: ["Claude", "Kavya", "claude"]), "Words I use: Claude, Kavya.\n",
            "deduped, one line")
    let many = ContextFit.prefix(terms: (0..<30).map { "Term\($0)" })
    T.equal(many.components(separatedBy: ", ").count, ContextFit.maxPrefixTerms, "capped")
    scorer.seen = []
    let long = (0..<40).map { "word\($0)" }.joined(separator: " ")
    _ = ContextFit.apply(long + " asked cloud " + long, entries: [fit], cues: FitCues(), scorer: scorer,
                         prefix: prefix)
    let longest = scorer.seen.map { $0.split(separator: " ").count }.max() ?? 0
    T.expect(longest <= 2 * ContextFit.windowWords + 1, "the model sees the sentence, not the dictation",
             "\(longest) words")

    T.begin("Context fit — the third button")
    let english = VocabularySuggestion(heard: "cloud", written: "Claude", scope: .english)
    let hinglish = VocabularySuggestion(heard: "nahin", written: "nahi", scope: .hinglish)
    T.expect(!AutoVocabularyStore.canOfferWhenItFits(hinglish), "never for Hinglish words")
    T.equal(AutoVocabularyStore.canOfferWhenItFits(english), LlamaContextScorer.isAvailable,
            "English words, even before the checker is downloaded")
    let store = AutoVocabularyStore(fileURL: T.tempFile("autovocab-fit.json"),
                                    defaults: UserDefaults(suiteName: "desi-tests-\(UUID().uuidString)")!)
    let dict = PersonalDictionary(fileURL: T.tempFile("dict-fit.json"))
    store.propose(EditPair(heard: "cloud", typed: "Claude"))
    store.acceptWhenItFits(store.suggestions[0], into: dict)
    T.equal(dict.entries.map(\.mode), [.whenItFits], "When it fits lands in Your words as When it fits")
    T.expect(store.suggestions.isEmpty, "…and clears the prompt")
}
