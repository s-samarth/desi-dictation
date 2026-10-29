import SwiftUI
import DesiDictationKit

/// Home page: is dictation on, which key, which language. Everything a user
/// changes weekly is at the top; tuning knobs sit behind "Advanced".
struct DictationPane: View {
    @ObservedObject var controller = DictationController.shared
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var models = ModelManager.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(statusColor).frame(width: 10, height: 10)
                            Text(statusText).font(.title3.weight(.semibold))
                        }
                        if controller.phase == .idle {
                            HStack(spacing: 6) {
                                Text(settings.activationMode == .pushToTalk ? "Hold" : "Tap")
                                Keycap(label: settings.hotkey.displayName)
                                Text("and speak, anywhere.")
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle("Enable Dictation", isOn: Binding(
                        get: { settings.dictationEnabled },
                        set: { enabled in
                            settings.dictationEnabled = enabled
                            enabled ? controller.enable() : controller.disable()
                        }))
                        .toggleStyle(.switch).labelsHidden()
                }
                // Last dictation's real cost: speed is the core promise, so it
                // stays checkable without a debugger (and quotable in a bug).
                if let timings = controller.lastTimings {
                    Text("Last: \(timings.summary)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Key", selection: $settings.hotkey) {
                    ForEach(HotkeyChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .onChange(of: settings.hotkey) { DictationController.shared.reloadHotkey() }
                if let hint = settings.hotkey.hint {
                    Text(hint).font(.caption).foregroundStyle(.orange)
                }
                Picker("Mode", selection: $settings.activationMode) {
                    ForEach(ActivationMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text(settings.activationMode == .pushToTalk
                     ? "Hold the key while speaking, release to insert. Esc cancels."
                     : "Tap to start, tap again to insert. Esc cancels.")
                    .footnote()
            }

            Section {
                Picker("Language", selection: $settings.languageMode) {
                    ForEach(LanguageMode.offered, id: \.self) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text("Language")
            } footer: {
                Text(modelLine).footnote()
            }

            Section {
                Toggle("Play sounds", isOn: $settings.soundsEnabled)
                Toggle("Copy to clipboard instead of pasting", isOn: $settings.copyInsteadOfPaste)
                Toggle("Start at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { LoginItem.apply() }
            } header: {
                Text("Options")
            }

            CleanupSection()
            ReviewSection()
            AdvancedDictationSettings()
            PermissionsSection()
        }
        .formStyle(.grouped)
    }

    /// Which model the language resolves to, or what's missing.
    private var modelLine: String {
        guard let model = models.resolveModel(
            for: settings.languageMode,
            pinnedPath: settings.modelPath(for: settings.languageMode)) else {
            return "No model for this language yet. Get one in Models."
        }
        return "Uses \(model.displayName). Change it in Models."
    }

    private var statusColor: Color {
        switch controller.phase {
        case .disabled: return .gray
        case .idle: return Theme.hindi
        case .recording: return .red
        case .transcribing, .translating, .polishing: return Theme.accent
        case .error: return .yellow
        }
    }

    private var statusText: String {
        switch controller.phase {
        case .disabled: return "Dictation is off"
        case .idle: return "Ready"
        case .recording: return "Recording… (Esc cancels)"
        case .transcribing: return "Transcribing…"
        case .translating: return "Translating…"
        case .polishing: return "Polishing…"
        case .error(let message): return message
        }
    }
}

/// Tuning knobs most people never touch, folded away.
struct AdvancedDictationSettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @State private var expanded = false

    var body: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $expanded) {
                Toggle("Smart pause handling (VAD)", isOn: $settings.vadEnabled)
                Toggle("Quick restart (mic stays warm 20 s after dictating)",
                       isOn: $settings.micWarm)
                    .onChange(of: settings.micWarm) {
                        DictationController.shared.micWarmChanged()
                    }
                Toggle("Flash attention (turn off only if output looks garbled)",
                       isOn: $settings.flashAttention)
                    .onChange(of: settings.flashAttention) {
                        DictationController.shared.modelChanged()
                    }
                PerAppModeSettings()
            }
        }
    }
}

/// One green line when all is well; a row per missing grant otherwise.
struct PermissionsSection: View {
    @State private var permissions = Permissions.check()

    var body: some View {
        Section {
            if permissions.microphone && permissions.accessibility && permissions.inputMonitoring {
                Label("Microphone, Accessibility and Input Monitoring are allowed",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                row("Microphone", permissions.microphone, .microphone)
                row("Accessibility (pastes text)", permissions.accessibility, .accessibility)
                row("Input Monitoring (the shortcut key)", permissions.inputMonitoring, .inputMonitoring)
                HStack {
                    Button("Re-check") { permissions = Permissions.check() }
                    Text("After granting, quit and reopen the app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Permissions")
        }
        .onAppear { permissions = Permissions.check() }
    }

    private func row(_ name: String, _ granted: Bool, _ pane: Permissions.Pane) -> some View {
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
}
