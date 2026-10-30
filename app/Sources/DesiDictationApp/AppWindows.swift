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
    private var lastDictation: NSWindow?
    private var thoughts: NSWindow?
    private var feedback: NSWindow?

    func showMain() {
        if main == nil {
            main = makeWindow(title: "Desi Dictation",
                              content: NSHostingView(rootView: MainWindow()),
                              size: MainWindow.size)
        }
        present(main!)
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = makeWindow(title: "Welcome to Desi Dictation",
                                    content: NSHostingView(rootView: OnboardingView()),
                                    size: OnboardingView.size)
        }
        present(onboarding!)
    }

    func showLastDictation() {
        if lastDictation == nil {
            lastDictation = makeWindow(title: "Last Dictation — edit & translate",
                                       content: NSHostingView(rootView: LastDictationView()),
                                       size: NSSize(width: 560, height: 400))
        }
        present(lastDictation!)
    }

    func showThoughts() {
        if thoughts == nil {
            thoughts = makeWindow(title: "Your thoughts, organized",
                                  content: NSHostingView(rootView: ThoughtsView()),
                                  size: NSSize(width: 600, height: 500))
        }
        present(thoughts!)
    }

    /// Send Feedback. Rebuilt each time so it starts empty and picks up the
    /// latest dictation.
    func showFeedback(includeLastDictation: Bool = false) {
        feedback?.close()
        let view = FeedbackView(includeLastDictation: includeLastDictation)
        let window = makeWindow(title: "Send Feedback", content: NSHostingView(rootView: view),
                                size: NSSize(width: 520, height: 420))
        feedback = window
        present(window)
    }

    /// The right-click "Always write as…" window, prefilled with the word.
    /// Rebuilt each time so it never shows the previous word.
    private var addWord: NSWindow?

    func showAddWord(heard: String) {
        addWord?.close()
        let scope = WordScope(mode: SettingsStore.shared.languageMode) ?? .english
        let view = AddDictionaryEntrySheet(heard: heard, scope: scope) { [weak self] in
            self?.addWord?.close()
        }
        let window = makeWindow(title: "Desi Dictation", content: NSHostingView(rootView: view),
                                size: NSSize(width: 460, height: 190))
        window.level = .floating
        addWord = window
        present(window)
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
