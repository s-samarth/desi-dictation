import AppKit
import DesiDictationKit

/// Explicit, user-initiated feedback (GTM.md §4.1). Opens a pre-filled email
/// draft — every byte of context is VISIBLE in the draft the user sends;
/// nothing is transmitted by the app itself. Privacy promise intact.
enum Feedback {
    static let address = "samarth.iitg@gmail.com"

    @MainActor static func compose(includeLastTranscript: Bool = false) {
        let settings = SettingsStore.shared
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "dev"
        let model = settings.modelPath.isEmpty
            ? "auto" : (settings.modelPath as NSString).lastPathComponent

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
