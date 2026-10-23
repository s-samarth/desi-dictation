import Foundation
import DesiDictationKit

/// FM#30: Hinglish Apex answered a clear 15.7 s clip with the single token
/// "nan" — the user dictated and nothing was pasted.
func runWhisperLabelTests() {
    T.begin("NaNLabelFilter — bans \"nan\" as the first token only")
    func run(_ logits: [Float], decoded: Int = 0) -> (NaNLabelFilter, [Float]) {
        let filter = NaNLabelFilter(token: 1, vocabSize: logits.count)
        var out = logits
        out.withUnsafeMutableBufferPointer { filter.filter(decoded: decoded, logits: $0) }
        return (filter, out)
    }
    let (onTop, banned) = run([1, 9, 3])
    T.expect(banned[1] == -.infinity, "first position: label banned")
    T.equal([banned[0], banned[2]], [1, 3], "other tokens untouched")
    T.expect(onTop.overruled, "label on top → recorded as overruled")
    T.expect(onTop.keeps(textTokens: 40), "overruled + real transcript → kept (0081)")
    T.expect(!onTop.keeps(textTokens: 1), "overruled + one stray token → dropped (noise)")
    let (runnerUp, _) = run([1, 2, 3])
    T.expect(!runnerUp.overruled, "label not on top → not overruled")
    T.expect(runnerUp.keeps(textTokens: 1), "one-word dictation untouched (\"Haan\")")
    let (later, untouched) = run([1, 9, 3], decoded: 4)
    T.equal(untouched, [1, 9, 3], "mid-transcript: \"nan\" is a legal word piece")
    T.expect(!later.overruled, "mid-transcript: nothing recorded")

    // Live regression: needs Apex installed and the gitignored eval clip.
    T.begin("WhisperCppEngine — Apex transcribes hinglish 0081 (regression)")
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let clip = repo.appendingPathComponent("evals/data/hinglish/clips/0081.wav")
    let apex = AppPaths.modelsDirectory.appendingPathComponent("ggml-hinglish-apex-q5_0.bin")
    guard FileManager.default.fileExists(atPath: clip.path),
          FileManager.default.fileExists(atPath: apex.path) else {
        print("  (skipped — Apex or evals/data/hinglish/clips/0081.wav not on this machine)")
        return
    }
    let engine = WhisperCppEngine()
    defer { engine.unload() }   // free Metal buffers before exit (FM#27)
    do {
        try engine.load(modelPath: apex.path)
        let samples = try AudioFileLoader.loadSamples(url: clip)
        let text = try engine.transcribe(samples: samples, mode: .hinglish).text
        T.expect(text.lowercased().contains("drawing competition"),
                 "0081 decodes in full, not \"\" (regression)", "got: \(text)")
        var rng = SystemRandomNumberGenerator()
        let noise = (0..<5 * 16000).map { _ in Float.random(in: -0.05...0.05, using: &rng) }
        let heard = (try? engine.transcribe(samples: noise, mode: .hinglish).text) ?? ""
        T.equal(heard, "", "5 s of noise still pastes nothing")
    } catch {
        T.expect(false, "0081 decodes in full, not \"\" (regression)", "\(error)")
    }
}
