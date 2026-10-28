import DesiDictationKit
import Foundation

/// desi-cli --fit <model.gguf> <cases.tsv> [--no-prefix] [--cpu]
///
/// Runs ContextFit — the exact code the app runs — over labelled sentences
/// (evals/context_fit/cases.tsv: expect<TAB>heard<TAB>written<TAB>sentence,
/// expect = swap|keep) and prints accuracy, a margin sweep and latency.
/// CONTEXT_FIT.md says how to read it; the Mac handoff says what to run.
func runFitEval(_ rest: [String]) -> Never {
    guard rest.count >= 2 else {
        print("usage: desi-cli --fit <model.gguf> <cases.tsv> [--no-prefix] [--cpu]")
        exit(1)
    }
    let loadStart = Date()
    guard let scorer = LlamaContextScorer(modelPath: rest[0], gpuLayers: rest.contains("--cpu") ? 0 : 99) else {
        print("couldn't load \(rest[0]) (llama runtime in this build: \(LlamaContextScorer.isAvailable);"
              + " run scripts/setup_llama.sh, then rebuild)")
        exit(1)
    }
    let loadMs = Date().timeIntervalSince(loadStart) * 1000
    guard let tsv = try? String(contentsOfFile: rest[1], encoding: .utf8) else {
        print("can't read \(rest[1])")
        exit(1)
    }
    let cases = tsv.split(separator: "\n").compactMap { line -> (Bool, String, String, String)? in
        let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard cols.count == 4, !line.hasPrefix("#"), cols[0] == "swap" || cols[0] == "keep" else { return nil }
        return (cols[0] == "swap", cols[1], cols[2], cols[3])
    }
    let terms = rest.contains("--no-prefix") ? [] : cases.map { $0.2 }
    let prefix = ContextFit.prefix(terms: terms)
    print("model loaded in \(Int(loadMs)) ms · \(cases.count) cases · prompt: \(prefix.debugDescription)")

    var results: [(expectSwap: Bool, delta: Double)] = []
    var timings: [Double] = []
    for (expectSwap, heard, written, sentence) in cases {
        let entry = DictionaryEntry(heard: heard, written: written, mode: .whenItFits)
        let started = Date()
        let out = ContextFit.apply(sentence, entries: [entry], cues: FitCues(), scorer: scorer, prefix: prefix)
        timings.append(Date().timeIntervalSince(started) * 1000)
        guard let decision = out.decisions.first, let delta = decision.modelDelta else {
            print("?  no decision (is \"\(heard)\" a whole word in it?): \(sentence)")
            continue
        }
        results.append((expectSwap, delta))
        let mark = decision.swapped == expectSwap ? "✓" : "✗"
        print("\(mark) want \(expectSwap ? "swap" : "keep")  Δ=\(String(format: "%+6.2f", delta))  \(sentence)")
    }

    func accuracy(at margin: Double) -> Double {
        let right = results.filter { ($0.delta > margin) == $0.expectSwap }.count
        return results.isEmpty ? 0 : Double(right) / Double(results.count)
    }
    print("\naccuracy at the shipped margin (\(ContextFit.margin)): \(String(format: "%.1f", accuracy(at: ContextFit.margin) * 100)) %")
    print("margin sweep (swap when Δ > margin):")
    for margin in [-3.0, -2, -1, -0.5, 0, 0.5, 1, 2, 3] {
        print("  \(String(format: "%+5.1f", margin)) → \(String(format: "%5.1f", accuracy(at: margin) * 100)) %")
    }
    let wrongSwaps = results.filter { !$0.expectSwap && $0.delta > ContextFit.margin }.count
    print("wrong swaps (the costly error): \(wrongSwaps) of \(results.filter { !$0.expectSwap }.count) keep cases")
    let sorted = timings.sorted()
    if !sorted.isEmpty {
        print("per-sentence time (2 scorings): median \(Int(sorted[sorted.count / 2])) ms,"
              + " max \(Int(sorted.last!)) ms")
    }
    exit(0)
}
