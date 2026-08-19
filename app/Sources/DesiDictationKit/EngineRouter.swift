import Foundation

/// Picks the runtime for a model file and keeps exactly one model resident.
///
/// Two engines ship now — whisper.cpp (Hinglish / हिन्दी / any Whisper GGML)
/// and Parakeet TDT (English, v0.6.1) — and the model *file* decides which one
/// runs, so nothing above this layer has to know engines exist.
///
/// One resident model, never two: a 574 MB whisper model plus a 416 MB
/// Parakeet model would be ~1 GB of wired memory on a machine that may only
/// have 8 GB (PERF_RCA_2026-08.md RC4). Switching languages swaps the model,
/// which is why mode changes preload (DictationController.modelChanged).
///
/// Not thread-safe: callers serialize through DictationController's worker
/// queue, exactly as with the bare engine before it.
public final class EngineRouter: TranscriptionEngine {
    private let whisper = WhisperCppEngine()
    private let parakeet = ParakeetEngine()

    private var active: TranscriptionEngine?

    public init() {}

    public var isLoaded: Bool { active?.isLoaded ?? false }
    public var loadedModelPath: String? { active?.loadedModelPath }

    public func unload() {
        active?.unload()
        active = nil
    }

    /// Loads `path` if it isn't already resident, unloading the other engine.
    public func load(modelPath: String) throws {
        if let active, active.isLoaded, active.loadedModelPath == modelPath { return }
        let wanted: TranscriptionEngine =
            ParakeetEngine.handles(modelPath: modelPath) ? parakeet : whisper
        // Free the outgoing model BEFORE allocating the incoming one.
        if let active, active !== wanted { active.unload() }
        try wanted.load(modelPath: modelPath)
        active = wanted
    }

    public func transcribe(samples: [Float], mode: LanguageMode) throws -> TranscriptionResult {
        guard let active else { throw EngineError.modelNotLoaded }
        return try active.transcribe(samples: samples, mode: mode)
    }
}
