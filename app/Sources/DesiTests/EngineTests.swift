import Foundation
import DesiDictationKit

/// Deterministic stand-in for Ollama: pipeline logic is testable without a
/// server, including failure paths.
final class MockLLM: LocalLLM {
    let model = "mock"
    var reply: (String) -> String = { "T[\($0)]" }
    var shouldFail = false
    var calls = 0

    func status() async -> LLMStatus { shouldFail ? .serverDown : .ready }

    func generate(system: String, user: String) async throws -> String {
        calls += 1
        if shouldFail { throw LLMError.serverUnavailable }
        return reply(user)
    }
}

func runEngineTests() async {
    T.begin("LLMTranslationEngine — chunking invariants")
    let text = Array(repeating: "yeh ek lambi baat hai jo chalti rehti hai.", count: 40)
        .joined(separator: " ")
    let chunks = LLMTranslationEngine.chunks(of: text, budget: 500)
    T.expect(chunks.count > 1, "long text splits")
    T.expect(chunks.allSatisfy { $0.count <= 502 }, "no chunk exceeds budget",
             "max \(chunks.map(\.count).max() ?? 0)")
    let words = { (s: String) in s.split(whereSeparator: \.isWhitespace).count }
    T.equal(chunks.map(words).reduce(0, +), words(text), "no words lost in chunking")
    T.equal(LLMTranslationEngine.chunks(of: "chhota", budget: 500), ["chhota"],
            "short text passes through")
    let paras = LLMTranslationEngine.chunks(of: "para one\n\npara two", budget: 500)
    T.equal(paras.count, 1, "small paragraphs merge into one chunk")

    T.begin("ThoughtStructurer — capping & fallback")
    let (head, overflow) = ThoughtStructurer.capped("word " + String(repeating: "a", count: 20), at: 10)
    T.expect(head == "word", "caps at word boundary", "head=\(head)")
    T.expect(overflow?.hasPrefix("aaa") == true, "overflow preserved")
    let (h2, o2) = ThoughtStructurer.capped("short input", at: 100)
    T.equal(h2, "short input", "under-cap passes whole")
    T.expect(o2 == nil, "no overflow under cap")

    let mock = MockLLM()
    mock.reply = { _ in "## Structured\n- point" }
    let structurer = ThoughtStructurer(llm: mock, inputCap: 60)
    let longRamble = "pehla point yeh hai ki hum late chal rahe hain aur dusra point budget ka hai"
    if let result = try? await structurer.structure(longRamble, style: .notes) {
        T.equal(result.raw, longRamble, "raw transcript always carried (zero-loss)")
        T.expect(result.structured.contains("## Structured"), "LLM output present")
        T.expect(result.structured.contains("unprocessed"), "overflow appended, not dropped")
    } else {
        T.expect(false, "structure succeeds via mock")
    }

    T.begin("OllamaLLM — response hygiene")
    T.equal(OllamaLLM.stripReasoning("<think>hmm</think>answer"), "answer",
            "reasoning stripped")
    T.equal(OllamaLLM.stripReasoning("plain answer"), "plain answer",
            "non-reasoning untouched")

    T.begin("PromptTemplates — structuring never invents")
    T.expect(OutputStyle.allCases.allSatisfy { PromptTemplates.structure(style: $0).contains("NEVER invent") },
             "every style forbids invention")
}
