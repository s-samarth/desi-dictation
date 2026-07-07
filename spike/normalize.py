"""Hinglish text normalization for fair WER scoring.

Hinglish has no canonical romanization ("nahi"/"nahin"/"nai" are the same word),
so raw WER over-penalizes models. We normalize common spelling variants to a
single form before scoring. Extend VARIANTS as you find more in your eval set.
"""

from __future__ import annotations

import re

# variant -> canonical (lowercase). Applied token-wise after punctuation strip.
VARIANTS: dict[str, str] = {
    "nahin": "nahi", "nahii": "nahi", "nai": "nahi", "nhi": "nahi",
    "kyaa": "kya", "kyu": "kyun", "kyon": "kyun",
    "hain": "hai", "hei": "hai", "he": "hai",
    "mein": "me", "meinn": "me", "mai": "me",
    "aap": "ap", "aapko": "apko",
    "thaa": "tha", "thii": "thi", "thee": "the",
    "raha": "rha", "rahaa": "rha", "rahi": "rhi", "rahe": "rhe",
    "karna": "krna", "karo": "kro", "karke": "krke",
    "achha": "acha", "accha": "acha", "achchha": "acha",
    "bohot": "bahut", "bahot": "bahut", "bhut": "bahut",
    "pe": "par", "pr": "par",
    "hoga": "hoga", "hogaa": "hoga",
}

_PUNCT = re.compile(r"[^\w\s]", re.UNICODE)
_SPACES = re.compile(r"\s+")


def normalize(text: str) -> str:
    """Lowercase, strip punctuation, collapse spaces, map spelling variants."""
    text = text.lower()
    text = _PUNCT.sub(" ", text)
    tokens = [_map_token(t) for t in _SPACES.split(text) if t]
    return " ".join(tokens)


def _map_token(token: str) -> str:
    return VARIANTS.get(token, token)
