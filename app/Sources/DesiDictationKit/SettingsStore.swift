import CoreGraphics
import Foundation
import Combine

/// Push-to-talk vs toggle activation (MacWhisper parity).
public enum ActivationMode: String, CaseIterable, Codable {
    case pushToTalk, toggle
    public var displayName: String {
        self == .pushToTalk ? "Push to Talk (hold)" : "Toggle (tap to start/stop)"
    }
}

/// Selectable dictation hotkeys. Modifier-style keys arrive via flagsChanged;
/// normal keys via keyDown/keyUp; combos check modifier flags on keyDown.
/// Ordered: built-in MacBook keys first, F-keys last (external keyboards).
public enum HotkeyChoice: String, CaseIterable, Codable {
    case rightOption, rightCommand, fnGlobe, rightControl, rightShift,
         leftControl, optionSpace, f13, f16, f17, f18, f19

    public var keyCode: Int64 {
        switch self {
        case .rightOption: return 61
        case .rightCommand: return 54
        case .fnGlobe: return 63
        case .rightControl: return 62
        case .rightShift: return 60
        case .leftControl: return 59
        case .optionSpace: return 49   // space; ⌥ checked via flags
        case .f13: return 105
        case .f16: return 106
        case .f17: return 64
        case .f18: return 79
        case .f19: return 80
        }
    }

    public var isModifier: Bool {
        switch self {
        case .rightOption, .rightCommand, .fnGlobe, .rightControl,
             .rightShift, .leftControl: return true
        default: return false
        }
    }

    /// The flag that indicates "held down" for modifier-style keys.
    public var modifierMask: CGEventFlags? {
        switch self {
        case .rightOption: return .maskAlternate
        case .rightCommand: return .maskCommand
        case .fnGlobe: return .maskSecondaryFn
        case .rightControl, .leftControl: return .maskControl
        case .rightShift: return .maskShift
        default: return nil
        }
    }

    /// For combo hotkeys: the modifier that must accompany the key press.
    public var comboModifier: CGEventFlags? {
        self == .optionSpace ? .maskAlternate : nil
    }

    public var displayName: String {
        switch self {
        case .rightOption: return "Right ⌥ Option"
        case .rightCommand: return "Right ⌘ Command"
        case .fnGlobe: return "Fn 🌐 Globe"
        case .rightControl: return "Right ⌃ Control"
        case .rightShift: return "Right ⇧ Shift"
        case .leftControl: return "Left ⌃ Control"
        case .optionSpace: return "⌥ Option + Space"
        case .f13: return "F13 (external keyboards)"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
        }
    }

    /// Extra setup a key needs, shown under the picker.
    public var hint: String? {
        switch self {
        case .fnGlobe:
            return "Set System Settings → Keyboard → “Press 🌐 key to” → Do Nothing, or macOS will also trigger its own action."
        case .optionSpace:
            return "Hold ⌥ and press Space. Note: some apps use ⌥Space for other shortcuts."
        default: return nil
        }
    }
}

/// UserDefaults-backed settings, observable from SwiftUI.
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    private let d = UserDefaults.standard

    @Published public var dictationEnabled: Bool { didSet { d.set(dictationEnabled, forKey: "dictationEnabled") } }
    @Published public var hotkey: HotkeyChoice { didSet { d.set(hotkey.rawValue, forKey: "hotkey") } }
    @Published public var activationMode: ActivationMode { didSet { d.set(activationMode.rawValue, forKey: "activationMode") } }
    @Published public var languageMode: LanguageMode { didSet { d.set(languageMode.rawValue, forKey: "languageMode") } }
    @Published public var modelPath: String { didSet { d.set(modelPath, forKey: "modelPath") } }
    @Published public var soundsEnabled: Bool { didSet { d.set(soundsEnabled, forKey: "soundsEnabled") } }
    @Published public var copyInsteadOfPaste: Bool { didSet { d.set(copyInsteadOfPaste, forKey: "copyInsteadOfPaste") } }
    @Published public var replacementRules: String { didSet { d.set(replacementRules, forKey: "replacementRules") } }
    @Published public var ollamaEnabled: Bool { didSet { d.set(ollamaEnabled, forKey: "ollamaEnabled") } }
    @Published public var ollamaModel: String { didSet { d.set(ollamaModel, forKey: "ollamaModel") } }
    @Published public var cleanupPrompt: String { didSet { d.set(cleanupPrompt, forKey: "cleanupPrompt") } }
    @Published public var licenseKey: String { didSet { d.set(licenseKey, forKey: "licenseKey") } }
    @Published public var historyEnabled: Bool { didSet { d.set(historyEnabled, forKey: "historyEnabled") } }
    @Published public var vadEnabled: Bool { didSet { d.set(vadEnabled, forKey: "vadEnabled") } }
    @Published public var micWarm: Bool { didSet { d.set(micWarm, forKey: "micWarm") } }
    @Published public var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    @Published public var launchAtLogin: Bool { didSet { d.set(launchAtLogin, forKey: "launchAtLogin") } }
    /// Local LLM model for translate/structure/tone (one model, all features).
    @Published public var llmModel: String { didSet { d.set(llmModel, forKey: "llmModel") } }
    /// Tone applied to dictations; .faithful = as spoken, no LLM pass.
    @Published public var toneMode: ToneMode { didSet { d.set(toneMode.rawValue, forKey: "toneMode") } }
    /// Per-app language memory (IDEAS #4) — on by default, learns silently.
    @Published public var perAppModes: Bool { didSet { d.set(perAppModes, forKey: "perAppModes") } }

    public static let defaultCleanupPrompt = """
    Clean up this dictated text: fix punctuation and obvious errors. \
    Keep Roman-script Hindi (Hinglish) words EXACTLY as they are — do not translate \
    or convert to Devanagari. Reply with only the cleaned text.
    """

    private init() {
        // ON by default: a dictation app that starts disabled confuses new
        // users ("nothing happens") — v0.5 pilot feedback.
        dictationEnabled = d.object(forKey: "dictationEnabled") as? Bool ?? true
        hotkey = HotkeyChoice(rawValue: d.string(forKey: "hotkey") ?? "") ?? .rightOption
        activationMode = ActivationMode(rawValue: d.string(forKey: "activationMode") ?? "") ?? .pushToTalk
        languageMode = LanguageMode(rawValue: d.string(forKey: "languageMode") ?? "") ?? .hinglish
        modelPath = d.string(forKey: "modelPath") ?? ""
        soundsEnabled = d.object(forKey: "soundsEnabled") as? Bool ?? true
        copyInsteadOfPaste = d.object(forKey: "copyInsteadOfPaste") as? Bool ?? false
        replacementRules = d.string(forKey: "replacementRules") ?? ""
        ollamaEnabled = d.object(forKey: "ollamaEnabled") as? Bool ?? false
        ollamaModel = d.string(forKey: "ollamaModel") ?? "llama3.2"
        cleanupPrompt = d.string(forKey: "cleanupPrompt") ?? Self.defaultCleanupPrompt
        licenseKey = d.string(forKey: "licenseKey") ?? ""
        historyEnabled = d.object(forKey: "historyEnabled") as? Bool ?? true
        vadEnabled = d.object(forKey: "vadEnabled") as? Bool ?? true
        micWarm = d.object(forKey: "micWarm") as? Bool ?? true
        onboarded = d.object(forKey: "onboarded") as? Bool ?? false
        launchAtLogin = d.object(forKey: "launchAtLogin") as? Bool ?? true
        llmModel = d.string(forKey: "llmModel") ?? LLMServices.defaultModel
        toneMode = ToneMode(rawValue: d.string(forKey: "toneMode") ?? "") ?? .faithful
        perAppModes = d.object(forKey: "perAppModes") as? Bool ?? true
    }
}
