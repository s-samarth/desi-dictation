import Foundation

/// Target language for on-device translation (TRANSLATION.md §4).
public enum TargetLanguage: String, CaseIterable, Codable, Sendable {
    case english, hindi

    public var displayName: String {
        self == .english ? "English" : "हिन्दी"
    }
}

/// Output styles for Structure-Your-Thoughts (STRUCTURE_THOUGHTS.md §3.6).
public enum OutputStyle: String, CaseIterable, Codable, Sendable {
    case notes, actionList, emailDraft, outline

    public var displayName: String {
        switch self {
        case .notes: return "Notes"
        case .actionList: return "Action list"
        case .emailDraft: return "Email draft"
        case .outline: return "Outline"
        }
    }
}

public enum LLMError: LocalizedError, Equatable {
    case serverUnavailable
    case modelMissing(String)
    case emptyResponse
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .serverUnavailable:
            return "The local AI engine (Ollama) isn't running. Open the Ollama app, then try again."
        case .modelMissing(let model):
            return "The AI model \"\(model)\" isn't installed yet. Get it from Settings → Text & AI."
        case .emptyResponse:
            return "The AI model returned nothing — your original text is untouched."
        case .requestFailed(let reason):
            return "AI request failed: \(reason)"
        }
    }
}

/// Readiness of the local LLM stack — drives inline UI guidance
/// (house rule: failures explain themselves, never require quit/reopen).
public enum LLMStatus: Equatable {
    case ready
    case serverDown
    case modelMissing(String)

    public var isReady: Bool { self == .ready }
}

/// Abstraction over a local text-generation engine, mirroring
/// `TranscriptionEngine`. Today's backend is Ollama (`OllamaLLM`) — already
/// on-device, zero new dependencies. A vendored llama.cpp backend
/// (`LlamaCppLLM`) can slot in behind this protocol later without touching
/// callers (see docs/features/implementation/LLM_ENGINE.md for why deferred).
public protocol LocalLLM: AnyObject {
    /// The model identifier requests will run against (e.g. "qwen2.5:1.5b-instruct").
    var model: String { get }

    /// Cheap readiness probe — callers use it to render inline setup guidance
    /// instead of failing mid-flow.
    func status() async -> LLMStatus

    /// One-shot generation. `system` fixes the task; `user` carries the text.
    /// Implementations must be safe to call from any thread/actor.
    func generate(system: String, user: String) async throws -> String
}
