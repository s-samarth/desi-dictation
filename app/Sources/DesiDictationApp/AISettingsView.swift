import SwiftUI
import DesiDictationKit

/// Everything LLM in one place: engine status + one-time setup, the tone dial,
/// and the shared model. One model powers translate / structure / tone
/// (TRANSLATION.md §4 — build the engine once, features are thin UI on top).
struct AISettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var llm = LLMServices.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable AI features", isOn: $settings.aiFeaturesEnabled)
                    .onChange(of: settings.aiFeaturesEnabled) {
                        if !settings.aiFeaturesEnabled,
                           settings.languageMode.needsLLM {
                            settings.languageMode = .hinglish
                        }
                    }
                Text("Off = the classic dictation app: no AI menu items, no LLM modes, nothing extra to download. Dictation itself is untouched either way.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if settings.aiFeaturesEnabled {
            Section {
                statusRow
                if let guidance = llm.statusGuidance {
                    Text(guidance).font(.caption).foregroundStyle(.secondary)
                }
                if case .modelMissing = llm.status {
                    if let progress = llm.pullProgress {
                        ProgressView(value: progress) {
                            Text("Downloading \(settings.llmModel)…")
                        }
                    } else {
                        Button("Get AI model (one-time download)") {
                            Task { await llm.pullModel() }
                        }
                    }
                }
            } header: {
                Text("On-device AI")
            } footer: {
                Text("Powers “English — from any language”, Translate, Structure my thoughts, and tones. Runs via Ollama on this Mac — nothing leaves it.")
                    .font(.caption)
            }

            Section {
                Picker("Tone", selection: $settings.toneMode) {
                    ForEach(ToneMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Tone of dictated text")
            } footer: {
                Text("Faithful inserts exactly what you said (default). Other tones lightly rewrite the register — never the meaning — and keep your Hinglish Hinglish. History keeps the original next to the rewrite.")
                    .font(.caption)
            }

            Section("Custom cleanup (advanced, Pro)") {
                Toggle("Clean up transcript with your own prompt before inserting",
                       isOn: $settings.ollamaEnabled)
                if settings.ollamaEnabled {
                    TextField("Cleanup model", text: $settings.ollamaModel)
                    TextEditor(text: $settings.cleanupPrompt).frame(height: 60)
                }
            }

            Section("Model (advanced)") {
                HStack {
                    TextField("Ollama model", text: $settings.llmModel)
                        .onSubmit { llm.modelChanged() }
                    Button("Apply") { llm.modelChanged() }
                }
                Text("Default for this Mac: \(LLMServices.defaultModel). gemma3:4b (~3.3 GB) translates Hinglish best; qwen3:1.7b (~1.4 GB) fits 8 GB Macs — numbers are handled by the app either way, but complex sentences suit the bigger model.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            }
        }
        .padding()
        .task { await llm.refreshStatus() }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle().fill(llm.status.isReady ? .green : .orange)
                .frame(width: 10, height: 10)
            switch llm.status {
            case .ready: Text("AI ready — \(settings.llmModel)")
            case .serverDown: Text("Ollama isn't running")
            case .modelMissing: Text("AI model not installed")
            }
            Spacer()
            Button("Refresh") { Task { await llm.refreshStatus() } }
        }
    }
}
