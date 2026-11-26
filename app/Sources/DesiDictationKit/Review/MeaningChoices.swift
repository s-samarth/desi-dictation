import Foundation

/// Context-specific confirmations from Review. Store at most 128 fingerprints
/// and selected forms in the local preferences. An unanswered prompt teaches nothing.
@MainActor
public struct MeaningChoices {
    private static let key = "hinglish.meaningChoices.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults) { self.defaults = defaults }

    private var rows: [[String: String]] {
        defaults.array(forKey: Self.key) as? [[String: String]] ?? []
    }

    public func preferred(for context: MeaningContext) -> String? {
        guard let key = context.key else { return nil }
        return rows.last(where: { $0["key"] == key })?["word"]
    }

    public func questions(in text: String) -> [UnsureWord] {
        let saved = rows
        return HinglishMeanings.questions(in: text).filter {
            guard let context = $0.meaning else { return false }
            guard let key = context.key else { return true }
            return saved.last(where: { $0["key"] == key })?["word"] != context.current
        }
    }

    public func remember(original: String, final: String, confirmed: Set<String>) {
        let asked = HinglishMeanings.questions(in: original).compactMap(\.meaning)
        guard !asked.isEmpty else { return }
        let finalContexts = HinglishMeanings.questions(in: final).compactMap(\.meaning)
        let finalByKey = Dictionary(grouping: finalContexts, by: \.key)
        let originalByKey = Dictionary(grouping: asked, by: \.key)
        var updated = rows
        for previous in asked {
            guard let key = previous.key, originalByKey[key]?.count == 1,
                let matches = finalByKey[key], matches.count == 1,
                let chosen = matches.first?.current,
                chosen == previous.other || (chosen == previous.current && confirmed.contains(key))
            else { continue }
            updated.removeAll { $0["key"] == key }
            updated.append(["key": key, "word": chosen])
        }
        let bounded = Array(updated.suffix(128))
        if bounded != rows { defaults.set(bounded, forKey: Self.key) }
    }

    func clear() { defaults.removeObject(forKey: Self.key) }
}
