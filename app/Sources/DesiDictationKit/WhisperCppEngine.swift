import Foundation
import CWhisper
import os.log

let engineLog = Logger(subsystem: "com.desi.dictation", category: "engine")

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
        // flash_attn was OFF since v0.3 (FM#12: NaN logits with quantized models
        // on Metal). Re-tested 2026-08-19 on the current whisper.cpp, which now
        // defaults it ON: 18 clips across apex/turbo/vaani q5_0 produced zero
        // NaN and zero empty decodes, text identical on 17/18 (one single-token
        // difference), for ~11 % less encode time. Kept behind a switch because
        // this is exactly the kind of thing that regresses upstream — Options →
        // "Flash attention" turns it off for bisecting.
        params.flash_attn = SettingsStore.shared.flashAttention
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

    /// Longest audio one whisper call may cover in `mode` (nil = no limit).
    ///
    /// whisper.cpp decodes at most 220 tokens per 30 s window
    /// (n_text_ctx/2 − 4). Devanagari costs ~5 tokens a word — ~11–14 tokens
    /// per second of Hindi speech — so a window holding more than ~16 s of
    /// dense Hindi runs out of tokens without an end-of-text, is flagged a
    /// "repetition loop", and is re-decoded at 5 more temperatures × 5
    /// candidates: 18 s of speech took 54 s, and still lost its last words
    /// (FM#26). 12 s pieces keep even fast speech (~18 tok/s) under the cap.
    /// Roman-script modes use ~1.3 tokens a word and never get near it.
    public static func maxCallSamples(for mode: LanguageMode) -> Int? {
        mode == .hindi ? 12 * 16000 : nil
    }

    /// Tokens at which a window has certainly hit the decoder cap above.
    private static let decoderBudgetTokens = 216

    public func transcribe(samples: [Float], mode: LanguageMode) throws -> TranscriptionResult {
        guard ctx != nil else { throw EngineError.modelNotLoaded }
        let start = Date()
        let ranges = Self.maxCallSamples(for: mode)
            .map { AudioSplitter.pieces(of: samples, maxSamples: $0) } ?? [0..<samples.count]
        var texts: [String] = []
        for range in ranges {
            do {
                texts.append(try transcribeWindow(Array(samples[range]), mode: mode))
            } catch EngineError.emptyAudio where ranges.count > 1 {
                continue   // a silent piece of a longer dictation is not an error
            }
        }
        guard !texts.isEmpty else { throw EngineError.emptyAudio }
        return TranscriptionResult(
            text: texts.filter { !$0.isEmpty }.joined(separator: " "),
            duration: Date().timeIntervalSince(start),
            audioSeconds: Double(samples.count) / 16000.0
        )
    }

    /// One whisper_full call. Returns trimmed text ("" for NaN garbage).
    private func transcribeWindow(_ samples: [Float], mode: LanguageMode) throws -> String {
        guard let ctx else { throw EngineError.modelNotLoaded }
        guard samples.count > 1600 else { throw EngineError.emptyAudio }  // <0.1s
        // Reject silent/corrupt buffers before they reach the model — NaN or
        // all-zero input produces NaN logits and garbage decodes downstream.
        guard samples.contains(where: { $0.isFinite && abs($0) > 0.0005 }) else {
            throw EngineError.emptyAudio
        }

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

        // Silero VAD (if installed AND enabled — Settings has a kill-switch so
        // users can bisect quality issues live): trims silences before
        // decoding — silence is exactly where Whisper hallucinates.
        var vadCString: UnsafeMutablePointer<CChar>?
        if SettingsStore.shared.vadEnabled, let vadPath = Self.vadModelPath() {
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

        engineLog.info("transcribe: \(samples.count, privacy: .public) samples, vad=\(params.vad, privacy: .public), lang=\(mode.whisperLanguage, privacy: .public), model=\(self.loadedModelPath?.components(separatedBy: "/").last ?? "?", privacy: .public)")
        let status = samples.withUnsafeBufferPointer { buf in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard status == 0 else {
            engineLog.error("whisper_full failed with status \(status, privacy: .public)")
            throw EngineError.transcriptionFailed
        }
        engineLog.info("segments: \(whisper_full_n_segments(ctx), privacy: .public)")

        var text = ""
        var tokens: Int32 = 0
        for i in 0..<whisper_full_n_segments(ctx) {
            tokens += whisper_full_n_tokens(ctx, i)
            if let seg = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: seg)
            }
        }
        if tokens >= Self.decoderBudgetTokens {
            // Means the text was truncated and temperature fallback ran (FM#26).
            engineLog.notice("decoder budget hit: \(tokens, privacy: .public) tokens in \(samples.count / 16000, privacy: .public) s")
        }
        engineLog.info("raw text (\(text.count, privacy: .public) chars): \(String(text.prefix(80)), privacy: .private(mask: .none))")
        // NaN logits decode to literal "nan" tokens — treat as no output
        // rather than pasting garbage into the user's document.
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "nan" || lowered.replacingOccurrences(of: "nan", with: "")
            .trimmingCharacters(in: .whitespaces).isEmpty && lowered.contains("nan") {
            text = ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
