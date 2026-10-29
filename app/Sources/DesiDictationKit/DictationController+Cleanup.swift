import Foundation

/// Filler clean-up in the pipeline (FILLERS_AND_CORRECTIONS.md): only what
/// the user switched on is applied. um/uh/hmm go when "Remove um and uh" is
/// on (default); fillers the context checker is sure of go when "Remove
/// fillers when sure" is on (English). Everything else is only offered in
/// Review before paste.
extension DictationController {
    struct CleanupPlan: Sendable {
        var sounds: Bool
        var sureFillers: Bool
    }

    /// Read on main at release, like the other settings the work queue uses.
    @MainActor static var cleanupPlan: CleanupPlan {
        CleanupPlan(sounds: CleanupSettings.shared.removeSounds,
                    sureFillers: CleanupSettings.shared.removeSureFillers)
    }

    /// Work queue: the text with the switched-on clean-up applied.
    nonisolated static func applyCleanup(_ text: String, mode: LanguageMode, plan: CleanupPlan) -> String {
        var out = text
        if plan.sounds { out = Fillers.removeSounds(out) }
        if plan.sureFillers, mode == .english, let scorer = ContextChecker.shared.loaded() {
            let result = Fillers.removeSure(out, scorer: scorer)
            if !result.removed.isEmpty {
                controllerLog.info("cleanup: removed \(result.removed.count, privacy: .public) sure fillers")
            }
            out = result.text
        }
        return out
    }
}
