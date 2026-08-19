import SwiftUI
import DesiDictationKit

struct MenuContent: View {
    @ObservedObject var controller = DictationController.shared
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var models = ModelManager.shared
    @ObservedObject var history = HistoryStore.shared
    @ObservedObject var appModes = AppModeStore.shared
    @ObservedObject var llm = LLMServices.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusLine)

        Button("Open Desi Dictation…") {
            AppWindows.shared.showMain()
        }

        Divider()

        Toggle("Enable Dictation", isOn: Binding(
            get: { settings.dictationEnabled },
            set: { enabled in
                settings.dictationEnabled = enabled
                enabled ? controller.enable() : controller.disable()
            }))

        Picker("Language", selection: $settings.languageMode) {
            ForEach(LanguageMode.allCases.filter {
                settings.aiFeaturesEnabled || !$0.needsLLM
            }, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }

        // Tone dial as modes (PATTERNS.md §1) — per-recipient switching lives
        // one click away: Faithful for chat, Respectful for the principal.
        if settings.aiFeaturesEnabled {
            Picker("Tone", selection: $settings.toneMode) {
                ForEach(ToneMode.allCases, id: \.self) { tone in
                    Text(tone.displayName).tag(tone)
                }
            }
        }

        // Pin a language to the app the user is working in (IDEAS #4) —
        // WhatsApp → Hinglish, Mail → English, set once, never switch again.
        if settings.perAppModes, let target = appModes.currentTarget {
            Menu("For \(target.appName)") {
                Picker("Language", selection: Binding(
                    get: { appModes.mode(for: target.bundleID)?.rawValue ?? "" },
                    set: { raw in
                        if let mode = LanguageMode(rawValue: raw) {
                            appModes.set(mode, bundleID: target.bundleID,
                                         appName: target.appName)
                        } else {
                            appModes.removeRule(bundleID: target.bundleID)
                        }
                        controller.modelChanged()
                    })) {
                    Text("Follow global setting").tag("")
                    ForEach(LanguageMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }
        }

        // Model list is scoped to the language above it: picking "English" and
        // then having to know which file speaks English was the app leaking its
        // internals (v0.6.1 feedback). Whatever is chosen here becomes THIS
        // language's default and is remembered per language.
        Picker("Model for \(settings.languageMode.displayName)", selection: Binding(
            get: { settings.modelPath(for: settings.languageMode) },
            set: {
                settings.setModelPath($0, for: settings.languageMode)
                controller.modelChanged()
            })) {
            Text(autoLabel).tag("")
            ForEach(models.candidates(for: settings.languageMode)) { model in
                Text("\(model.name) (\(model.sizeMB) MB)").tag(model.path)
            }
        }

        // AI-dependent features need one-time setup; say so where the user is,
        // with a way there (house rule: no dead-looking features).
        if settings.aiFeaturesEnabled, needsLLMSetup {
            Button("⚠️ Finish AI setup (one-time)…") {
                MainNav.shared.selection = .ai
                AppWindows.shared.showMain()
            }
        }

        if settings.aiFeaturesEnabled {
            Divider()

            // Thinking session (STRUCTURE_THOUGHTS.md): ramble → structured doc.
            if controller.thinkingSessionArmed, case .recording = controller.phase {
                Button("🧠 Finish thinking session — organize now") {
                    controller.finishThinkingSession()
                }
            } else {
                Button("🧠 Structure my thoughts (beta)…") {
                    controller.startThinkingSession()
                }
                .disabled(controller.phase != .idle)
            }

            Button("Last dictation — edit / translate…") {
                AppWindows.shared.showLastDictation()
            }
            .disabled(history.entries.isEmpty)
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
        Button("Send Feedback…") { Feedback.compose() }
        if !controller.lastTranscript.isEmpty {
            Button("Report Last Transcription…") {
                Feedback.compose(includeLastTranscript: true)
            }
        }
        Button("Open Models Folder") {
            NSWorkspace.shared.open(AppPaths.modelsDirectory)
        }
        Button("Refresh Models") { models.refresh() }

        Divider()
        Button("Quit Desi Dictation") { NSApp.terminate(nil) }
    }

    /// "Auto" names what it actually resolves to — a default the user can't see
    /// is a default they don't trust.
    private var autoLabel: String {
        guard let pick = models.autoChoice(for: settings.languageMode) else {
            return "Auto — no model for this language yet"
        }
        return "Auto (\(pick.name))"
    }

    /// True when an AI-dependent choice is active but the engine isn't ready.
    private var needsLLMSetup: Bool {
        (settings.languageMode == .anyToEnglish || settings.toneMode != .faithful)
            && !llm.status.isReady
    }

    private var statusLine: String {
        switch controller.phase {
        case .disabled: return "Dictation off"
        case .idle:
            return "Ready — hold \(settings.hotkey.displayName)"
        case .recording: return "● Recording… (Esc cancels)"
        case .transcribing: return "Transcribing…"
        case .translating: return "Translating to English…"
        case .polishing: return "Polishing…"
        case .error(let message): return "⚠️ \(message)"
        }
    }
}
