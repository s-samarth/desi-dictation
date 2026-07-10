import Foundation

/// Engine abstraction for on-device translation, mirroring `TranscriptionEngine`
/// (TRANSLATION.md §4). Callers depend on this, not on any backend.
public protocol TranslationEngine: AnyObject {
    func status() async -> LLMStatus
    func translate(_ text: String, to language: TargetLanguage) async throws -> String
}

/// Translation via the shared local LLM. Long inputs are translated in
/// paragraph chunks (TRANSCRIBE_TRANSLATE.md §3: ">~2 min → translate in
/// chunks"); sentence-level context stays intact because chunks split only on
/// blank lines or at a generous character budget.
public final class LLMTranslationEngine: TranslationEngine {
    private let llm: LocalLLM
    /// ~2 minutes of speech ≈ 260 words ≈ 1,600 chars; 4,000 is comfortably
    /// inside a small model's context with the template.
    private let chunkBudget: Int

    public init(llm: LocalLLM, chunkBudget: Int = 4000) {
        self.llm = llm
        self.chunkBudget = chunkBudget
    }

    public func status() async -> LLMStatus { await llm.status() }

    public func translate(_ text: String, to language: TargetLanguage) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let system = PromptTemplates.translate(to: language)

        guard trimmed.count > chunkBudget else {
            return try await llm.generate(system: system, user: trimmed)
        }
        var results: [String] = []
        for chunk in Self.chunks(of: trimmed, budget: chunkBudget) {
            results.append(try await llm.generate(system: system, user: chunk))
        }
        return results.joined(separator: "\n\n")
    }

    /// Splits on paragraph boundaries first, then sentence-ish boundaries,
    /// so no chunk cuts mid-thought. Pure + static for testability.
    public static func chunks(of text: String, budget: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for paragraph in text.components(separatedBy: "\n\n") {
            let pieces = paragraph.count > budget
                ? splitBySentence(paragraph, budget: budget) : [paragraph]
            for piece in pieces {
                if current.isEmpty {
                    current = piece
                } else if current.count + piece.count + 2 <= budget {
                    current += "\n\n" + piece
                } else {
                    chunks.append(current)
                    current = piece
                }
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func splitBySentence(_ text: String, budget: Int) -> [String] {
        var pieces: [String] = []
        var current = ""
        // Dictated text may lack punctuation entirely — fall back to words.
        let units = text.contains(". ")
            ? text.components(separatedBy: ". ").map { $0 + "." }
            : text.split(separator: " ").map(String.init)
        for unit in units {
            if current.isEmpty {
                current = unit
            } else if current.count + unit.count + 1 <= budget {
                current += " " + unit
            } else {
                pieces.append(current)
                current = unit
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}
