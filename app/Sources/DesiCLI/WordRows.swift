import DesiDictationKit
import Foundation

/// JSON rows for `--words`: [text, confidence, surprise, peak]. Confidence is
/// null when the engine gives none; surprise and peak (the context checker's
/// −log p of the word in its sentence, SentenceSurprise) are null when the
/// checker isn't installed. Read by evals/word_confidence.py. An engine with
/// no word list (Qwen3-ASR) gets the text's words, with no confidence.
func wordRows(_ result: TranscriptionResult) -> [[Any]] {
    let words = !result.words.isEmpty ? result.words
        : result.text.split(whereSeparator: \.isWhitespace).map { ScoredWord(text: String($0), confidence: .nan) }
    let surprise = wordSurprise(words)
    return words.enumerated().map { n, word in
        [word.text,
         word.confidence.isFinite ? Double(word.confidence) : NSNull(),
         surprise.map { $0[n].total } ?? NSNull(),
         surprise.map { $0[n].peak } ?? NSNull()]
    }
}

/// The checker the CLI scores with: $DESI_CHECKER (a .gguf), else the app's
/// installed one. Set to nil before exit (FM#40); finish() does.
nonisolated(unsafe) var cliChecker: LlamaContextScorer? = {
    let path = ProcessInfo.processInfo.environment["DESI_CHECKER"] ?? ContextChecker.modelURL.path
    return FileManager.default.fileExists(atPath: path) ? LlamaContextScorer(modelPath: path) : nil
}()

/// Scores the words as one sentence, joined by spaces, the way they'll read.
private func wordSurprise(_ words: [ScoredWord]) -> [WordSurprise]? {
    guard !words.isEmpty, let scorer = cliChecker else { return nil }
    var text = ""
    var ranges: [(Int, Int)] = []
    for word in words {
        if !text.isEmpty { text += " " }
        let start = text.utf8.count
        text += word.text
        ranges.append((start, text.utf8.count))
    }
    let indexed = ranges.map { lo, hi in
        text.utf8.index(text.startIndex, offsetBy: lo)..<text.utf8.index(text.startIndex, offsetBy: hi)
    }
    return SentenceSurprise.scores(for: indexed, in: text, scorer: scorer)
}

/// desi-cli --surprise "text": each word's surprise in its sentence, oddest
/// marked, to see what the reviewer would underline.
func runSurprise(_ rest: [String]) -> Never {
    exit(surprise(rest.first ?? ""))
}

private func surprise(_ text: String) -> Int32 {
    defer { cliChecker = nil }   // free before exit (FM#40)
    guard let scorer = cliChecker else {
        print("no context checker: set DESI_CHECKER=<model.gguf> or install it in the app")
        return 1
    }
    let start = Date()
    guard let words = SentenceSurprise.words(in: text, scorer: scorer) else {
        print("scoring failed")
        return 1
    }
    for word in words {
        print(String(format: "%6.2f  %6.2f  ", word.total, word.peak) + text[word.range])
    }
    print(String(format: "%.0f ms (first call includes model load)", Date().timeIntervalSince(start) * 1000))
    return 0
}
