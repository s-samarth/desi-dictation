import Foundation

/// Where a vocabulary term came from. The source decides how much a term is
/// trusted (AUTO_VOCABULARY.md §3.4): text visible right now may overrule a
/// real-but-wrong word, a dictionary term alone may not.
public enum VocabularySource: String, Codable, Sendable {
    /// A written form from the user's PersonalDictionary.
    case dictionary
    /// Text in the focused field or window at dictation start (memory only).
    case screen
    /// Hinglish spelling already used in the field being edited.
    case fieldSpelling
    /// A "when it fits" pair the sentence agreed with (ContextFit).
    case context

    /// Shown next to a fix in History and the overlay.
    public var label: String {
        switch self {
        case .dictionary: return "your dictionary"
        case .screen: return "on screen"
        case .fieldSpelling: return "your spelling"
        case .context: return "fits the sentence"
        }
    }

    /// Visible in this dictation's window: strong enough to replace a real word.
    var isOnScreen: Bool { self == .screen || self == .fieldSpelling }
}

/// One spelling the corrector may write: "Saraswat" (from your dictionary).
public struct VocabularyTerm: Hashable, Sendable {
    public let text: String
    public let source: VocabularySource

    public init(_ text: String, source: VocabularySource) {
        self.text = text
        self.source = source
    }
}

/// One change the corrector made, kept in History so it can be seen and undone.
public struct WordFix: Codable, Hashable, Sendable {
    public let from: String
    public let to: String
    public let source: VocabularySource

    public init(from: String, to: String, source: VocabularySource) {
        self.from = from
        self.to = to
        self.source = source
    }

    /// Case-insensitive identity of the pair, used by the reject list.
    public var pairKey: String { Self.pairKey(from: from, to: to) }

    public static func pairKey(from: String, to: String) -> String {
        "\(from.lowercased())→\(to.lowercased())"
    }
}

/// Everything the corrector needs for one dictation, snapshotted on the main
/// actor and used on the work queue.
public struct VocabularySnapshot: Sendable {
    public var terms: [VocabularyTerm]
    /// Words of the focused field, for Hinglish spelling preference.
    public var fieldWords: [String]
    public var rejected: Set<String>

    public init(terms: [VocabularyTerm] = [], fieldWords: [String] = [],
                rejected: Set<String> = []) {
        self.terms = terms
        self.fieldWords = fieldWords
        self.rejected = rejected
    }

    public var isEmpty: Bool { terms.isEmpty && fieldWords.isEmpty }
}
