import Foundation
import Combine

/// Which list a word lives in. The rule is the language you dictate in:
/// Hinglish dictations use the Hinglish list, English ones the English list,
/// so "nahin → nahi" never touches English text. हिन्दी has no vocabulary.
public enum WordScope: String, Codable, CaseIterable, Sendable {
    case english, hinglish

    public var label: String {
        switch self {
        case .english: return "English"
        case .hinglish: return "Hinglish"
        }
    }

    /// The list for a dictation language; nil for हिन्दी (no vocabulary).
    /// "English from any language" transcribes as Hinglish first.
    public init?(mode: LanguageMode) {
        switch mode {
        case .english: self = .english
        case .hinglish, .anyToEnglish: self = .hinglish
        case .hindi: return nil
        }
    }

    public func applies(to mode: LanguageMode) -> Bool { WordScope(mode: mode) == self }
}

/// One learned spelling: "when you hear X, always write Y".
public struct DictionaryEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    /// What the model tends to output (e.g. "Saraswath", "meating").
    public var heard: String
    /// What must be written instead (e.g. "Saraswat", "meeting").
    public var written: String
    public var scope: WordScope

    public init(heard: String, written: String, scope: WordScope = .english) {
        self.id = UUID()
        self.heard = heard
        self.written = written
        self.scope = scope
    }

    // Entries saved before the two lists existed were English-mode words.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        heard = try c.decode(String.self, forKey: .heard)
        written = try c.decode(String.self, forKey: .written)
        scope = try c.decodeIfPresent(WordScope.self, forKey: .scope) ?? .english
    }
}

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

    public func add(heard: String, written: String, scope: WordScope = .english) {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = written.trimmingCharacters(in: .whitespacesAndNewlines)
        // Case-only rules are legitimate ("jira" → "Jira", "gpt" → "GPT");
        // only an exact self-mapping is meaningless.
        guard !heard.isEmpty, !written.isEmpty, heard != written else { return }
        // One rule per heard-form per list: adding again replaces it.
        entries.removeAll { $0.heard.lowercased() == heard.lowercased() && $0.scope == scope }
        entries.append(DictionaryEntry(heard: heard, written: written, scope: scope))
        save()
    }

    public func setScope(_ scope: WordScope, for entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].scope = scope
        save()
    }

    /// The words that apply to a dictation in `mode`.
    public func entries(for mode: LanguageMode) -> [DictionaryEntry] {
        entries.filter { $0.scope.applies(to: mode) }
    }

    public func remove(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    public func removeAll() {
        entries = []
        save()
    }

    // MARK: - Applying

    /// Instance convenience over the pure static core.
    public func apply(to text: String) -> String {
        Self.apply(text, entries: entries)
    }

    /// Pure + static so the pipeline can run it off-main with a snapshot and
    /// tests can hit it directly.
    public static func apply(_ text: String, entries: [DictionaryEntry]) -> String {
        var result = text
        for entry in entries {
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

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
