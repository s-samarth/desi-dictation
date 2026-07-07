// desi-cli — headless engine verification (no mic/accessibility permissions needed).
//
// Usage:
//   swift run desi-cli <model.bin> <audio.wav> [hinglish|english|hindi]
import DesiDictationKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: desi-cli <model.bin> <audio file> [hinglish|english|hindi]")
    exit(1)
}
let modelPath = args[1]
let audioURL = URL(fileURLWithPath: args[2])
let mode = LanguageMode(rawValue: args.count > 3 ? args[3] : "hinglish") ?? .hinglish

do {
    let engine = WhisperCppEngine()
    let loadStart = Date()
    try engine.load(modelPath: modelPath)
    print("model loaded in \(String(format: "%.2f", Date().timeIntervalSince(loadStart)))s")

    let samples = try AudioFileLoader.loadSamples(url: audioURL)
    print("audio: \(String(format: "%.1f", Double(samples.count) / 16000.0))s")

    if CommandLine.arguments.contains("--novad") {
        UserDefaults.standard.set(false, forKey: "vadEnabled")
    }

    // Repeated transcriptions on ONE loaded context — mirrors real app usage
    // (the app keeps the model resident across dictations).
    let repeats = CommandLine.arguments.contains("--repeat") ? 3 : 1
    for i in 1...repeats {
        let result = try engine.transcribe(samples: samples, mode: mode)
        let rtf = result.audioSeconds / max(result.duration, 0.001)
        print("[run \(i)] \(String(format: "%.2f", result.duration))s "
            + "(\(String(format: "%.0f", rtf))x realtime) -> \"\(result.text)\"")
    }
} catch {
    print("error: \(error.localizedDescription)")
    exit(2)
}
