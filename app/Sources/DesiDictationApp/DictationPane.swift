import SwiftUI
import DesiDictationKit

/// Home pane: live status + every dictation control in one place
/// (mirrors MacWhisper's Dictation settings screen).
struct DictationPane: View {
    @ObservedObject var controller = DictationController.shared
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var models = ModelManager.shared
    @State private var permissions = Permissions.check()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Circle().fill(statusColor).frame(width: 12, height: 12)
                    Text(statusText).font(.headline)
                    Spacer()
                    Toggle("Enable Dictation", isOn: Binding(
                        get: { settings.dictationEnabled },
                        set: { enabled in
                            settings.dictationEnabled = enabled
                            enabled ? controller.enable() : controller.disable()
                        }))
                        .toggleStyle(.switch)
                }
            }

            Section("Controls") {
                Picker("Dictation key", selection: $settings.hotkey) {
                    ForEach(HotkeyChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .onChange(of: settings.hotkey) { DictationController.shared.reloadHotkey() }

                Picker("Activation mode", selection: $settings.activationMode) {
                    ForEach(ActivationMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Text(settings.activationMode == .pushToTalk
                     ? "Hold the key while speaking; release to insert. Esc cancels."
                     : "Tap once to start, tap again to finish. Esc cancels.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Language & model") {
                Picker("Language", selection: $settings.languageMode) {
                    ForEach(LanguageMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker("Model", selection: Binding(
                    get: { settings.modelPath },
                    set: { settings.modelPath = $0; controller.modelChanged() })) {
                    Text("Auto — best for language (recommended)").tag("")
                    ForEach(models.installed) { model in
                        Text("\(model.name) (\(model.sizeMB) MB)").tag(model.path)
                    }
                }
                if let auto = models.resolveModel(for: settings.languageMode,
                                                  pinnedPath: settings.modelPath) {
                    Text("Using: \(auto.name)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("⚠️ No suitable model installed — see the Models tab.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Options") {
                Toggle("Play sounds", isOn: $settings.soundsEnabled)
                Toggle("Copy to clipboard instead of pasting", isOn: $settings.copyInsteadOfPaste)
                Toggle("Keep dictation history (last 24 h, on this Mac only)",
                       isOn: $settings.historyEnabled)
            }

            Section("Permissions") {
                permissionRow("Microphone", granted: permissions.microphone, pane: .microphone)
                permissionRow("Accessibility (pastes text)", granted: permissions.accessibility, pane: .accessibility)
                permissionRow("Input Monitoring (global hotkey)", granted: permissions.inputMonitoring, pane: .inputMonitoring)
                HStack {
                    Button("Re-check") { permissions = Permissions.check() }
                    Text("Grant → quit → relaunch the app for changes to apply.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(_ name: String, granted: Bool, pane: Permissions.Pane) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
            Text(name)
            Spacer()
            if !granted {
                Button("Open Settings") { Permissions.openSystemSettings(pane: pane) }
            }
        }
    }

    private var statusColor: Color {
        switch controller.phase {
        case .disabled: return .gray
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .orange
        case .error: return .yellow
        }
    }

    private var statusText: String {
        switch controller.phase {
        case .disabled: return "Dictation off"
        case .idle: return "Ready — \(settings.activationMode == .pushToTalk ? "hold" : "tap") \(settings.hotkey.displayName)"
        case .recording: return "Recording… (Esc to cancel)"
        case .transcribing: return "Transcribing…"
        case .error(let message): return message
        }
    }
}
