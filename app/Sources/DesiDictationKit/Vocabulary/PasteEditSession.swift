import Foundation

/// State for a single paste. Field identity comes from the destination app's
/// Accessibility element. Tests use simple IDs and a clock they can advance.
package struct PasteEditSession<Field: Equatable> {
    package enum Event: Equatable {
        case watching, fieldUnavailable, pasteUnverified
        case edited([EditPair])
    }

    private let inserted: String
    private let started: Date
    private var target: Field?
    private var tracker: EditTracker?
    private var sawReadableField = false
    package private(set) var finished = false

    package init(inserted: String, target: Field?, started: Date) {
        self.inserted = inserted
        self.target = target
        self.started = started
    }

    /// Read only the original field. A late AX tree may supply the initial
    /// element, but it must first contain the paste before learning can start.
    package mutating func sample(
        focused: Field?, now: Date,
        value: (Field) -> String?, caret: (Field) -> Int?
    ) -> Event? {
        guard !finished else { return nil }
        let elapsed = now.timeIntervalSince(started)
        if tracker == nil, elapsed > 3 {
            finished = true
            return sawReadableField ? .pasteUnverified : .fieldUnavailable
        }
        let field = (target == nil || target == focused) ? focused : nil
        let current = field.flatMap(value)
        if var active = tracker {
            let result = active.observe(current, now: now)
            tracker = active
            finished = !result.keepGoing
            return result.pairs.map(Event.edited)
        }
        if let field, let current {
            sawReadableField = true
            if current.contains(inserted) {
                target = field
                tracker = EditTracker(baseline: current, inserted: inserted, caret: caret(field), started: started)
                return .watching
            }
        }
        return nil
    }
}
