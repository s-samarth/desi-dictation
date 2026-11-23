import Foundation
import DesiDictationKit

/// Hinglish rules from an English word to a Hindi spelling ("to → toh") stay
/// out of English sentences; every other rule applies as before
/// (PERSONAL_DICTIONARY.md, 2026-11-24).
func runEnglishContextTests() {
    let english = WordLexicon(words: [
        "how", "to", "fix", "want", "say", "spelling", "be", "send", "it", "open", "a", "new",
        "tab", "view", "review", "my", "is", "the", "honest", "word", "and", "meeting", "cancel",
        "i", "go", "please", "this", "know", "hag", "hak", "relay", "message", "adapted", "don", "hum", "ho",
    ])
    let toh = DictionaryEntry(heard: "to", written: "toh", scope: .hinglish)
    let tab = DictionaryEntry(heard: "tab", written: "tabh", scope: .hinglish)
    func apply(_ text: String, _ entries: [DictionaryEntry] = [toh]) -> String {
        PersonalDictionary.apply(text, entries: entries, lexicon: english)
    }

    T.begin("English context — which rules are checked")
    T.expect(EnglishContext.isGuarded(toh, lexicon: english), "to → toh: English word to a Hindi spelling")
    T.expect(!EnglishContext.isGuarded(DictionaryEntry(heard: "view", written: "review", scope: .hinglish),
                                       lexicon: english), "view → review: English to English, always applies")
    T.expect(!EnglishContext.isGuarded(DictionaryEntry(heard: "nahin", written: "nahi", scope: .hinglish),
                                       lexicon: english), "nahin → nahi: not an English word, always applies")
    T.expect(!EnglishContext.isGuarded(DictionaryEntry(heard: "to", written: "toh", scope: .english),
                                       lexicon: english), "English list: unchanged")
    T.expect(!EnglishContext.isGuarded(DictionaryEntry(heard: "miss direct", written: "misdirect",
                                                       scope: .hinglish), lexicon: english), "two words: unchanged")

    T.begin("English context — English sentences keep the English word")
    T.equal(apply("I want to say how to fix it"), "I want to say how to fix it", "the 2026-11-24 report")
    T.equal(apply("To be honest"), "To be honest", "sentence start")
    T.equal(apply("send it to Samarth"), "send it to Samarth", "a name counts for neither")
    T.equal(apply("I don't want to"), "I don't want to", "apostrophes")
    T.equal(apply("open a new tab", [tab]), "open a new tab", "tab → tabh")
    T.equal(apply("it has adapted to my word"), "it has adapted to my word", "English Webster's lacks (has)")

    T.begin("English context — Hindi sentences still get the rule")
    T.equal(apply("mujhe to pata nahi"), "mujhe toh pata nahi", "Hindi words around it")
    T.equal(apply("ye to theek hai"), "ye toh theek hai", "ye and theek")
    T.equal(apply("To kya hua"), "Toh kya hua", "capitals kept")
    T.equal(apply("hum to ho"), "hum toh ho", "Hindi words Webster's also lists")
    T.equal(apply("meeting to cancel kar do"), "meeting toh cancel kar do", "one Hindi word is enough")
    T.equal(apply("to"), "toh", "nothing around it: applies, as before")
    T.equal(apply("tab main aaunga", [tab]), "tabh main aaunga", "aaunga isn't English")
    T.equal(apply("I know. Phir to bolo"), "I know. Phir toh bolo", "only the same sentence counts")
    T.equal(PersonalDictionary.apply("how to fix", entries: [toh]), "how toh fix",
            "no lexicon (desi-cli): the old behaviour")
}
