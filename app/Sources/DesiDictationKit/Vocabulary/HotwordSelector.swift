import Foundation

/// An engine whose model can be biased toward words before it transcribes.
/// Qwen3-ASR-1.7B ("Accurate English") is the first: it was trained to use
/// the context in its system prompt, and mlx-audio exposes that as hotwords
/// (AUTO_VOCABULARY.md §2c, Path 2).
///
/// Hooking up an engine takes two steps. The engine conforms; then
/// `EngineRouter` forwards to its active engine (in EngineRouter.swift,
/// where the private `active` is visible):
///
///     extension EngineRouter: HotwordBiasing {
///         public func setHotwords(_ terms: [String]) {
///             (active as? HotwordBiasing)?.setHotwords(terms)
///         }
///     }
///
/// The controller already calls `setHotwords` before every engine call when
/// the engine conforms (DictationController+Vocabulary.swift).
public protocol HotwordBiasing: AnyObject {
    /// Terms for the next transcription, most relevant first. An empty list
    /// clears them. Called on the engine's work queue.
    func setHotwords(_ terms: [String])
}

/// Chooses the few terms a biasable engine gets *before* any audio is
/// decoded. Speech LLMs get worse as distractors grow, and word order
/// matters (BR-ASR; Huber & Waibel 2026), so the list is short, ordered,
/// and only what this dictation can see plus your own dictionary.
public enum HotwordSelector {
    public static let limit = 30

    public static func select(
        fieldTerms: [String], windowTerms: [String],
        dictionary: [String], limit: Int = limit
    ) -> [String] {
        // The field you're writing in first, then the window, then your own words.
        let ordered = fieldTerms + windowTerms + dictionary
        var seen = Set<String>()
        var out: [String] = []
        for term in ordered where seen.insert(term.lowercased()).inserted {
            out.append(term)
            if out.count == limit { break }
        }
        return out
    }

    /// The context text for a model that takes free-form context instead of a
    /// list. Qwen3-ASR integrations use exactly this shape ("Vocabulary: …").
    public static func contextPrompt(_ terms: [String]) -> String {
        terms.isEmpty ? "" : "Vocabulary: " + terms.joined(separator: ", ") + "."
    }
}
