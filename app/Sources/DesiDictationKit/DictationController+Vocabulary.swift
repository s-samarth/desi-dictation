import Foundation

/// Auto-vocabulary hooks (AUTO_VOCABULARY.md), kept out of the main
/// controller file. The pipeline order: dictionary (exact pairs) →
/// vocabulary corrector → translate/tone → paste → watch for edits.
extension DictationController {
    /// Key-down: read the screen while the user talks, stop any old watch.
    func beginVocabulary() {
        EditWatcher.shared.stop()
        AccessibilityPrimer.primeFrontmost()
        let plan = VocabularySession.plan(mode: vocabularyMode)
        VocabularySession.shared.begin(plan)
        if !plan.fitEntries.isEmpty { ContextChecker.shared.warmUp() }
    }

    /// Release, on main: what the work queue may use.
    func vocabularyPlan() -> VocabularySession.Plan {
        VocabularySession.plan(mode: vocabularyMode)
    }

    /// This dictation's language, so only its words are used.
    private var vocabularyMode: LanguageMode { sessionLanguage?.mode ?? settingsMode }

    /// Work queue: near-miss names and Hinglish spellings, after the exact
    /// dictionary step, then "when it fits" pairs (English). Returns the
    /// transcript unchanged when nothing applies.
    nonisolated static func applyVocabulary(
        _ text: String, mode: LanguageMode, plan: VocabularySession.Plan
    ) -> String {
        let session = VocabularySession.shared
        let snapshot = session.snapshot(plan, mode: mode)
        let runFit = mode == .english && !plan.fitEntries.isEmpty
        guard !text.isEmpty, !snapshot.isEmpty || runFit else { return text }
        var corrected = text
        var fixes: [WordFix] = []
        if !snapshot.isEmpty {
            let result = VocabularyCorrector.correct(text, mode: mode, snapshot: snapshot)
            corrected = result.text
            fixes = result.fixes
        }
        if runFit {
            let started = Date()
            let fit = ContextFit.apply(
                corrected, entries: plan.fitEntries,
                cues: FitCues(screenTerms: session.currentScreenTerms, appName: plan.appName),
                scorer: ContextChecker.shared.loaded(),
                prefix: ContextFit.prompt, rejected: plan.rejected)
            corrected = fit.text
            fixes += fit.fixes
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            controllerLog.info("context fit: \(fit.decisions.count, privacy: .public) checked in \(ms, privacy: .public) ms")
            Task { @MainActor in logFitDecisions(fit.decisions, ms: ms) }
        }
        session.recordFixes(fixes, unfixed: text)
        if !fixes.isEmpty {
            // Counts only: the words themselves never reach the log.
            controllerLog.info("vocabulary: \(fixes.count, privacy: .public) fixes")
        }
        return corrected
    }

    /// Kept words are said too, so "why didn't it write Claude?" has an answer.
    @MainActor private static func logFitDecisions(_ decisions: [FitDecision], ms: Int) {
        for decision in decisions where !decision.swapped {
            let why = decision.modelDelta == nil
                ? "no context checker loaded and no on-screen hint"
                : "the sentence reads better as \"\(decision.heard)\""
            VocabularyActivityLog.shared.add(.info, "Kept \"\(decision.heard)\" (not \"\(decision.written)\"): \(why). \(ms) ms.")
        }
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
                if let undone = CorrectionLearner.revertedFix(pair, fixes: fixes), undone.source == .context {
                    // A context fix depends on the sentence: one undo isn't "never".
                    log.add(.info, "You changed \"\(undone.to)\" back to \"\(undone.from)\" here. \"When it fits\" still decides per sentence; switch it to Always or remove it in Your words.")
                } else if let undone = CorrectionLearner.revertedFix(pair, fixes: fixes) {
                    store.respect(undone)
                    log.add(.learned, "You changed \"\(undone.to)\" back, so it won't make that fix again.")
                } else if store.learnFromEdits, let proposal = CorrectionLearner.proposal(
                    for: pair, mode: mode, dictionary: dictionary, rejected: []) {
                    let scope = WordScope(mode: mode) ?? .english
                    let words = "\"\(proposal.heard)\" as \"\(proposal.typed)\""
                    switch store.propose(proposal, scope: scope) {
                    case .asked: log.add(.suggested, "Suggested for your \(scope.label) words: always write \(words)")
                    case .waiting: log.add(.info, "Writing \(words) is already waiting for your answer.")
                    case .snoozed(let left):
                        log.add(.info, "You said Not now to writing \(words). It asks again after \(left) more fix\(left == 1 ? "" : "es").")
                    case .rejected:
                        log.add(.info, "You turned down writing \(words). Vocabulary → Advanced → Allow again brings it back.")
                    }
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
