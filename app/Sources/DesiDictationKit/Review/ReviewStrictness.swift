import Foundation

/// How readily Review before paste underlines words (REVIEW_BEFORE_PASTE.md
/// "Strictness"). Every level uses the same two signals: the speech model's
/// confidence and, with the context checker installed, how odd the word is
/// in its sentence. The levels differ in how many words they may underline.
/// Thresholds are from `evals/review_strictness.py` on the 2026-10-29 quick tier.
public enum ReviewStrictness: String, CaseIterable, Codable, Sendable {
    /// Underlines the most; for people new to dictation.
    case conservative
    case moderate
    /// Lets almost everything through; only clear mistakes are underlined.
    case liberal

    public var label: String {
        switch self {
        case .conservative: return "Conservative"
        case .moderate: return "Moderate"
        case .liberal: return "Liberal"
        }
    }

    public var detail: String {
        switch self {
        case .conservative: return "Conservative underlines about one word in seven, so fewer mistakes slip through."
        case .moderate: return "Moderate underlines about one word in twelve."
        case .liberal: return "Liberal underlines about one word in thirty: only words that are likely wrong."
        }
    }

    /// A word below this confidence is underlined; nil when the engine gives
    /// none (Qwen3-ASR: transcribe.cpp has no token rows for it).
    public func confidenceThreshold(forModel path: String) -> Float? {
        let name = path.lowercased()
        if name.contains("qwen3-asr") { return nil }
        if name.contains("parakeet") { return pick(0.69, 0.53, 0.40) }
        if name.contains("vaani") { return pick(0.59, 0.59, 0.54) }
        return pick(0.84, 0.64, 0.52)                   // whisper: measured on Hinglish Prime
    }

    /// A word whose surprise in its sentence (SentenceSurprise.total, nats)
    /// is above this is underlined as odd in context. nil for Hinglish: the
    /// checker finds romanised Hinglish odd everywhere, and it caught nothing
    /// confidence didn't. With no confidence (Qwen3-ASR) it is the only
    /// signal, so its bar is lower.
    public func surpriseThreshold(forModel path: String, mode: LanguageMode) -> Double? {
        switch mode {
        case .english:
            return path.lowercased().contains("qwen3-asr") ? pick(9.4, 11.1, 13.3) : pick(15.0, 15.8, 17.0)
        case .hindi:
            return pick(11.3, 19.4, 25.3)
        default:
            return nil
        }
    }

    private func pick<T>(_ conservative: T, _ moderate: T, _ liberal: T) -> T {
        switch self {
        case .conservative: return conservative
        case .moderate: return moderate
        case .liberal: return liberal
        }
    }
}
