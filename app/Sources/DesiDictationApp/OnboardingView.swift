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

                step(1, "Which language will you dictate in most?")
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
                    // the Hinglish model + adds an AI stage (unreleased).
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

                step(2, "Download your models")
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

                step(3, "Give macOS permissions")
                OnboardingPermissions()

                step(4, "Teach it your names (optional)")
                Text("Fixes names it keeps getting wrong, and learns from the words you correct. All off until you turn them on. The Guide page (opens after setup) explains each one.")
                    .font(.caption).foregroundStyle(.secondary)
                Form { SmartVocabularyToggles() }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                    .frame(height: 230)

                step(5, "Check before pasting (optional)")
                Text("A panel can show your words before they're pasted, with the ones that may be wrong underlined: **orange** when the audio was unclear, **purple** when a word is odd in its sentence (a name, or a mishearing like \"one PC\" for \"One Piece\"). It suggests, you decide: nothing is changed for you. **Moderate** (default) suits most people; Liberal underlines only likely mistakes, Conservative catches more but asks more often. Purple needs the optional context checker (397 MB, Get button below once review is on). All of this is optional; you can leave it off.")
                    .font(.caption).foregroundStyle(.secondary)
                Form { ReviewSection() }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                    .frame(height: settings.reviewMode == .off ? 170 : 260)

                Divider()
                MenuBarHomeNote()
                Text("Then: **hold Right ⌥ (Option)**, speak, release — your words appear wherever your cursor is. Esc cancels. Change the key, language or model anytime: menu bar mic → Open Desi Dictation…")
                    .font(.callout)

                Button("Finish — Restart Desi Dictation") {
                    settings.languageMode = choice
                    settings.dictationEnabled = true
                    settings.onboarded = true
                    UserDefaults.standard.set(true, forKey: MenuBarPointer.tourPendingKey)
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
        .tint(Theme.accent)
        .frame(width: 560, height: 640)
    }

    /// Step heading with a saffron number badge.
    private func step(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.accent, in: Circle())
            Text(title).font(.headline)
        }
        .padding(.top, 4)
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
