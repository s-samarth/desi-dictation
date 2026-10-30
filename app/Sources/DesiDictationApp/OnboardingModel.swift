import SwiftUI
import DesiDictationKit

/// What setup has decided so far, shared by its pages (FIRST_RUN.md).
/// One object instead of @State on each page, so Back and Continue keep
/// every choice, and the footer can show download progress on any page.
@MainActor
final class OnboardingModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, language, models, permissions, words, review, done

        /// The progress bar's label; the welcome page has none.
        var label: String {
            switch self {
            case .welcome: return ""
            case .language: return "Language"
            case .models: return "Models"
            case .permissions: return "Permissions"
            case .words: return "Your words"
            case .review: return "Review"
            case .done: return "Done"
            }
        }
    }

    @Published var step: Step = .welcome
    /// English first (user decision 2026-10-30): most people try it in
    /// English before trusting it with Hinglish.
    @Published var language: LanguageMode = .english
    @Published var alsoFor: Set<LanguageMode> = []
    /// Parakeet is the default English model; Qwen is the accurate one.
    @Published var englishFast = true
    @Published var englishAccurate = false

    private var models: ModelManager { .shared }

    var languages: Set<LanguageMode> { alsoFor.union([language]) }

    /// Every model the choices need, VAD last.
    var wanted: [DownloadableModel] {
        var list: [DownloadableModel] = []
        if languages.contains(.english) {
            if englishFast { list.append(ModelManager.catalogEntry(for: .english)) }
            if englishAccurate { list.append(ModelManager.qwenEntry) }
        }
        if languages.contains(.hinglish) { list.append(ModelManager.catalogEntry(for: .hinglish)) }
        if languages.contains(.hindi) { list.append(ModelManager.catalogEntry(for: .hindi)) }
        return list + [ModelManager.vadEntry]
    }

    var missingMB: Int { wanted.filter { !models.isInstalled($0) }.reduce(0) { $0 + $1.approxMB } }
    var allDownloaded: Bool { wanted.allSatisfy { models.isInstalled($0) } }
    var failed: Bool { wanted.contains { models.downloadErrors[$0.id] != nil } }

    /// 0…1 across every wanted model, weighted by size.
    var progress: Double {
        let total = Double(wanted.reduce(0) { $0 + $1.approxMB })
        let done = wanted.reduce(0.0) { sum, item in
            let fraction = models.isInstalled(item) ? 1 : models.downloadProgress[item.id] ?? 0
            return sum + fraction * Double(item.approxMB)
        }
        return total > 0 ? done / total : 1
    }

    /// Starts every download not already done or running. They carry on
    /// while the user goes through the remaining pages.
    func startDownloads() {
        for item in wanted where !models.isInstalled(item) && models.downloadProgress[item.id] == nil {
            models.downloadErrors[item.id] = nil
            Task { await models.download(item) }
        }
    }

    func next() { if let step = Step(rawValue: step.rawValue + 1) { self.step = step } }
    func back() { if let step = Step(rawValue: step.rawValue - 1) { self.step = step } }

    func finish() {
        let settings = SettingsStore.shared
        settings.languageMode = language
        settings.dictationEnabled = true
        settings.onboarded = true
        UserDefaults.standard.set(true, forKey: MenuBarPointer.tourPendingKey)
        AppRelauncher.relaunch()
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
