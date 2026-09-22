import Foundation
import DesiDictationKit

/// FM#26: हिन्दी audio is split so each whisper call stays under the
/// decoder's 220-token budget — the cuts must be lossless and land in pauses.
func runAudioSplitterTests() {
    T.begin("AudioSplitter — decoder-budget pieces")
    let rate = 16_000
    // Loud "speech" except silent gaps at 9 s and 20 s, each inside the
    // ±1.5 s search around the even 10 s / 20 s boundaries.
    var audio = (0..<(30 * rate)).map { Float(sin(Double($0) * 0.05)) * 0.3 }
    for gap in [9, 20] {
        for i in (gap * rate)..<(gap * rate + 3_200) { audio[i] = 0 }
    }
    let max12 = 12 * rate
    let pieces = AudioSplitter.pieces(of: audio, maxSamples: max12)
    T.equal(pieces.first?.lowerBound, 0, "starts at sample 0")
    T.equal(pieces.last?.upperBound, audio.count, "ends at the last sample")
    T.expect(zip(pieces, pieces.dropFirst()).allSatisfy { $0.upperBound == $1.lowerBound },
             "pieces are contiguous — no audio lost or doubled")
    T.expect(pieces.allSatisfy { $0.count <= max12 }, "no piece exceeds 12 s",
             "\(pieces.map { $0.count / rate })")
    T.equal(pieces.count, 3, "30 s → 3 balanced pieces, no runt tail")
    let cuts = pieces.dropLast().map(\.upperBound)
    let inGap = { (c: Int) in [9, 20].contains { c >= $0 * rate && c < $0 * rate + 3_200 } }
    T.expect(cuts.allSatisfy(inGap), "cuts land in the silent gaps",
             "cuts at \(cuts.map { Double($0) / Double(rate) }) s")

    T.equal(AudioSplitter.pieces(of: Array(audio.prefix(max12)), maxSamples: max12).count, 1,
            "audio at the limit stays one call")
    T.equal(WhisperCppEngine.maxCallSamples(for: .hindi), max12, "हिन्दी calls capped at 12 s")
    T.equal(WhisperCppEngine.maxCallSamples(for: .hinglish), nil, "Roman-script modes unsplit")
}
