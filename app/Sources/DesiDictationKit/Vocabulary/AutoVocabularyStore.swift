import Foundation
import Combine

/// An "Always write X as Y?" proposal waiting for the user's answer.
public struct VocabularySuggestion: Codable, Identifiable, Equatable {
    public let id: UUID
    public let heard: String
    public let written: String
    public let date: Date
    /// Where the word will apply once accepted (Hinglish spellings stay Hinglish).
    public let scope: WordScope

    public init(heard: String, written: String, scope: WordScope = .english) {
        id = UUID()
        self.heard = heard
        self.written = written
        date = Date()
        self.scope = scope
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        heard = try c.decode(String.self, forKey: .heard)
        written = try c.decode(String.self, forKey: .written)
        date = try c.decode(Date.self, forKey: .date)
        scope = try c.decodeIfPresent(WordScope.self, forKey: .scope) ?? .english
    }

    var pairKey: String { WordFix.pairKey(from: heard, to: written) }
}

/// What `propose` did with a pair, so the activity list can say why.
public enum ProposalOutcome: Equatable {
    case asked
    /// Already waiting under "Waiting for you".
    case waiting
    /// "Not now" earlier: asked again after `left` more sightings.
    case snoozed(left: Int)
    /// "Never", or an undone automatic fix.
    case rejected
}

/// Smart-vocabulary settings, pending proposals and the reject list
/// (AUTO_VOCABULARY.md). Its own file and defaults keys, so it never collides
/// with SettingsStore. Everything is **off** by default. What this stores is
/// only what the user typed or rejected; screen text is never
/// written anywhere.
public final class AutoVocabularyStore: ObservableObject {
    public static let shared = AutoVocabularyStore()

    @Published public var learnFromEdits: Bool { didSet { d.set(learnFromEdits, forKey: "autoVocab.learnFromEdits") } }
    @Published public var fixNearMisses: Bool { didSet { d.set(fixNearMisses, forKey: "autoVocab.fixNearMisses") } }
    @Published public var readScreen: Bool { didSet { d.set(readScreen, forKey: "autoVocab.readScreen") } }
    @Published public var hinglishFieldSpelling: Bool {
        didSet { d.set(hinglishFieldSpelling, forKey: "autoVocab.hinglishFieldSpelling") }
    }

    @Published public private(set) var suggestions: [VocabularySuggestion] = []
    /// Pair keys ("rowan→rohan") never applied or proposed again.
    @Published public private(set) var rejected: Set<String> = []
    /// The newest proposal, for the on-screen prompt. The UI clears it.
    @Published public var liveSuggestion: VocabularySuggestion?
    /// A one-line confirmation for the popup ("Got it — …"). The UI clears it.
    @Published public var liveAcknowledgement: String?

    private var dismissCounts: [String: Int] = [:]
    /// Pair key → sightings left before it's asked again ("Not now").
    private var snoozed: [String: Int] = [:]
    private let d: UserDefaults
    private let fileURL: URL

    public init(fileURL: URL = AppPaths.supportDirectory.appendingPathComponent("autovocab.json"),
                defaults: UserDefaults = .standard) {
        self.fileURL = fileURL
        d = defaults
        learnFromEdits = defaults.bool(forKey: "autoVocab.learnFromEdits")
        fixNearMisses = defaults.bool(forKey: "autoVocab.fixNearMisses")
        readScreen = defaults.bool(forKey: "autoVocab.readScreen")
        hinglishFieldSpelling = defaults.bool(forKey: "autoVocab.hinglishFieldSpelling")
        load()
    }

    /// The focused field is needed for names (screen) or Hinglish spelling.
    public var needsFieldText: Bool { (fixNearMisses && readScreen) || hinglishFieldSpelling }

    // MARK: - Proposals

    /// Queues a proposal; duplicates, snoozed and rejected pairs are dropped.
    @discardableResult
    public func propose(_ pair: EditPair, scope: WordScope = .english) -> ProposalOutcome {
        let suggestion = VocabularySuggestion(heard: pair.heard, written: pair.typed, scope: scope)
        let key = suggestion.pairKey
        if rejected.contains(key) { return .rejected }
        if suggestions.contains(where: { $0.pairKey == key }) { return .waiting }
        if let left = snoozed[key], left > 1 {
            snoozed[key] = left - 1
            save()
            return .snoozed(left: left - 1)
        }
        snoozed[key] = nil
        suggestions.insert(suggestion, at: 0)
        liveSuggestion = suggestion
        save()
        return .asked
    }

    /// "Add": the pair becomes a normal PersonalDictionary entry.
    public func accept(_ suggestion: VocabularySuggestion, into dictionary: PersonalDictionary = .shared) {
        dictionary.add(heard: suggestion.heard, written: suggestion.written, scope: suggestion.scope)
        remove(suggestion)
        let line = "Learned: \"\(suggestion.heard)\" is now always written \"\(suggestion.written)\""
        Task { @MainActor in VocabularyActivityLog.shared.add(.learned, line) }
    }

    /// "Not now" never means never (it once did, after two): the pair is
    /// asked again on its 3rd sighting, then the 6th, 12th, and every 24th.
    public func dismiss(_ suggestion: VocabularySuggestion) {
        dismissCounts[suggestion.pairKey, default: 0] += 1
        snoozed[suggestion.pairKey] = Self.snoozeLength(afterDismissals: dismissCounts[suggestion.pairKey]!)
        remove(suggestion)
    }

    static func snoozeLength(afterDismissals n: Int) -> Int { min(3 << max(n - 1, 0), 24) }

    /// "Never": stop proposing this pair.
    public func never(_ suggestion: VocabularySuggestion) {
        rejected.insert(suggestion.pairKey)
        remove(suggestion)
    }

    // MARK: - Undoing an automatic fix

    /// "Don't change this again", from History.
    public func reject(_ fix: WordFix) {
        rejected.insert(fix.pairKey)
        save()
    }

    /// The user undid an automatic fix in the field: never make it again,
    /// and say so (the popup shows `liveAcknowledgement`).
    public func respect(_ fix: WordFix) {
        reject(fix)
        liveAcknowledgement = "Got it — \"\(fix.from)\" stays \"\(fix.from)\" from now on."
    }

    public func clearRejections() {
        rejected = []
        dismissCounts = [:]
        snoozed = [:]
        save()
    }

    func remove(_ suggestion: VocabularySuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
        if liveSuggestion?.id == suggestion.id { liveSuggestion = nil }
        save()
    }

    // MARK: - Persistence (same pattern as PersonalDictionary)

    private struct Stored: Codable {
        var suggestions: [VocabularySuggestion]
        var rejected: [String]
        var dismissCounts: [String: Int]
        var snoozed: [String: Int]?
        /// nil = written before "Not now" stopped rejecting (version 2).
        var version: Int?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        suggestions = stored.suggestions
        rejected = Set(stored.rejected)
        dismissCounts = stored.dismissCounts
        snoozed = stored.snoozed ?? [:]
        if stored.version == nil {
            // Pairs rejected by two "Not now"s get asked again; "Never" and
            // undone fixes have no dismissals, so they stay.
            rejected.subtract(dismissCounts.filter { $0.value >= 2 }.keys)
            save()
        }
    }

    private func save() {
        let stored = Stored(suggestions: suggestions, rejected: rejected.sorted(), dismissCounts: dismissCounts,
                            snoozed: snoozed, version: 2)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
