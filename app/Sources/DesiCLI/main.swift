// desi-cli — headless engine verification (no mic/accessibility permissions needed).
//
// Usage:
//   swift run desi-cli <model.bin> <audio.wav> [hinglish|english|hindi]
//   swift run desi-cli <model.bin> --batch <dir-with-wavs> [mode]   # JSONL out (evals)
//   swift run desi-cli --translate "text" [english|hindi]           # LLM spike (TRANSLATION.md §5)
//   swift run desi-cli --structure "text" [notes|actionList|emailDraft|outline]
import DesiDictationKit
import Foundation

let args = CommandLine.arguments

/// exit() after freeing the model: ggml's Metal teardown (a static destructor
/// run by exit()) aborts if GPU buffers are still allocated — every batch run
/// used to end in SIGABRT, exit 134 (FM#27).
func finish(_ code: Int32, unloading engine: EngineRouter?) -> Never {
    engine?.unload()
    exit(code)
}

// --novad: VAD off for THIS run only. Goes in the volatile argument domain
// (highest priority, never saved) before SettingsStore first reads it. The old
// UserDefaults.set arrived after SettingsStore had loaded — no effect on its
// own run — and was persisted, so every later desi-cli run, evals and latency
// gate included, silently ran without VAD (FM#28). Works in any mode.
if args.contains("--novad") {
    var argDomain = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
    argDomain["vadEnabled"] = false
    UserDefaults.standard.setVolatileDomain(argDomain, forName: UserDefaults.argumentDomain)
}
guard args.count >= 3 else {
    print("""
    usage: desi-cli <model.bin> <audio file | --batch dir> [hinglish|english|hindi]
           desi-cli --translate "text" [english|hindi]
           desi-cli --structure "text" [notes|actionList|emailDraft|outline]
    """)
    exit(1)
}

// Holistic end-to-end: wav → whisper → dictionary → LLM translate — the full
// anyToEnglish pipeline through the same classes the app runs, minus UI.
// Usage: desi-cli --e2e <whisper-model.bin> <audio.wav>
if args[1] == "--e2e", args.count >= 4 {
    let semaphore = DispatchSemaphore(value: 0)
    // Router, not a bare whisper engine: the CLI must exercise the exact
    // path the app takes, including Parakeet models (English mode).
    let engine = EngineRouter()
    Task {
        defer { semaphore.signal() }
        do {
            try engine.load(modelPath: args[2])
            let samples = try AudioFileLoader.loadSamples(url: URL(fileURLWithPath: args[3]))
            let asr = try engine.transcribe(samples: samples, mode: .anyToEnglish)
            var text = PostProcessor.applyReplacements(
                asr.text, rules: SettingsStore.shared.replacementRules)
            text = PersonalDictionary.shared.apply(to: text)
            print("HEARD (\(String(format: "%.1f", asr.duration))s ASR): \(text)")
            let llm = OllamaLLM(model: SettingsStore.shared.llmModel)
            guard (await llm.status()).isReady else {
                print("LLM not ready — app would paste the raw words above")
                finish(3, unloading: engine)
            }
            let start = Date()
            let english = try await LLMTranslationEngine(llm: llm)
                .translate(text, to: .english)
            print("PASTED (\(String(format: "%.1f", Date().timeIntervalSince(start)))s LLM): \(english)")
        } catch {
            FileHandle.standardError.write("e2e error: \(error.localizedDescription)\n".data(using: .utf8)!)
            finish(2, unloading: engine)
        }
    }
    semaphore.wait()
    finish(0, unloading: engine)
}

// Parity hook: print HindiNumbers.normalize(text) — scripts/check_parity.sh
// diffs this against the web demo's Python port so the two never drift.
if args[1] == "--normalize" {
    print(HindiNumbers.normalize(args[2]))
    exit(0)
}

// LLM verification paths — exercise the exact engine the app uses.
if args[1] == "--translate" || args[1] == "--structure" {
    let llm = OllamaLLM(model: SettingsStore.shared.llmModel)
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        defer { semaphore.signal() }
        let status = await llm.status()
        guard status.isReady else {
            FileHandle.standardError.write("llm not ready: \(status)\n".data(using: .utf8)!)
            exit(3)
        }
        do {
            let start = Date()
            if args[1] == "--translate" {
                let target = TargetLanguage(rawValue: args.count > 3 ? args[3] : "english") ?? .english
                let out = try await LLMTranslationEngine(llm: llm).translate(args[2], to: target)
                print(out)
            } else {
                let style = OutputStyle(rawValue: args.count > 3 ? args[3] : "notes") ?? .notes
                let out = try await ThoughtStructurer(llm: llm).structure(args[2], style: style)
                print(out.structured)
            }
            FileHandle.standardError.write(
                "(\(String(format: "%.1f", Date().timeIntervalSince(start)))s, model \(llm.model))\n"
                    .data(using: .utf8)!)
        } catch {
            FileHandle.standardError.write("error: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(2)
        }
    }
    semaphore.wait()
    exit(0)
}
let modelPath = args[1]
let mode = LanguageMode(rawValue: args.count > 3 ? args[3] : "hinglish") ?? .hinglish

// Batch mode: one model load, transcribe every .wav in a directory,
// emit one JSON line per file — consumed by evals/run_eval.py.
if args[2] == "--batch", args.count >= 4 {
    let dir = URL(fileURLWithPath: args[3])
    let batchMode = LanguageMode(rawValue: args.count > 4 ? args[4] : "hinglish") ?? .hinglish
    // Router, not a bare whisper engine: the CLI must exercise the exact
    // path the app takes, including Parakeet models (English mode).
    let engine = EngineRouter()
    do {
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
        finish(0, unloading: engine)
    } catch {
        FileHandle.standardError.write("batch error: \(error.localizedDescription)\n".data(using: .utf8)!)
        finish(2, unloading: engine)
    }
}

let audioURL = URL(fileURLWithPath: args[2])
// Router, not a bare whisper engine: the CLI must exercise the exact
// path the app takes, including Parakeet models (English mode).
let engine = EngineRouter()

do {
    let loadStart = Date()
    try engine.load(modelPath: modelPath)
    print("model loaded in \(String(format: "%.2f", Date().timeIntervalSince(loadStart)))s")

    let samples = try AudioFileLoader.loadSamples(url: audioURL)
    print("audio: \(String(format: "%.1f", Double(samples.count) / 16000.0))s")

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
    finish(2, unloading: engine)
}
finish(0, unloading: engine)
