import Combine
import SwiftUI
import DesiDictationKit

/// Setup's permission step: one macOS prompt per button, so three system
/// dialogs never pile up over the setup window at launch. The ticks update by
/// themselves while the window is open.
struct OnboardingPermissions: View {
    @State private var status = Permissions.check()
    @State private var asked: Set<String> = []
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Press **Allow** on each, one at a time. macOS asks you to confirm; the ticks turn green by themselves.")
                .font(.caption).foregroundStyle(.secondary)
            row("Microphone", "to hear you", status.microphone, .microphone)
            row("Accessibility", "to type your words into apps", status.accessibility, .accessibility)
            row("Input Monitoring", "for the Right ⌥ hotkey", status.inputMonitoring, .inputMonitoring)
            if asked.contains("inputMonitoring"), !status.inputMonitoring {
                Text("Input Monitoring may only show its tick after Finish restarts the app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onReceive(tick) { _ in status = Permissions.check() }
    }

    private func row(_ name: String, _ why: String, _ granted: Bool,
                     _ pane: Permissions.Pane) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.callout.weight(.semibold))
                Text(why).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button(asked.contains("\(pane)") ? "Open Settings" : "Allow") { allow(pane) }
            }
        }
    }

    /// First press shows macOS's own prompt; if that was dismissed or denied,
    /// the next press opens the right System Settings pane.
    private func allow(_ pane: Permissions.Pane) {
        let first = asked.insert("\(pane)").inserted
        switch pane {
        case .microphone:
            if Permissions.microphoneUndecided { Permissions.requestMicrophone() }
            else { Permissions.openSystemSettings(pane: pane) }
        case .accessibility:
            if first { Permissions.requestAccessibility() }
            else { Permissions.openSystemSettings(pane: pane) }
        case .inputMonitoring:
            if first { Permissions.requestInputMonitoring() }
            else { Permissions.openSystemSettings(pane: pane) }
        }
    }
}

/// Before Finish, in big letters: where the app goes and why.
struct MenuBarHomeNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 28)).foregroundStyle(Theme.accent)
                Text("After setup, it lives in your menu bar")
                    .font(.title2.bold())
            }
            Text("Look for the **mic** at the top-right of your screen. There's no Dock icon and no window to keep open: it stays out of your way and works in every app.")
            Text("When you press Finish, the app restarts and points at the mic, so you can't miss it.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.5)))
    }
}
