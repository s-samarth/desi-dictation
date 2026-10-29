import AppKit
import DesiDictationKit

/// The email route for feedback (GTM.md §4.1), now the Send Feedback window's
/// "Email instead" button (FeedbackWindow.swift): a pre-filled draft in the
/// user's own mail app, every byte of context visible, sent by them.
enum Feedback {
    static let address = "samarth.iitg@gmail.com"

    @MainActor static func compose(includeLastTranscript: Bool = false) {
        let settings = SettingsStore.shared
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "dev"
        let pinned = settings.modelPath(for: settings.languageMode)
        let model = pinned.isEmpty ? "auto" : (pinned as NSString).lastPathComponent

        var body = ""
        if includeLastTranscript {
            body += """
            What I said (roughly):


            What came out:
            \(DictationController.shared.lastTranscript)


            """
            // When an AI stage ran, include what was HEARD too — a translation
            // bug and a transcription bug need different fixes.
            if let raw = HistoryStore.shared.entries.first?.raw {
                body += """
                What was heard (before AI):
                \(raw)


                """
            }
        }
        body += """
        (Describe what happened / what you expected)


        —— app info: visible to you, edit freely before sending ——
        Desi Dictation \(version) · macOS \(os)
        language: \(settings.languageMode.rawValue) · model: \(model)
        """

        var comps = URLComponents(string: "mailto:\(address)")!
        comps.queryItems = [
            .init(name: "subject", value: "Desi Dictation feedback (\(version))"),
            .init(name: "body", value: body),
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }
}
