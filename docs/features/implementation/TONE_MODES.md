# Tone Modes — implementation

**Spec:** IDEAS.md #1 (tone dial) shaped by competitors/PATTERNS.md §1:
Superwhisper and VoiceInk converged on **modes-as-bundles**, so our dial is a
mode picker, not a hidden toggle. **The India angle:** a *Respectful
(आदरपूर्वक)* register for elders/teachers/officials that Western tools don't
model.

## The four modes (`ToneMode` in PromptTemplates.swift)

| Mode | What happens |
|---|---|
| **Faithful (as spoken)** — default | **No LLM pass at all.** `PromptTemplates.tone(.faithful) == nil` is the architectural guarantee (tested). Faithfulness-first is the trust stance — PATTERNS.md §3 names "rewriting what you said as polish" as a competitor's trust violation. |
| Casual | Light rewrite toward relaxed/friendly register |
| Professional | Workplace-clear, no slang |
| Respectful | Polite forms (aap/ji where natural), deferential not servile |

All rewrite prompts share hard constraints: **keep the language mix exactly as
dictated** (Hinglish stays Hinglish), preserve all meaning/facts/names/numbers,
change as little as possible.

## Where it runs

`DictationController.finishPipeline`: for non-LLM language modes, if
`settings.toneMode != .faithful` → phase **`.polishing`** (own overlay stage,
"Polishing ✨") → `LLMServices.applyTone(tone, to: text)` → deliver. If the
rewrite changed the text, history stores the original in `raw:` (the
"heard:" line) — the user can always see what they actually said.
`applyTone` returns the original on ANY failure; a dead Ollama can slow a
dictation by a timeout but can never eat it.

Deliberate scoping: tone does **not** stack on the anyToEnglish translation
(that output is already polished English; stacking rewrites doubles latency
and drift risk). Chain it in `finishPipeline` if that ever changes.

## UI surfaces

- **Menu bar → Tone picker** — right under Language, because tone-switching is
  per-recipient (Rekha: WhatsApp customer vs courier escalation).
- **AI tab → radio group** with the honest footer ("never the meaning…
  History keeps the original next to the rewrite").

## Not built (yet) — the leash

PATTERNS.md §3 mentions an *edit-distance leash* (reject rewrites that drift
too far). v1 relies on prompt constraints + the visible original. If a real
leash is wanted: compute a token-level distance between input and output in
`applyTone` and fall back to the original beyond a threshold — one small,
well-tested function away.
