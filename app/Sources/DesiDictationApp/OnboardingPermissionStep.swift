import Combine
import SwiftUI
import DesiDictationKit

/// Watches the three permissions while setup is open. Accessibility and
/// Input Monitoring come from a fresh probe each time (PermissionProbe):
/// the in-process answer never changes once the app is running, which left
/// the Accessibility tick blank after it was granted (FM#44).
@MainActor
final class PermissionWatcher: ObservableObject {
    @Published private(set) var status = Permissions.check()
    private var timer: AnyCancellable?
    private var activation: AnyCancellable?
    private var checking = false

    func start() {
        refresh()
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
        // Coming back from System Settings: check at once, not on the next tick.
        activation = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refresh() }
    }

    func stop() { timer = nil; activation = nil }

    func refresh() {
        guard !checking, !status.allGranted else { return }
        checking = true
        Task.detached {
            let fresh = Permissions.checkFresh()
            await MainActor.run {
                self.status = fresh
                self.checking = false
            }
        }
    }
}

/// Setup: the three permissions, one button each, with a picture of what
/// to switch on in System Settings once macOS sends you there.
struct PermissionsStep: View {
    @StateObject private var watcher = PermissionWatcher()
    @State private var asked: Set<Permissions.Pane> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(title: "Give it three permissions",
                      subtitle: "macOS asks you to confirm each one. Press Allow, and the tick turns green by itself.")
            row(.microphone, "mic.fill", "Microphone", "To hear you while you hold the key.",
                watcher.status.microphone)
            row(.accessibility, "accessibility", "Accessibility", "To type your words into the app you're using.",
                watcher.status.accessibility)
            row(.inputMonitoring, "keyboard", "Input Monitoring", "To notice when you hold the dictation key. It reads no other keys.",
                watcher.status.inputMonitoring)
            if watcher.status.allGranted {
                Tip(symbol: "checkmark.seal", text: "All set. Nothing here leaves your Mac.")
            } else {
                Text("You can continue now and allow them later, but dictation needs all three.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .onAppear { watcher.start() }
        .onDisappear { watcher.stop() }
    }

    private func row(_ pane: Permissions.Pane, _ symbol: String, _ name: String,
                     _ why: String, _ granted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title2).foregroundStyle(Theme.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.title3.weight(.semibold))
                    Text(why).font(.body).foregroundStyle(.secondary)
                }
                Spacer()
                if granted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(.green)
                } else {
                    Button(asked.contains(pane) ? "Open System Settings" : "Allow") { allow(pane) }
                        .controlSize(.large)
                }
            }
            if asked.contains(pane), !granted, pane != .microphone {
                SettingsHint()
            }
        }
        .card(selected: granted, tint: .green)
    }

    /// First press shows macOS's own prompt; after that, it opens the pane.
    private func allow(_ pane: Permissions.Pane) {
        let first = asked.insert(pane).inserted
        switch pane {
        case .microphone:
            if Permissions.microphoneUndecided { Permissions.requestMicrophone() }
            else { Permissions.openSystemSettings(pane: pane) }
        case .accessibility:
            if first { Permissions.requestAccessibility() } else { Permissions.openSystemSettings(pane: pane) }
        case .inputMonitoring:
            if first { Permissions.requestInputMonitoring() } else { Permissions.openSystemSettings(pane: pane) }
        }
        watcher.refresh()
    }
}

/// "Find Desi Dictation in the list and switch it on", with a drawing of
/// the row as System Settings shows it. The list isn't named: macOS 27 files
/// Accessibility under "Device Control and Data Access".
struct SettingsHint: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("In the list System Settings opens, find **Desi Dictation** and switch it on.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill").foregroundStyle(Theme.accent)
                    Text("Desi Dictation").font(.callout)
                    Spacer()
                    Capsule().fill(Color.accentColor).frame(width: 30, height: 18)
                        .overlay(alignment: .trailing) { Circle().fill(.white).padding(2) }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 280)
            }
        }
        .padding(.leading, 40)
    }
}
