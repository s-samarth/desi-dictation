import Foundation
import CWhisper

/// whisper.cpp-backed engine. Not thread-safe by itself — callers serialize
/// through DictationController's single worker queue.
public final class WhisperCppEngine: TranscriptionEngine {
    private var ctx: OpaquePointer?
    public private(set) var loadedModelPath: String?

    public init() {}
    deinit { unload() }

    public var isLoaded: Bool { ctx != nil }

    /// Silero VAD model, if installed (Models tab offers it as a download).
    static func vadModelPath() -> String? {
        let path = AppPaths.modelsDirectory
            .appendingPathComponent("ggml-silero-vad.bin").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    public func load(modelPath: String) throws {
        unload()
        var params = whisper_context_default_params()
        params.use_gpu = true            // Metal (JIT-compiled shaders; no Xcode needed)
        params.flash_attn = true
        guard let newCtx = whisper_init_from_file_with_params(modelPath, params) else {
            throw EngineError.modelLoadFailed(modelPath)
        }
        ctx = newCtx
        loadedModelPath = modelPath
    }

    public func unload() {
        if let ctx { whisper_free(ctx) }
        ctx = nil
        loadedModelPath = nil
    }

    public func transcribe(samples: [Float], mode: LanguageMode) throws -> TranscriptionResult {
        guard let ctx else { throw EngineError.modelNotLoaded }
        guard samples.count > 1600 else { throw EngineError.emptyAudio }  // <0.1s

        let start = Date()
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_special = false
        params.print_timestamps = false
        params.no_timestamps = true
        params.translate = false
        params.suppress_blank = true
        params.n_threads = Int32(max(2, ProcessInfo.processInfo.activeProcessorCount - 2))

        // Long-form quality (v0.3): without this, each 30s window conditions on
        // the previous window's text, so one bad segment degrades everything
        // after it — the classic "long dictation gets worse" failure.
        params.no_context = true

        // Silero VAD (if the model file is installed): trims silences before
        // decoding — silence is exactly where Whisper hallucinates.
        var vadCString: UnsafeMutablePointer<CChar>?
        if let vadPath = Self.vadModelPath() {
            params.vad = true
            vadCString = strdup(vadPath)
            params.vad_model_path = UnsafePointer(vadCString)
            params.vad_params = whisper_vad_default_params()
        }
        defer { free(vadCString) }

        // whisper_full keeps a borrowed pointer to language for the call duration.
        let langCString = strdup(mode.whisperLanguage)
        defer { free(langCString) }
        params.language = UnsafePointer(langCString)

        let status = samples.withUnsafeBufferPointer { buf in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard status == 0 else { throw EngineError.transcriptionFailed }

        var text = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let seg = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: seg)
            }
        }
        return TranscriptionResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: Date().timeIntervalSince(start),
            audioSeconds: Double(samples.count) / 16000.0
        )
    }
}
