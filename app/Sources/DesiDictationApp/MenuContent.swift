import SwiftUI
import DesiDictationKit

struct MenuContent: View {
    @ObservedObject var controller = DictationController.shared
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var models = ModelManager.shared
    @ObservedObject var history = HistoryStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusLine)

        Button("Open Desi Dictation…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Toggle("Enable Dictation", isOn: Binding(
            get: { settings.dictationEnabled },
            set: { enabled in
                settings.dictationEnabled = enabled
                enabled ? controller.enable() : controller.disable()
            }))

        Picker("Language", selection: $settings.languageMode) {
            ForEach(LanguageMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }

        Picker("Model", selection: Binding(
            get: { settings.modelPath },
            set: { settings.modelPath = $0; controller.modelChanged() })) {
            Text("Auto (recommended)").tag("")
            ForEach(models.installed) { model in
                Text("\(model.name) (\(model.sizeMB) MB)").tag(model.path)
            }
        }

        Divider()

        if !controller.lastTranscript.isEmpty {
            Button("Copy Last: \"\(String(controller.lastTranscript.prefix(30)))…\"") {
                TextInserter.insert(controller.lastTranscript, copyOnly: true)
            }
        }

        Menu("History") {
            if history.entries.isEmpty {
                Text("No dictations yet")
            }
            ForEach(history.entries.prefix(10)) { entry in
                Button(String(entry.text.prefix(48))) {
                    TextInserter.insert(entry.text, copyOnly: true)
                }
            }
            Divider()
            Button("Clear History") { history.clear() }
        }

        Divider()

        SettingsLink { Text("Settings…") }
        Button("Open Models Folder") {
            NSWorkspace.shared.open(AppPaths.modelsDirectory)
        }
        Button("Refresh Models") { models.refresh() }

        Divider()
        Button("Quit Desi Dictation") { NSApp.terminate(nil) }
    }

    private var statusLine: String {
        switch controller.phase {
        case .disabled: return "Dictation off"
        case .idle:
            return "Ready — hold \(settings.hotkey.displayName)"
        case .recording: return "● Recording… (Esc cancels)"
        case .transcribing: return "Transcribing…"
        case .error(let message): return "⚠️ \(message)"
        }
    }
}
