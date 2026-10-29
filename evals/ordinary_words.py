"""Python twin of OrdinaryWords.swift, for review_strictness.py: is a word an
everyday word (macOS word list + the app's CommonWords, endings stripped)?"""

from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUFFIXES = [("ies", "y"), ("ied", "y"), ("es", ""), ("s", ""), ("ed", ""), ("ed", "e"), ("d", ""),
            ("ing", ""), ("ing", "e"), ("ers", ""), ("er", ""), ("er", "e"), ("ly", ""), ("ness", ""), ("ment", "")]


@lru_cache(maxsize=1)
def vocabulary() -> set[str]:
    words = {w for w in Path("/usr/share/dict/words").read_text().split() if w[:1].islower()}
    swift = (ROOT / "app/Sources/DesiDictationKit/Vocabulary/CommonWords.swift").read_text()
    for block in re.findall(r'"""(.*?)"""', swift, re.S):
        words |= {w.lower() for w in block.split()}
    return words


def forms(w: str) -> list[str]:
    out = [w]
    bare = w[:-2] if w.endswith("'s") else w
    out.append(bare)
    for suffix, replacement in SUFFIXES:
        if bare.endswith(suffix) and len(bare) > len(suffix) + 2:
            stem = bare[: -len(suffix)]
            out.append(stem + replacement)
            if not replacement and len(stem) > 1 and stem[-1] == stem[-2]:
                out.append(stem[:-1])
    return out


def is_ordinary(word: str) -> bool:
    w = re.sub(r"[^\w']", "", word).lower()
    if not w or not all(c.isascii() and (c.isalpha() or c == "'") for c in w):
        return False
    return any(f in vocabulary() for f in forms(w))
