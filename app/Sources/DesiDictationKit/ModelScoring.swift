import Foundation

extension ModelManager {
    /// Public so the test runner can pin the routing rules directly (which
    /// model serves which language) instead of inferring them from resolve().
    public static func score(_ model: ModelDescriptor, for mode: LanguageMode) -> Int {
        let name = model.name.lowercased()
        var score = 0
        // Parakeet covers English + 24 European languages — no Hindi, and it
        // cannot emit Devanagari or Roman-Hinglish. English mode only.
        if model.isParakeet, mode != .english { return 0 }
        // Qwen3-ASR could transcribe Hindi, but here it is the English
        // accuracy pick; Hinglish and हिन्दी have their own fine-tunes.
        if model.isQwenASR, mode != .english { return 0 }
        switch mode {
        // anyToEnglish transcribes the same mixed speech as Hinglish mode
        // (TRANSCRIBE_TRANSLATE.md §4); the English comes from the translation
        // stage, not the ASR model. Prime is the default since 2026-10-28;
        // Apex is no longer offered but a file already on disk still serves.
        case .hinglish, .anyToEnglish:
            if name.contains("hinglish-prime") { score = 100 }
            else if name.contains("hinglish-apex") { score = 90 }
            else if name.contains("hinglish-swift") { score = 50 }
            else if name.contains("turbo") { score = 40 }
            else if name.contains("small") { score = 30 }
            else if name.contains("base") { score = 20 }
        case .english:
            // Parakeet wins on measurement, not on novelty: 4.3 % vs turbo's
            // 4.5 % nWER on the eval english suite (20 clips; FLEURS US English, not
            // Svarah as once written — FM#24) at 5x
            // the speed — MODEL_RESEARCH.md §E, ParakeetEngine.swift.
            if name.contains("parakeet") { score = 120 }
            // Opt-in accuracy pick: below Parakeet so Auto keeps the fast
            // default, above everything else (ENGLISH_ASR_AB_2026-10.md).
            else if name.contains("qwen3-asr") { score = 110 }
            else if name.contains("turbo") { score = 100 }
            else if name.contains("hinglish-apex") { score = 80 }   // great Indian English
            else if name.contains("small") { score = 60 }
            else if name.contains("hinglish-prime") { score = 55 }
            else if name.contains("base") { score = 40 }
            else if name.contains("hinglish-swift") { score = 30 }
        case .hindi:
            guard !model.isHinglish else { return 0 }               // wrong output script
            if name.contains("vaani") { score = 110 }               // 718h Indian-speech fine-tune
            else if name.contains("turbo") { score = 100 }
            else if name.contains("small") { score = 80 }
            else if name.contains("base") { score = 60 }
        }
        if score > 0, name.contains("q5") { score += 5 }            // prefer quantized
        return score
    }
}
