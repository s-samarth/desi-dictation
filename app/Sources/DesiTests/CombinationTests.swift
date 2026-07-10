import Foundation
import DesiDictationKit

/// Features in combination, mirroring DictationController's pipeline order:
///   transcript → legacy replacements → personal dictionary → LLM stage
/// (translate for anyToEnglish, tone otherwise) → deliver-or-fallback.
func runCombinationTests() async {
    T.begin("Pipeline combination — dictionary + translation")
    let rules = "desy=desi"
    let dictionary = [DictionaryEntry(heard: "meating", written: "meeting")]
    let mock = MockLLM()
    let engine = LLMTranslationEngine(llm: mock)

    let raw = "kal desy team ki meating hai"
    var text = PostProcessor.applyReplacements(raw, rules: rules)
    text = PersonalDictionary.apply(text, entries: dictionary)
    T.equal(text, "kal desi team ki meeting hai",
            "both correction layers apply before the LLM sees the text")
    let english = try? await engine.translate(text, to: .english)
    T.equal(english, "T[kal desi team ki meeting hai]",
            "translation receives corrected text — garbage-in fixed first")

    T.begin("Pipeline combination — anyToEnglish failure falls back to raw")
    mock.shouldFail = true
    let delivered = (try? await engine.translate(text, to: .english)) ?? text
    T.equal(delivered, text, "LLM failure → user's words pasted, never lost")

    T.begin("Pipeline combination — tone is meaning-preserving plumbing")
    mock.shouldFail = false
    mock.reply = { "polished: \($0)" }
    if let prompt = PromptTemplates.tone(.professional) {
        let toned = (try? await mock.generate(system: prompt, user: text)) ?? text
        T.equal(toned, "polished: kal desi team ki meeting hai",
                "tone rewrite rides the same corrected text")
    } else {
        T.expect(false, "professional tone has a prompt")
    }
    // .faithful must never touch the LLM: the controller skips the stage
    // entirely (PromptTemplates.tone(.faithful) == nil is that guarantee).
    T.expect(PromptTemplates.tone(.faithful) == nil,
             "faithful tone bypasses the LLM stage")

    T.begin("Pipeline combination — structure carries dictionary fixes + raw")
    mock.reply = { _ in "## Notes\n- sab kuch" }
    let structurer = ThoughtStructurer(llm: mock)
    if let result = try? await structurer.structure(text, style: .notes) {
        T.equal(result.raw, text, "review window's raw = exactly what pipeline heard")
        T.expect(!result.structured.isEmpty, "structured output produced")
    } else {
        T.expect(false, "structuring succeeds")
    }

    T.begin("Per-app rule + anyToEnglish (the Rekha flow)")
    let store = AppModeStore(fileURL: T.tempFile("combo-modes.json"))
    store.set(.anyToEnglish, bundleID: "com.apple.mail", appName: "Mail")
    let mode = store.mode(for: "com.apple.mail") ?? .hinglish
    T.expect(mode.needsLLM, "Mail rule routes into the translation stage")
    T.equal(ModelManager.catalogEntry(for: mode).id, "hinglish-apex-q5_0",
            "…while transcribing with Apex")
}
