import Foundation
import DesiDictationKit

func runStoreTests() {
    T.begin("AppModeStore — rules & persistence")
    let modesURL = T.tempFile("appmodes.json")
    let store = AppModeStore(fileURL: modesURL)
    T.expect(store.rules.isEmpty, "starts empty")
    store.set(.hinglish, bundleID: "net.whatsapp.WhatsApp", appName: "WhatsApp")
    store.set(.english, bundleID: "com.apple.mail", appName: "Mail")
    T.equal(store.mode(for: "net.whatsapp.WhatsApp"), .hinglish, "rule lookup")
    T.expect(store.mode(for: "com.unknown.app") == nil, "no rule → nil (global wins)")
    store.set(.anyToEnglish, bundleID: "net.whatsapp.WhatsApp", appName: "WhatsApp")
    T.equal(store.mode(for: "net.whatsapp.WhatsApp"), .anyToEnglish, "rule update replaces")
    T.equal(store.rules.count, 2, "no duplicate rules")
    store.removeRule(bundleID: "com.apple.mail")
    T.expect(store.mode(for: "com.apple.mail") == nil, "rule removal")
    let reloaded = AppModeStore(fileURL: modesURL)
    T.equal(reloaded.rules, store.rules, "persistence round-trip")

    T.begin("LanguageMode — anyToEnglish contract")
    T.equal(LanguageMode.anyToEnglish.whisperLanguage, "en", "transcribes under en")
    T.expect(LanguageMode.anyToEnglish.needsLLM, "needsLLM flag")
    T.expect(!LanguageMode.hinglish.needsLLM && !LanguageMode.english.needsLLM
             && !LanguageMode.hindi.needsLLM, "base modes need no LLM")
    // Raw values are persisted in UserDefaults + history JSON — renaming any
    // case is a data migration, so pin them.
    T.equal(LanguageMode.allCases.map(\.rawValue),
            ["hinglish", "english", "hindi", "anyToEnglish"], "raw values stable")
    T.equal(ToneMode.allCases.map(\.rawValue),
            ["faithful", "casual", "professional", "respectful"], "tone raw values stable")

    T.begin("Model routing — anyToEnglish rides the Hinglish model")
    T.equal(ModelManager.catalogEntry(for: .anyToEnglish).id,
            ModelManager.catalogEntry(for: .hinglish).id, "same catalog entry (Apex)")
    ModelManager.shared.refresh()
    if let apex = ModelManager.shared.resolveModel(for: .hinglish, pinnedPath: ""),
       apex.name.contains("apex") {
        let any = ModelManager.shared.resolveModel(for: .anyToEnglish, pinnedPath: "")
        T.equal(any?.name, apex.name, "resolver picks the same ASR model (regression)")
        let hindi = ModelManager.shared.resolveModel(for: .hindi, pinnedPath: "")
        T.expect(hindi.map { !$0.isHinglish } ?? true,
                 "Hindi never resolves to a Hinglish model (regression)")
    } else {
        print("  (skipped resolver checks — Apex not installed on this machine)")
    }

    T.begin("HistoryEntry — codable compatibility")
    let old = #"[{"id":"6E9CDE9B-6E9C-4E9C-8E9C-6E9CDE9B6E9C","date":773452800,"text":"purana entry","mode":"hinglish"}]"#
    let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: Data(old.utf8))
    T.expect(decoded?.first != nil, "pre-0.6 history JSON still decodes (regression)")
    T.expect(decoded?.first?.raw == nil && decoded?.first?.translation == nil,
             "absent fields decode as nil")
    var entry = HistoryEntry(text: "final english", mode: "anyToEnglish", raw: "kaccha hinglish")
    entry.translation = "attached later"
    if let data = try? JSONEncoder().encode([entry]),
       let back = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
        T.equal(back.first, entry, "new fields round-trip")
    } else {
        T.expect(false, "new fields round-trip")
    }
}
