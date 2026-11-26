import DesiDictationKit
import Foundation

private final class MeaningScorer: ContextScorer {
    var seen: [String] = []
    var delta = 3.0

    func logProbability(of text: String, after prefix: String) -> Double? {
        seen.append(text)
        return text.contains(" काम ") ? delta : 0
    }
}

@MainActor
func runMeaningReviewTests() {
    T.begin("Hinglish — meaning choices in Review")
    let example = "Aaj kaam kam hai."
    let both = HinglishMeanings.questions(in: example)
    T.equal(both.map(\.word), ["kaam", "kam"], "same sentence can contain work and less")
    T.equal(both.map { String(example[$0.range]) }, ["kaam", "kam"], "each underline targets its own occurrence")
    T.equal(
        HinglishMeanings.questions(in: "📌 @kam kam.com on par with my pal").count, 0,
        "handles, domains and English uses of par/pal stay quiet")
    T.equal(HinglishMeanings.label("Kaam"), "Kaam · work", "labels explain meanings and preserve case")
    let text = "Office. mera kam baaki hai. Noise."
    let items = HinglishMeanings.questions(in: text)
    guard let item = items.first, let context = item.meaning else {
        T.expect(false, "expected a meaning question")
        return
    }
    let scorer = MeaningScorer()
    T.equal(context.recommendation(using: scorer), "kaam", "rank the alternative in context")
    T.equal(scorer.seen, ["मेरा कम बाक़ी है", "मेरा काम बाक़ी है"], "compare just the two readings in the same sentence")
    scorer.delta = 0.5
    T.equal(context.recommendation(using: scorer), nil, "close scores leave both choices neutral")
    T.equal(context.recommendation(using: nil), nil, "without a model both buttons still work")
    let style = HinglishStyle(rules: [.shortA])
    T.equal(style.apply(example, lexicon: WordLexicon(words: [])), example, "a broad spelling habit preserves meaning")

    if let crossing = HinglishMeanings.questions(in: "sadak paar karo").first?.meaning {
        T.equal(crossing.recommendation(using: scorer), nil, "par/paar waits for personal evidence")
    } else {
        T.expect(false, "par/paar still offers both meanings")
    }
    let unclear = ReviewPlanner.unsure(
        in: example, words: [ScoredWord(text: "kaam", confidence: 0.1)],
        threshold: 0.8, sources: .init(entries: [], screenTerms: []))
    let merged = HinglishMeanings.merge(unclear, questions: both)
    T.equal(merged.map(\.word), ["kaam", "kam"], "confidence and meaning share one underline per word")

    let dictionary = PersonalDictionary(fileURL: T.tempFile("meaning-words.json"))
    dictionary.add(heard: "kam", written: "kaam", scope: .hinglish)
    if let rule = dictionary.entries.first {
        T.equal(
            style.applyingDictionary(to: example, entries: [rule]), "Aaj kaam kaam hai.",
            "an existing Always entry remains active")
        dictionary.setMode(.whenItFits, for: rule)
        T.equal(
            style.applyingDictionary(to: example, entries: dictionary.entries), example,
            "Suggest in Learning keeps both readings available")
        T.equal(dictionary.entries.first?.id, rule.id, "changing mode preserves the entry")
        dictionary.setMode(.always, for: rule)
        T.equal(dictionary.entries.first, rule, "Always can be restored")
    }

    let suite = "meaning-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = HinglishLearning(defaults: defaults)
    let choices = store.meaningChoices
    choices.remember(original: text, final: text, confirmed: [])
    T.equal(choices.preferred(for: context), nil, "plain Paste teaches no meaning")
    choices.remember(original: text, final: "Office. mera kaam baaki hai. Noise.", confirmed: [])
    let reopened = HinglishLearning(defaults: defaults).meaningChoices
    T.equal(reopened.preferred(for: context), "kaam", "a corrected occurrence survives relaunch")
    T.equal(reopened.questions(in: "mera kaam baaki hai").count, 0, "confirmed correct form needs no new question")
    T.equal(reopened.questions(in: "mera kam baaki hai").count, 1, "the other reading remains editable")
    T.equal(reopened.questions(in: "chai mein cheeni kam daalo").count, 1, "a different context keeps its own meaning")
    choices.remember(original: text, final: text, confirmed: Set([context.key!]))
    T.equal(choices.preferred(for: context), "kam", "explicitly keeping the word can revise the earlier hint")
    store.forgetAll()
    T.equal(choices.preferred(for: context), nil, "Forget clears the contextual hints in this suite")

    let ambiguous = "mera kam baaki hai. mera kam baaki hai."
    choices.remember(original: ambiguous, final: ambiguous.replacingOccurrences(of: "kam", with: "kaam"), confirmed: [])
    T.equal(choices.preferred(for: context), nil, "duplicate contexts cannot misattribute a confirmation")
    T.expect(
        HinglishMeanings.isMeaningChange(EditPair(heard: "Kaam", typed: "kam")), "semantic swaps bypass global learning"
    )
    T.expect(
        !HinglishMeanings.isMeaningChange(EditPair(heard: "nahin", typed: "nahi")),
        "ordinary spelling learning stays available")
}

/// Optional local smoke test. It runs the production context conversion and
/// suggestion threshold with a real checker. CI uses deterministic tests above.
func runMeaningModelSample() -> Int32 {
    guard let scorer = LlamaContextScorer(modelPath: ContextChecker.modelURL.path) else {
        print("Local context checker unavailable.")
        return 1
    }
    let samples = [
        ("mujhe apna kam poora karna hai", "kam", "kaam"), ("chai mein cheeni kaam karo", "kaam", "kam"),
        ("mera kaam baaki hai", "kaam", "kaam"), ("budget kam hai", "kam", "kam"),
        ("usne kahan ki meeting hogi", "kahan", "kaha"), ("mera phone kaha hai", "kaha", "kahan"),
        ("maine kaha ghar jao", "kaha", "kaha"), ("tum kahan ja rahe ho", "kahan", "kahan"),
        ("har deen office jaata hu", "deen", "din"), ("apne din aur imaan ki baat karo", "din", "deen"),
        ("aaj ka din accha tha", "din", "din"), ("uska deen aur imaan mazboot hai", "deen", "deen"),
        ("nadi par karni hai", "par", "paar"), ("table paar kitaab hai", "paar", "par"),
        ("sadak paar karo", "paar", "paar"), ("ghar par koi hai", "par", "par"),
        ("ek paal ruko", "paal", "pal"), ("bacche pal rahe hain woh", "pal", "paal"),
        ("har pal yaad aata hai", "pal", "pal"), ("woh kutta paal raha hai", "paal", "paal"),
    ]
    // Separate examples added after choosing the par/paar abstention policy.
    let heldOut = [
        ("office ka kam pending hai", "kam", "kaam"), ("volume thoda kaam karo", "kaam", "kam"),
        ("boss ne kahan tha", "kahan", "kaha"), ("invoice kaha bhejna hai", "kaha", "kahan"),
        ("teen deen ki chhutti hai", "deen", "din"), ("apna deen aur imaan yaad rakho", "deen", "deen"),
        ("pul paar karke aao", "paar", "paar"), ("file desk par hai", "par", "par"),
        ("bas do paal ruk jao", "paal", "pal"), ("ghar mein billi pal raha hai", "pal", "paal"),
    ]
    return measure(samples, with: scorer) && measure(heldOut, with: scorer) ? 0 : 1
}

private func measure(_ samples: [(String, String, String)], with scorer: ContextScorer) -> Bool {
    var correct = 0
    var wrong = 0
    var neutral = 0
    for (sentence, heard, expected) in samples {
        guard let context = HinglishMeanings.questions(in: sentence).first(where: { $0.word == heard })?.meaning else {
            print("Missing question in sample: \(sentence)")
            return false
        }
        let hint = context.recommendation(using: scorer)
        if hint == nil { neutral += 1 } else if hint == expected { correct += 1 } else { wrong += 1 }
        print("\(sentence) | expected \(expected) | hint \(hint ?? "neutral")")
    }
    print(
        "Meaning hints: \(correct) correct, \(wrong) wrong, \(neutral) neutral / \(samples.count) synthetic sentences")
    return true
}
