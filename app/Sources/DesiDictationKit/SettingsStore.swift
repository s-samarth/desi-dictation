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
/// normal keys via keyDown/keyUp. Fn/Globe is intentionally excluded (macOS
/// reserves it aggressively; MacWhisper users hit the same issue).
public enum HotkeyChoice: String, CaseIterable, Codable {
    case rightOption, rightCommand, f13, f16, f17, f18, f19

    public var keyCode: Int64 {
        switch self {
        case .rightOption: return 61
        case .rightCommand: return 54
        case .f13: return 105
        case .f16: return 106
        case .f17: return 64
        case .f18: return 79
        case .f19: return 80
        }
    }

    public var isModifier: Bool {
        self == .rightOption || self == .rightCommand
    }

    public var displayName: String {
        switch self {
        case .rightOption: return "Right ⌥ Option"
        case .rightCommand: return "Right ⌘ Command"
        case .f13: return "F13"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
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

    public static let defaultCleanupPrompt = """
    Clean up this dictated text: fix punctuation and obvious errors. \
    Keep Roman-script Hindi (Hinglish) words EXACTLY as they are — do not translate \
    or convert to Devanagari. Reply with only the cleaned text.
    """

    private init() {
        dictationEnabled = d.object(forKey: "dictationEnabled") as? Bool ?? false
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
    }
}
