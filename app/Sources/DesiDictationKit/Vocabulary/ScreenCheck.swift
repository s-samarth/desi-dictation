import AppKit

/// "Use names on screen" and "Hinglish: match my spelling", without a
/// microphone (AUTO_VOCABULARY.md): reads the front window the way a
/// dictation does at key-down, runs a dictated sentence through the same
/// corrector, and says what Review would offer.
///
/// It must run as the app itself, with its own Accessibility grant: a tool
/// started from a terminal is refused by the Accessibility server even when
/// `AXIsProcessTrusted()` says yes (2026-10-30). So the app takes a hidden
/// flag, and LaunchServices starts it as itself:
///
///   open -n -a "Desi Dictation" --args --screen-check <seconds> "<text>" [english|hinglish] <out.txt>
public enum ScreenCheck {
    /// In a `--screen-check` launch: waits, checks, writes the report, exits.
    public static func runIfAsked() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--screen-check"), args.count >= i + 5,
              let delay = Double(args[i + 1]) else { return }
        Thread.sleep(forTimeInterval: delay)
        let mode: LanguageMode = args[i + 3] == "english" ? .english : .hinglish
        try? report(dictated: args[i + 2], mode: mode).write(toFile: args[i + 4], atomically: true, encoding: .utf8)
        exit(0)
    }

    public static func report(dictated: String, mode: LanguageMode) -> String {
        guard let app = NSWorkspace.shared.frontmostApplication else { return "no front app" }
        // As AccessibilityPrimer does: Chromium apps build their tree only when asked.
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        Thread.sleep(forTimeInterval: 0.5)
        var lines = ["front app: \(app.localizedName ?? "?")   Accessibility: \(AXIsProcessTrusted())"]
        guard let context = ScreenContextReader.read(includeWindow: true) else {
            return (lines + ["✗ no focused text field could be read"]).joined(separator: "\n")
        }
        let fieldTerms = TermExtractor.terms(from: [context.fieldText])
        let windowTerms = TermExtractor.terms(from: [context.windowTitle] + context.windowTexts)
        let snapshot = VocabularySnapshot(
            terms: (fieldTerms + windowTerms).map { VocabularyTerm($0, source: .screen) },
            fieldWords: mode == .hinglish ? WordTokens.words(in: context.fieldText) : [], rejected: [])
        let fixes = VocabularyCorrector.correct(dictated, mode: mode, snapshot: snapshot).fixes
        lines += ["window title: \(context.windowTitle)",
                  "field text: \(context.fieldText.prefix(160))",
                  "names on screen: \((fieldTerms + windowTerms).prefix(20).joined(separator: ", "))",
                  "dictated (\(mode.rawValue)): \(dictated)",
                  "Review would offer: " + (fixes.isEmpty ? "nothing"
                    : fixes.map { "\($0.from) → \($0.to) (\($0.source))" }.joined(separator: ", "))]
        return lines.joined(separator: "\n")
    }
}
