import Foundation

/// The language one dictation runs in, and whose choice it was.
///
/// Shown on the overlay so a per-app rule is never silent: a "Claude →
/// English" rule once sent every हिन्दी dictation in Claude to the English
/// model, and nothing on screen said why (USER_WALKTHROUGH §2).
public struct SessionLanguage: Equatable, Sendable {
    public let mode: LanguageMode
    /// The app whose per-app rule overrode the global language; nil when the
    /// global setting decided (including a rule that agrees with it).
    public let ruleApp: String?

    public init(mode: LanguageMode, ruleApp: String?) {
        self.mode = mode
        self.ruleApp = ruleApp
    }

    /// `DictationController.effectiveMode()`'s logic, pure: a rule beats the
    /// global setting; LLM modes fall back to Hinglish while AI is off.
    public static func resolve(
        global: LanguageMode, rule: LanguageMode?, ruleApp: String?, aiEnabled: Bool
    ) -> SessionLanguage {
        var mode = rule ?? global
        if mode.needsLLM, !aiEnabled { mode = .hinglish }
        let overridden = rule != nil && mode != global
        return SessionLanguage(mode: mode, ruleApp: overridden ? ruleApp : nil)
    }
}
