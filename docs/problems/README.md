# Problems (private)

The problems that decide whether this product lives. Each problem gets one doc with the same structure:

1. **Problem definition** — what exactly is broken
2. **The user & what they face** — persona-grounded (see ../features/PERSONAS.md)
3. **Impact on the journey** — where in the user flow it hurts
4. **Why it's this bad** — root-cause dig, not just symptoms
5. **Severity** — honest rating and why
6. **Proposed solutions** — each with trade-offs, implementation complexity, UX changes, what it solves, and what it leaves unsolved

## Index

| Doc | Problem | Severity |
|---|---|---|
| [P1_HINGLISH_ACCURACY.md](P1_HINGLISH_ACCURACY.md) | Hinglish transcription isn't reliable — and it's our core promise | **Existential** |
| [P2_OOD_WORDS.md](P2_OOD_WORDS.md) | Out-of-distribution words: cuss words, slang, names get censored or mangled | High |
| [P3_MODEL_FRESHNESS.md](P3_MODEL_FRESHNESS.md) | Language moves; our frozen models don't — and we collect no data | Medium (compounds) |
| [P4_PERSONALIZATION.md](P4_PERSONALIZATION.md) | Users can't make the output *their* Hinglish without manual drudgery | High |
| [ADDITIONAL_PROBLEMS.md](ADDITIONAL_PROBLEMS.md) | Top 10 further problems from an end-to-end product analysis | Mixed |

This folder is gitignored — stays local.
