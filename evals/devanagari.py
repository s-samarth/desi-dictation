"""Devanagari -> Hinglish-style Roman, for crWER.

Replaces ITRANS, which spells what is *written* (inherent vowel, nasal marks):
में -> "mem", वजह -> "vajaha", एक -> "eka", हालाँकि -> "hala nki". Hinglish
writers spell what is *said* — "me", "vajah", "ek", "halanki" — so a correct
Roman hypothesis used to score as wrong. Here each word is parsed into
aksharas first, where the inherent 'a' (schwa) is still distinguishable from
a written ा, and then:

1. Schwa deletion (Ohala's rule for Hindi): word-final schwa goes (एक -> ek,
   वजह -> vajah) unless the word is one akshara (न -> na) or ends in a
   conjunct with य/र/व (मित्र -> mitra, सत्य -> satya); medially, V C a C V
   -> V C C V, scanned right to left (निकलने -> nikalne, समझता -> samajhta,
   बदलता -> badalta, करना -> karna — ना is a written ā, never deleted).
2. Nasals (ं ँ): before a consonant they become the homorganic nasal — "m"
   before labials (संभव -> sambhav), "n" otherwise (पाँच -> panch), nothing
   before न/म (मैंने -> maine). Word-final they are dropped (में -> me,
   हैं -> hai, नहीं -> nahi): the VARIANTS map already treats hain = hai,
   mein = me, nahin = nahi, so final nasalization was never scored.
3. Hinglish letter choices: long vowels written single (the metric collapses
   them anyway), छ -> ch (Roman "chh" is collapsed to "ch" too), श/ष -> sh,
   ज्ञ -> gy, ऋ -> ri, nukta letters by their Roman use (ज़ -> z, फ़ -> f,
   ड़ -> d), ऑ -> o.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

CONSONANTS = dict(zip(
    "कखगघङचछजझञटठडढणतथदधनपफबभमयरलवशषसहळ",
    "k kh g gh n ch ch j jh n t th d dh n t th d dh n p ph b bh m y r l v sh sh s h l".split(),
    strict=True))
CONSONANTS.update({"ऩ": "n", "ऱ": "r", "ऴ": "l"})   # NFC keeps these composed
NUKTA = {"क": "k", "ख": "kh", "ग": "g", "ज": "z", "ड": "d", "ढ": "dh", "फ": "f",
         "य": "y", "न": "n", "र": "r", "ळ": "l"}
VOWELS = dict(zip("अआइईउऊऋएऐओऔऑऍऎऒ", "a a i i u u ri e ai o au o e e o".split(), strict=True))
MATRAS = dict(zip("ािीुूृेैोौॉॅॆॊ", "a i i u u ri e ai o au o e e o".split(), strict=True))
VIRAMA, NUKTA_SIGN, NASALS, VISARGA = "्", "़", "ंँ", "ः"
LABIALS = {"p", "ph", "b", "bh", "m"}
_RUN = re.compile(r"[ऀ-ॿ]+")
_DIGITS = str.maketrans("०१२३४५६७८९", "0123456789")


@dataclass
class Akshara:
    cons: str = ""        # Roman consonant; "" for an independent vowel
    vowel: str = "a"      # Roman vowel; "a" + schwa=True is the inherent one
    schwa: bool = True
    nasal: bool = False


def _parse(word: str) -> list[Akshara]:
    units: list[Akshara] = []
    prev_ch = ""
    for ch in word:
        last = units[-1] if units else None
        if ch in CONSONANTS:
            units.append(Akshara(CONSONANTS[ch]))
        elif ch == NUKTA_SIGN and last and prev_ch in CONSONANTS:
            last.cons = NUKTA.get(prev_ch, last.cons)
        elif ch in VOWELS:
            units.append(Akshara("", VOWELS[ch], schwa=False))
        elif ch in MATRAS and last and last.cons:
            last.vowel, last.schwa = MATRAS[ch], False
        elif ch == VIRAMA and last and last.cons:
            last.vowel, last.schwa = "", False
        elif ch in NASALS and last:
            last.nasal = True
        elif ch == VISARGA and last:
            last.vowel += "h"
        prev_ch = ch
    return units


def _fix_gy(units: list[Akshara]) -> None:
    """ज्ञ (j + virama + ñ) is said "gy" in Hindi: ज्ञान -> gyan."""
    for a, b in zip(units, units[1:], strict=False):
        if a.cons == "j" and a.vowel == "" and b.cons == "n":
            a.cons, b.cons = "g", "y"


def _delete_schwas(units: list[Akshara]) -> None:
    n = len(units)
    if n < 2:
        return
    last, prev = units[-1], units[-2]
    conjunct_glide = prev.cons and prev.vowel == "" and last.cons in ("y", "r", "v")
    if last.schwa and not last.nasal and not conjunct_glide:
        last.vowel, last.schwa = "", False
    for i in range(n - 2, 0, -1):          # right to left: V C [a] C V
        u, before, after = units[i], units[i - 1], units[i + 1]
        if (u.schwa and not u.nasal and before.vowel
                and after.cons and after.vowel):
            u.vowel, u.schwa = "", False


def _nasal(units: list[Akshara], i: int) -> str:
    nxt = units[i + 1] if i + 1 < len(units) else None
    if not nxt or not nxt.cons or nxt.cons in ("n", "m"):
        return ""                            # word-final / before a vowel / before n, m
    return "m" if nxt.cons in LABIALS else "n"


def romanize_word(word: str) -> str:
    """One Devanagari word (no spaces) -> Roman."""
    units = _parse(word)
    _fix_gy(units)
    _delete_schwas(units)
    return "".join(u.cons + u.vowel + (_nasal(units, i) if u.nasal else "")
                   for i, u in enumerate(units))


def romanize(text: str) -> str:
    """Romanize every Devanagari run in mixed-script text; leave the rest."""
    text = unicodedata.normalize("NFC", text).replace("\u200c", "").replace("\u200d", "")
    text = text.translate(_DIGITS).replace("।", " ").replace("॥", " ")
    return _RUN.sub(lambda m: romanize_word(m.group()), text)
