import Foundation

/// The edit watcher's judgment, without Accessibility: given the field's
/// text over time, when is an edit finished, and what changed? Pure, so the
/// timing rules are testable (VocabularyLearningTests).
public struct EditTracker {
    public let inserted: String
    public let baseline: String
    let caret: Int?
    let started: Date
    var lastValue: String
    var lastChange: Date
    var evaluated: String?

    public init(baseline: String, inserted: String, caret: Int? = nil, started: Date = Date()) {
        self.baseline = baseline
        self.inserted = inserted
        self.caret = caret
        self.started = started
        lastValue = baseline
        lastChange = started
    }

    /// One look at the field (`nil` = focus moved away). `pairs` is nil when
    /// nothing was judged; `keepGoing` false ends the watch.
    public mutating func observe(_ current: String?, now: Date) -> (pairs: [EditPair]?, keepGoing: Bool) {
        var value = current
        // Sent: a chat box emptied (or nearly) right after the edit. Judge
        // the text as it was just before, then stop watching.
        if let current, current.count * 2 < lastValue.count { value = nil }
        if let value, value != lastValue {
            lastValue = value
            lastChange = now
        }
        // Focus moved on, sent, or time's up: judge the last state, stop.
        let ending = value == nil || now.timeIntervalSince(started) >= EditWatcher.window
        let settled = now.timeIntervalSince(lastChange) >= EditWatcher.settle
        guard settled || ending, lastValue != baseline, lastValue != evaluated else {
            return (nil, !ending)
        }
        evaluated = lastValue
        return (EditDiff.pairs(before: baseline, after: lastValue, inserted: inserted, caretUTF16: caret), !ending)
    }
}
