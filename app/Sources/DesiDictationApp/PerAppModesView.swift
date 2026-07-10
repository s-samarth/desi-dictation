import SwiftUI
import DesiDictationKit

/// Per-app language rules management (IDEAS #4) — review and remove what the
/// menu's "For <App>" submenu created. Lives in General settings.
struct PerAppModeSettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var appModes = AppModeStore.shared

    var body: some View {
        Section {
            Toggle("Remember language per app", isOn: $settings.perAppModes)
            if settings.perAppModes {
                if appModes.rules.isEmpty {
                    Text("No app rules yet. From the menu bar, use “For <app name>” to pin a language — e.g. WhatsApp → Hinglish, Mail → English.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(appModes.rules) { rule in
                    HStack {
                        Text(rule.appName)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { rule.mode },
                            set: { appModes.set($0, bundleID: rule.bundleID,
                                                appName: rule.appName) })) {
                            ForEach(LanguageMode.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 190)
                        Button {
                            appModes.removeRule(bundleID: rule.bundleID)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove — this app follows the global language again")
                    }
                }
            }
        } header: {
            Text("Per-app language")
        } footer: {
            Text("Dictation in an app with a rule uses that language automatically; everywhere else follows the menu-bar setting.")
                .font(.caption)
        }
    }
}
