"""Spoken-Hindi number normalization — Python port of the Mac app's
HindiNumbers.swift (same maps, same guards, same Indian digit grouping).
Digits go in BEFORE the LLM: every model ≤4B mangles "assi hazaar"-class
figures; all of them translate digits correctly.
"""

UNITS: dict[str, float] = {
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
}
SCALES: dict[str, float] = {
    "sau": 100, "hazaar": 1_000, "hazar": 1_000, "hajaar": 1_000,
    "hajar": 1_000, "lakh": 100_000, "laakh": 100_000, "lakhs": 100_000,
    "crore": 10_000_000, "crores": 10_000_000, "karod": 10_000_000,
}
POSSESSIVES = {"ke", "mere", "tere", "uske", "iske", "aapke", "hamare",
               "humare", "tumhare", "unke", "inke", "sabke", "kiske"}


def _split(token: str) -> tuple[str, str, str]:
    i, j = 0, len(token)
    while i < j and not token[i].isalpha():
        i += 1
    while j > i and not token[j - 1].isalpha():
        j -= 1
    return token[i:j].lower(), token[:i], token[j:]


def _unit(word: str, prev: str) -> float | None:
    if word in ("saath", "sath") and prev in POSSESSIVES:
        return None
    return UNITS.get(word)


def _compute(tokens: list[str]) -> int | None:
    total, current = 0.0, 0.0
    for token in tokens:
        word = _split(token)[0]
        if word in UNITS:
            current += UNITS[word]
        elif word == "sau":
            current = (current or 1) * 100
        elif word in SCALES:
            total += (current or 1) * SCALES[word]
            current = 0
    value = total + current
    return int(value) if value >= 100 and value == int(value) else None


def indian_grouped(value: int) -> str:
    digits = str(value)
    if len(digits) <= 3:
        return digits
    head, last3 = digits[:-3], digits[-3:]
    groups = []
    while len(head) > 2:
        groups.insert(0, head[-2:])
        head = head[:-2]
    if head:
        groups.insert(0, head)
    return ",".join(groups + [last3])


def normalize(text: str) -> str:
    tokens = text.split(" ")
    out: list[str] = []
    i = 0
    while i < len(tokens):
        word = _split(tokens[i])[0]
        prev = _split(out[-1])[0] if out else ""
        if _unit(word, prev) is not None:
            j, saw_scale, last = i, False, prev
            while j < len(tokens):
                core, _, trailing = _split(tokens[j])
                is_unit, is_scale = _unit(core, last) is not None, core in SCALES
                if not (is_unit or is_scale):
                    break
                saw_scale = saw_scale or is_scale
                last = core
                j += 1
                if trailing:
                    break
            value = _compute(tokens[i:j]) if saw_scale else None
            if value is not None:
                lead = _split(tokens[i])[1]
                trail = _split(tokens[j - 1])[2]
                out.append(lead + indian_grouped(value) + trail)
                i = j
                continue
        out.append(tokens[i])
        i += 1
    return " ".join(out)
