import Foundation
import CWhisper
import os.log

let parakeetLog = Logger(subsystem: "com.desi.dictation", category: "parakeet")

/// NVIDIA Parakeet TDT (FastConformer) via whisper.cpp's `libparakeet` — the
/// English-mode engine since v0.6.1.
///
/// Why a second engine at all (measured, 20 Svarah Indian-accented English
/// clips, M3 Air — docs/MODEL_RESEARCH.md §E):
///
/// | engine | nWER | per call | size |
/// |---|---|---|---|
/// | large-v3-turbo q5_0 | 4.5 % | 1.94 s | 574 MB |
/// | **parakeet-tdt-0.6b-v3 q4_k** | **4.3 %** | **0.39 s** | **416 MB** |
///
/// The speed is architectural, not a quantization trick: whisper always encodes
/// a **padded 30-second window**, so a 3-second dictation costs the same as a
/// 30-second one (PERF_RCA_2026-08.md RC1). Parakeet encodes the audio it was
/// actually given, so short dictations — the common case — get radically
/// cheaper. Its compute buffer grows with audio length instead, which is why
/// long sessions still chunk (DictationController.chunkFloorSamples).
///
/// English only, deliberately: the model covers 25 European languages, none of
/// them Hindi, and it cannot emit Devanagari or Roman-Hinglish.
public final class ParakeetEngine: TranscriptionEngine {
    private var ctx: OpaquePointer?
    public private(set) var loadedModelPath: String?

    public init() {}
    deinit { unload() }

    public var isLoaded: Bool { ctx != nil }

    /// Filename convention — the one place "is this a Parakeet file?" is decided.
    public static func handles(modelPath: String) -> Bool {
        modelPath.lowercased().contains("parakeet")
    }

    public func load(modelPath: String) throws {
        unload()
        var params = parakeet_context_default_params()
        params.use_gpu = true
        guard let newCtx = parakeet_init_from_file_with_params(modelPath, params) else {
            throw EngineError.modelLoadFailed(modelPath)
        }
        ctx = newCtx
        loadedModelPath = modelPath
    }

    public func unload() {
        if let ctx { parakeet_free(ctx) }
        ctx = nil
        loadedModelPath = nil
    }

    public func transcribe(samples: [Float], mode: LanguageMode) throws -> TranscriptionResult {
        guard let ctx else { throw EngineError.modelNotLoaded }
        guard samples.count > 1600 else { throw EngineError.emptyAudio }
        // Same guard as the whisper engine: silent or non-finite buffers decode
        // to garbage, so they never reach the model.
        guard samples.contains(where: { $0.isFinite && abs($0) > 0.0005 }) else {
            throw EngineError.emptyAudio
        }

        let start = Date()
        var params = parakeet_full_default_params(PARAKEET_SAMPLING_GREEDY)
        params.n_threads = Int32(max(2, ProcessInfo.processInfo.activeProcessorCount - 2))
        params.no_context = true

        parakeetLog.info("transcribe: \(samples.count, privacy: .public) samples, model=\(self.loadedModelPath?.components(separatedBy: "/").last ?? "?", privacy: .public)")
        let status = samples.withUnsafeBufferPointer { buf in
            parakeet_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard status == 0 else {
            parakeetLog.error("parakeet_full failed with status \(status, privacy: .public)")
            throw EngineError.transcriptionFailed
        }

        var text = ""
        for i in 0..<parakeet_full_n_segments(ctx) {
            if let seg = parakeet_full_get_segment_text(ctx, i) {
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
