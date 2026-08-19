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
                // Last dictation's real cost. Visible on purpose: speed is the
                // core promise, so it should be checkable without a debugger —
                // and it's the line to quote in a bug report.
                if let timings = controller.lastTimings {
                    Text("Last: \(timings.summary)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Controls") {
                Picker("Dictation key", selection: $settings.hotkey) {
                    ForEach(HotkeyChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .onChange(of: settings.hotkey) { DictationController.shared.reloadHotkey() }
                if let hint = settings.hotkey.hint {
                    Text(hint).font(.caption).foregroundStyle(.orange)
                }

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
                    ForEach(LanguageMode.allCases.filter {
                        settings.aiFeaturesEnabled || !$0.needsLLM
                    }, id: \.self) { Text($0.displayName).tag($0) }
                }
                // Only models that serve the selected language (v0.6.1) — and
                // the choice is remembered per language, not globally.
                Picker("Model", selection: Binding(
                    get: { settings.modelPath(for: settings.languageMode) },
                    set: {
                        settings.setModelPath($0, for: settings.languageMode)
                        controller.modelChanged()
                    })) {
                    Text("Auto — best for this language (recommended)").tag("")
                    ForEach(models.candidates(for: settings.languageMode)) { model in
                        Text("\(model.name) (\(model.sizeMB) MB)").tag(model.path)
                    }
                }
                if let auto = models.resolveModel(
                    for: settings.languageMode,
                    pinnedPath: settings.modelPath(for: settings.languageMode)) {
                    Text("Using: \(auto.name)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("⚠️ No suitable model installed — see the Models tab.")
                        .font(.caption).foregroundStyle(.orange)
                }
                if settings.languageMode.needsLLM, !LLMServices.shared.status.isReady {
                    Text("⚠️ This mode also needs the AI model — one-time setup in the AI tab. Until then, dictations paste as heard.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Options") {
                Toggle("Smart pause handling (VAD)", isOn: $settings.vadEnabled)
                Toggle("Flash attention (faster; turn off to diagnose garbled output)",
                       isOn: $settings.flashAttention)
                    .onChange(of: settings.flashAttention) {
                        DictationController.shared.modelChanged()
                    }
                Toggle("Quick restart (mic stays warm 20 s after dictating)",
                       isOn: $settings.micWarm)
                    .onChange(of: settings.micWarm) {
                        DictationController.shared.micWarmChanged()
                    }
                Toggle("Play sounds", isOn: $settings.soundsEnabled)
                Toggle("Copy to clipboard instead of pasting", isOn: $settings.copyInsteadOfPaste)
                Toggle("Keep dictation history (last 24 h, on this Mac only)",
                       isOn: $settings.historyEnabled)
                Toggle("Start Desi Dictation at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { LoginItem.apply() }
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
        case .transcribing, .translating, .polishing: return .orange
        case .error: return .yellow
        }
    }

    private var statusText: String {
        switch controller.phase {
        case .disabled: return "Dictation off"
        case .idle: return "Ready — \(settings.activationMode == .pushToTalk ? "hold" : "tap") \(settings.hotkey.displayName)"
        case .recording: return "Recording… (Esc to cancel)"
        case .transcribing: return "Transcribing…"
        case .translating: return "Translating…"
        case .polishing: return "Polishing…"
        case .error(let message): return message
        }
    }
}
