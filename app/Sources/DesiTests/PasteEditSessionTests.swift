import DesiDictationKit
import Foundation

func runPasteEditSessionTests() {
    T.begin("Vocabulary — paste destination and focus changes")
    typealias Watch = PasteEditSession<Int>
    let start = Date()
    let pasted = "yeh kyaa hai"
    let fixed = "yeh kya hai"
    let expected = [EditPair(heard: "kyaa", typed: "kya")]
    func tick(_ watch: inout Watch, _ field: Int?, _ value: String?, _ seconds: Double) -> Watch.Event? {
        watch.sample(
            focused: field, now: start.addingTimeInterval(seconds),
            value: { _ in value }, caret: { _ in nil })
    }

    var slow = Watch(inserted: pasted, target: nil, started: start)
    T.equal(tick(&slow, nil, nil, 0.4), nil, "an AX tree can still be loading")
    T.equal(tick(&slow, 1, "older text", 1), nil, "paste delivery can lag the AX field")
    T.equal(tick(&slow, 1, pasted, 2.9), .watching, "late Electron field starts a watch")
    T.equal(tick(&slow, nil, nil, 4), nil, "switching away pauses")
    var readOtherField = false
    let other = slow.sample(
        focused: 2, now: start.addingTimeInterval(6),
        value: { _ in
            readOtherField = true
            return fixed
        }, caret: { _ in nil })
    T.expect(other == nil && !readOtherField, "another chat's field is never read")
    T.equal(tick(&slow, 1, fixed, 8), nil, "return to the original field and fix a word")
    T.equal(tick(&slow, nil, nil, 8.3), .edited(expected), "switching right after an observed edit flushes it")
    T.equal(tick(&slow, 1, fixed, 12), nil, "returning does not repeat the suggestion")
    _ = tick(&slow, nil, nil, 121)
    T.expect(slow.finished, "time spent away counts toward the two-minute limit")

    var pinned = Watch(inserted: pasted, target: 1, started: start)
    T.equal(tick(&pinned, 2, pasted, 0.1), nil, "same text in another field cannot start the watch")
    T.equal(tick(&pinned, 1, pasted, 1), .watching, "paste-time field can return before attachment")
    _ = tick(&pinned, 1, fixed, 2)
    T.equal(tick(&pinned, 1, "", 2.3), .edited(expected), "sending a corrected chat keeps the last edit")
    T.expect(pinned.finished, "sending stops the watch")

    var privateField = Watch(inserted: pasted, target: 1, started: start)
    T.equal(tick(&privateField, 1, nil, 3.1), .fieldUnavailable, "unreadable field has its own outcome")
    var unmatched = Watch(inserted: pasted, target: nil, started: start)
    _ = tick(&unmatched, 1, "some other text", 0.4)
    T.equal(tick(&unmatched, nil, nil, 3.1), .pasteUnverified, "a readable field without our paste is distinguished")
    T.equal(tick(&unmatched, 1, pasted, 4), nil, "an expired startup never attaches later")

    MainActor.assumeIsolated {
        let log = VocabularyActivityLog.shared
        let count = log.entries.count
        log.addFieldDiagnostic("QA field unavailable")
        log.addFieldDiagnostic("QA field unavailable")
        T.equal(log.entries.count, min(count + 1, VocabularyActivityLog.limit), "repeated field failures share one row")
    }
}
