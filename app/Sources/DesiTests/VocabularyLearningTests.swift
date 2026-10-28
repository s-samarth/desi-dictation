import Foundation
import DesiDictationKit

/// Auto vocabulary, part 2: learning from edits, screen terms, hotwords.
func runVocabularyLearningTests() {
    T.begin("Vocabulary — edit diff")
    let pasted = "send it to Rowan today"
    T.equal(EditDiff.pairs(before: "Hi! " + pasted, after: "Hi! send it to Rohan today", inserted: pasted),
            [EditPair(heard: "Rowan", typed: "Rohan")], "one retyped word")
    T.equal(EditDiff.pairs(before: pasted, after: pasted + " please, thanks", inserted: pasted),
            [], "typing after our text isn't a correction")
    T.equal(EditDiff.pairs(before: "Dear team, " + pasted, after: "Dear all, " + pasted, inserted: pasted),
            [], "edits outside our text are ignored")
    T.equal(EditDiff.pairs(before: pasted, after: "can you forward the deck to Priya by noon", inserted: pasted),
            [], "a rewrite isn't a spelling fix")
    T.equal(EditDiff.pairs(before: "meet Sara swat at 5", after: "meet Saraswat at 5", inserted: "meet Sara swat at 5"),
            [EditPair(heard: "Sara swat", typed: "Saraswat")], "two words joined")
    T.equal(EditDiff.pairs(before: "ok ok", after: "ok OK", inserted: "ok", caretUTF16: 5),
            [EditPair(heard: "ok", typed: "OK")], "caret picks the right copy")

    T.begin("Vocabulary — what gets proposed")
    func propose(_ heard: String, _ typed: String, mode: LanguageMode = .english,
                 dictionary: [DictionaryEntry] = []) -> Bool {
        CorrectionLearner.proposal(for: EditPair(heard: heard, typed: typed), mode: mode,
                                   dictionary: dictionary, rejected: []) != nil
    }
    T.expect(propose("Rowan", "Rohan"), "name respelling is proposed")
    T.expect(propose("Saraswath", "Saraswat"), "misspelled surname is proposed")
    T.expect(propose("kavya", "Kavya"), "capitalizing a name is proposed")
    T.expect(propose("nahin", "nahi", mode: .hinglish), "Hinglish style edit is proposed")
    T.expect(!propose("nahin", "nahi", mode: .english), "…but not in English mode")
    T.expect(!propose("their", "there"), "grammar between common words is not")
    T.expect(!propose("the", "The"), "sentence-start capital is not")
    T.expect(!propose("deploy", "deployed"), "an inflection is not")
    T.expect(!propose("meeting", "standup"), "a different word is not")
    T.expect(!propose("raha", "rahi", mode: .hinglish), "Hinglish gender change is not")
    T.expect(!propose("Rowan", "Rohan", dictionary: [DictionaryEntry(heard: "rowan", written: "Rohan")]),
             "a pair already in the dictionary is not")
    T.expect(CorrectionLearner.proposal(for: EditPair(heard: "Rowan", typed: "Rohan"), mode: .english,
                                        dictionary: [], rejected: [WordFix.pairKey(from: "Rowan", to: "Rohan")]) == nil,
             "a rejected pair is never proposed again")

    T.begin("Vocabulary — the user's edit is respected")
    let fixes = [WordFix(from: "Rowan", to: "Rohan", source: .screen)]
    T.equal(CorrectionLearner.revertedFix(EditPair(heard: "Rohan", typed: "Rowan"), fixes: fixes), fixes.first,
            "typing our fix back is detected")
    T.equal(CorrectionLearner.revertedFix(EditPair(heard: "Rohan", typed: "Rohit"), fixes: fixes), nil,
            "a different edit is not an undo")
    let store = AutoVocabularyStore(fileURL: T.tempFile("autovocab.json"),
                                    defaults: UserDefaults(suiteName: "desi-tests-\(UUID().uuidString)")!)
    store.respect(fixes[0])
    T.expect(store.rejected.contains(fixes[0].pairKey), "an undone fix is never applied again")
    T.expect(store.liveAcknowledgement != nil, "…and the user is told so")
    T.expect(!store.learnFromEdits && !store.fixNearMisses && !store.readScreen && !store.hinglishFieldSpelling,
             "every switch is off by default")
    let dict = PersonalDictionary(fileURL: T.tempFile("dict.json"))
    store.propose(EditPair(heard: "Saraswath", typed: "Saraswat"))
    store.propose(EditPair(heard: "saraswath", typed: "Saraswat"))
    T.equal(store.suggestions.count, 1, "duplicate proposals collapse")
    store.accept(store.suggestions[0], into: dict)
    T.equal(dict.entries.map { $0.written }, ["Saraswat"], "Add puts it in the dictionary")
    T.expect(store.suggestions.isEmpty && store.liveSuggestion == nil, "…and clears the prompt")
    store.propose(EditPair(heard: "Kavia", typed: "Kavya"))
    store.dismiss(store.suggestions[0])
    store.propose(EditPair(heard: "Kavia", typed: "Kavya"))
    store.dismiss(store.suggestions[0])
    store.propose(EditPair(heard: "Kavia", typed: "Kavya"))
    T.expect(store.suggestions.isEmpty, "two 'Not now's mean never")

    T.begin("Vocabulary — screen terms")
    let terms = TermExtractor.terms(from: [
        "Rohan Mehta",
        "Hey, did Rohan share the Figma file? The iPhone build is with McKinsey.",
        "Milenge kal. kya scene hai",
    ])
    T.expect(terms.contains("Rohan") && terms.contains("Mehta"), "name label kept", "\(terms)")
    T.expect(terms.contains("Figma") && terms.contains("iPhone") && terms.contains("McKinsey"),
             "mid-sentence capitals and CamelCase kept", "\(terms)")
    T.expect(!terms.contains("Milenge") && !terms.contains("Hey") && !terms.contains("The"),
             "sentence-start words dropped", "\(terms)")
    T.expect(!terms.contains("scene") && !terms.contains("kal"), "lowercase words dropped", "\(terms)")
    T.equal(terms.first, "Rohan", "most frequent first")
    let many = TermExtractor.terms(from: (0..<400).map { "Hi Name\(String(UnicodeScalar(65 + $0 % 26)!))x\($0)" })
    T.expect(many.count <= TermExtractor.maxTerms, "capped")

    T.begin("Vocabulary — hotword selection (Qwen3-ASR)")
    let hot = HotwordSelector.select(
        fieldTerms: ["Figma", "Rohan"], windowTerms: ["Slack", "Priya", "Rohan"],
        dictionary: ["Saraswat", "figma"])
    T.equal(hot, ["Figma", "Rohan", "Slack", "Priya", "Saraswat"],
            "ordered field → window → dictionary, deduped")
    let capped = HotwordSelector.select(fieldTerms: (0..<50).map { "Term\($0)" }, windowTerms: [],
                                        dictionary: [])
    T.equal(capped.count, HotwordSelector.limit, "at most 30 hotwords")
    T.equal(HotwordSelector.contextPrompt(["Rohan", "Figma"]), "Vocabulary: Rohan, Figma.", "context prompt")
    T.equal(HotwordSelector.contextPrompt([]), "", "no terms → no prompt")
}
