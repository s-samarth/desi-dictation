import Foundation

/// Deterministic spoken-Hindi number normalization (IDEAS #7, promoted after
/// the 2026-07-10 model matrix): EVERY candidate LLM ≤4B mangled lakh-figures
/// ("assi hazaar" → 60k/10k/100k), but every one of them translated the same
/// sentences correctly once digits were substituted. So digits are substituted
/// BEFORE the LLM ever sees the text — rules, not model size, fix numbers.
///
/// Scope (deliberately narrow to avoid false positives):
/// - Only sequences that START with a number word and CONTAIN a scale word
///   (sau/hazaar/lakh/crore) are converted: "do lakh pachaas hazaar" →
///   "2,50,000" (Indian grouping); "paanch minute", "teen features", bare
///   "lakh koshish" stay untouched.
/// - "saath" (60, but also "with") is ignored right after possessives
///   (ke/mere/uske…) so "mere saath hazaar log" survives.
public enum HindiNumbers {

    // Common Roman spellings; lowercase. Units/teens/tens 1–99 + fractions.
    private static let units: [String: Double] = [
        "ek": 1, "do": 2, "teen": 3, "tin": 3, "chaar": 4, "char": 4,
        "paanch": 5, "panch": 5, "chhe": 6, "che": 6, "cheh": 6, "chah": 6,
        "saat": 7, "aath": 8, "ath": 8, "nau": 9, "das": 10, "dus": 10,
        "gyarah": 11, "gyaarah": 11, "barah": 12, "baarah": 12, "terah": 13,
        "chaudah": 14, "pandrah": 15, "solah": 16, "satrah": 17,
        "atharah": 18, "attharah": 18, "unnis": 19,
        "bees": 20, "bis": 20, "ikkis": 21, "bais": 22, "baais": 22,
        "teis": 23, "chaubis": 24, "pachchis": 25, "pachees": 25, "pacchis": 25,
        "chhabbis": 26, "sattais": 27, "atthais": 28, "athais": 28, "untis": 29,
        "tees": 30, "tis": 30, "battis": 32, "paintis": 35, "pentis": 35,
        "chhattis": 36, "chalis": 40, "chaalis": 40, "paintalis": 45,
        "pentalis": 45, "unchas": 49, "pachaas": 50, "pachas": 50,
        "ikyavan": 51, "bavan": 52, "pachpan": 55, "chhappan": 56,
        "chappan": 56, "unsath": 59, "saath": 60, "sath": 60,
        "chausath": 64, "painsath": 65, "sattar": 70, "bahattar": 72,
        "pachhattar": 75, "pachattar": 75, "athattar": 78,
        "assi": 80, "asi": 80, "ikyasi": 81, "bayasi": 82, "chaurasi": 84,
        "pachasi": 85, "nabbe": 90, "nabe": 90, "pachanve": 95,
        "ninyanve": 99, "ninanve": 99,
        "dedh": 1.5, "dhai": 2.5, "dhaai": 2.5, "sava": 1.25, "sawa": 1.25,
    ]
    private static let scales: [String: Double] = [
        "sau": 100, "hazaar": 1_000, "hazar": 1_000, "hajaar": 1_000,
        "hajar": 1_000, "lakh": 100_000, "laakh": 100_000, "lakhs": 100_000,
        "crore": 10_000_000, "crores": 10_000_000, "karod": 10_000_000,
    ]
    /// "X saath" where X is a possessive means "with", never 60.
    private static let possessives: Set<String> = [
        "ke", "mere", "tere", "uske", "iske", "aapke", "hamare", "humare",
        "tumhare", "unke", "inke", "sabke", "kiske",
    ]

    public static func normalize(_ text: String) -> String {
        let tokens = text.components(separatedBy: " ")
        var out: [String] = []
        var i = 0
        while i < tokens.count {
            // A candidate sequence starts on a UNIT word (never a bare scale).
            let (word, _, _) = split(tokens[i])
            let prev = out.last.map { split($0).core } ?? ""
            if unitValue(word, after: prev) != nil {
                var j = i
                var sawScale = false
                var last = prev
                // Extend while tokens are number words; stop at clean breaks.
                while j < tokens.count {
                    let (core, _, trailing) = split(tokens[j])
                    let isUnit = unitValue(core, after: last) != nil
                    let isScale = scales[core] != nil
                    guard isUnit || isScale else { break }
                    if isScale { sawScale = true }
                    last = core
                    j += 1
                    if !trailing.isEmpty { break }   // punctuation ends the number
                }
                if sawScale, let value = compute(tokens[i..<j]) {
                    let (_, lead, _) = split(tokens[i])
                    let (_, _, trail) = split(tokens[j - 1])
                    out.append(lead + indianGrouped(value) + trail)
                    i = j
                    continue
                }
            }
            out.append(tokens[i])
            i += 1
        }
        return out.joined(separator: " ")
    }

    private static func unitValue(_ word: String, after prev: String) -> Double? {
        if (word == "saath" || word == "sath"), possessives.contains(prev) { return nil }
        return units[word]
    }

    /// Standard Indian composition: units accumulate, sau multiplies the
    /// accumulator, big scales flush it into the total.
    private static func compute(_ tokens: ArraySlice<String>) -> Int? {
        var total = 0.0, current = 0.0
        for token in tokens {
            let word = split(token).core
            if let v = units[word] {
                current += v
            } else if word == "sau" {
                current = (current == 0 ? 1 : current) * 100
            } else if let scale = scales[word] {
                total += (current == 0 ? 1 : current) * scale
                current = 0
            }
        }
        let value = total + current
        guard value >= 100, value == value.rounded() else { return nil }
        return Int(value)
    }

    /// 250000 → "2,50,000" (lakh/crore grouping, not Western thousands).
    public static func indianGrouped(_ value: Int) -> String {
        let digits = String(value)
        guard digits.count > 3 else { return digits }
        let last3 = String(digits.suffix(3))
        var head = String(digits.dropLast(3))
        var groups: [String] = []
        while head.count > 2 {
            groups.insert(String(head.suffix(2)), at: 0)
            head = String(head.dropLast(2))
        }
        if !head.isEmpty { groups.insert(head, at: 0) }
        return (groups + [last3]).joined(separator: ",")
    }

    /// token → (core word lowercased, leading punctuation, trailing punctuation)
    private static func split(_ token: String) -> (core: String, lead: String, trail: String) {
        let lead = String(token.prefix { !$0.isLetter })
        let rest = String(token.dropFirst(lead.count))
        let trail = String(rest.reversed().prefix { !$0.isLetter }.reversed())
        let core = String(rest.dropLast(trail.count)).lowercased()
        return (core, lead, trail)
    }
}
