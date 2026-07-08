import AppKit
import SwiftUI
import DesiDictationKit

/// AppKit-managed windows so they can be summoned from anywhere (AppDelegate
/// reopen events, menu items, onboarding) — SwiftUI's openWindow environment
/// is view-only and can't serve Dock-icon clicks (v0.5 pilot feedback:
/// "clicking the app does nothing visible").
@MainActor
final class AppWindows {
    static let shared = AppWindows()
    private var main: NSWindow?
    private var onboarding: NSWindow?

    func showMain() {
        if main == nil {
            main = makeWindow(title: "Desi Dictation",
                              content: NSHostingView(rootView: MainWindow()),
                              size: NSSize(width: 780, height: 520))
        }
        present(main!)
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = makeWindow(title: "Welcome to Desi Dictation",
                                    content: NSHostingView(rootView: OnboardingView()),
                                    size: NSSize(width: 560, height: 640))
        }
        present(onboarding!)
    }

    /// Dock/Spotlight re-open → show something useful.
    func handleReopen() {
        SettingsStore.shared.onboarded ? showMain() : showOnboarding()
    }

    private func makeWindow(title: String, content: NSView, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
