import SwiftUI
import DesiDictationKit

/// Per-app language rules management (IDEAS #4) — review and remove what the
/// menu's "For <App>" submenu created. Lives under Dictation → Advanced.
struct PerAppModeSettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var appModes = AppModeStore.shared

    var body: some View {
        Group {
            Toggle(isOn: $settings.perAppModes) {
                Text("Remember language per app")
                Text("Set one from the menu bar's “For <app>” item, e.g. WhatsApp → Hinglish.")
            }
            if settings.perAppModes {
                ForEach(appModes.rules) { rule in
                    HStack {
                        Text(rule.appName)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { rule.mode },
                            set: { appModes.set($0, bundleID: rule.bundleID,
                                                appName: rule.appName) })) {
                            ForEach(LanguageMode.offered, id: \.self) {
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
        }
    }
}
