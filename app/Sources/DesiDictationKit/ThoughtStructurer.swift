import Foundation

/// The structured result of a thinking session (STRUCTURE_THOUGHTS.md).
/// `raw` is always carried alongside — the zero-loss guarantee: nothing the
/// user said is ever hidden, structured output is verifiable against it.
public struct StructuredThoughts: Equatable, Sendable {
    public let raw: String
    public let structured: String
    public let style: OutputStyle

    public init(raw: String, structured: String, style: OutputStyle) {
        self.raw = raw
        self.structured = structured
        self.style = style
    }
}

/// Turns rambling transcripts into structured markdown via the local LLM
/// (STRUCTURE_THOUGHTS.md §4). Restyling reuses the same transcript with a
/// different template — seconds, not minutes.
public final class ThoughtStructurer {
    private let llm: LocalLLM
    /// v1 input cap ≈ 15 min of speech (~2,000 words ≈ 12k chars). Beyond it we
    /// structure the head and append the tail raw — never drop words silently.
    private let inputCap: Int

    public init(llm: LocalLLM, inputCap: Int = 12_000) {
        self.llm = llm
        self.inputCap = inputCap
    }

    public func status() async -> LLMStatus { await llm.status() }

    public func structure(
        _ transcript: String, style: OutputStyle
    ) async throws -> StructuredThoughts {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return StructuredThoughts(raw: trimmed, structured: "", style: style)
        }
        let (head, overflow) = Self.capped(trimmed, at: inputCap)
        var structured = try await llm.generate(
            system: PromptTemplates.structure(style: style), user: head)
        if let overflow {
            structured += "\n\n---\n**Beyond the 15-minute mark (unprocessed):**\n\n" + overflow
        }
        return StructuredThoughts(raw: trimmed, structured: structured, style: style)
    }

    /// Splits at the cap on a word boundary. Pure + static for testability.
    public static func capped(_ text: String, at cap: Int) -> (head: String, overflow: String?) {
        guard text.count > cap else { return (text, nil) }
        let cut = text.index(text.startIndex, offsetBy: cap)
        let boundary = text[..<cut].lastIndex(of: " ") ?? cut
        let head = String(text[..<boundary])
        let overflow = String(text[boundary...]).trimmingCharacters(in: .whitespaces)
        return (head, overflow.isEmpty ? nil : overflow)
    }
}
