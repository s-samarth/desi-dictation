import Foundation

/// Auto-vocabulary hooks (AUTO_VOCABULARY.md), kept out of the main
/// controller file. The pipeline order: dictionary (exact pairs) →
/// vocabulary corrector → translate/tone → paste → watch for edits.
extension DictationController {
    /// Key-down: read the screen while the user talks, stop any old watch.
    func beginVocabulary() {
        EditWatcher.shared.stop()
        AccessibilityPrimer.primeFrontmost()
        VocabularySession.shared.begin(VocabularySession.plan(mode: vocabularyMode))
    }

    /// Release, on main: what the work queue may use.
    func vocabularyPlan() -> VocabularySession.Plan {
        VocabularySession.plan(mode: vocabularyMode)
    }

    /// This dictation's language, so only its words are used.
    private var vocabularyMode: LanguageMode { sessionLanguage?.mode ?? settingsMode }

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
        // Watch when there's something to learn, or a fix the user may undo.
        let log = VocabularyActivityLog.shared
        for fix in fixes { log.add(.fixed, "Fixed \"\(fix.from)\" → \"\(fix.to)\" (\(fix.source.label))") }
        let mode = vocabularyMode
        // हिन्दी has no vocabulary list, so nothing to learn there.
        if store.learnFromEdits || !fixes.isEmpty, WordScope(mode: mode) != nil {
            EditWatcher.shared.watch(inserted: text) { event in
                Self.handle(event, fixes: fixes, mode: mode)
            }
        }
        return DictationNotice.forFixes(fixes)
    }

    /// Turns what the watcher saw into proposals, undo-respects, and a line
    /// in the activity log either way, so "nothing happened" has a reason.
    private static func handle(_ event: EditWatcher.Event, fixes: [WordFix], mode: LanguageMode) {
        let store = AutoVocabularyStore.shared, log = VocabularyActivityLog.shared
        switch event {
        case .unreadable(let app):
            log.add(.problem, "Couldn't read the text in \(app) after pasting, so edits there can't be learned. Try again in a moment; some apps need a few seconds the first time.")
        case .watching(let app):
            if store.learnFromEdits {
                log.add(.info, "Watching your text in \(app) for 30 s. Fix a misheard word to teach it.")
            }
        case .edited(let pairs, let app):
            if pairs.isEmpty {
                log.add(.info, "Saw your edit in \(app), but no misheard word was swapped (rewrites and new sentences are skipped).")
            }
            let dictionary = PersonalDictionary.shared.entries(for: mode)
            for pair in pairs {
                if let undone = CorrectionLearner.revertedFix(pair, fixes: fixes) {
                    store.respect(undone)
                    log.add(.learned, "You changed \"\(undone.to)\" back, so it won't make that fix again.")
                } else if store.learnFromEdits, let proposal = CorrectionLearner.proposal(
                    for: pair, mode: mode, dictionary: dictionary, rejected: store.rejected) {
                    let scope = WordScope(mode: mode) ?? .english
                    store.propose(proposal, scope: scope)
                    log.add(.suggested, "Suggested for your \(scope.label) words: always write \"\(proposal.heard)\" as \"\(proposal.typed)\"")
                } else {
                    log.add(.info, "Saw \"\(pair.heard)\" → \"\(pair.typed)\" in \(app). Not a sound-alike, so no suggestion.")
                }
            }
        }
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
