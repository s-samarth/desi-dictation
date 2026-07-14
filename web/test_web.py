#!/usr/bin/env python3
"""Web-demo unit tests (no server needed): the Python HindiNumbers port must
behave exactly like the Swift original, and the ported prompts must keep the
load-bearing lines. Run: python3 web/test_web.py  (exit 0 = green; CI runs it).
"""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import prompts
from hindi_numbers import indian_grouped, normalize

FAILURES = 0


def expect(actual, wanted, name):
    global FAILURES
    if actual == wanted:
        print(f"  ok {name}")
    else:
        FAILURES += 1
        print(f"  FAIL {name}: got {actual!r}, want {wanted!r}")


# Mirrors app/Sources/DesiTests/NumberTests.swift — keep the two in lockstep.
expect(normalize("maine do lakh pachaas hazaar ka order diya"),
       "maine 2,50,000 ka order diya", "do lakh pachaas hazaar")
expect(normalize("assi hazaar ka loss hua"), "80,000 ka loss hua", "assi hazaar")
expect(normalize("dedh lakh advance de diya"), "1,50,000 advance de diya", "dedh lakh")
expect(normalize("paanch sau log aaye"), "500 log aaye", "paanch sau")
expect(normalize("do hazaar chaar sau bees rupaye"), "2,420 rupaye", "compound")
expect(normalize("Assi hazaar, phir se!"), "80,000, phir se!", "punctuation+casing")
expect(normalize("paanch minute late ho jaunga"),
       "paanch minute late ho jaunga", "no scale word untouched")
expect(normalize("mere saath hazaar log the"),
       "mere saath hazaar log the", "possessive saath guard")
expect(normalize("lakh koshish kar lo"), "lakh koshish kar lo", "bare scale idiom")
expect(normalize(""), "", "empty")
expect(indian_grouped(12_500_000), "1,25,00,000", "crore grouping")

# Prompt sentinels: the hard-won lines from the 2026-07-10 model matrix.
# If someone tunes the Swift prompt, these greps force the port to follow.
for sentinel in ('"die/diye" = gave', '"parso" = the day after tomorrow',
                 "copied exactly as digits"):
    expect(sentinel in prompts.TRANSLATE_EN, True, f"EN prompt keeps: {sentinel[:30]}…")
expect("Devanagari" in prompts.TRANSLATE_HI, True, "HI prompt keeps Devanagari rule")
expect("NEVER invent" in prompts.STRUCTURE_NOTES, True, "structure keeps no-invention")

print(f"\n{'ALL GREEN' if not FAILURES else str(FAILURES) + ' FAILURES'}")
sys.exit(1 if FAILURES else 0)
