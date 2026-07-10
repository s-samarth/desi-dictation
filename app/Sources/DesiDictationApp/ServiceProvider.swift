import AppKit
import DesiDictationKit

/// macOS Services integration (TRANSLATION.md Flow B) — the most native flow
/// there is: select text in ANY app → right-click → Services →
/// "Translate to English (Desi Dictation)". In editable fields macOS swaps
/// the selection for the translation in place; elsewhere the caller decides.
///
/// Registered in AppDelegate (`NSApp.servicesProvider`); menu entries are
/// declared in the bundle's Info.plist (scripts/build_app.sh). The provider
/// replies synchronously because return-type services require it — a 25 s cap
/// keeps a hung local model from freezing the calling app.
final class ServiceProvider: NSObject {

    @objc func translateToEnglish(
        _ pboard: NSPasteboard, userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        translate(pboard, to: .english, error: error)
    }

    @objc func translateToHindi(
        _ pboard: NSPasteboard, userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        translate(pboard, to: .hindi, error: error)
    }

    private func translate(
        _ pboard: NSPasteboard, to target: TargetLanguage,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard SettingsStore.shared.aiFeaturesEnabled else {
            error.pointee = "AI features are switched off — enable them in Desi Dictation → AI."
            return
        }
        guard let text = pboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error.pointee = "No text was selected."
            return
        }
        var result: String?
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            result = try? await LLMServices.shared.translator.translate(text, to: target)
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 25) != .timedOut,
              let translated = result, !translated.isEmpty else {
            // The selection stays untouched — the user's words are never lost.
            error.pointee = "Translation isn't ready — open Desi Dictation → AI to finish the one-time setup."
            return
        }
        pboard.clearContents()
        pboard.setString(translated, forType: .string)
    }
}
