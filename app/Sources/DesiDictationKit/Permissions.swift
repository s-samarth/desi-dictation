import AppKit
import AVFoundation
import ApplicationServices

/// Permission checks + System Settings deep links. All three are required for
/// full dictation: mic (record), accessibility (paste events), input
/// monitoring (global hotkey tap).
public enum Permissions {
    public struct Status {
        public let microphone: Bool
        public let accessibility: Bool
        public let inputMonitoring: Bool
        public var allGranted: Bool { microphone && accessibility && inputMonitoring }
    }

    public static func check() -> Status {
        Status(
            microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
            accessibility: AXIsProcessTrusted(),
            inputMonitoring: CGPreflightListenEventAccess()
        )
    }

    public static func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    public static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    public static func openSystemSettings(pane: Pane) {
        let base = "x-apple.systempreferences:com.apple.preference.security?"
        if let url = URL(string: base + pane.anchor) {
            NSWorkspace.shared.open(url)
        }
    }

    public enum Pane {
        case microphone, accessibility, inputMonitoring
        var anchor: String {
            switch self {
            case .microphone: return "Privacy_Microphone"
            case .accessibility: return "Privacy_Accessibility"
            case .inputMonitoring: return "Privacy_ListenEvent"
            }
        }
    }
}
