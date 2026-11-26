import Foundation

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
public struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    /// What the model tends to output (e.g. "Saraswath", "meating").
    public var heard: String
    /// What must be written instead (e.g. "Saraswat", "meeting").
    public var written: String
    public var scope: WordScope
    /// Always, or only when the sentence fits (cloud → Claude). English only.
    public var mode: EntryMode

    public init(heard: String, written: String, scope: WordScope = .english, mode: EntryMode = .always) {
        self.id = UUID()
        self.heard = heard
        self.written = written
        self.scope = scope
        self.mode = mode
    }

    // Entries saved before the two lists existed were English-mode words.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        heard = try c.decode(String.self, forKey: .heard)
        written = try c.decode(String.self, forKey: .written)
        scope = try c.decodeIfPresent(WordScope.self, forKey: .scope) ?? .english
        mode = try c.decodeIfPresent(EntryMode.self, forKey: .mode) ?? .always
    }
}
