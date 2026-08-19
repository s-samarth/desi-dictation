import SwiftUI
import DesiDictationKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gear") }
            ModelsSettings().tabItem { Label("Models", systemImage: "cpu") }
            TextSettings().tabItem { Label("Text", systemImage: "character.cursor.ibeam") }
            AISettings().tabItem { Label("AI", systemImage: "sparkles") }
            LicenseSettings().tabItem { Label("License", systemImage: "key") }
        }
        .frame(width: 480, height: 420)
    }
}

struct GeneralSettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @State private var permissions = Permissions.check()

    var body: some View {
        Form {
            Picker("Dictation hotkey", selection: $settings.hotkey) {
                ForEach(HotkeyChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: settings.hotkey) { DictationController.shared.reloadHotkey() }

            Picker("Activation", selection: $settings.activationMode) {
                ForEach(ActivationMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.radioGroup)

            Toggle("Play sounds", isOn: $settings.soundsEnabled)
            Toggle("Copy to clipboard instead of pasting", isOn: $settings.copyInsteadOfPaste)

            PerAppModeSettings()

            Section("Permissions") {
                permissionRow("Microphone", granted: permissions.microphone, pane: .microphone)
                permissionRow("Accessibility", granted: permissions.accessibility, pane: .accessibility)
                permissionRow("Input Monitoring", granted: permissions.inputMonitoring, pane: .inputMonitoring)
                Button("Re-check") { permissions = Permissions.check() }
            }
        }
        .padding()
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
}

struct ModelsSettings: View {
    @ObservedObject var models = ModelManager.shared
    @ObservedObject var license = LicenseManager.shared

    var body: some View {
        Form {
            DefaultModelSettings()
            Section("Installed (\(AppPaths.modelsDirectory.path))") {
                if models.installed.isEmpty {
                    Text("No models yet. Download below, or convert Hinglish models with scripts/convert_model.sh")
                        .foregroundStyle(.secondary)
                }
                ForEach(models.installed) { Text("\($0.name) — \($0.sizeMB) MB") }
            }
            Section {
                ForEach(ModelManager.catalog) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text((item.recommended ? "⭐ " : "") + item.label
                                 + (item.pro && LicenseManager.gatingEnabled ? "  (Pro)" : ""))
                            Text(item.category).font(.caption2).foregroundStyle(.secondary)
                            if let error = models.downloadErrors[item.id] {
                                Text(error).font(.caption2).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        if models.isInstalled(item) {
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption)
                        } else if let progress = models.downloadProgress[item.id] {
                            ProgressView(value: progress).frame(width: 90)
                        } else {
                            Button("Get (\(item.approxMB) MB)") {
                                Task { await models.download(item) }
                            }
                            .disabled(item.pro && !license.isPro)
                        }
                    }
                }
            } header: {
                Text("Downloads")
            } footer: {
                Text("Recommendation: grab one ⭐ model per language you use, plus the VAD add-on — it makes pauses and long dictations dramatically better. Models are large, so they aren't bundled with the app.")
                    .font(.caption)
            }
        }
        .padding()
    }
}

struct TextSettings: View {
    @ObservedObject var settings = SettingsStore.shared

    var body: some View {
        Form {
            DictionarySettings()
            Section("Replacements (advanced) — one per line: find=replace") {
                TextEditor(text: $settings.replacementRules)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
            }
        }
        .padding()
    }
}

struct LicenseSettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var license = LicenseManager.shared

    var body: some View {
        Form {
            if !LicenseManager.gatingEnabled {
                Label("Beta: everything is free — all models, all features.",
                      systemImage: "gift.fill")
                    .foregroundStyle(.green)
                Text("A paid Pro tier may arrive later; whatever you use during the beta stays yours.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Gumroad license key", text: $settings.licenseKey)
                Button("Activate") {
                    Task { await license.activate(key: settings.licenseKey) }
                }
                if let error = license.lastError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .padding()
    }
}
