import Foundation

/// This dictation's terms, deduplicated, with their phonetic keys computed
/// once. When a term arrives from several sources the most trusted one wins:
/// on screen > your dictionary > Contacts.
struct TermIndex {
    struct Entry {
        let term: VocabularyTerm
        let lower: String
        let key: String
    }

    private var byLower: [String: Entry] = [:]
    private var entries: [Entry] = []

    init(_ terms: [VocabularyTerm]) {
        for term in terms {
            let lower = term.text.lowercased()
            // Single words of letters only; "Rohan Mehta" arrives as two terms.
            guard lower.count >= 3, lower.allSatisfy({ $0.isLetter && $0.isASCII }) else { continue }
            if let existing = byLower[lower], Self.rank(existing.term.source) >= Self.rank(term.source) {
                continue
            }
            byLower[lower] = Entry(term: term, lower: lower, key: IndicPhonetics.key(lower))
        }
        entries = Array(byLower.values)
    }

    func containsExact(_ lower: String) -> Bool { byLower[lower] != nil }

    func exact(_ lower: String) -> VocabularyTerm? { byLower[lower]?.term }

    /// Cheap prefilter before the weighted distance: keys of similar length.
    func near(_ key: String) -> [Entry] {
        entries.filter { abs($0.key.count - key.count) <= 2 }
    }

    private static func rank(_ source: VocabularySource) -> Int {
        switch source {
        case .screen, .fieldSpelling: return 3
        case .dictionary: return 2
        case .contacts: return 1
        }
    }
}
