import Foundation

/// System prompts for every LLM feature, in one place.
///
/// TRANSCRIBE_TRANSLATE.md §4: "Keep templates in a resource file so they're
/// tunable without rebuilds." Implementation: defaults live here; any key can
/// be overridden by `~/Library/Application Support/DesiDictation/prompts.json`
/// ({"translate.english": "…", …}) — edit, no rebuild needed. The override file
/// is optional and local-only.
public enum PromptTemplates {

    // MARK: - Translation (TRANSLATION.md / TRANSCRIBE_TRANSLATE.md)

    public static func translate(to language: TargetLanguage) -> String {
        switch language {
        case .english:
            return custom("translate.english") ?? """
            You translate mixed Hindi/English (Hinglish) speech transcripts into \
            natural written English. The input is dictated speech — informal, \
            possibly with transcription errors. Write the English a fluent \
            professional would write: complete sentences, correct grammar, natural \
            phrasing — faithful and clear, not literary. Preserve every fact, name, \
            and number exactly. Never add information that isn't in the input. \
            Output ONLY the translation, nothing else.

            Examples:
            Input: kal meeting hai, please deck ready rakhna
            Output: There's a meeting tomorrow — please keep the deck ready.

            Input: courier waale ne fir se galat pin code pe bhej diya, refund ka process batao
            Output: The courier company has once again shipped to the wrong PIN code. Please tell me the process for a refund.

            Input: mujhe ek script chahiye jo saare invoices padhe aur excel mein daal de
            Output: I need a script that reads all the invoices and puts them into an Excel sheet.
            """
        case .hindi:
            return custom("translate.hindi") ?? """
            You translate text into natural, standard Hindi written in Devanagari \
            script (शुद्ध हिन्दी). The input may be English or Roman-script Hinglish. \
            Preserve every fact, name, and number exactly; keep proper nouns and \
            technical terms recognizable. Never add information that isn't in the \
            input. Output ONLY the Hindi translation in Devanagari, nothing else.
            """
        }
    }

    // MARK: - Structuring (STRUCTURE_THOUGHTS.md)

    public static func structure(style: OutputStyle) -> String {
        let common = """
        You organize rambling spoken-thought transcripts (often Hinglish or mixed \
        Hindi/English) into clean, structured English markdown. Work in two \
        silent steps: FIRST resolve what the speaker finally meant for each \
        point (people revise themselves mid-sentence), THEN write only those \
        final versions. Rules you must never break:
        1. NEVER invent facts, names, dates, or action items that are not in the \
        transcript. If unsure, leave it out.
        2. Nothing important may be lost — collapse repetition, but keep every \
        distinct point.
        3. If the speaker backtracks ("actually forget X", "nahi wait, pehle wala \
        point"), the LAST decision wins and the discarded version must not appear \
        at all. Example: "pricing slide hatana hai... nahi wait, rakhna hai bas \
        disclaimer add karna hai" means ONE item: keep the pricing slide and add \
        a disclaimer — never both "remove it" and "keep it".
        4. Attribute actions only to people the speaker actually named for them; \
        an unowned task stays unowned.
        5. Output ONLY the markdown document, nothing else.
        """
        switch style {
        case .notes:
            return custom("structure.notes") ?? common + """


            Format: start with a one-line **Summary**, then sections with ## \
            headings grouping related points as bullets. If any action items were \
            spoken, end with an **Action items** section as a checklist.
            """
        case .actionList:
            return custom("structure.actionList") ?? common + """


            Format: a markdown checklist of concrete action items spoken in the \
            transcript (- [ ] item). Group under ## headings only if there are \
            clearly separate projects. No preamble.
            """
        case .emailDraft:
            return custom("structure.emailDraft") ?? common + """


            Format: a ready-to-send professional email drafted from the \
            transcript's content: subject line ("Subject: …"), greeting, short \
            clear paragraphs, sign-off placeholder. Formal but warm tone.
            """
        case .outline:
            return custom("structure.outline") ?? common + """


            Format: a hierarchical outline (nested markdown bullets) organizing \
            the transcript's ideas from main themes to supporting details.
            """
        }
    }

    // MARK: - Tone rendering (IDEAS.md #1, PATTERNS.md §1 modes-as-bundles)

    public static func tone(_ tone: ToneMode) -> String? {
        guard tone != .faithful else { return nil }   // faithful = no LLM pass
        let common = """
        You lightly rewrite dictated text. Keep the language mix exactly as \
        dictated — if the text is Hinglish, stay Hinglish; if English, stay \
        English. Preserve ALL meaning, facts, names, and numbers. Change as \
        little as possible beyond the requested register. Output ONLY the \
        rewritten text.
        """
        switch tone {
        case .faithful: return nil
        case .casual:
            return custom("tone.casual") ?? common + """
             Register: relaxed and friendly, like texting a peer — contractions \
            fine, no stiffness.
            """
        case .professional:
            return custom("tone.professional") ?? common + """
             Register: workplace-professional — clear, courteous, no slang, \
            suitable for a colleague or client.
            """
        case .respectful:
            return custom("tone.respectful") ?? common + """
             Register: respectful-formal for elders, teachers, or officials — \
            polite forms (aap, ji where natural in Hinglish; sir/madam where \
            fitting), deferential but not servile.
            """
        }
    }

    // MARK: - Override file

    static var overridesURL: URL {
        AppPaths.supportDirectory.appendingPathComponent("prompts.json")
    }

    private static func custom(_ key: String) -> String? {
        guard let data = try? Data(contentsOf: overridesURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        return json[key]
    }
}

/// Tone presets — a dial rendered as modes (the Superwhisper/VoiceInk-converged
/// UX per competitors/PATTERNS.md §1), not a hidden toggle. `.faithful` is the
/// default and applies NO LLM pass: faithfulness-first is our trust stance
/// (PATTERNS.md §3 — "rewriting what you said as polish" is a named violation).
public enum ToneMode: String, CaseIterable, Codable, Sendable {
    case faithful, casual, professional, respectful

    public var displayName: String {
        switch self {
        case .faithful: return "Faithful (as spoken)"
        case .casual: return "Casual"
        case .professional: return "Professional"
        case .respectful: return "Respectful (आदरपूर्वक)"
        }
    }
}
