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
        switch mode {
        // anyToEnglish transcribes the same mixed speech as Hinglish mode
        // (TRANSCRIBE_TRANSLATE.md §4: Apex handles the mix best); the English
        // comes from the translation stage, not the ASR model.
        case .hinglish, .anyToEnglish:
            if name.contains("hinglish-apex") { score = 100 }
            else if name.contains("hinglish-prime") { score = 90 }
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
