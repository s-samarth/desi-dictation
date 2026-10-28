import Foundation
import CTranscribe
import os.log

let qwenLog = Logger(subsystem: "com.desi.dictation", category: "qwen-asr")

/// Qwen3-ASR-1.7B via transcribe.cpp — the opt-in "Accurate English" engine
/// (v0.6.3), replacing Whisper large-v3-turbo as the second English model.
///
/// Why (full english tier, 278 Indian-English clips, docs/ENGLISH_ASR_AB_2026-10.md):
///
/// | engine | nWER clean | nWER noisy | per short dictation |
/// |---|---|---|---|
/// | Parakeet TDT v3 (default) | 14.3 % | 19.5 % | 0.09 s |
/// | **Qwen3-ASR-1.7B** | **12.6 %** | **17.7 %** | 0.39 s |
/// | large-v3-turbo (replaced) | 16.4 %* | 33.0 %* | 1.44 s |
///
/// (*quick tier.) The only model significantly better than Parakeet on both
/// clean and noisy speech — but ~4× slower, so Parakeet stays the default and
/// this is what you pick when accuracy matters more than speed.
///
/// An audio-LLM (encoder → Qwen3 decoder), so it is English-only *here* by
/// choice: the user asked for it as an English model, and Hinglish/हिन्दी have
/// their own fine-tunes. Runs on Metal; ggml is private to transcribe.cpp.
public final class QwenASREngine: TranscriptionEngine {
    private var session: OpaquePointer?
    public private(set) var loadedModelPath: String?

    public init() {}
    deinit { unload() }

    public var isLoaded: Bool { session != nil }

    /// Filename convention — the one place "is this a Qwen3-ASR file?" is decided.
    public static func handles(modelPath: String) -> Bool {
        modelPath.lowercased().contains("qwen3-asr")
    }

    public func load(modelPath: String) throws {
        unload()
        var newSession: OpaquePointer?
        let status = transcribe_open(modelPath, nil, nil, &newSession)
        guard status == TRANSCRIBE_OK, let newSession else {
            qwenLog.error("transcribe_open failed: \(String(cString: transcribe_status_string(Int32(status.rawValue))), privacy: .public)")
            throw EngineError.modelLoadFailed(modelPath)
        }
        session = newSession
        loadedModelPath = modelPath
    }

    public func unload() {
        if let session { transcribe_session_free(session) }
        session = nil
        loadedModelPath = nil
    }

    public func transcribe(samples: [Float], mode: LanguageMode) throws -> TranscriptionResult {
        guard let session else { throw EngineError.modelNotLoaded }
        guard samples.count > 1600 else { throw EngineError.emptyAudio }
        // Same guard as the other engines — and it matters more here: an LLM
        // decoder handed silence will happily invent a sentence.
        guard samples.contains(where: { $0.isFinite && abs($0) > 0.0005 }) else {
            throw EngineError.emptyAudio
        }

        let start = Date()
        qwenLog.info("transcribe: \(samples.count, privacy: .public) samples, model=\(self.loadedModelPath?.components(separatedBy: "/").last ?? "?", privacy: .public)")
        // One call over 45–110 s of audio was measurably worse than the same
        // audio in ≤ 30 s pieces (quick tier: 22 % vs 16 % nWER on those clips),
        // so long input is cut at pauses — the same size the app chunks at.
        var parts: [String] = []
        for range in AudioSplitter.pieces(of: samples, maxSamples: Self.maxPieceSamples) {
            let text = try run(session, Array(samples[range]), language: mode.whisperLanguage)
            if !text.isEmpty { parts.append(text) }
        }
        return TranscriptionResult(
            text: parts.joined(separator: " "),
            duration: Date().timeIntervalSince(start),
            audioSeconds: Double(samples.count) / 16000.0
        )
    }

    /// Longest single call: 30 s, matching DictationController's chunk size.
    static let maxPieceSamples = 30 * 16000

    private func run(_ session: OpaquePointer, _ pcm: [Float], language: String) throws -> String {
        var params = transcribe_run_params()
        transcribe_run_params_init(&params)
        let status: transcribe_status = language.withCString { lang in
            params.language = lang  // forced: auto-detect can drift on accented English
            return pcm.withUnsafeBufferPointer { buf in
                transcribe_run(session, buf.baseAddress, Int32(buf.count), &params)
            }
        }
        let why = String(cString: transcribe_status_string(Int32(status.rawValue)))
        switch status {
        case TRANSCRIBE_OK: break
        // Result-bearing: the decoder looped or hit its budget and was stopped
        // early. The partial text is real — losing the whole dictation over
        // it is worse than a possibly-short tail (transcribe.h).
        case TRANSCRIBE_ERR_OUTPUT_REPETITION, TRANSCRIBE_ERR_OUTPUT_TRUNCATED:
            qwenLog.notice("transcribe_run stopped early (\(why, privacy: .public)); keeping partial text")
        default:
            qwenLog.error("transcribe_run failed: \(why, privacy: .public)")
            throw EngineError.transcriptionFailed
        }
        let text = transcribe_full_text(session).map { String(cString: $0) } ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
