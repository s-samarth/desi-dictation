import Foundation

/// One shared home for the LLM-backed services (translation, structuring,
/// tone). All three features ride ONE engine and ONE model — the shared-spike
/// design from TRANSLATION.md §4 / STRUCTURE_THOUGHTS.md §4.
///
/// The backend is rebuilt when the user changes the model name in settings;
/// everything else holds a reference to `LLMServices.shared`, never to a
/// concrete backend.
public final class LLMServices: ObservableObject {
    public static let shared = LLMServices()

    /// Default model, RAM-gated (TRANSCRIBE_TRANSLATE.md §4: "if we ever offer
    /// a bigger LLM, gate it on RAM"). The 2026-07-10 spike was decisive:
    /// gemma3:4b translates code-mixed Hinglish correctly (numbers, idiom,
    /// subject) where 1.5B/3B Qwen invert meaning and mangle lakh-figures —
    /// exactly the §7 research prediction. 4B needs ~3.5 GB resident → only
    /// machines with 12 GB+ default to it; 8 GB Airs get the small model and
    /// honest docs about its limits.
    public static let defaultModel: String =
        ProcessInfo.processInfo.physicalMemory >= 12 * 1_073_741_824
            ? "gemma3:4b" : "qwen2.5:1.5b-instruct"

    @Published public private(set) var status: LLMStatus = .serverDown
    @Published public var pullProgress: Double?   // nil = not pulling

    public private(set) var llm: LocalLLM
    public private(set) var translator: LLMTranslationEngine
    public private(set) var structurer: ThoughtStructurer

    private init() {
        let backend = OllamaLLM(model: SettingsStore.shared.llmModel)
        llm = backend
        translator = LLMTranslationEngine(llm: backend)
        structurer = ThoughtStructurer(llm: backend)
        Task { await refreshStatus() }
    }

    /// Rebuilds the backend after a model-name change in settings.
    public func modelChanged() {
        let backend = OllamaLLM(model: SettingsStore.shared.llmModel)
        llm = backend
        translator = LLMTranslationEngine(llm: backend)
        structurer = ThoughtStructurer(llm: backend)
        Task { await refreshStatus() }
    }

    @MainActor
    public func refreshStatus() async {
        status = await llm.status()
    }

    /// Human guidance for the current status — shown inline wherever an LLM
    /// feature is offered (plain words, no jargon: Rekha-proof per PERSONAS.md).
    public var statusGuidance: String? {
        switch status {
        case .ready: return nil
        case .serverDown:
            return "AI features need the free Ollama app running (ollama.com). Install it, open it once, then hit Refresh."
        case .modelMissing(let model):
            return "One-time setup: get the AI model \"\(model)\" (~1 GB) below. Everything stays on your Mac."
        }
    }

    /// Inline model download with progress (mirrors ModelManager.download UX).
    public func pullModel() async {
        guard let backend = llm as? OllamaLLM else { return }
        await MainActor.run { pullProgress = 0 }
        do {
            try await backend.pull { fraction in
                Task { @MainActor [weak self] in self?.pullProgress = fraction }
            }
            await MainActor.run { pullProgress = nil }
            await refreshStatus()
        } catch {
            await MainActor.run { pullProgress = nil }
            await refreshStatus()
        }
    }

    /// Applies the selected tone to dictated text. Faithful mode = passthrough
    /// (no LLM call at all). Any failure returns the original text — dictation
    /// is never lost to a flaky rewrite (house rule).
    public func applyTone(_ tone: ToneMode, to text: String) async -> String {
        guard let system = PromptTemplates.tone(tone), !text.isEmpty else { return text }
        guard let rewritten = try? await llm.generate(system: system, user: text),
              !rewritten.isEmpty
        else { return text }
        return rewritten
    }
}
