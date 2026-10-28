import ServiceManagement
import SwiftUI
import DesiDictationKit

@main
struct DesiDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var controller = DictationController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)
        // The one window (menu → Open Desi Dictation…) and onboarding are AppKit-managed
        // (AppWindows) so Dock clicks and the AppDelegate can summon them. No
        // SwiftUI Settings scene: a second window with the same pages under
        // other names was half of the clutter.
    }

    private var menuBarSymbol: String {
        switch controller.phase {
        case .disabled: return "mic.slash"
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .translating, .polishing: return "sparkles"
        case .error: return "mic.badge.xmark"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let directory = UISnapshots.directory {
            NSApp.setActivationPolicy(.accessory)
            UISnapshots.run(into: directory)
            return
        }
        #endif
        // Read before anything else handles an Apple event.
        let launchedAtLogin = LoginItem.launchedAtLogin
        // Menu-bar-only app (no Dock icon), also when run via `swift run`.
        NSApp.setActivationPolicy(.accessory)

        // Right-click → Services, from any app: "Always write as…" always;
        // Translate (Flow B) only once AI ships — build_app.sh drops those
        // Info.plist entries until then, and the handlers refuse anyway.
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()

        // Surface permission prompts early instead of on first dictation.
        let status = Permissions.check()
        if !status.microphone { Permissions.requestMicrophone() }
        if !status.accessibility { Permissions.requestAccessibility() }
        if !status.inputMonitoring { Permissions.requestInputMonitoring() }

        // Overlay follows the dictation phase for its whole lifetime.
        OverlayCoordinator.shared.start()
        // "Always write X as Y?" popup above it (AUTO_VOCABULARY.md).
        VocabularyPromptCoordinator.shared.start()
        // Electron apps hide their text fields until asked (FM#37).
        AccessibilityPrimer.start()
        // Review before paste: the panel between transcription and ⌘V.
        ReviewCoordinator.shared.start()

        // Thinking sessions route their transcript to the review window
        // instead of pasting (STRUCTURE_THOUGHTS.md) — wired here because the
        // kit stays UI-free.
        DictationController.shared.onThinkingTranscript = { transcript in
            ThoughtsSession.shared.begin(transcript: transcript)
        }

        LoginItem.apply()

        if !SettingsStore.shared.onboarded {
            // First launch: guide the user instead of sitting silently in the
            // menu bar (v0.5 pilot feedback).
            AppWindows.shared.showOnboarding()
        } else {
            if SettingsStore.shared.dictationEnabled {
                DictationController.shared.enable()
            }
            // Opened by hand (Finder, Spotlight, Launchpad): show the window,
            // or "opening" the app looks like nothing happened. At login it
            // stays quietly in the menu bar.
            if !launchedAtLogin { AppWindows.shared.showMain() }
        }
    }

    /// Unload the model before exit() — a resident model aborts the process
    /// in ggml's Metal teardown (FM#27).
    func applicationWillTerminate(_ notification: Notification) {
        DictationController.shared.shutdown()
    }

    /// Clicking the app in Dock/Spotlight/Finder shows a window — before this,
    /// "opening" the app appeared to do nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows: Bool) -> Bool {
        AppWindows.shared.handleReopen()
        return true
    }
}

/// Launch-at-login (SMAppService) — dictation should survive a reboot.
@MainActor
enum LoginItem {
    /// True when macOS started us as a login item, from the launch event's
    /// `keyAELaunchedAsLogInItem` marker.
    static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
            == keyAELaunchedAsLogInItem
    }

    static func apply() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }  // not `swift run`
        if SettingsStore.shared.launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
