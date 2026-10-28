import ApplicationServices
import Foundation

/// Watches the field we just pasted into, so a retyped word can become an
/// "Always write X as Y?" proposal (§2a). Polls the same AX element once a
/// second for 30 s instead of using AXObserver: no run loop per app, nothing
/// measurable at 1 Hz, and AXObserver delivery varies by app.
///
/// The field text lives only in this object and is dropped when the watch ends.
public final class EditWatcher: @unchecked Sendable {
    public static let shared = EditWatcher()

    public static let window: TimeInterval = 30
    /// Unchanged this long → the user finished that edit.
    public static let settle: TimeInterval = 2

    private let queue = DispatchQueue(label: "desi.vocab.editwatch", qos: .utility)
    private var generation = 0   // touched only on `queue`

    /// Starts a watch; a running one is replaced. `onPairs` runs on main.
    public func watch(inserted: String, onPairs: @escaping @MainActor ([EditPair]) -> Void) {
        queue.async { [self] in
            generation += 1
            let mine = generation
            // Let the ⌘V land before the baseline snapshot.
            queue.asyncAfter(deadline: .now() + 0.4) { [self] in
                guard mine == generation, let session = Session(inserted: inserted) else { return }
                poll(session, generation: mine, onPairs: onPairs)
            }
        }
    }

    public func stop() {
        queue.async { [self] in generation += 1 }
    }

    private func poll(_ session: Session, generation mine: Int,
                      onPairs: @escaping @MainActor ([EditPair]) -> Void) {
        guard mine == generation else { return }
        let outcome = session.tick(now: Date())
        if !outcome.pairs.isEmpty {
            let pairs = outcome.pairs
            Task { @MainActor in onPairs(pairs) }
        }
        guard outcome.keepGoing else { return }
        queue.asyncAfter(deadline: .now() + 1) { [self] in poll(session, generation: mine, onPairs: onPairs) }
    }

    /// One watch: the element, the post-paste baseline, and the settle clock.
    final class Session {
        let element: AXUIElement
        let inserted: String
        let baseline: String
        let caret: Int?
        let started = Date()
        var lastValue: String
        var lastChange = Date()
        var evaluated: String?

        init?(inserted: String) {
            guard let element = AXReader.focusedElement(),
                  let value = AXReader.fieldValue(element), value.contains(inserted) else { return nil }
            self.element = element
            self.inserted = inserted
            baseline = value
            lastValue = value
            caret = AXReader.caretUTF16(element)
        }

        func tick(now: Date) -> (pairs: [EditPair], keepGoing: Bool) {
            // Focus moved on, or time's up: judge the last state, then stop.
            let stillFocused = AXReader.focusedElement().map { CFEqual($0, element) } ?? false
            let value = stillFocused ? AXReader.fieldValue(element) : nil
            if let value, value != lastValue {
                lastValue = value
                lastChange = now
            }
            let ending = value == nil || now.timeIntervalSince(started) >= EditWatcher.window
            let settled = now.timeIntervalSince(lastChange) >= EditWatcher.settle
            var pairs: [EditPair] = []
            if (settled || ending), lastValue != baseline, lastValue != evaluated {
                evaluated = lastValue
                pairs = EditDiff.pairs(before: baseline, after: lastValue, inserted: inserted, caretUTF16: caret)
            }
            return (pairs, !ending)
        }
    }
}
