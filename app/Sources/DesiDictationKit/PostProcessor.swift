import Foundation

/// Post-transcription text pipeline:
///   1. user dictionary replacements (Hinglish spelling consistency)
///   2. optional LLM cleanup via local Ollama (privacy-preserving)
public enum PostProcessor {

    /// Rules format (one per line): `find=replace`. Lines without '=' are ignored.
    public static func applyReplacements(_ text: String, rules: String) -> String {
        var result = text
        for line in rules.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let find = parts[0].trimmingCharacters(in: .whitespaces)
            let replace = parts[1].trimmingCharacters(in: .whitespaces)
            guard !find.isEmpty else { continue }
            result = result.replacingOccurrences(
                of: find, with: replace, options: [.caseInsensitive])
        }
        return result
    }

    /// Sends text through a local Ollama model. Returns the original text on any
    /// failure — dictation must never be lost to a flaky LLM.
    public static func ollamaCleanup(
        _ text: String, model: String, prompt: String
    ) async -> String {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return text }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": "\(prompt)\n\n---\n\(text)",
            "stream": false,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return text }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let cleaned = json["response"] as? String,
                  !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return text }
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return text
        }
    }
}
