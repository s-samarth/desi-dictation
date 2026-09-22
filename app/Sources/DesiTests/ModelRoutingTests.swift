import Foundation
import DesiDictationKit

/// v0.6.1: per-language model defaults, language-scoped candidate lists, and
/// the Parakeet English engine. The rules these lock in come from real user
/// pain — "why do I pick English and then have to find a model that speaks
/// English?" — and from PERF_RCA_2026-08.md.
func runModelRoutingTests() {
    T.begin("Per-language model defaults")
    let hinglishPin = "/models/ggml-hinglish-apex-q5_0.bin"
    let englishPin = "/models/ggml-parakeet-tdt-0.6b-v3-q4_k.bin"
    let settings = SettingsStore.shared
    let saved = settings.modelPaths
    defer { settings.modelPaths = saved }

    settings.modelPaths = [:]
    T.equal(settings.modelPath(for: .english), "", "no pin → Auto")
    settings.setModelPath(englishPin, for: .english)
    settings.setModelPath(hinglishPin, for: .hinglish)
    T.equal(settings.modelPath(for: .english), englishPin, "English keeps its own pin")
    T.equal(settings.modelPath(for: .hinglish), hinglishPin, "Hinglish keeps its own pin")
    T.equal(settings.modelPath(for: .hindi), "", "untouched language stays on Auto")
    // The whole point: switching language must not drag the other language's
    // model along (the 0.6.0 behaviour, one global pin).
    T.expect(settings.modelPath(for: .english) != settings.modelPath(for: .hinglish),
             "languages do not share one pin")
    T.equal(settings.modelPath(for: .anyToEnglish), hinglishPin,
            "anyToEnglish rides the Hinglish pin (it transcribes as Hinglish)")
    settings.setModelPath("", for: .english)
    T.equal(settings.modelPath(for: .english), "", "empty path restores Auto")

    T.begin("Model catalog — lookup by id, not index")
    T.equal(ModelManager.catalogEntry(for: .english).id, "parakeet-tdt-0.6b-v3-q4_k",
            "English onboards to Parakeet (4.3 % nWER, 5x faster — MODEL_RESEARCH §E)")
    T.equal(ModelManager.catalogEntry(for: .hindi).id, "vaani-hindi-q5_0", "हिन्दी → Vaani")
    T.equal(ModelManager.catalogEntry(for: .hinglish).id, "hinglish-apex-q5_0", "Hinglish → Apex")
    T.equal(ModelManager.vadEntry.id, "silero-vad", "VAD entry resolves")

    T.begin("Language-scoped candidates")
    let parakeet = ModelDescriptor(
        name: "parakeet-tdt-0.6b-v3-q4_k", path: englishPin, sizeMB: 416)
    let apex = ModelDescriptor(
        name: "hinglish-apex-q5_0", path: hinglishPin, sizeMB: 547)
    T.expect(parakeet.isParakeet, "parakeet detected by filename")
    T.expect(!apex.isParakeet && apex.isHinglish, "apex is a Hinglish whisper model")
    // Parakeet speaks English + 24 European languages — no Hindi, and it can
    // emit neither Devanagari nor Roman-Hinglish. It must never be offered
    // outside English, or a user "just picking a model" gets nonsense.
    T.expect(ModelManager.score(parakeet, for: .english) > 0, "Parakeet serves English")
    T.equal(ModelManager.score(parakeet, for: .hindi), 0, "Parakeet hidden for हिन्दी")
    T.equal(ModelManager.score(parakeet, for: .hinglish), 0, "Parakeet hidden for Hinglish")
    T.equal(ModelManager.score(apex, for: .hindi), 0, "Hinglish models hidden for हिन्दी")
    T.expect(ModelManager.score(parakeet, for: .english)
             > ModelManager.score(apex, for: .english),
             "English Auto prefers Parakeet over a Hinglish fine-tune")

    T.begin("Engine routing by model file")
    T.expect(ParakeetEngine.handles(modelPath: englishPin), "parakeet file → Parakeet engine")
    T.expect(!ParakeetEngine.handles(modelPath: hinglishPin), "ggml whisper file → whisper.cpp")

    T.begin("Chunking thresholds (PERF_RCA_2026-08.md RC2)")
    // A whisper call costs a full padded 30 s window whatever it holds, so a
    // chunk must be worth more than the call it costs. If someone lowers these
    // again, every ordinary dictation silently pays extra full-price calls.
    T.expect(DictationController.chunkFloorSamples >= 30 * 16000,
             "short dictations never chunk (one call)")
    T.expect(DictationController.chunkEverySamples >= 20 * 16000,
             "chunks are long relative to the fixed per-call cost")
    T.expect(DictationController.chunkForceSamples > DictationController.chunkEverySamples,
             "forced cut is the outer bound, not the normal one")
    T.expect(DictationController.tailFloorSamples >= 3200,
             "sub-0.2 s tails are key-release noise, not speech")

    // FM#26: हिन्दी chunks early because the engine splits at 12 s anyway;
    // a chunk may overshoot `force` by one 1 s ticker step and must still fit.
    let hindi = DictationController.chunkThresholds(for: .hindi)
    let cap = WhisperCppEngine.maxCallSamples(for: .hindi) ?? 0
    T.expect(hindi.force + 16000 <= cap, "हिन्दी chunks never need a second split")
    T.expect(hindi.every >= 8 * 16000, "हिन्दी chunks still worth their call")
    T.expect(DictationController.chunkThresholds(for: .hinglish).floor
             == DictationController.chunkFloorSamples, "other modes keep the 30 s floor")
}
