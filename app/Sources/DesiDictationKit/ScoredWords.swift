import Foundation

/// One word as the speech model wrote it, with how sure it was: the lowest
/// probability among the word's tokens (one weak piece makes the word weak).
/// NaN when the engine gives no probability. Feeds Review before paste
/// (REVIEW_BEFORE_PASTE.md): the least sure words get underlined.
public struct ScoredWord: Equatable, Sendable {
    public let text: String
    public let confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

/// Builds `ScoredWord`s from an engine's token stream. Tokens arrive as raw
/// UTF-8 bytes: whisper can split one Devanagari letter across two tokens, so
/// bytes are joined per word and decoded once.
public struct WordAssembler {
    private var words: [ScoredWord] = []
    private var bytes: [UInt8] = []
    private var lowest = Float.nan

    public init() {}

    /// `startsWord`: this token begins a new word (whisper: a leading space;
    /// Parakeet: `is_word_start`). Probabilities outside 0…1 count as missing.
    public mutating func add(_ tokenBytes: [UInt8], p: Float, startsWord: Bool) {
        if startsWord { flush() }
        bytes += tokenBytes
        if p.isFinite, (0...1).contains(p) { lowest = lowest.isNaN ? p : min(lowest, p) }
    }

    /// A word the engine already delimits (transcribe.cpp's word rows).
    public mutating func addWord(_ text: String, confidence: Float) {
        flush()
        bytes = Array(text.utf8)
        lowest = confidence
        flush()
    }

    public mutating func finish() -> [ScoredWord] {
        flush()
        defer { words = [] }
        return words
    }

    private mutating func flush() {
        let text = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2581}", with: "")   // SentencePiece's word mark
        if !text.isEmpty { words.append(ScoredWord(text: text, confidence: lowest)) }
        bytes = []
        lowest = .nan
    }
}

extension Array where Element == UInt8 {
    /// The bytes of a C string the engine owns (copied: it may be freed later).
    init(cString pointer: UnsafePointer<CChar>?) {
        guard let pointer else { self = []; return }
        self = Array(UnsafeBufferPointer(start: UnsafeRawPointer(pointer)
            .assumingMemoryBound(to: UInt8.self), count: strlen(pointer)))
    }
}
