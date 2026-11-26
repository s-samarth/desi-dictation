import DesiDictationKit
import Foundation

@MainActor
func runRepeatedLearningTests() {
    T.begin("Review — learn once and reuse on later dictations")
    let path = T.tempFile("dictionary.json")
    let dictionary = PersonalDictionary(fileURL: path)
    let choices = ReviewPlanner.fixes(from: "sath bolo sath", to: "saath bolo saath")
    T.equal(choices, [EditPair(heard: "sath", typed: "saath")], "two occurrences produce one Review choice")
    let rows = choices.map { ($0, EntryMode.always as EntryMode?) }
    let log = VocabularyActivityLog.shared
    ReviewPlanner.remember(rows, scope: .hinglish, dictionary: dictionary)
    let firstID = dictionary.entries.first?.id
    let firstActivity = log.entries.first?.id

    let reopened = PersonalDictionary(fileURL: path)
    ReviewPlanner.remember(rows, scope: .hinglish, dictionary: reopened)
    T.equal(reopened.entries.first?.id, firstID, "the same choice in another review retains the saved entry")
    T.equal(log.entries.first?.id, firstActivity, "already learned choices add no new activity")

    let style = HinglishStyle(rules: [.shortA])
    let entries = reopened.entries(for: .hinglish)
    T.equal(
        style.applyingDictionary(to: "mere sath aur saath", entries: entries), "mere saath aur saath",
        "both the recognized variant and the saved spelling survive the active short-a habit")
    let phrase = DictionaryEntry(heard: "do naam", written: "saara vaala", scope: .hinglish)
    let mixed = HinglishStyle(rules: [.shortA, .wNotV])
    T.equal(
        mixed.applyingDictionary(to: "do naam aur vaala", entries: [phrase], lexicon: WordLexicon(words: [])),
        "saara vaala aur wala", "the whole dictionary phrase is protected only where it occurs")

    T.equal(
        reopened.add(heard: "sath", written: "Saath", scope: .hinglish), .saved,
        "a genuinely changed written form can still be learned")
    T.equal(
        reopened.add(heard: "sath", written: "saath", scope: .english), .saved,
        "the same rule can be saved independently in another language")
    let inaccessible = PersonalDictionary(fileURL: path.appendingPathComponent("invalid-file"))
    T.equal(inaccessible.add(heard: "sath", written: "saath"), .failed, "a failed write is reported")
    T.expect(inaccessible.entries.isEmpty, "a failed write cannot masquerade as a saved rule")
}
