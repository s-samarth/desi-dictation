import Foundation
import CWhisper
import CTranscribe

/// Reads per-word confidence out of each runtime's last result (stage 1 of
/// REVIEW_BEFORE_PASTE.md). Kept apart from the engines so they stay short.
enum EngineWords {
    /// whisper.cpp: text tokens (ids below end-of-text) of every segment,
    /// a new word at each leading space.
    static func whisper(_ ctx: OpaquePointer) -> [ScoredWord] {
        var assembler = WordAssembler()
        let eot = whisper_token_eot(ctx)
        for i in 0..<whisper_full_n_segments(ctx) {
            for j in 0..<whisper_full_n_tokens(ctx, i) where whisper_full_get_token_id(ctx, i, j) < eot {
                let bytes = [UInt8](cString: whisper_full_get_token_text(ctx, i, j))
                assembler.add(bytes, p: whisper_full_get_token_p(ctx, i, j), startsWord: bytes.first == 0x20)
            }
        }
        return assembler.finish()
    }

    /// Parakeet TDT: the runtime marks word starts; blank tokens carry no text.
    static func parakeet(_ ctx: OpaquePointer) -> [ScoredWord] {
        var assembler = WordAssembler()
        let blank = parakeet_token_blank(ctx)
        for i in 0..<parakeet_full_n_segments(ctx) {
            for j in 0..<parakeet_full_n_tokens(ctx, i) {
                let data = parakeet_full_get_token_data(ctx, i, j)
                guard data.id != blank else { continue }
                let bytes = [UInt8](cString: parakeet_full_get_token_text(ctx, i, j))
                assembler.add(bytes, p: data.p, startsWord: data.is_word_start)
            }
        }
        return assembler.finish()
    }

    /// transcribe.cpp: word rows, each scored by its weakest token. Qwen3-ASR
    /// has no word alignment (0 word rows), so then tokens are grouped at
    /// leading spaces, as for whisper.
    static func transcribe(_ session: OpaquePointer) -> [ScoredWord] {
        var assembler = WordAssembler()
        guard transcribe_n_words(session) > 0 else {
            for t in 0..<transcribe_n_tokens(session) {
                var token = transcribe_token()
                transcribe_token_init(&token)
                guard transcribe_get_token(session, t, &token) == TRANSCRIBE_OK, token.text != nil else { continue }
                let bytes = [UInt8](cString: token.text)
                assembler.add(bytes, p: token.p, startsWord: bytes.first == 0x20)
            }
            return assembler.finish()
        }
        for w in 0..<transcribe_n_words(session) {
            var word = transcribe_word()
            transcribe_word_init(&word)
            guard transcribe_get_word(session, w, &word) == TRANSCRIBE_OK, let text = word.text else { continue }
            var lowest = Float.nan
            for t in word.first_token..<(word.first_token + word.n_tokens) {
                var token = transcribe_token()
                transcribe_token_init(&token)
                guard transcribe_get_token(session, t, &token) == TRANSCRIBE_OK,
                      token.p.isFinite, (0...1).contains(token.p) else { continue }
                lowest = lowest.isNaN ? token.p : min(lowest, token.p)
            }
            assembler.addWord(String(cString: text), confidence: lowest)
        }
        return assembler.finish()
    }
}
