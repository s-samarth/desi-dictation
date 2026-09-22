"""Metrics for Indic/code-mixed ASR evaluation.

Why four metrics (see README / METRICS.md for the full rationale):
- WER: the standard — but it PUNISHES valid Hinglish spelling variants.
- CER: robust for Devanagari conjuncts / agglutination.
- nWER: WER after case/punctuation normalization and spoken↔written numbers
  ("rupees four hundred" == "Rs. 400") — removes formatting noise only.
- crWER (collapsed-roman WER): both texts mapped to one collapsed Roman form
  (Devanagari romanized the way Hinglish is written, long vowels collapsed,
  known variants unified) — the fairest single number for code-mixed output,
  and the only way to compare a Roman-Hinglish model against a Devanagari
  reference.

Every rule runs identically on reference and hypothesis.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import jiwer

from devanagari import romanize
from numbers_en import prepare, to_digits

sys.path.insert(0, str(Path(__file__).parent.parent / "spike"))
from normalize import VARIANTS  # spike's Hinglish spelling-variant map

# Bump when a normalization change moves scores; reports record it and
# aggregate.py never trends numbers across versions (v1 = ITRANS, pre-2026-09-23).
VERSION = 2

_PUNCT = re.compile(r"[^\w\sऀ-ॿ]", re.UNICODE)
# Roman writes a y-glide in vowel hiatus that Devanagari doesn't: लिए "liye",
# गई "gayi", कोई "koyi". Dropped before e/i after a/i/u/o only — "eyes" must
# not become "ees" -> "is".
_GLIDE = re.compile(r"(?<=[aiuo])y(?=[ei])")
_LONG_VOWELS = [("chh", "ch"), ("aa", "a"), ("ee", "i"), ("ii", "i"), ("oo", "u"), ("uu", "u")]

# Roman Hinglish writes word-final nasalization ("yahan", "hun", "logon",
# "hamein"); romanized Devanagari drops it (devanagari.py), as VARIANTS
# already does for hain/mein/nahin. Function words by list; the plural
# oblique "-on" and "-ein" by suffix (5+ letters, so English "on"/"in" and
# short words are untouched; English "-on" words only lose a letter both sides).
NASAL_FINAL = {
    "han": "ha", "hun": "hu", "main": "mai", "yahan": "yaha", "vahan": "vaha",
    "wahan": "waha", "kahan": "kaha", "jahan": "jaha", "kahin": "kahi",
    "yahin": "yahi", "vahin": "vahi", "wahin": "wahi", "kyo": "kyun",
    "hamen": "hame", "tumhen": "tumhe", "unhen": "unhe", "inhen": "inhe",
    "jinhen": "jinhe",
}


def basic_normalize(text: str) -> str:
    """Lowercase, numbers to digits, strip punctuation (keeping Devanagari)."""
    text = _PUNCT.sub(" ", prepare(text.lower()))
    return " ".join(to_digits(text.split()))


def _nasal_final(token: str) -> str:
    token = NASAL_FINAL.get(token, token)
    if len(token) >= 5 and token.endswith("ein"):
        return token[:-2]
    if len(token) >= 5 and token.endswith("on"):
        return token[:-1]
    return token


def collapse_roman(text: str) -> str:
    """Map text (any script mix) to one collapsed Roman form for crWER.

    1. Devanagari words -> Hinglish-style Roman (schwa deletion, nasals)
    2. basic normalization (case, punctuation, numbers)
    3. y-glide (liye == lie), chh -> ch, long-vowel collapse (kyaa == kya)
    4. word-final nasal (logon == logo), then spike VARIANTS (nahin == nahi)
    """
    text = _GLIDE.sub("", basic_normalize(romanize(text)))
    for long, short in _LONG_VOWELS:
        text = text.replace(long, short)
    return " ".join(VARIANTS.get(t, t) for t in map(_nasal_final, text.split()))


def score(refs: list[str], hyps: list[str]) -> dict[str, float]:
    """All four metrics over parallel reference/hypothesis lists."""
    n_refs = [basic_normalize(r) for r in refs]
    n_hyps = [basic_normalize(h) for h in hyps]
    c_refs = [collapse_roman(r) for r in refs]
    c_hyps = [collapse_roman(h) for h in hyps]
    return {
        "wer": round(jiwer.wer(refs, hyps), 4),
        "cer": round(jiwer.cer(refs, hyps), 4),
        "nwer": round(jiwer.wer(n_refs, n_hyps), 4),
        "crwer": round(jiwer.wer(c_refs, c_hyps), 4),
    }
