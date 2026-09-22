"""Checks for the crWER / nWER normalizers. Run: uv run test_metrics.py

Each case is (reference, hypothesis): SAME pairs must score 0 errors,
DIFFERENT pairs must still count as errors (the rules stay conservative).
"""

from __future__ import annotations

import jiwer

from devanagari import romanize
from metrics import basic_normalize, collapse_roman

ROMANIZE = [  # Devanagari -> what a Hinglish writer types
    ("में", "me"), ("वजह", "vajah"), ("एक", "ek"), ("नहीं", "nahi"),
    ("हालाँकि", "halanki"), ("निकलने", "nikalne"), ("समझता", "samajhta"),
    ("बदलता", "badalta"), ("करना", "karna"), ("मित्र", "mitra"), ("न", "na"),
    ("संभव", "sambhav"), ("पाँच", "panch"), ("मैंने", "maine"), ("ज्ञान", "gyan"),
    ("ख़ज़ाने", "khazane"), ("लड़का", "ladka"), ("लखनऊ", "lakhnau"), ("और", "aur"),
]

# The brief's example, verbatim: Apex writes "niklane" for निकलने (said
# "nikalne"), so 1 of 11 words stays an error — that one is a real misspelling.
BRIEF = ("Television reports में plant से निकलने वाला white smoke दिखाया गया है।",
         "Television reports mein plant se niklane vaala white smoke dikhaaya gaya hai.")

SAME_CR = [
    (BRIEF[0], BRIEF[1].replace("niklane", "nikalne")),
    ("हालाँकि इसकी वजह एक है", "halanki iski vajah ek hai"),
    ("मैं यहाँ हूँ, लोगों की बातें सुनता हूँ", "main yahan hoon, logon ki baatein sunta hun"),
    ("उसने पाँच मैचों की हार की streak को खत्म कर दिया",
     "usne paanch maichon ki haar ki streak ko khatm kar diya"),
    ("अच्छा, छोटा सा काम", "achchha, chhota sa kaam"),
    ("इसने हमें train, car दिए हैं", "isne hamein train car diye hain"),   # METRICS.md
    ("उसके लिए गई कोई", "uske liye gayi koyi"),
]
DIFFERENT_CR = [  # causatives, plurals-vs-singular stems, gemination: all real words
    ("मिलना", "milana"), ("पता", "patta"), ("कमरा", "kamar"), ("then", "the"),
    ("taken", "take"), ("west", "vest"), ("eyes", "is"),
]

SAME_N = [
    ("Can you transfer Rs. 400 to my 6844663153262",
     "can you transfer rupees four hundred to my "
     "six eight four four six six three one five three two six two"),
    ("So 15,000 people", "So fifteen thousand people"),
    ("1999", "Nineteen. Ninety nine."),
    ("Who won the 2016 Grand Prix?", "Who won the two thousand sixteen Grand Prix?"),
    ("martyred in the 2nd century", "martyred in the second century"),
    ("of the 20th century", "of the twentieth century"),
    ("In the 70s when I was young", "In the seventies when I was young"),
    ("lag behind by 25 to 30 years", "lag behind by 25-30 years"),
    ("the format is 35mm", "the format is 35 mm"),
    ("add 2 kgs and 1 pack", "add two kgs and one pack"),
    ("₹4,00,000 is 400000 rupees", "four lakh rupees is 4,00,000 rupees"),
    ("call 9988776655", "call double nine double eight seven seven six six five five"),
    ("one hundred and five", "105"), ("twenty first", "21st"),
    ("3.5 percent", "three point five %"),
]
DIFFERENT_N = [
    ("23", "two three"), ("eleven thirty", "1130"), ("1, 2", "12"),
    ("nineteen five", "1905"), ("fourth", "forth"),
]


def errors(ref: str, hyp: str) -> int:
    out = jiwer.process_words(ref, hyp)
    return out.substitutions + out.deletions + out.insertions


def check(cases, norm, want_zero: bool) -> int:
    failed = 0
    for ref, hyp in cases:
        r, h = norm(ref), norm(hyp)
        if (r == h) != want_zero:
            failed += 1
            print(f"FAIL {'same' if want_zero else 'different'}: {r!r} vs {h!r}")
    return failed


def main() -> None:
    failed = sum(romanize(dev) != want and not print(f"FAIL romanize {dev} -> {romanize(dev)}")
                 for dev, want in ROMANIZE)
    failed += check(SAME_CR, collapse_roman, True) + check(DIFFERENT_CR, collapse_roman, False)
    failed += check(SAME_N, basic_normalize, True) + check(DIFFERENT_N, basic_normalize, False)
    brief = errors(collapse_roman(BRIEF[0]), collapse_roman(BRIEF[1]))
    print(f"brief example: {brief} crWER error(s) of 11 words (was 2: mem, nikalane)")
    failed += brief != 1
    total = len(ROMANIZE) + len(SAME_CR) + len(DIFFERENT_CR) + len(SAME_N) + len(DIFFERENT_N)
    print(f"{total - failed}/{total} passed")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
