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

    T.begin("LLMTranslationEngine — via mock")
    let mock = MockLLM()
    let engine = LLMTranslationEngine(llm: mock)
    let out = try? await engine.translate("namaste duniya", to: .english)
    T.equal(out, "T[namaste duniya]", "translate calls the LLM once")
    T.equal(mock.calls, 1, "single call for short input")
    let empty = try? await engine.translate("   ", to: .english)
    T.equal(empty, "", "whitespace input short-circuits, no LLM call")
    T.equal(mock.calls, 1, "no call for empty input")
    mock.shouldFail = true
    do {
        _ = try await engine.translate("fail please", to: .english)
        T.expect(false, "failure propagates as thrown error")
    } catch {
        T.expect(true, "failure propagates as thrown error")
    }

    T.begin("ThoughtStructurer — capping & fallback")
    let (head, overflow) = ThoughtStructurer.capped("word " + String(repeating: "a", count: 20), at: 10)
    T.expect(head == "word", "caps at word boundary", "head=\(head)")
    T.expect(overflow?.hasPrefix("aaa") == true, "overflow preserved")
    let (h2, o2) = ThoughtStructurer.capped("short input", at: 100)
    T.equal(h2, "short input", "under-cap passes whole")
    T.expect(o2 == nil, "no overflow under cap")

    mock.shouldFail = false
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

    T.begin("PromptTemplates — sanity")
    T.expect(PromptTemplates.tone(.faithful) == nil, "faithful tone = no LLM pass")
    for tone in ToneMode.allCases where tone != .faithful {
        T.expect(PromptTemplates.tone(tone)?.isEmpty == false, "tone \(tone) has prompt")
    }
    for style in OutputStyle.allCases {
        T.expect(!PromptTemplates.structure(style: style).isEmpty, "style \(style) has prompt")
        T.expect(PromptTemplates.structure(style: style).contains("NEVER invent"),
                 "style \(style) forbids invention")
    }
    T.expect(PromptTemplates.translate(to: .english).contains("Output ONLY"),
             "translate prompt constrains output")
}
