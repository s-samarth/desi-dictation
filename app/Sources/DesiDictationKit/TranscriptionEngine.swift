import Foundation

/// A language mode the user dictates in. Maps to a Whisper language token.
/// Hinglish models are trained to emit Roman-script Hinglish under "en".
public enum LanguageMode: String, CaseIterable, Codable, Sendable {
    case hinglish
    case english
    case hindi
    /// Speak Hindi/Hinglish/broken English → polished written English
    /// (TRANSCRIBE_TRANSLATE.md). Transcribes like .hinglish, then a local LLM
    /// translation stage runs before insertion.
    case anyToEnglish

    public var whisperLanguage: String {
        switch self {
        case .hinglish, .english, .anyToEnglish: return "en"
        case .hindi: return "hi"
        }
    }

    public var displayName: String {
        switch self {
        case .hinglish: return "Hinglish (Roman)"
        case .english: return "English"
        case .hindi: return "हिन्दी (Devanagari)"
        case .anyToEnglish: return "English — from any language ✨"
        }
    }

    /// Guidance shown in UI: which model family suits this mode.
    public var modelHint: String {
        switch self {
        case .hinglish: return "Use a Hinglish model (hinglish-swift / prime / apex)"
        case .english: return "Any model works; Hinglish models handle Indian accents best"
        case .hindi: return "Use a stock multilingual model (base / small / large-v3-turbo)"
        case .anyToEnglish: return "Transcribes with the Hinglish model, then writes polished English (AI model required)"
        }
    }

    /// True for modes that run an LLM stage after transcription.
    public var needsLLM: Bool { self == .anyToEnglish }

    /// Which model-default slot this mode uses. `anyToEnglish` transcribes with
    /// the Hinglish model (the English comes from the LLM stage), so the two
    /// share one pin — two separate defaults for one ASR job would just be a
    /// second thing to keep in sync.
    public var modelKey: String {
        self == .anyToEnglish ? LanguageMode.hinglish.rawValue : rawValue
    }
}

public struct TranscriptionResult: Sendable {
    public let text: String
    public let duration: TimeInterval   // wall-clock transcription time
    public let audioSeconds: Double
}

public enum EngineError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case transcriptionFailed
    case emptyAudio

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "No model is loaded. Pick one in Settings → Models."
        case .modelLoadFailed(let path): return "Failed to load model at \(path)."
        case .transcriptionFailed: return "Transcription failed."
        case .emptyAudio: return "No audio was captured."
        }
    }
}

/// Engine abstraction (mirrors MacWhisper's runner architecture) so WhisperKit /
/// MLX / cloud backends can be added later without touching callers.
public protocol TranscriptionEngine: AnyObject {
    var isLoaded: Bool { get }
    var loadedModelPath: String? { get }
    func load(modelPath: String) throws
    func transcribe(samples: [Float], mode: LanguageMode) throws -> TranscriptionResult
    func unload()
}
