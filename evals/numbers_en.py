"""English number normalization for nWER / crWER — spoken and written forms
of the same number score as equal ("rupees four hundred" == "Rs. 400").

Applied identically to reference and hypothesis. Every rule maps one spoken
form to one written form, so it never merges different numbers, with two
deliberate edge cases: runs of 3+ single digits join ("six eight four four"
== "6844", an account number read digit by digit — "two three" stays "2 3"),
and "eighteen/nineteen/twenty + 10..99" reads as a year ("nineteen ninety
nine" == 1999; "eleven thirty" stays a time).

Conventions follow the app's number handling (HindiNumbers.swift ->
web/hindi_numbers.py): lakh/crore scales, Indian digit grouping — commas are
dropped either way ("4,00,000" == "400,000" == 400000).
"""

from __future__ import annotations

import re

_SMALL = ("zero one two three four five six seven eight nine ten eleven twelve "
          "thirteen fourteen fifteen sixteen seventeen eighteen nineteen").split()
_TENS_W = "twenty thirty forty fifty sixty seventy eighty ninety".split()
UNITS = {w: i for i, w in enumerate(_SMALL)}
TENS = {w: 20 + 10 * i for i, w in enumerate(_TENS_W)}
SCALES = {"thousand": 10**3, "lakh": 10**5, "lakhs": 10**5, "lac": 10**5,
          "million": 10**6, "crore": 10**7, "crores": 10**7, "billion": 10**9}
ORDINALS = dict(zip(
    ("first second third fourth fifth sixth seventh eighth ninth tenth eleventh "
     "twelfth thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth "
     "nineteenth").split(), range(1, 20), strict=True))
ORDINALS.update({w[:-1] + "ieth": v for w, v in TENS.items()})   # twentieth...
DECADES = {w[:-1] + "ies": f"{v}s" for w, v in TENS.items()}      # seventies -> 70s
CURRENCY = {"rs": "rupees", "inr": "rupees", "rupee": "rupees",
            "dollar": "dollars", "usd": "dollars"}
YEAR_HEADS = {18, 19, 20}


def _grouped(m: re.Match) -> str:
    """Drop commas only in real digit grouping (Indian or Western), not lists."""
    groups = m.group().split(",")
    body = groups[1:-1]
    ok = len(groups[-1]) == 3 and (all(len(g) == 3 for g in body)
                                   or all(len(g) == 2 for g in body))
    return m.group().replace(",", "") if ok else m.group()


def prepare(text: str) -> str:
    """Written-form rules that need punctuation still present (lowercased text)."""
    text = re.sub(r"\b\d{1,3}(?:,\d{2,3})+\b", _grouped, text)
    text = re.sub(r"₹\s*(\d+)", r"\1 rupees", text)
    text = re.sub(r"\$\s*(\d+)", r"\1 dollars", text)
    text = text.replace("%", " percent ")
    text = re.sub(r"\bper cent\b", "percent", text)
    text = re.sub(r"\b(\d{1,4})\s*[-–]\s*(\d{1,4})\b", r"\1 to \2", text)  # 25-30
    text = re.sub(r"(\d)\.(\d)", r"\1 point \2", text)
    text = re.sub(r"\b(\d+)'s\b", r"\1s", text)                            # 70's
    return re.sub(r"\b(\d+)(?!(?:st|nd|rd|th|s)\b)([a-z]+)", r"\1 \2", text)  # 35mm


def _ordinal(v: int) -> str:
    suffix = "th" if 10 <= v % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(v % 10, "th")
    return f"{v}{suffix}"


def _phrase(tokens: list[str], i: int) -> tuple[str, int, int] | None:
    """Longest number phrase at tokens[i] -> (written form, value, next index)."""
    total, cur, last, j, n = 0, 0, None, i, len(tokens)
    while j < n:
        t, nxt = tokens[j], tokens[j + 1] if j + 1 < n else ""
        opens = last in (None, "hundred", "scale")
        if t == "a" and last is None and nxt in ("hundred", *SCALES):
            cur, last = 1, "unit"
        elif t.isdigit() and last is None and nxt in ("hundred", *SCALES):
            cur, last = int(t), "unit"                        # "15 thousand"
        elif t == "and" and last in ("hundred", "scale") and nxt != "zero" and (
                nxt in UNITS or nxt in TENS):
            pass                                              # "one hundred and five"
        elif t in UNITS and t != "zero" and (opens or (last == "tens" and UNITS[t] < 10)):
            cur, last = cur + UNITS[t], "unit" if UNITS[t] < 10 else "teen"
        elif t == "zero" and last is None:
            return "0", 0, j + 1
        elif t in TENS and opens:
            cur, last = cur + TENS[t], "tens"
        elif t in ORDINALS and (opens or (last == "tens" and ORDINALS[t] < 10)):
            v = total + cur + ORDINALS[t]
            return _ordinal(v), v, j + 1
        elif t == "hundred" and last in (None, "unit", "teen", "tens"):
            cur, last = (cur or 1) * 100, "hundred"
        elif t in SCALES and last != "scale":
            total, cur, last = total + (cur or 1) * SCALES[t], 0, "scale"
        else:
            break
        j += 1
    if last is None:
        return None
    return str(total + cur), total + cur, j


def to_digits(tokens: list[str]) -> list[str]:
    """Number words -> digits over punctuation-free tokens."""
    expanded: list[str] = []
    for k, t in enumerate(tokens):   # "double four": emit one extra "four" here,
        if t in ("double", "triple") and k + 1 < len(tokens) and (
                UNITS.get(tokens[k + 1], 99) < 10 or re.fullmatch(r"\d", tokens[k + 1])):
            expanded += [tokens[k + 1]] * (1 if t == "double" else 2)  # + the next token
        else:
            expanded.append(CURRENCY.get(t) or DECADES.get(t) or t)
    out: list[str] = []
    i = 0
    while i < len(expanded):
        found = _phrase(expanded, i)
        if not found:
            out.append(expanded[i])
            i += 1
            continue
        text, value, j = found
        if j == i + 1 and value in YEAR_HEADS and text.isdigit() and not expanded[i].isdigit():
            tail = _phrase(expanded, j)                # "nineteen ninety nine"
            if tail and tail[0].isdigit() and 10 <= tail[1] <= 99:
                text, j = str(value * 100 + tail[1]), tail[2]
        out.append(text)
        i = j
    return _join_digit_runs(out)


def _join_digit_runs(tokens: list[str]) -> list[str]:
    out: list[str] = []
    run: list[str] = []
    for t in tokens + [""]:
        if len(t) == 1 and t.isdigit():
            run.append(t)
            continue
        out += ["".join(run)] if len(run) >= 3 else run
        run = []
        if t:
            out.append(t)
    return out
