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

        if SettingsStore.shared.dictationEnabled {
            DictationController.shared.enable()
        }
    }
}
