import ServiceManagement
import SwiftUI
import DesiDictationKit

/// Entry point. The permission probe (PermissionProbe) and the screen check
/// (ScreenCheck) are launches that must answer and exit before any of the
/// app starts.
@main
enum Launch {
    static func main() {
        PermissionProbe.answerIfAsked()
        ScreenCheck.runIfAsked()
        DesiDictationApp.main()
    }
}

struct DesiDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var controller = DictationController.shared
    @ObservedObject var updater = Updater.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            Image(nsImage: MenuBarIcon.image(menuBarSymbol, dot: updater.hasUpdate))
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
    /// Read in willFinishLaunching, while the launch event is still current.
    private var launchedAsLoginItem = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAsLoginItem = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
            == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let directory = UISnapshots.directory {
            NSApp.setActivationPolicy(.accessory)
            UISnapshots.run(into: directory)
            return
        }
        if ReviewDemo.enabled {
            NSApp.setActivationPolicy(.accessory)
            ReviewDemo.run()
            return
        }
        // Update rehearsal (UPDATES.md): only the updater runs. No permission
        // prompts, hotkey or login item for the throwaway test bundle.
        if ProcessInfo.processInfo.environment["DESI_UPDATE_REHEARSAL"] == "1" {
            NSApp.setActivationPolicy(.accessory)
            Updater.shared.start()
            return
        }
        // DESI_POINTER=tour|reminder: show the menu-bar pointer on any launch.
        if let style = ProcessInfo.processInfo.environment["DESI_POINTER"] {
            MenuBarPointer.shared.show(style == "tour" ? .tour : .reminder)
        }
        #endif
        // Menu-bar-only app (no Dock icon), also when run via `swift run`.
        NSApp.setActivationPolicy(.accessory)

        // Right-click → Services, from any app: "Always write as…" always;
        // Translate (Flow B) only once AI ships — build_app.sh drops those
        // Info.plist entries until then, and the handlers refuse anyway.
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()

        // A permission lost after setup: ask again now, not on first
        // dictation. Before setup, its permission step asks one at a time, so
        // three system dialogs don't bury the setup window.
        if SettingsStore.shared.onboarded {
            let status = Permissions.check()
            if !status.microphone { Permissions.requestMicrophone() }
            if !status.accessibility { Permissions.requestAccessibility() }
            if !status.inputMonitoring { Permissions.requestInputMonitoring() }
        }

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
        // Newer release? A menu line and a dot on the mic (UPDATES.md).
        Updater.shared.start()

        if SettingsStore.shared.onboarded, SettingsStore.shared.dictationEnabled {
            DictationController.shared.enable()
        }
        // The app lives in the menu bar (user decision 2026-10-29: no window
        // on launch), so each launch shows where it went (FIRST_RUN.md).
        let kind = LaunchKind.of(
            onboarded: SettingsStore.shared.onboarded,
            tourPending: UserDefaults.standard.bool(forKey: MenuBarPointer.tourPendingKey),
            loginItem: launchedAsLoginItem,
            uptime: ProcessInfo.processInfo.systemUptime)
        switch kind {
        case .firstRun:
            AppWindows.shared.showOnboarding()
        case .afterSetup:
            UserDefaults.standard.set(false, forKey: MenuBarPointer.tourPendingKey)
            MenuBarPointer.shared.show(.tour)
        case .byHand:
            MenuBarPointer.shared.show(.reminder)
        case .atLogin:
            break
        }
    }

    /// Unload the model before exit() — a resident model aborts the process
    /// in ggml's Metal teardown (FM#27).
    func applicationWillTerminate(_ notification: Notification) {
        DictationController.shared.shutdown()
    }

    /// Opening the app again from Spotlight or Finder while it runs: point at
    /// the menu-bar mic, where the window opens from. Unfinished setup comes
    /// back instead, so a closed onboarding isn't lost.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows: Bool) -> Bool {
        if SettingsStore.shared.onboarded {
            MenuBarPointer.shared.show(.reminder)
        } else {
            AppWindows.shared.showOnboarding()
        }
        return false
    }
}

/// Launch-at-login (SMAppService) — dictation should survive a reboot.
@MainActor
enum LoginItem {
    static func apply() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }  // not `swift run`
        if SettingsStore.shared.launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
