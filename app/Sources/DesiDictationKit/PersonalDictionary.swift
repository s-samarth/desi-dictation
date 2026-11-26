import Foundation
import Combine

/// The personal dictionary (P4-S1; competitors/PATTERNS.md §1 — every serious
/// competitor has one). Names, brand words, code terms: per-user accuracy wins
/// no shared model can deliver. Local JSON, clearable, never uploaded.
///
/// Differences from the legacy `replacementRules` text field (kept for
/// backward compatibility, applied first):
///   - word-boundary aware — "meating"→"meeting" won't corrupt "defeating"
///   - capitalization-preserving — sentence-start "Meating" → "Meeting"
///   - structured storage, so UI can list/edit/remove entries individually
public final class PersonalDictionary: ObservableObject {
    public static let shared = PersonalDictionary()

    @Published public private(set) var entries: [DictionaryEntry] = []
    private let fileURL: URL

    public init(fileURL: URL = AppPaths.supportDirectory
        .appendingPathComponent("dictionary.json")) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - Editing

    public enum AddResult { case unchanged, saved, failed }

    @discardableResult
    public func add(heard: String, written: String, scope: WordScope = .english, mode: EntryMode = .always) -> AddResult {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = written.trimmingCharacters(in: .whitespacesAndNewlines)
        // Case-only rules are legitimate ("jira" → "Jira", "gpt" → "GPT");
        // only an exact self-mapping is meaningless.
        guard !heard.isEmpty, !written.isEmpty, heard != written else { return .unchanged }
        // One rule per heard-form per list: adding again replaces it.
        let sameKey: (DictionaryEntry) -> Bool = { $0.scope == scope && $0.heard.lowercased() == heard.lowercased() }
        if let entry = entries.first(where: sameKey), entry.written == written, entry.mode == mode {
            return .unchanged
        }
        var next = entries.filter { !sameKey($0) }
        next.append(DictionaryEntry(heard: heard, written: written, scope: scope, mode: mode))
        guard save(next) else { return .failed }
        entries = next
        return .saved
    }

    public func setScope(_ scope: WordScope, for entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].scope = scope
        save(entries)
    }

    public func setMode(_ mode: EntryMode, for entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].mode = mode
        save(entries)
    }

    /// The words that apply to a dictation in `mode`.
    public func entries(for mode: LanguageMode) -> [DictionaryEntry] {
        entries.filter { $0.scope.applies(to: mode) }
    }

    public func remove(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save(entries)
    }

    public func removeAll() {
        entries = []
        save(entries)
    }

    // MARK: - Applying

    /// Instance convenience over the pure static core.
    public func apply(to text: String) -> String {
        Self.apply(text, entries: entries)
    }

    /// Pure + static so the pipeline can run it off-main with a snapshot and
    /// tests can hit it directly.
    /// "When it fits" entries are skipped here: ContextFit judges them.
    /// With a `lexicon`, a Hinglish rule from an English word to a Hindi
    /// spelling ("to → toh") skips English sentences (EnglishContext).
    public static func apply(_ text: String, entries: [DictionaryEntry], lexicon: WordLexicon? = nil) -> String {
        var result = text
        for entry in entries where entry.mode == .always {
            let guarded = lexicon.map { EnglishContext.isGuarded(entry, lexicon: $0) } ?? false
            let escaped = NSRegularExpression.escapedPattern(for: entry.heard)
            // \b fails around Devanagari/word-edge punctuation for some terms;
            // fall back to plain replacement if the pattern can't compile.
            guard let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b", options: [.caseInsensitive])
            else {
                result = result.replacingOccurrences(
                    of: entry.heard, with: entry.written, options: [.caseInsensitive])
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                guard let matchRange = Range(match.range, in: result) else { continue }
                if guarded, let lexicon, EnglishContext.surrounds(matchRange, in: result, lexicon: lexicon) {
                    continue
                }
                let matched = String(result[matchRange])
                result.replaceSubrange(
                    matchRange, with: casedLike(matched, replacement: entry.written))
            }
        }
        return result
    }

    /// "Meating" → "Meeting" (sentence start), "MEATING" → "MEETING",
    /// otherwise the dictionary's spelling verbatim.
    public static func casedLike(_ original: String, replacement: String) -> String {
        guard let first = original.first else { return replacement }
        if original == original.uppercased(), original.count > 1 {
            return replacement.uppercased()
        }
        if first.isUppercase, let head = replacement.first, head.isLowercase {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    // MARK: - Persistence (same pattern as HistoryStore)

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    @discardableResult private func save(_ entries: [DictionaryEntry]) -> Bool {
        do {
            try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
            return true
        } catch { return false }
    }
}
