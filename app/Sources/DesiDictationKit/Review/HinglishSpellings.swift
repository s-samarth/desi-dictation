import Foundation

/// Everyday Hinglish words that people write several ways (HINGLISH_LEARNING.md).
/// None of these spellings is wrong, and each person sticks to one, so in
/// Learning mode the panel asks which is yours, once per word.
///
/// Only safe groups: a spelling that is also an English word ("or", "to",
/// "me", "bad", "thick") or a different Hindi word ("kam" less / "kaam" work,
/// "kaha" said / "kahan" where, "main" I / "mein" in) is left out, so
/// settling a group can never turn one word into another.
public enum HinglishSpellings {
    static let groups: [[String]] = [
        ["chahiye", "chahie", "chaahiye", "chaahie"],
        ["wala", "waala", "vala", "vaala"],
        ["wale", "waale", "vale", "vaale"],
        ["wali", "waali", "vali", "vaali"],
        ["walon", "waalon", "valon", "vaalon", "walo", "waalo"],
        ["kyunki", "kyonki", "kyuki", "kyoki", "kyunke"],
        ["kyun", "kyu", "kyon", "kyoon"],
        ["nahi", "nahin", "nhi", "nai"],
        ["accha", "acha", "achha", "achcha"],
        ["theek", "thik", "theekh"],
        ["bahut", "bohot", "bahot", "bht"],
        ["kuch", "kuchh", "kucch"],
        ["phir", "fir"],
        ["woh", "wo", "voh", "vo"],
        ["yeh", "ye", "yah"],
        ["waise", "vaise"],
        ["jaise", "jese"],
        ["kaise", "kese"],
        ["aise", "ese"],
        ["kaun", "kon"],
        ["yaar", "yar"],
        ["haan", "haa"],
        ["abhi", "abi"],
        ["matlab", "matlb"],
        ["samajh", "samaj", "samjh"],
        ["karna", "krna"],
        ["karo", "kro"],
        ["raha", "rha"],
        ["rahi", "rhi"],
        ["rahe", "rhe"],
        ["sakta", "skta"],
        ["bilkul", "bilkool"],
        ["zaroor", "jaroor", "zarur", "jarur"],
        ["zyada", "jyada", "zyaada", "jyaada"],
        ["thoda", "thora"],
        ["thodi", "thori"],
        ["pata", "pta"],
        ["mujhe", "mujhey", "muje"],
        ["humein", "hume", "hamein", "hame"],
        ["tumhe", "tumhein"],
        ["yahan", "yahaan"],
        ["wahan", "wahaan", "vahan", "vahaan"],
        ["pehle", "pahle", "pehele"],
        ["dobara", "dubara"],
        ["shayad", "shaayad"],
        ["zindagi", "jindagi"],
        ["ladki", "larki"],
        ["ladka", "larka"],
    ]

    /// Lowercased spelling → its group.
    private static let index: [String: Int] = {
        var out: [String: Int] = [:]
        for (i, group) in groups.enumerated() {
            for spelling in group { out[spelling] = i }
        }
        return out
    }()

    /// The word's group, or nil when it isn't one of these words.
    public static func group(of word: String) -> [String]? {
        index[word.lowercased()].map { groups[$0] }
    }

    /// A stable name for the group (its first spelling), used as the key
    /// for the user's chosen spelling.
    public static func head(of word: String) -> String? {
        group(of: word)?.first
    }

    /// Whether two spellings are the same word.
    public static func sameWord(_ a: String, _ b: String) -> Bool {
        guard let x = index[a.lowercased()], let y = index[b.lowercased()] else { return false }
        return x == y
    }

    /// `spelling` with `original`'s capitalization: "Chahiye" stays capital.
    static func cased(_ spelling: String, like original: String) -> String {
        guard let first = original.first, first.isUppercase else { return spelling }
        return spelling.prefix(1).uppercased() + spelling.dropFirst()
    }
}
