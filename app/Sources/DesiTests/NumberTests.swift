import Foundation
import DesiDictationKit

/// HindiNumbers: the deterministic prepass that fixes the number-error class
/// every candidate LLM failed (2026-07-10 matrix). Conversions must be
/// conservative — a false positive corrupts a dictation.
func runNumberTests() {
    T.begin("HindiNumbers — conversions")
    let n = HindiNumbers.normalize
    T.equal(n("maine do lakh pachaas hazaar ka order diya"),
            "maine 2,50,000 ka order diya", "do lakh pachaas hazaar")
    T.equal(n("assi hazaar ka loss hua"), "80,000 ka loss hua", "assi hazaar")
    T.equal(n("teen lakh ka profit"), "3,00,000 ka profit", "teen lakh")
    T.equal(n("dedh lakh advance de diya"), "1,50,000 advance de diya", "dedh lakh (1.5)")
    T.equal(n("paanch sau log aaye"), "500 log aaye", "paanch sau")
    T.equal(n("sava crore ka ghar"), "1,25,00,000 ka ghar", "sava crore")
    T.equal(n("do hazaar chaar sau bees rupaye"), "2,420 rupaye", "compound with tens")
    T.equal(n("Assi hazaar, phir se!"), "80,000, phir se!", "punctuation + casing")

    T.begin("HindiNumbers — must NOT convert (false-positive guards)")
    T.equal(n("paanch minute late ho jaunga"), "paanch minute late ho jaunga",
            "no scale word → untouched")
    T.equal(n("teen features nahi ho payenge"), "teen features nahi ho payenge",
            "counts stay words")
    T.equal(n("do naye clients aaye hain"), "do naye clients aaye hain", "bare do")
    T.equal(n("mere saath hazaar log the"), "mere saath hazaar log the",
            "possessive + saath = 'with', not 60")
    T.equal(n("lakh koshish kar lo"), "lakh koshish kar lo",
            "bare scale word (idiom) untouched")
    T.equal(n("aadha maal aaya hai"), "aadha maal aaya hai", "aadha excluded by design")
    T.equal(n(""), "", "empty")

    T.begin("HindiNumbers — Indian digit grouping")
    T.equal(HindiNumbers.indianGrouped(250_000), "2,50,000", "lakh grouping")
    T.equal(HindiNumbers.indianGrouped(80_000), "80,000", "thousands")
    T.equal(HindiNumbers.indianGrouped(12_500_000), "1,25,00,000", "crore grouping")
    T.equal(HindiNumbers.indianGrouped(500), "500", "no grouping under 1000")
}
