import Foundation

/// Auto-vocabulary hooks (AUTO_VOCABULARY.md), kept out of the main
/// controller file. The pipeline order: dictionary (exact pairs) →
/// vocabulary corrector → translate/tone → paste → watch for edits.
extension DictationController {
    /// Key-down: read the screen while the user talks, stop any old watch.
    func beginVocabulary() {
        EditWatcher.shared.stop()
        VocabularySession.shared.begin(VocabularySession.plan())
    }

    /// Release, on main: what the work queue may use.
    func vocabularyPlan() -> VocabularySession.Plan {
        VocabularySession.plan()
    }

    /// Work queue: near-miss names and Hinglish spellings, after the exact
    /// dictionary step. Returns the transcript unchanged when nothing applies.
    nonisolated static func applyVocabulary(
        _ text: String, mode: LanguageMode, plan: VocabularySession.Plan
    ) -> String {
        let snapshot = VocabularySession.shared.snapshot(plan, mode: mode)
        guard !snapshot.isEmpty, !text.isEmpty else { return text }
        let result = VocabularyCorrector.correct(text, mode: mode, snapshot: snapshot)
        VocabularySession.shared.recordFixes(result.fixes, unfixed: text)
        if !result.fixes.isEmpty {
            // Counts only: the words themselves never reach the log.
            controllerLog.info("vocabulary: \(result.fixes.count, privacy: .public) fixes")
        }
        return result.text
    }

    /// Before an engine call: a biasable engine (Qwen3-ASR) gets this
    /// dictation's hotwords; Parakeet and whisper.cpp don't conform.
    nonisolated static func applyHotwords(to engine: AnyObject) {
        guard let biasable = engine as? HotwordBiasing else { return }
        biasable.setHotwords(VocabularySession.shared.currentHotwords)
    }

    /// After the paste: say what was fixed, and start watching for edits.
    func vocabularyDelivered(_ outcome: InsertOutcome, text: String,
                             fixes: [WordFix]) -> DictationNotice? {
        VocabularySession.shared.end()
        guard outcome == .pasted else { return nil }
        let store = AutoVocabularyStore.shared
        if store.learnFromEdits {
            let mode = sessionLanguage?.mode ?? settingsMode
            EditWatcher.shared.watch(inserted: text) { pairs in
                let dictionary = PersonalDictionary.shared.entries
                for pair in pairs {
                    if let proposal = CorrectionLearner.proposal(
                        for: pair, mode: mode, dictionary: dictionary, rejected: store.rejected) {
                        store.propose(proposal)
                    }
                }
            }
        }
        return DictationNotice.forFixes(fixes)
    }

    private var settingsMode: LanguageMode { SettingsStore.shared.languageMode }
}

extension DictationNotice {
    /// "Fixed: Rowan → Rohan", so an automatic change is never invisible (§3.6).
    public static func forFixes(_ fixes: [WordFix]) -> DictationNotice? {
        guard let first = fixes.first else { return nil }
        let rest = fixes.count > 1 ? " (+\(fixes.count - 1) more — see History)" : ""
        return DictationNotice(kind: .fixed, message: "Fixed: \(first.from) → \(first.to)\(rest)")
    }
}
