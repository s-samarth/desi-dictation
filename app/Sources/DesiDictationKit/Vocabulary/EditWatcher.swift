import ApplicationServices
import Foundation

/// Watches the field we just pasted into, so a retyped word can become an
/// "Always write X as Y?" proposal (§2a). Polls the same AX element every
/// 0.3 s for 2 minutes instead of using AXObserver: no run loop per app,
/// nothing measurable, and AXObserver delivery varies by app.
///
/// The field text lives only in this object and is dropped when the watch ends.
public final class EditWatcher: @unchecked Sendable {
    public static let shared = EditWatcher()

    /// Long enough to read what was pasted, then fix it (30 s was too short
    /// to read and edit, user feedback 2026-10-29).
    public static let window: TimeInterval = 120
    /// Unchanged this long → the user finished that edit.
    public static let settle: TimeInterval = 2

    private let queue = DispatchQueue(label: "desi.vocab.editwatch", qos: .utility)
    private var generation = 0   // touched only on `queue`

    /// What a watch saw, for the activity log ("why didn't it learn?").
    public enum Event {
        /// The pasted text couldn't be read back from the field.
        case unreadable(app: String)
        case watching(app: String)
        /// The field changed and settled; these are the word swaps found.
        case edited(pairs: [EditPair], app: String)
    }

    /// Starts a watch; a running one is replaced. `onEvent` runs on main.
    public func watch(inserted: String, onEvent: @escaping @MainActor (Event) -> Void) {
        queue.async { [self] in
            generation += 1
            let mine = generation
            // Let the ⌘V land before the baseline snapshot.
            queue.asyncAfter(deadline: .now() + 0.4) { [self] in
                guard mine == generation else { return }
                let app = AXReader.focusedElement().map { AXReader.appName($0) } ?? "this app"
                guard let session = Session(inserted: inserted) else {
                    Task { @MainActor in onEvent(.unreadable(app: app)) }
                    return
                }
                Task { @MainActor in onEvent(.watching(app: app)) }
                poll(session, app: app, generation: mine, onEvent: onEvent)
            }
        }
    }

    public func stop() {
        queue.async { [self] in generation += 1 }
    }

    private func poll(_ session: Session, app: String, generation mine: Int,
                      onEvent: @escaping @MainActor (Event) -> Void) {
        guard mine == generation else { return }
        let outcome = session.tick(now: Date())
        if let pairs = outcome.pairs {
            Task { @MainActor in onEvent(.edited(pairs: pairs, app: app)) }
        }
        guard outcome.keepGoing else { return }
        queue.asyncAfter(deadline: .now() + Self.interval) { [self] in
            poll(session, app: app, generation: mine, onEvent: onEvent)
        }
    }

    /// Fast enough to catch the fixed text in a chat box before Enter sends
    /// it and clears the box (2 s settle alone missed every chat edit).
    static let interval: TimeInterval = 0.3

    /// One watch: the element, plus the tracker that judges its text.
    final class Session {
        var element: AXUIElement
        var tracker: EditTracker

        init?(inserted: String) {
            guard let element = AXReader.focusedElement(),
                  let value = AXReader.fieldValue(element), value.contains(inserted) else { return nil }
            self.element = element
            tracker = EditTracker(baseline: value, inserted: inserted, caret: AXReader.caretUTF16(element))
        }

        func tick(now: Date) -> (pairs: [EditPair]?, keepGoing: Bool) {
            tracker.observe(currentValue(), now: now)
        }

        /// The field's text. Web views (Electron, browsers) may swap the
        /// focused element for a new one after an edit; same app and role
        /// counts as the same field.
        private func currentValue() -> String? {
            guard let focused = AXReader.focusedElement() else { return nil }
            if !CFEqual(focused, element) {
                guard AXReader.pid(focused) == AXReader.pid(element),
                      AXReader.string(focused, kAXRoleAttribute) == AXReader.string(element, kAXRoleAttribute)
                else { return nil }
                element = focused
            }
            return AXReader.fieldValue(element)
        }
    }
}
