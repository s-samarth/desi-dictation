import Foundation

/// Stock multilingual GGML models downloadable straight from Hugging Face
/// (prebuilt by the whisper.cpp project). Hinglish models are produced locally
/// by scripts/convert_model.sh (or downloaded from our own HF repo post-launch).
public struct DownloadableModel: Identifiable {
    public let id: String
    public let label: String
    public let url: URL
    public let approxMB: Int
    public let pro: Bool
    /// Shown with a ⭐ in-app: our opinionated pick per category.
    public let recommended: Bool
    /// Which need it serves — rendered as a section hint in the Models UI.
    public let category: String
    /// SHA256 of the file — verified after download so a hijacked model repo
    /// can't feed us a tampered binary (whisper.cpp parses these files in C).
    public let sha256: String
}

extension ModelManager {
    /// Base URL for our published Hinglish models — see scripts/publish_models.sh
    /// and docs/LAUNCH.md step 3. Overridable for forks/testing.
    public static let hinglishRepoBase = UserDefaults.standard.string(forKey: "modelRepoBase")
        ?? "https://huggingface.co/SamarthBuilds/desi-dictation-models/resolve/main"

    // One ⭐ model per language + the VAD add-on. Deliberately minimal (v0.5
    // pilot feedback: base/small/swift variants just confused people).
    // Prime replaced Apex as the Hinglish model (2026-10-28): the bake-off
    // (MODEL_RESEARCH.md §F) found it more accurate on long, conversational
    // Hinglish. Apex is no longer offered; an installed Apex file still works
    // when pinned (ModelScoring keeps it below Prime).
    public static let catalog: [DownloadableModel] = [
        .init(id: "hinglish-prime-q5_0", label: "Hinglish Prime — our specialty",
              url: URL(string: "\(hinglishRepoBase)/ggml-hinglish-prime-q5_0.bin")!,
              approxMB: 1031, pro: true, recommended: true, category: "Hinglish",
              sha256: "ccd4e5e48de189f9be887007f96744cb51a3ee086d97ab8787b132f94055fda3"),
        .init(id: "parakeet-tdt-0.6b-v3-q4_k", label: "Parakeet — fastest English",
              url: URL(string: "https://huggingface.co/ggml-org/parakeet-GGUF/resolve/main/ggml-parakeet-tdt-0.6b-v3-q4_k.bin")!,
              approxMB: 416, pro: true, recommended: true, category: "English",
              sha256: "8b205b8b39c6535e153de6fb11c51db46125d45c4f16ba496fe41a0fe71b885e"),
        // Replaced Whisper large-v3-turbo (v0.6.3): more accurate than Parakeet
        // on Indian English, clean and noisy, at ~4x its latency — the opt-in
        // "accuracy over speed" pick (docs/ENGLISH_ASR_AB_2026-10.md).
        .init(id: "qwen3-asr-1.7b-q8_0", label: "Qwen — most accurate English (slower)",
              url: URL(string: "https://huggingface.co/handy-computer/Qwen3-ASR-1.7B-gguf/resolve/0e0a596e3959c3f3f2ab7d443a5b6f0f4a4bba6f/Qwen3-ASR-1.7B-Q8_0.gguf")!,
              approxMB: 2084, pro: true, recommended: true, category: "English",
              sha256: "9a0d81792dfea2d5f278b8a63deb3ea6e02139ce42c2301f32ea19c4f77526b7"),
        .init(id: "vaani-hindi-q5_0", label: "Vaani Hindi — शुद्ध हिन्दी (Devanagari)",
              url: URL(string: "\(hinglishRepoBase)/ggml-vaani-hindi-q5_0.bin")!,
              approxMB: 1060, pro: true, recommended: true, category: "हिन्दी",
              sha256: "c016cde18a36eaa285c238b7929c3c3f457f62a2dd12765d563df18d600374e7"),
        .init(id: "silero-vad", label: "Silero VAD — smooth pauses (everyone needs this)",
              url: URL(string: "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin")!,
              approxMB: 1, pro: false, recommended: true, category: "Engine add-on",
              sha256: "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf"),
    ]

    /// Onboarding: catalog entry that serves a language mode. Looked up by id,
    /// never by index — a new catalog entry must not silently re-point these.
    public static func catalogEntry(for mode: LanguageMode) -> DownloadableModel {
        switch mode {
        case .hinglish, .anyToEnglish: return entry("hinglish-prime-q5_0")
        case .english: return entry("parakeet-tdt-0.6b-v3-q4_k")
        case .hindi: return entry("vaani-hindi-q5_0")
        }
    }

    public static var vadEntry: DownloadableModel { entry("silero-vad") }

    /// The "When it fits" context checker (CONTEXT_FIT.md): a small text
    /// model that scores sentences, never a transcription model, so it lives
    /// outside `catalog` and is offered on the Vocabulary page.
    /// Base, not instruct: it judged the eval better (CONTEXT_FIT.md "Measured").
    public static let contextCheckerEntry = DownloadableModel(
        id: ContextChecker.modelID, label: "Context checker — underlines odd words, decides \"When it fits\"",
        url: URL(string: "https://huggingface.co/mradermacher/Qwen3-0.6B-Base-GGUF/resolve/b8b11a6dbbb14c739e25018f3f77abac860c28f4/Qwen3-0.6B-Base.Q4_K_M.gguf")!,
        approxMB: 397, pro: false, recommended: true, category: "Engine add-on",
        sha256: "1c728e4fe4abb28cde33b59cd66396e62b2ef755f53db44cdb54e9655b863782")

    /// What pickers call a model: short, and says what it's for (2026-10-29:
    /// "Qwen3-ASR 1.7B" told the user nothing). Download rows keep the label.
    public static func shortName(for id: String) -> String? {
        switch id {
        case "hinglish-prime-q5_0": return "Hinglish Prime"
        case "parakeet-tdt-0.6b-v3-q4_k": return "Parakeet (fastest)"
        case "qwen3-asr-1.7b-q8_0": return "Qwen (most accurate)"
        case "vaani-hindi-q5_0": return "Vaani Hindi"
        default: return nil
        }
    }

    static func entry(_ id: String) -> DownloadableModel {
        guard let found = catalog.first(where: { $0.id == id }) else {
            preconditionFailure("catalog is missing \(id)")
        }
        return found
    }
}
