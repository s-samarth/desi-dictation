import Foundation
import DesiDictationKit

/// Personal dictionary (P4-S1): boundary awareness, casing, persistence.
func runDictionaryTests() {
    T.begin("PersonalDictionary — apply")
    let entries = [
        DictionaryEntry(heard: "Saraswath", written: "Saraswat"),
        DictionaryEntry(heard: "meating", written: "meeting"),
        DictionaryEntry(heard: "gpt", written: "GPT"),
    ]
    T.equal(PersonalDictionary.apply("kal meating hai", entries: entries),
            "kal meeting hai", "basic replacement")
    T.equal(PersonalDictionary.apply("Meating at 5", entries: entries),
            "Meeting at 5", "sentence-start capitalization preserved")
    T.equal(PersonalDictionary.apply("MEATING NOW", entries: entries),
            "MEETING NOW", "all-caps preserved")
    T.equal(PersonalDictionary.apply("we are defeating them", entries: entries),
            "we are defeating them", "word boundary — no mid-word corruption")
    T.equal(PersonalDictionary.apply("samarth saraswath ji", entries: entries),
            "samarth Saraswat ji", "dictionary casing wins over lowercase match")
    T.equal(PersonalDictionary.apply("chat gpt aur gpt-4", entries: entries),
            "chat GPT aur GPT-4", "expansion to uppercase + hyphen boundary")
    T.equal(PersonalDictionary.apply("", entries: entries), "", "empty text")
    T.equal(PersonalDictionary.apply("kuch bhi", entries: []), "kuch bhi", "no entries")

    T.begin("PersonalDictionary — editing & persistence")
    let dictURL = T.tempFile("dict.json")
    let store = PersonalDictionary(fileURL: dictURL)
    store.add(heard: "  jira  ", written: " Jira ")
    T.equal(store.entries.count, 1, "trimmed add — case-fix rules are legitimate")
    T.equal(store.entries.first?.written, "Jira", "trim applied to written form")
    store.add(heard: "JIRA", written: "Jira Cloud")
    T.equal(store.entries.count, 1, "same heard-form replaces (latest wins)")
    T.equal(store.entries.first?.written, "Jira Cloud", "latest correction wins")
    store.add(heard: "word", written: "word")
    T.equal(store.entries.count, 1, "exact self-mapping rejected")
    store.add(heard: "", written: "x")
    T.equal(store.entries.count, 1, "empty heard rejected")

    let reloaded = PersonalDictionary(fileURL: dictURL)
    T.equal(reloaded.entries, store.entries, "persistence round-trip")

    T.begin("Legacy replacements still work (regression)")
    T.equal(PostProcessor.applyReplacements("desi dicta test", rules: "dicta=Dictation"),
            "desi Dictation test", "legacy find=replace")
    T.equal(PostProcessor.applyReplacements("a=b ignored", rules: "no-equals-line"),
            "a=b ignored", "malformed rule ignored")
}
