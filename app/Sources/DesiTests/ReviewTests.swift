import Foundation
import DesiDictationKit

/// Review before paste (REVIEW_BEFORE_PASTE.md): word confidence, what gets
/// underlined, and what's offered instead. All pure; the panel is UI.
func runReviewTests() {
    T.begin("Review — words assembled from engine tokens")
    var assembler = WordAssembler()
    assembler.add(Array(" What".utf8), p: 0.99, startsWord: true)
    assembler.add(Array(" hak".utf8), p: 0.40, startsWord: true)
    assembler.add(Array("ka".utf8), p: 0.90, startsWord: false)
    assembler.add(Array("?".utf8), p: .nan, startsWord: false)
    var words = assembler.finish()
    T.equal(words.map(\.text), ["What", "hakka?"], "a word ends at the next leading space")
    T.equal(words.last?.confidence, 0.40, "a word is as sure as its weakest token")
    let ki = Array("की".utf8)      // one Devanagari syllable, split across two tokens
    assembler.add(Array(ki[0..<4]), p: 0.8, startsWord: true)
    assembler.add(Array(ki[4...]), p: 0.7, startsWord: false)
    words = assembler.finish()
    T.equal(words.map(\.text), ["की"], "split UTF-8 is joined before decoding")
    assembler.add(Array("\u{2581}hello".utf8), p: 2, startsWord: true)
    T.expect(assembler.finish().first?.confidence.isNaN ?? false, "out-of-range p counts as unknown")

    T.begin("Review — unsure words land on the final text")
    let scored = [ScoredWord(text: "what", confidence: 0.99), ScoredWord(text: "does", confidence: 0.96),
                  ScoredWord(text: "a", confidence: 0.98), ScoredWord(text: "hakka", confidence: 0.39),
                  ScoredWord(text: "symbolize?", confidence: 0.65)]
    var unsure = UnsureWords.find(in: "What does a hakka symbolize?", scored: scored, threshold: 0.61)
    T.equal(unsure.map(\.word), ["hakka"], "only words under the threshold")
    T.equal(unsure.first?.confidence, 0.39, "…with their confidence")
    unsure = UnsureWords.find(in: "Pay ₹2,50,000 to Hakka, now.",
                              scored: [ScoredWord(text: "pay", confidence: 0.9),
                                       ScoredWord(text: "do", confidence: 0.1),
                                       ScoredWord(text: "lakh", confidence: 0.2),
                                       ScoredWord(text: "pachaas", confidence: 0.2),
                                       ScoredWord(text: "hazaar", confidence: 0.2),
                                       ScoredWord(text: "to", confidence: 0.9),
                                       ScoredWord(text: "hakka", confidence: 0.3),
                                       ScoredWord(text: "now", confidence: 0.9)], threshold: 0.6)
    T.equal(unsure.map(\.word), ["Hakka"], "words our own rules wrote (numbers) are never underlined")
    T.equal(unsure.first?.reason, .unclear, "…because the audio was unclear")

    T.begin("Review — alternatives come from the user's own words")
    let sources = ReviewAlternatives.Sources(
        entries: [DictionaryEntry(heard: "Saraswath", written: "Saraswat"),
                  DictionaryEntry(heard: "cloud", written: "Claude", mode: .whenItFits)],
        screenTerms: ["Kavya", "Tazapay"])
    T.equal(ReviewAlternatives.candidates(for: "Saraswath", sources: sources).first, "Saraswat",
            "a dictionary pair comes first")
    T.equal(ReviewAlternatives.candidates(for: "Cavya", sources: sources), ["Kavya"], "a sound-alike on screen")
    T.equal(ReviewAlternatives.candidates(for: "Kavya", sources: sources), [], "never the word itself")
    T.equal(ReviewAlternatives.candidates(for: "banana", sources: sources), [], "nothing that sounds different")
    let alike = ReviewAlternatives.soundAlikes(in: "I asked cloud and Cavya about the plan", sources: sources)
    T.equal(alike.map(\.word), ["cloud", "Cavya"], "named pairs and uncommon sound-alikes are underlined")
    T.expect(alike.allSatisfy { $0.confidence == nil }, "…marked as sound-alikes, not low confidence")
    var judgedSources = sources
    judgedSources.judged = ["cloud"]
    T.equal(ReviewAlternatives.soundAlikes(in: "data in the cloud", sources: judgedSources), [],
            "a word the context checker already judged isn't underlined again")

    T.begin("Review — when the panel opens")
    let plain = ReviewPlanner.unsure(in: "all good here", words: [], threshold: 0.6, sources: .init())
    T.expect(!ReviewPlanner.opens(.off, unsure: alike), "Off never opens")
    T.expect(ReviewPlanner.opens(.unsure, unsure: alike), "Only when unsure opens on an unsure word")
    T.expect(!ReviewPlanner.opens(.unsure, unsure: plain), "…and not without one")
    T.expect(ReviewPlanner.opens(.always, unsure: plain), "Always opens every time")
    let merged = ReviewPlanner.unsure(in: "I asked cloud about hakka", words: [
        ScoredWord(text: "I", confidence: 0.9), ScoredWord(text: "asked", confidence: 0.9),
        ScoredWord(text: "cloud", confidence: 0.3), ScoredWord(text: "about", confidence: 0.9),
        ScoredWord(text: "hakka", confidence: 0.2)], threshold: 0.6, sources: sources)
    T.equal(merged.map(\.word), ["cloud", "hakka"], "low confidence and sound-alikes, in text order, once each")
    T.equal(merged.first?.alternatives, ["Claude"], "a low-confidence word still gets its alternatives")

    T.begin("Review — fixes made in the panel")
    T.equal(ReviewPlanner.fixes(from: "my name is Samar Saraswath", to: "my name is Samarth Saraswat"),
            [EditPair(heard: "Samar", typed: "Samarth"), EditPair(heard: "Saraswath", typed: "Saraswat")],
            "each retyped word is a fix to remember")
    T.equal(ReviewPlanner.fixes(from: "send it today", to: "please send it today"), [],
            "added words aren't fixes")
    T.equal(ReviewPlanner.fixes(from: "a b c d e f", to: "u v w x y z"), [], "a rewrite isn't a fix")

    T.begin("Review — guessed fixes are offered, never applied")
    let guessed = [WordFix(from: "plus", to: "PRs", source: .screen)]
    let offered = ReviewPlanner.unsure(in: "A surplus, plus one", words: [], threshold: nil,
                                       suggested: guessed, sources: .init())
    T.equal(offered.map(\.word), ["plus"], "the word itself, not inside \"surplus\"")
    T.equal(offered.first?.alternatives.first, "PRs", "…with the guess as choice 1")
    T.equal(offered.first?.reason, .suggested, "…and it says why")
}
