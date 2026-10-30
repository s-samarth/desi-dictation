import Foundation
import DesiDictationKit

/// The watcher's timing rules, on the case that exposed them: "Samar
/// Saraswath" fixed in a chat box, then sent with Enter (FM#37).
func runEditTrackerTests() {
    T.begin("Vocabulary — edit timing (chat boxes)")
    let said = "I just wanted to say my name is Samar Saraswath."
    let fixed = "I just wanted to say my name is Samarth Saraswat."
    let t0 = Date()
    func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    var sent = EditTracker(baseline: said, inserted: said, started: t0)
    T.expect(sent.observe(said, now: at(0.3)).pairs == nil, "no edit yet, nothing judged")
    T.expect(sent.observe(fixed, now: at(4)).pairs == nil, "mid-edit, not judged before it settles")
    let onSend = sent.observe("", now: at(4.3))
    T.expect(!(onSend.pairs ?? []).isEmpty, "Enter right after the fix still judges the fixed text")
    T.expect(!onSend.keepGoing, "…and the watch ends once the message is sent")

    var paused = EditTracker(baseline: said, inserted: said, started: t0)
    _ = paused.observe(fixed, now: at(3))
    T.expect(!(paused.observe(fixed, now: at(5.1)).pairs ?? []).isEmpty, "a 2 s pause judges the edit")
    T.expect(paused.observe(fixed, now: at(6)).pairs == nil, "the same edit is judged once")

    var untouched = EditTracker(baseline: said, inserted: said, started: t0)
    T.expect(untouched.observe("", now: at(2)).pairs == nil, "sent without edits: nothing to learn")
}
