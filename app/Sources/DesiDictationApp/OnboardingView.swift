import SwiftUI
import DesiDictationKit

/// First-launch flow (v0.5 pilot feedback: "the app just opens in the menu bar,
/// nobody realizes it's there"): pick a language → download its model + VAD →
/// permissions → relaunch. Keeps expectations honest about Hinglish accuracy.
struct OnboardingView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var models = ModelManager.shared
    @State private var choice: LanguageMode = .hinglish
    @State private var alsoDownload: Set<LanguageMode> = []
    @State private var permissions = Permissions.check()

    private var wanted: [DownloadableModel] {
        var entries = [ModelManager.catalogEntry(for: choice)]
        entries += alsoDownload.filter { $0 != choice }.map(ModelManager.catalogEntry(for:))
        entries.append(ModelManager.vadEntry)
        return entries
    }
    private var allDownloaded: Bool { wanted.allSatisfy { models.isInstalled($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Namaste! 🙏").font(.largeTitle.bold())
                Text("Desi Dictation lives in your **menu bar** (the mic icon, top-right). Two minutes of setup and you'll be dictating anywhere on your Mac.")

                Text("1 · Which language will you dictate in most?").font(.headline)
                Picker("", selection: $choice) {
                    Text("Hinglish — \"kal meeting hai, deck ready rakhna\"").tag(LanguageMode.hinglish)
                    Text("English").tag(LanguageMode.english)
                    Text("हिन्दी (Devanagari)").tag(LanguageMode.hindi)
                }
                .pickerStyle(.radioGroup).labelsHidden()
                Text("**Honest note:** Hinglish is our specialty — but code-mixed speech is the hardest problem in dictation, so expect more errors than pure English. If you strictly speak English or want Devanagari output, pick those — they're extremely accurate. You can switch languages anytime from the menu bar.")
                    .font(.caption).foregroundStyle(.secondary)

                Text("Also download models for:").font(.subheadline)
                HStack {
                    // Base languages only — "English from any language" shares
                    // the Hinglish model + adds an AI stage (set up later in AI tab).
                    ForEach([LanguageMode.hinglish, .english, .hindi].filter { $0 != choice },
                            id: \.self) { mode in
                        Toggle(mode.displayName, isOn: Binding(
                            get: { alsoDownload.contains(mode) },
                            set: { on in
                                if on { alsoDownload.insert(mode) }
                                else { alsoDownload.remove(mode) }
                            }))
                    }
                }

                Text("2 · Download your models").font(.headline)
                ForEach(wanted) { item in
                    HStack {
                        Text(item.label).font(.callout)
                        Spacer()
                        if models.isInstalled(item) {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption)
                        } else if let progress = models.downloadProgress[item.id] {
                            ProgressView(value: progress).frame(width: 120)
                        } else {
                            Text("\(item.approxMB) MB").font(.caption).foregroundStyle(.secondary)
                        }
                        if let error = models.downloadErrors[item.id] {
                            Text(error).font(.caption2).foregroundStyle(.red)
                        }
                    }
                }
                Button(allDownloaded ? "All models ready ✓" : "Download (\(wanted.filter { !models.isInstalled($0) }.reduce(0) { $0 + $1.approxMB }) MB)") {
                    for item in wanted where !models.isInstalled(item) {
                        Task { await models.download(item) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(allDownloaded)

                Text("3 · Give macOS permissions").font(.headline)
                permissionRow("Microphone — to hear you", permissions.microphone, .microphone)
                permissionRow("Accessibility — to type into apps", permissions.accessibility, .accessibility)
                permissionRow("Input Monitoring — for the hotkey", permissions.inputMonitoring, .inputMonitoring)
                Button("Re-check permissions") { permissions = Permissions.check() }
                    .font(.caption)

                Divider()
                Text("Then: **hold Right ⌥ (Option)**, speak, release — your words appear wherever your cursor is. Esc cancels. Change the key, language, or model anytime: menu bar mic → Open Desi Dictation.")
                    .font(.callout)
                Text("New ✨: speak Hindi/Hinglish and paste polished English, structure your rambles into notes, or set a tone — one-time AI setup lives in Open Desi Dictation → AI.")
                    .font(.caption).foregroundStyle(.secondary)

                Button("Finish — Restart Desi Dictation") {
                    settings.languageMode = choice
                    settings.dictationEnabled = true
                    settings.onboarded = true
                    AppRelauncher.relaunch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!allDownloaded)
                if !allDownloaded {
                    Text("Finish unlocks once your models are downloaded.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(width: 560, height: 640)
    }

    private func permissionRow(_ label: String, _ granted: Bool, _ pane: Permissions.Pane) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
            Text(label).font(.callout)
            Spacer()
            if !granted { Button("Open Settings") { Permissions.openSystemSettings(pane: pane) } }
        }
    }
}

/// Relaunch so permissions + model preload apply cleanly.
enum AppRelauncher {
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}
