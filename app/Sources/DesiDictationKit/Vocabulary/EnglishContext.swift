import Foundation

/// Keeps Hinglish vocabulary rules that turn an English word into a Hindi
/// spelling ("to → toh", "tab → tabh") out of English sentences. Prime writes
/// the same "to" for both, so "how to fix" became "how toh fix"
/// (PERSONAL_DICTIONARY.md, 2026-11-24 user report).
///
/// The rule is skipped only when the words around it are clearly English;
/// when in doubt it applies, exactly as before.
public enum EnglishContext {
    /// Words looked at on each side, within the same sentence.
    static let window = 2

    /// Common Hindi words. Webster's lists many of them (hum, ye, ho, par,
    /// tum, ka, ko), so they decide before the English list does. Words that
    /// are everyday English too (me, main, hi, do, so, are) are left out.
    static let hindiWords: Set<String> = [
        "hai", "hain", "tha", "thi", "thay", "ho", "hoga", "hogi", "honge", "hua", "hui", "hue",
        "kya", "kyu", "kyun", "kyon", "kyunki", "kyonki", "nahi", "nahin", "nhi", "mat", "bhi",
        "aur", "ya", "ki", "ka", "ke", "ko", "se", "mein", "mai", "ne", "pe", "par", "toh",
        "hum", "tum", "aap", "mujhe", "mujh", "tujhe", "humein", "hame", "hamein", "unhe", "unko",
        "usko", "isko", "inko", "mera", "meri", "mere", "tera", "teri", "tere", "apna", "apni",
        "apne", "uska", "uski", "uske", "iska", "iski", "iske", "unka", "unki", "unke", "ye", "yeh",
        "yah", "vo", "voh", "wo", "woh", "yahan", "wahan", "vahan", "kahan", "kaha", "jahan", "kab",
        "jab", "ab", "abhi", "kabhi", "sabhi", "phir", "fir", "sab", "kuch", "kuchh", "koi", "kisi",
        "kaun", "kaise", "kaisa", "kitna", "kitne", "bahut", "bohot", "bahot", "accha", "acha",
        "achha", "theek", "thik", "haan", "na", "lekin", "magar", "agar", "matlab", "wala", "wali",
        "wale", "waala", "waali", "waale", "vala", "vali", "vale", "chahiye", "chahie", "sakta",
        "sakti", "sakte", "raha", "rahi", "rahe", "gaya", "gayi", "gaye", "diya", "liya", "liye",
        "kar", "karo", "karna", "karne", "karke", "karta", "karti", "karte", "kiya", "kiye", "hona",
        "hone", "hota", "hoti", "hote", "jao", "jana", "jaana", "aao", "aana", "aaya", "aayi",
        "bata", "batao", "batana", "bolo", "bola", "dekh", "dekho", "dekha", "dena", "lena", "yaar",
        "bhai", "arre", "arey", "bas", "bilkul", "zaroor", "sirf", "jo", "isliye", "waise", "vaise",
        "aise", "kaafi", "thoda", "thodi", "zyada", "jyada", "pehle", "baad", "kaam", "baat",
        "samajh", "pata", "maine", "usne", "humne", "aapne", "saath", "upar", "andar", "bahar",
        "mujhse", "tumse", "aapse", "unse", "isse", "usse",
    ]

    /// Everyday English Webster's base-form list lacks ("has adapted to my"
    /// read as Hindi), plus contractions written without the apostrophe.
    static let englishWords: Set<String> = [
        "has", "having", "gets", "lets", "okay", "ok", "thats", "dont", "doesnt", "didnt", "isnt",
        "wasnt", "cant", "wont", "im", "ive", "youre", "theyre", "whats",
    ]

    /// Whether `entry` needs the check: a one-word Hinglish rule from an
    /// English word to a Hindi spelling. "view → review" (English to English)
    /// and "nahin → nahi" (not English) always apply, as before.
    public static func isGuarded(_ entry: DictionaryEntry, lexicon: WordLexicon) -> Bool {
        guard entry.scope == .hinglish else { return false }
        let heard = entry.heard.lowercased(), written = entry.written.lowercased()
        guard heard.allSatisfy(\.isLetter), written.allSatisfy(\.isLetter),
              lexicon.isRealWord(heard) else { return false }
        return hindiWords.contains(written) || !lexicon.isRealWord(written)
    }

    /// True when the words around `range` are English and none is Hindi.
    /// Names and numbers count for neither; nothing around means apply.
    public static func surrounds(_ range: Range<String.Index>, in text: String, lexicon: WordLexicon) -> Bool {
        let before = sentence(text[..<range.lowerBound], fromEnd: true).suffix(window)
        let after = sentence(text[range.upperBound...], fromEnd: false).prefix(window)
        var english = 0
        for word in before + after {
            let lower = word.lowercased()
            if hindiWords.contains(lower) { return false }
            if englishWords.contains(lower) || lexicon.isRealWord(lower) {
                english += 1
            } else if word.first?.isLowercase == true {
                return false   // a lowercase word that isn't English: Hindi
            }
        }
        return english > 0
    }

    /// The words of the part of `text` in the same sentence as the match.
    /// "don't" → "don", "I'll" → "I".
    private static func sentence(_ text: Substring, fromEnd: Bool) -> [Substring] {
        let stops: Set<Character> = [".", "!", "?", "\n", "।"]
        let part: Substring
        if fromEnd {
            part = text.lastIndex(where: stops.contains).map { text[text.index(after: $0)...] } ?? text
        } else {
            part = text.firstIndex(where: stops.contains).map { text[..<$0] } ?? text
        }
        return part.split { !$0.isLetter && $0 != "'" && $0 != "’" }
            .compactMap { $0.split(whereSeparator: { $0 == "'" || $0 == "’" }).first }
    }
}
