import AppKit
import os.log

private let menuLog = Logger(subsystem: "com.desi.dictation", category: "menu")

/// Knows whether one of OUR menus is open (the menu-bar menu, a submenu).
///
/// An open menu holds keyboard focus as the window server's "key thief": every
/// keystroke, our synthesized ⌘V included, goes to the menu instead of the
/// focused text field, even though the frontmost app hasn't changed. The
/// user can open the menu, start dictating, wander around, and stop with the
/// menu still open, and the paste silently vanishes (FM#32). TextInserter
/// asks this before pasting and closes the menu first.
@MainActor
public final class MenuTracker {
    public static let shared = MenuTracker()

    /// Menus currently tracking, outermost first. Weak: AppKit owns them.
    private var open: [WeakMenu] = []
    private var observers: [NSObjectProtocol] = []

    public var isMenuOpen: Bool {
        open.removeAll { $0.menu == nil }
        return !open.isEmpty
    }

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] note in
            let menu = note.object as? NSMenu
            MainActor.assumeIsolated { self?.began(menu) }
        })
        observers.append(center.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { [weak self] note in
            let menu = note.object as? NSMenu
            MainActor.assumeIsolated { self?.ended(menu) }
        })
    }

    /// Starts observing. Call at launch: a menu opened before the first
    /// call would go unseen.
    public func start() {}

    /// Dismisses every open menu. Focus returns to the text field once the
    /// menu has faded out (didEndTracking), which `isMenuOpen` reports.
    public func closeAll() {
        menuLog.info("closing \(self.open.count, privacy: .public) open menu(s) before paste")
        for entry in open.reversed() { entry.menu?.cancelTracking() }
    }

    private func began(_ menu: NSMenu?) {
        guard let menu, !open.contains(where: { $0.menu === menu }) else { return }
        open.append(WeakMenu(menu: menu))
        menuLog.info("menu open (\(self.open.count, privacy: .public))")
    }

    private func ended(_ menu: NSMenu?) {
        open.removeAll { $0.menu == nil || $0.menu === menu }
        menuLog.info("menu closed (\(self.open.count, privacy: .public) still open)")
    }

    private struct WeakMenu { weak var menu: NSMenu? }
}
