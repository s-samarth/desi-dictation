import Foundation
import os.log

let timingLog = Logger(subsystem: "com.desi.dictation", category: "timing")

/// What one dictation actually cost, stage by stage.
///
/// Exists because the 2026-08 slowness investigation had nothing to work with:
/// `Logger.info` is not persisted, so a user saying "it took ten seconds" left
/// no trace, and the only speed number anyone tracked was realtime-factor on a
/// long clip — a throughput metric that hides a fixed per-call cost entirely
/// (PERF_RCA_2026-08.md "What we're lacking"). These are the numbers users
/// actually feel: how long after releasing the key the text appeared, and how
/// many engine calls that took.
public struct DictationTimings: Sendable, Equatable {
    /// Seconds of speech captured.
    public var audioSeconds: Double = 0
    /// Engine calls this dictation paid for (chunks + tail). Each one costs a
    /// full padded window on whisper, so this is the number that matters.
    public var engineCalls: Int = 0
    /// Time inside the engine, summed across those calls.
    public var engineSeconds: Double = 0
    /// Release → text delivered. The user-visible latency.
    public var releaseToPaste: Double = 0
    /// Whether an LLM stage (translate/tone) ran in that window.
    public var llmStage: Bool = false

    public var summary: String {
        String(format: "%.1fs speech · %.2fs to paste · %d call%@ (%.2fs engine)%@",
               audioSeconds, releaseToPaste, engineCalls,
               engineCalls == 1 ? "" : "s", engineSeconds, llmStage ? " + AI" : "")
    }

    /// `.notice` (not `.info`) so it survives in `log show` — the whole point
    /// is being able to reconstruct a complaint after the fact.
    public func log() {
        timingLog.notice("dictation: \(self.summary, privacy: .public)")
    }
}
