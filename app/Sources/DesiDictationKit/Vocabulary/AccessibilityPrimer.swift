import AppKit
import ApplicationServices

/// Electron apps (Claude, Slack, VS Code, Notion, Discord…) keep their
/// accessibility tree switched off until someone asks for it. Until then
/// macOS reports *no focused element at all*, so the edit watcher and the
/// screen reader see nothing (BUILD_LOG FM#37: measured in Claude, error
/// -25212 before, a readable AXTextArea 1–3 s after).
///
/// `AXManualAccessibility = true` on the app element is Electron's documented
/// switch for this. Other apps reject the attribute and nothing happens. The
/// tree takes a moment to build, so we ask as soon as an app comes to the
/// front, not at key-down.
@MainActor
public enum AccessibilityPrimer {
    private static var primed: Set<pid_t> = []
    private static var observer: NSObjectProtocol?

    /// Prime every app the user switches to, while a feature needs field text.
    public static func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { primeIfNeeded(app) }
        }
        primeIfNeeded(NSWorkspace.shared.frontmostApplication)
    }

    /// Key-down fallback, for an app that was already in front at launch.
    public static func primeFrontmost() {
        primeIfNeeded(NSWorkspace.shared.frontmostApplication)
    }

    private static func primeIfNeeded(_ app: NSRunningApplication?) {
        let store = AutoVocabularyStore.shared
        guard store.learnFromEdits || store.readScreen || store.hinglishFieldSpelling,
              let app, app.processIdentifier != getpid(),
              AXIsProcessTrusted(), !primed.contains(app.processIdentifier) else { return }
        primed.insert(app.processIdentifier)
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, AXReader.messageTimeout)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
}
