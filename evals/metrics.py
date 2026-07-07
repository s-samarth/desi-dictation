"""Metrics for Indic/code-mixed ASR evaluation.

Why four metrics (see README for the full rationale):
- WER: the standard — but it PUNISHES valid Hinglish spelling variants.
- CER: robust for Devanagari conjuncts / agglutination.
- nWER: WER after basic normalization (case/punct) — removes formatting noise.
- crWER (collapsed-roman WER): both texts mapped to one collapsed Roman form
  (Devanagari transliterated, long vowels collapsed, known variants unified) —
  the fairest single number for code-mixed output, and the only way to compare
  a Roman-Hinglish model against a Devanagari reference.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import jiwer
from indic_transliteration import sanscript

sys.path.insert(0, str(Path(__file__).parent.parent / "spike"))
from normalize import VARIANTS  # spike's Hinglish spelling-variant map

_PUNCT = re.compile(r"[^\w\sऀ-ॿ]", re.UNICODE)
_SPACES = re.compile(r"\s+")
_DEVANAGARI = re.compile(r"[ऀ-ॿ]")
_LONG_VOWELS = [("aa", "a"), ("ee", "i"), ("ii", "i"), ("oo", "u"), ("uu", "u")]


def basic_normalize(text: str) -> str:
    """Lowercase, strip punctuation (keeping Devanagari), collapse spaces."""
    text = text.lower()
    text = _PUNCT.sub(" ", text)
    return _SPACES.sub(" ", text).strip()


def collapse_roman(text: str) -> str:
    """Map text (any script mix) to one collapsed Roman form for crWER.

    1. Devanagari spans -> ITRANS romanization
    2. basic normalization
    3. long-vowel collapse (kyaa == kya), drop ITRANS artifacts
    4. spike VARIANTS map (nahin == nahi ...)
    """
    if _DEVANAGARI.search(text):
        text = sanscript.transliterate(text, sanscript.DEVANAGARI, sanscript.ITRANS)
    text = basic_normalize(text)
    text = text.replace("~", "").replace("^", "").replace(".", "")
    for long, short in _LONG_VOWELS:
        text = text.replace(long, short)
    tokens = [VARIANTS.get(t, t) for t in text.split()]
    return " ".join(tokens)


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
