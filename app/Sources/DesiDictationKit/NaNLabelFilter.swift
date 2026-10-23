import CWhisper

/// Overrules Hinglish Apex's "no transcript" label when the audio has words (FM#30).
///
/// Apex answers some clear speech with exactly one token, "nan" (p ≈ 0.999),
/// then end-of-text: a fine-tuning artifact, almost certainly training rows
/// whose empty transcript was written out as pandas' NaN. It is a learned
/// answer, not a numeric NaN: it decodes the same on CPU with flash attention
/// off. The engine's "nan" guard turned it into "", so the user dictated 15 s
/// and nothing was pasted.
///
/// The filter bans "nan" as a window's first token (where the label sits;
/// mid-transcript it can be a legitimate word piece). With the ban, real speech
/// decodes in full. On noise and hum the model gives the label too. Banned, it
/// spells one stray piece ("n", "na", "ne"), and whisper's no-speech check
/// can't catch that (Apex's no-speech probability is ~1e-9 even on noise).
/// So the filter records whether the label was the model's top choice, and
/// the engine keeps the "no transcript" answer when the forced decode is a
/// single token.
public final class NaNLabelFilter {
    let token: whisper_token
    /// Length of the logits array (the model's vocabulary).
    let vocabSize: Int
    /// Set when "nan" was the top first-token candidate in this call.
    public private(set) var overruled = false

    public init(token: whisper_token, vocabSize: Int) {
        self.token = token
        self.vocabSize = vocabSize
    }

    /// The filter for the loaded model, nil if "nan" is not one token in its vocab.
    static func make(for ctx: OpaquePointer) -> NaNLabelFilter? {
        var buffer = [whisper_token](repeating: 0, count: 4)
        let count = whisper_tokenize(ctx, "nan", &buffer, Int32(buffer.count))
        guard count == 1 else { return nil }
        return NaNLabelFilter(token: buffer[0], vocabSize: Int(whisper_n_vocab(ctx)))
    }

    /// Bans the label at the first position and records whether it was on top.
    public func filter(decoded: Int, logits: UnsafeMutableBufferPointer<Float>) {
        let index = Int(token)
        guard decoded == 0, logits.indices.contains(index) else { return }
        if logits[index] >= (logits.max() ?? -.infinity) { overruled = true }
        logits[index] = -.infinity
    }

    /// The decode is kept unless the label was overruled into a lone token.
    public func keeps(textTokens: Int) -> Bool { !overruled || textTokens > 1 }

    /// Points `params` at this filter. The filter must outlive the
    /// whisper_full call (C function pointers can't capture; user_data
    /// carries an unretained reference instead).
    func install(in params: inout whisper_full_params) {
        overruled = false
        params.logits_filter_callback = Self.callback
        params.logits_filter_callback_user_data = Unmanaged.passUnretained(self).toOpaque()
    }

    private static let callback: whisper_logits_filter_callback = { _, _, _, decoded, logits, userData in
        guard let logits, let userData else { return }
        let filter = Unmanaged<NaNLabelFilter>.fromOpaque(userData).takeUnretainedValue()
        filter.filter(decoded: Int(decoded),
                      logits: UnsafeMutableBufferPointer(start: logits, count: filter.vocabSize))
    }
}
