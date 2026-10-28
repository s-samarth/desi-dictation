import AppKit

/// One dictation's vocabulary, from key-down to paste. The screen is read
/// while the user talks, so it adds nothing to the wait after release;
/// whatever isn't ready by correction time is simply skipped.
///
/// Thread-safe: written from a background read, read on the work queue
/// (correction, hotwords) and on main (delivery).
public final class VocabularySession: @unchecked Sendable {
    public static let shared = VocabularySession()

    private let lock = NSLock()
    private var generation = 0
    private var screenTerms: [VocabularyTerm] = []
    private var fieldWords: [String] = []
    private var hotwords: [String] = []
    private var lastFixes: (fixes: [WordFix], unfixed: String)?
    private let readQueue = DispatchQueue(label: "desi.vocab.screen", qos: .userInitiated)

    /// What the main actor knows at recording start: toggles and the stored lists.
    public struct Plan: Sendable {
        var readScreen: Bool
        var readField: Bool
        var useVocabulary: Bool
        var hinglishSpelling: Bool
        var dictionaryTerms: [String]
        var rejected: Set<String>
        /// English "when it fits" pairs and the app being dictated into (ContextFit).
        var fitEntries: [DictionaryEntry] = []
        var appName: String?
    }

    @MainActor
    public static func plan(mode: LanguageMode? = nil, store: AutoVocabularyStore = .shared,
                            dictionary: PersonalDictionary = .shared) -> Plan {
        let words = mode.map { dictionary.entries(for: $0) } ?? dictionary.entries
        // English only: small models are weak on Roman Hinglish (VOCABULARY_NEXT.md).
        let fit = mode == .english ? words.filter { $0.mode == .whenItFits } : []
        return Plan(readScreen: store.fixNearMisses && store.readScreen,
             readField: store.needsFieldText,
             useVocabulary: store.fixNearMisses,
             hinglishSpelling: store.hinglishFieldSpelling,
             dictionaryTerms: words.flatMap { WordTokens.words(in: $0.written) },
             rejected: store.rejected,
             fitEntries: fit,
             appName: NSWorkspace.shared.frontmostApplication?.localizedName)
    }

    /// Recording started: forget the last dictation, read the screen if asked.
    public func begin(_ plan: Plan) {
        lock.lock()
        generation += 1
        let mine = generation
        screenTerms = []; fieldWords = []; lastFixes = nil
        hotwords = plan.useVocabulary ? Array(plan.dictionaryTerms.prefix(HotwordSelector.limit)) : []
        lock.unlock()
        guard plan.readField || plan.readScreen else { return }
        readQueue.async { [self] in
            guard let context = ScreenContextReader.read(includeWindow: plan.readScreen) else { return }
            let fieldTerms = plan.readScreen ? TermExtractor.terms(from: [context.fieldText]) : []
            let windowTerms = plan.readScreen
                ? TermExtractor.terms(from: [context.windowTitle] + context.windowTexts) : []
            lock.lock(); defer { lock.unlock() }
            guard mine == generation else { return }
            screenTerms = (fieldTerms + windowTerms).map { VocabularyTerm($0, source: .screen) }
            fieldWords = plan.hinglishSpelling ? WordTokens.words(in: context.fieldText) : []
            if plan.useVocabulary {
                hotwords = HotwordSelector.select(fieldTerms: fieldTerms, windowTerms: windowTerms,
                                                  dictionary: plan.dictionaryTerms)
            }
        }
    }

    /// Terms read from the screen this dictation (cues for ContextFit).
    public var currentScreenTerms: [String] {
        lock.lock(); defer { lock.unlock() }
        return screenTerms.map(\.text)
    }

    /// Hotwords for a biasable engine (Qwen3-ASR); empty for the others.
    public var currentHotwords: [String] {
        lock.lock(); defer { lock.unlock() }
        return hotwords
    }

    /// Everything the corrector may use right now.
    public func snapshot(_ plan: Plan, mode: LanguageMode) -> VocabularySnapshot {
        lock.lock(); defer { lock.unlock() }
        var terms: [VocabularyTerm] = []
        if plan.useVocabulary {
            terms += screenTerms
            terms += plan.dictionaryTerms.map { VocabularyTerm($0, source: .dictionary) }
        }
        let hinglish = mode == .hinglish || mode == .anyToEnglish
        return VocabularySnapshot(terms: terms, fieldWords: hinglish ? fieldWords : [],
                                  rejected: plan.rejected)
    }

    public func recordFixes(_ fixes: [WordFix], unfixed: String) {
        lock.lock(); defer { lock.unlock() }
        lastFixes = fixes.isEmpty ? nil : (fixes, unfixed)
    }

    /// The fixes of the dictation being delivered, once.
    public func takeFixes() -> (fixes: [WordFix], unfixed: String)? {
        lock.lock(); defer { lock.unlock() }
        defer { lastFixes = nil }
        return lastFixes
    }

    /// Cancel / end: drop everything read from the screen.
    public func end() {
        lock.lock(); defer { lock.unlock() }
        generation += 1
        screenTerms = []; fieldWords = []; hotwords = []
    }
}
