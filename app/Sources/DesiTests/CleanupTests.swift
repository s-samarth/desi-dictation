import Foundation
import DesiDictationKit

/// Filler clean-up and spoken corrections (FILLERS_AND_CORRECTIONS.md):
/// the rule parts. The checker's verdicts are measured by `desi-cli --fillers`.
func runCleanupTests() {
    T.begin("Clean-up — taking a word out keeps the sentence right")
    func without(_ word: String, _ text: String) -> String {
        TextSpans.removing(text.range(of: word)!, from: text)
    }
    T.equal(without("uh", "I, uh, think so"), "I think so", "between commas: both go")
    T.equal(without("Um", "Um, I think so"), "I think so", "at the start: the next word leads")
    T.equal(without("um", "I think so, um."), "I think so.", "at the end: before the full stop")
    T.equal(without("like", "it was like really big"), "it was really big", "mid-sentence")
    T.equal(without("so", "Done. so we ship"), "Done. We ship", "a new sentence is capitalised")

    T.begin("Clean-up — um and uh go, real words stay")
    T.equal(Fillers.removeSounds("Um, so I, uh, think we should, hmm, ship it, er, today"),
            "So I think we should ship it today", "um, uh, hmm, er")
    T.equal(Fillers.removeSounds("Ummm the uhh build"), "The build", "drawn-out sounds")
    T.equal(Fillers.removeSounds("Huh, that's all. Uh-huh, done. Umbrella and hummus."),
            "Huh, that's all. Uh-huh, done. Umbrella and hummus.", "huh, uh-huh and words that start like them stay")

    T.begin("Clean-up — spoken corrections are found, not applied")
    func fix(_ text: String) -> [String] {
        Corrections.find(in: text).map { "\(text[$0.range]) → \($0.replacement)" }
    }
    T.equal(fix("Let's meet at 2, no, make it 3 tomorrow."), ["2, no, make it 3 tomorrow → 3 tomorrow"], "no, make it")
    T.equal(fix("Send it to Rohan, sorry, Rahul."), ["Rohan, sorry, Rahul → Rahul"], "a name for a name")
    T.equal(fix("We need five, no, six chairs."), ["five, no, six chairs → six chairs"], "a number for a number")
    T.equal(fix("Ship it Monday, actually Tuesday."), ["Monday, actually Tuesday → Tuesday"], "a day for a day")
    T.equal(fix("I think we should meet at two. No, make it three tomorrow."),
            ["two. No, make it three tomorrow → three tomorrow"], "a new sentence: \". No, make it\" (live, 2026-10-29)")
    T.equal(fix("Meet at two. No wait, three."), ["two. No wait, three → three"], "a new sentence: \". No wait\"")
    T.equal(fix("We had two. No, three people came. Was it two? No, make it three."), [],
            "at a sentence start \"No\" alone is an answer; after a question too")
    T.equal(fix("Monday works, scratch that, Tuesday works."), ["Monday works, scratch that,  → "],
            "scratch that: the taken-back words")
    T.equal(fix("I said no, make it simple. He tried to call, no answer. It's fine, actually it's great."), [],
            "no correction without a comma before \"no\", or of a different kind")

    T.begin("Clean-up — review gets corrections; fillers need the checker")
    let items = CleanupReview.items(in: "Meet at 2, no, make it 3, like, today", mode: .english, scorer: nil, removeSounds: false)
    T.equal(items.map(\.reason), [.correction], "a correction; no checker, so no filler verdicts")
    T.equal(CleanupReview.items(in: "So, um, yes", mode: .english, scorer: nil, removeSounds: false).map(\.word), ["um"],
            "with \"Remove um and uh\" off, the sound is offered instead")
    T.equal(CleanupReview.items(in: "मीटिंग 2 बजे", mode: .hindi, scorer: nil, removeSounds: false).count, 0, "not for हिन्दी")
}
