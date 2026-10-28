import Foundation

// MARK: - Incremental chunking (perceived-latency fix, v0.4)
// While the user speaks, completed stretches are transcribed in the
// background; on release only the tail remains → even multi-minute
// dictations insert quickly.
//
// Thresholds re-derived from measurement in v0.6.1 (PERF_RCA_2026-08.md):
// whisper always encodes a padded 30 s window, so a chunk call costs the
// SAME ~1.5 s (M3) / ~3 s (M1 Air) whether it holds 2 s of speech or 30 s.
// The old 12 s cut therefore taxed every ordinary dictation with extra
// full-price calls — and the tail queues behind any chunk still decoding on
// this serial queue. So: don't chunk short dictations at all, and when we
// do chunk, make each chunk far longer than the call it costs.
//
// Side effect worth knowing (FM#31): chunks are cut at quiet moments, so the
// tail left at stop is often pure silence, which VAD returns in ~10 ms. The
// paste can then fire while the hotkey is still held — TextInserter waits.
extension DictationController {
    /// No chunking below this — a normal dictation should cost exactly one call.
    public nonisolated static let chunkFloorSamples = 30 * 16000        // 30 s of speech
    /// Minimum audio per chunk once chunking starts.
    public nonisolated static let chunkEverySamples = 25 * 16000        // 25 s
    /// Cut here even mid-sentence, so one bad cut can't poison more than this.
    public nonisolated static let chunkForceSamples = 35 * 16000        // 35 s
    /// Below this the "tail" is key-release noise, not speech.
    public nonisolated static let tailFloorSamples = 5600               // 0.35 s

    /// The (floor, every, force) chunk thresholds for a session in `mode`.
    /// हिन्दी is the exception (FM#26): the engine splits anything over 12 s
    /// into separate whisper calls to stay under the decoder's token budget,
    /// so those calls are paid either way — make them while the user is still
    /// talking. Force is one ticker second under the cap, so the engine never
    /// has to split a chunk again.
    public nonisolated static func chunkThresholds(
        for mode: LanguageMode
    ) -> (floor: Int, every: Int, force: Int) {
        guard let cap = WhisperCppEngine.maxCallSamples(for: mode) else {
            return (chunkFloorSamples, chunkEverySamples, chunkForceSamples)
        }
        return (cap, cap * 2 / 3, cap - 16000)
    }
}
