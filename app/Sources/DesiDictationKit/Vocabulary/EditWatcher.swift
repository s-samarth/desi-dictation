import AppKit
import ApplicationServices

/// One cancellable watch. Capture the destination just before posting ⌘V;
/// poll its Accessibility tree off-main. Field contents live only in RAM.
@MainActor
public final class EditWatcher {
    public static let shared = EditWatcher()
    nonisolated public static let window: TimeInterval = 120
    nonisolated public static let settle: TimeInterval = 2

    private var task: Task<Void, Never>?

    public enum Event {
        case fieldUnavailable(app: String)
        case pasteUnverified(app: String)
        case watching(app: String)
        case edited(pairs: [EditPair], app: String)
    }

    public func watch(inserted: String, onEvent: @escaping @MainActor (Event) -> Void) {
        stop()
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else {
            onEvent(.fieldUnavailable(app: "the paste destination"))
            return
        }
        AccessibilityPrimer.primeForPaste(app)
        let pid = app.processIdentifier
        let name = app.localizedName ?? "the paste destination"
        // Electron can initially expose a window or web area while its
        // text field is loading. Pin an editable element when available.
        let field = AXReader.pasteField(inApp: pid).flatMap { element -> AXUIElement? in
            let role = AXReader.string(element, kAXRoleAttribute)
            return [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole].contains(role) ? element : nil
        }
        let start = Date()
        task = Task.detached(priority: .utility) {
            var session = PasteEditSession(inserted: inserted, target: field, started: start)
            var delay: UInt64 = 100_000_000
            var attached = false
            while !session.finished {
                do { try await Task.sleep(nanoseconds: delay) } catch { return }
                // During startup the original app can still expose its focused
                // field in the background. Once attached, pause while away.
                let focused: AXUIElement?
                if attached {
                    focused = app.isActive ? AXReader.pasteField(inApp: pid) : nil
                } else {
                    focused = field ?? AXReader.pasteField(inApp: pid)
                }
                let event = session.sample(
                    focused: focused, now: Date(), value: { AXReader.fieldValue($0) },
                    caret: AXReader.caretUTF16)
                delay = 300_000_000
                guard let event else { continue }
                let activity: Event
                switch event {
                case .watching:
                    attached = true
                    activity = .watching(app: name)
                case .fieldUnavailable: activity = .fieldUnavailable(app: name)
                case .pasteUnverified: activity = .pasteUnverified(app: name)
                case .edited(let pairs): activity = .edited(pairs: pairs, app: name)
                }
                await MainActor.run {
                    if !Task.isCancelled { onEvent(activity) }
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
