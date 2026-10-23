import CWhisper

/// Overrules the Oriserve models' "no transcript" label on real speech (FM#30).
///
/// Hinglish Apex and Prime answer some clear speech with exactly one token,
/// "nan" (p 0.8–0.999), then end-of-text: a fine-tuning artifact, almost
/// certainly training rows whose empty transcript was written out as pandas'
/// NaN. It is a learned answer, not a numeric NaN: it decodes the same on CPU
/// with flash attention off. The engine's "nan" guard turned it into "", so
/// the user dictated 15 s and nothing was pasted.
///
/// The filter bans "nan" as a window's first token (where the label sits;
/// mid-transcript it can be a legitimate word piece). With the ban, real speech
/// decodes in full. The models give the label for noise and hum too, and
/// banned there, Apex spells a stray piece ("n", "na") while Prime invents
/// whole sentences. Their no-speech probability is ~1e-9 even on noise, so
/// whisper's own check can't tell the cases apart. Hence the engine installs
/// the filter only when VAD is on (Silero vouched for speech). As a backstop
/// against VAD false positives, it records whether the label was the top
/// choice, and a forced decode of a single token keeps the "no transcript" answer.
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
