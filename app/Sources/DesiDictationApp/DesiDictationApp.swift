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

        // Main window + onboarding are AppKit-managed (AppWindows) so Dock
        // clicks and the AppDelegate can summon them — SwiftUI Window scenes
        // can't be opened from outside the view hierarchy.
        Settings {
            SettingsView()
        }
    }

    private var menuBarSymbol: String {
        switch controller.phase {
        case .disabled: return "mic.slash"
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .error: return "mic.badge.xmark"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app (no Dock icon), also when run via `swift run`.
        NSApp.setActivationPolicy(.accessory)

        // Surface permission prompts early instead of on first dictation.
        let status = Permissions.check()
        if !status.microphone { Permissions.requestMicrophone() }
        if !status.accessibility { Permissions.requestAccessibility() }
        if !status.inputMonitoring { Permissions.requestInputMonitoring() }

        // Overlay follows the dictation phase for its whole lifetime.
        OverlayCoordinator.shared.start()

        LoginItem.apply()

        if !SettingsStore.shared.onboarded {
            // First launch: guide the user instead of sitting silently in the
            // menu bar (v0.5 pilot feedback).
            AppWindows.shared.showOnboarding()
        } else if SettingsStore.shared.dictationEnabled {
            DictationController.shared.enable()
        }
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
    static func apply() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }  // not `swift run`
        if SettingsStore.shared.launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
