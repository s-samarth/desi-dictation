import AppKit
import SwiftUI
import DesiDictationKit

/// Points at the menu-bar mic: a callout hanging under it and a pulsing ring
/// around it, so a new user sees where the app went (FIRST_RUN.md).
///
/// MenuBarExtra keeps its NSStatusItem private, but the item draws in its own
/// NSStatusBarWindow, whose frame is the icon's. Both panels float above the
/// menu bar and never take focus from the user's app.
@MainActor
final class MenuBarPointer {
    static let shared = MenuBarPointer()
    /// Set by setup's Finish; the relaunched app shows the tour once.
    static let tourPendingKey = "menuBarTourPending"
    /// Set once the reminder has shown: after that, opening the app by hand
    /// stays quiet (user decision 2026-10-30: not on every ⌘ Space; the
    /// Guide's "Where it lives" explains the menu bar instead).
    static let reminderShownKey = "menuBarReminderShown"

    enum Style {
        /// After setup: big, stays until "Got it" or the menu opens.
        case tour
        /// Opened again by hand: small, fades after a few seconds.
        case reminder
    }

    private var callout: NSPanel?
    private var ring: NSPanel?
    private var dismissal: Task<Void, Never>?
    private var menuObserver: NSObjectProtocol?

    /// The status item may not be laid out yet right after launch: retry
    /// for about three seconds, then show the centred notice instead.
    func show(_ style: Style, attempt: Int = 0) {
        let icon = Self.iconWindow()
        if icon == nil, attempt < 12 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                self.show(style, attempt: attempt + 1)
            }
            return
        }
        hide()
        let screen = icon?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = icon?.frame ?? .zero
        let clear = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea].compactMap { $0 }
        let visibility = MenuBarPlacement.visibility(icon: frame, screen: screen.frame, clearAreas: clear)
        #if DEBUG
        NSLog("[pointer] \(style) icon \(frame) screen \(screen.frame) notch-free \(clear) → \(visibility)")
        #endif
        switch visibility {
        case .visible:
            if style == .reminder {
                guard !UserDefaults.standard.bool(forKey: Self.reminderShownKey) else { return }
                UserDefaults.standard.set(true, forKey: Self.reminderShownKey)
            }
            showCallout(style, icon: frame, screen: screen)
            showRing(around: frame)
        case .behindNotch:
            showNotice(.behindNotch, style: style, screen: screen)
        case .offScreen:
            showNotice(.offScreen, style: style, screen: screen)
        }
        if style == .reminder {
            dismissal = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                if !Task.isCancelled { self.hide() }
            }
        }
        // Clicking the mic opens its menu: the pointer has done its job.
        // queue nil: runs at once on the posting (main) thread. Anything queued
        // would wait until the menu closes: tracking blocks the main queue.
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil
        ) { _ in
            MainActor.assumeIsolated { MenuBarPointer.shared.hide() }
        }
    }

    func hide() {
        dismissal?.cancel()
        dismissal = nil
        if let menuObserver { NotificationCenter.default.removeObserver(menuObserver) }
        menuObserver = nil
        callout?.orderOut(nil)
        ring?.orderOut(nil)
        callout = nil
        ring = nil
    }

    /// Opens the mic's menu, as if clicked.
    static func openMenu() {
        guard let content = iconWindow()?.contentView else { return }
        statusButton(in: content)?.performClick(nil)
    }

    /// The status item's button: NSStatusBarContentView › NSView › NSStatusBarButton
    /// on macOS 26, searched for rather than assumed.
    private static func statusButton(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        for sub in view.subviews { if let found = statusButton(in: sub) { return found } }
        return nil
    }

    /// The window the mic draws in, once the menu bar has laid it out (just
    /// after launch its frame is still empty).
    static func iconWindow() -> NSWindow? {
        NSApp.windows.first {
            String(describing: type(of: $0)) == "NSStatusBarWindow" && $0.isVisible
                && $0.frame.width > 0 && $0.frame.height > 0
        }
    }

    private func showCallout(_ style: Style, icon: CGRect, screen: NSScreen) {
        let probe = NSHostingView(rootView: PointerCallout(style: style, arrowX: 0))
        let size = probe.fittingSize
        let place = MenuBarPlacement.callout(size: size, below: icon, in: screen.frame)
        let view = NSHostingView(rootView: PointerCallout(style: style, arrowX: place.arrowX))
        callout = present(view, frame: place.frame, clickThrough: false)
        #if DEBUG
        NSLog("[pointer] callout \(place.frame) arrow at \(place.arrowX)")
        #endif
    }

    private func showRing(around icon: CGRect) {
        let frame = icon.insetBy(dx: -6, dy: -3)
        ring = present(NSHostingView(rootView: PulsingRing()), frame: frame, clickThrough: true)
    }

    private func showNotice(_ reason: PointerNotice.Reason, style: Style, screen: NSScreen) {
        let view = NSHostingView(rootView: PointerNotice(reason: reason))
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        let frame = MenuBarPlacement.centered(size: view.fittingSize, under: screen.frame,
                                              menuBarHeight: menuBar)
        callout = present(view, frame: frame, clickThrough: false)
        // Opened by hand but the icon can't be reached: open the window too.
        if style == .reminder { AppWindows.shared.showMain() }
    }

    private func present(_ view: NSView, frame: CGRect, clickThrough: Bool) -> NSPanel {
        let panel = PointerPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = !clickThrough
        panel.level = .popUpMenu   // above the menu bar itself
        panel.ignoresMouseEvents = clickThrough
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = view
        panel.orderFrontRegardless()
        return panel
    }
}

/// Borderless panels can't become key by default, so their buttons would
/// need a second click. Non-activating: the user's app keeps focus.
private final class PointerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
