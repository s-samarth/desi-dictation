import DesiDictationKit
import Foundation

@MainActor
func runReviewSpellingTests() {
    T.begin("Review — spelling choices survive the next dictation")
    let suite = "desi-review-tests-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = HinglishLearning(defaults: defaults)
    store.review = .learning
    let url = T.tempFile("dictionary.json")
    let dict = PersonalDictionary(fileURL: url)
    dict.add(heard: "Codecs", written: "Codex", scope: .english)

    func review(_ original: String, replace: String, with edited: String, always: Bool = true) {
        let questions = HinglishLearning.spellingWords(in: original, style: store.style)
        let text = NSMutableAttributedString(string: original)
        ReviewSpellingMarks.mark(text, questions: questions)
        let range = (original as NSString).range(of: replace)
        text.replaceCharacters(in: range, with: NSAttributedString(string: edited))
        let changes = ReviewPlanner.fixes(from: original, to: text.string)
        let kept = always ? changes : []
        ReviewPlanner.remember(kept.map { ($0, .always) }, scope: .hinglish, dictionary: dict)
        store.finish(
            unchangedSpellings: ReviewSpellingMarks.surviving(in: text, questions: questions),
            edited: original != text.string, changes: changes, kept: kept, adopt: [], decline: [])
    }

    review("nahin bolo nhi", replace: "nahin", with: "nahi")
    let reloaded = HinglishLearning(defaults: defaults)
    let saved = PersonalDictionary(fileURL: url)
    let text = reloaded.style.applyingDictionary(to: "nahin aur nhi", entries: saved.entries(for: .hinglish))
    T.equal(text, "nahi aur nahi", "explicit choice wins after reloading both stores")
    T.equal(saved.entries(for: .english).map(\.written), ["Codex"], "English vocabulary stays separate")

    review("mujhe coffee do", replace: "mujhe ", with: "")
    T.equal(store.style.preferred["mujhe"], nil, "deleting a marked word never approves its spelling")
    T.equal(store.cleanStreak, 0, "a deletion counts as editing")
    review("chaahie ya chahie", replace: "chaahie", with: "chahiye", always: false)
    T.equal(store.style.preferred["chahiye"], nil, "a one-time edit leaves its group undecided")
    review("kal vaise hi", replace: "kal", with: "aaj")
    T.equal(store.style.preferred["waise"], "vaise", "an intact question survives edits elsewhere")
    review("vo ya woh", replace: "ya", with: "aur")
    T.equal(store.style.preferred["woh"], nil, "two untouched variants express no single preference")
    review("thoda", replace: "da", with: "di")
    T.equal(store.style.preferred["thoda"], nil, "partial replacement cannot approve the old word")
}
