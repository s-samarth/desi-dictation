import Foundation

/// `LocalLLM` backed by a local Ollama server (http://127.0.0.1:11434).
///
/// Why Ollama first (and not vendored llama.cpp, which TRANSLATION.md §4
/// prefers long-term): Ollama is already integrated in this app (PostProcessor
/// AI cleanup), runs fully on-device — the privacy promise holds — and adds
/// zero build dependencies. Vendoring llama.cpp next to our whisper.cpp static
/// libs needs its own spike (both bundle ggml → duplicate-symbol conflicts).
/// This class is deliberately thin so that swap stays cheap.
public final class OllamaLLM: LocalLLM {
    public let model: String
    private let base = URL(string: "http://127.0.0.1:11434")!
    private let timeout: TimeInterval

    public init(model: String, timeout: TimeInterval = 60) {
        self.model = model
        self.timeout = timeout
    }

    // MARK: - Readiness

    public func status() async -> LLMStatus {
        var request = URLRequest(url: base.appendingPathComponent("api/tags"),
                                 timeoutInterval: 3)
        request.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]]
        else { return .serverDown }

        let installed = models.compactMap { $0["name"] as? String }
        // Ollama names may carry a ":latest" suffix the user didn't type.
        let wanted = model.contains(":") ? model : model + ":latest"
        return installed.contains(wanted) || installed.contains(model)
            ? .ready : .modelMissing(model)
    }

    // MARK: - Generation

    public func generate(system: String, user: String) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("api/chat"),
                                 timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "stream": false,
            // Translation/structuring want faithfulness, not creativity.
            "options": ["temperature": 0.2],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.serverUnavailable
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode != 404 else { throw LLMError.modelMissing(model) }
        guard statusCode == 200 else {
            throw LLMError.requestFailed(Self.serverMessage(from: data)
                ?? "server returned \(statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw LLMError.requestFailed("unexpected response shape") }

        let text = Self.stripReasoning(content)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }

    /// Pulls a model through the Ollama server with progress (0…1) — powers the
    /// inline "Get AI model" flow (house rule: downloads happen in-place, with
    /// progress, never "go run a terminal command").
    public func pull(progress: @escaping @Sendable (Double) -> Void) async throws {
        var request = URLRequest(url: base.appendingPathComponent("api/pull"),
                                 timeoutInterval: 3600)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["name": model, "stream": true])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw LLMError.requestFailed("pull rejected — is Ollama running?")
        }
        // Streaming JSONL: {"status":…,"total":…,"completed":…} per line.
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let error = json["error"] as? String {
                throw LLMError.requestFailed(error)
            }
            if let total = json["total"] as? Double,
               let completed = json["completed"] as? Double, total > 0 {
                progress(completed / total)
            }
            if (json["status"] as? String) == "success" { progress(1.0) }
        }
    }

    // MARK: - Response hygiene

    private static func serverMessage(from data: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
    }

    /// Reasoning models wrap deliberation in <think>…</think>; users must only
    /// ever see the answer.
    public static func stripReasoning(_ text: String) -> String {
        guard let open = text.range(of: "<think>"),
              let close = text.range(of: "</think>")
        else { return text }
        var result = text
        result.removeSubrange(open.lowerBound..<close.upperBound)
        return result
    }
}
