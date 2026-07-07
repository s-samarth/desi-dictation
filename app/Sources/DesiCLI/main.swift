// desi-cli — headless engine verification (no mic/accessibility permissions needed).
//
// Usage:
//   swift run desi-cli <model.bin> <audio.wav> [hinglish|english|hindi]
//   swift run desi-cli <model.bin> --batch <dir-with-wavs> [mode]   # JSONL out (evals)
import DesiDictationKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: desi-cli <model.bin> <audio file | --batch dir> [hinglish|english|hindi]")
    exit(1)
}
let modelPath = args[1]
let mode = LanguageMode(rawValue: args.count > 3 ? args[3] : "hinglish") ?? .hinglish

// Batch mode: one model load, transcribe every .wav in a directory,
// emit one JSON line per file — consumed by evals/run_eval.py.
if args[2] == "--batch", args.count >= 4 {
    let dir = URL(fileURLWithPath: args[3])
    let batchMode = LanguageMode(rawValue: args.count > 4 ? args[4] : "hinglish") ?? .hinglish
    do {
        let engine = WhisperCppEngine()
        try engine.load(modelPath: modelPath)
        let files = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            let samples = try AudioFileLoader.loadSamples(url: file)
            let result = try engine.transcribe(samples: samples, mode: batchMode)
            let record: [String: Any] = [
                "file": file.lastPathComponent,
                "text": result.text,
                "seconds": (result.duration * 100).rounded() / 100,
                "audio_seconds": (result.audioSeconds * 10).rounded() / 10,
            ]
            let data = try JSONSerialization.data(withJSONObject: record)
            print(String(data: data, encoding: .utf8)!)
        }
        exit(0)
    } catch {
        FileHandle.standardError.write("batch error: \(error.localizedDescription)\n".data(using: .utf8)!)
        exit(2)
    }
}

let audioURL = URL(fileURLWithPath: args[2])

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
