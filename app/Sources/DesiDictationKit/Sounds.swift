import AppKit

/// Audio cues using built-in system sounds (no bundled assets needed).
/// MacWhisper ships custom mp3s; system sounds are the zero-dependency v1.
public enum Sounds {
    case start, finish, error

    private var systemSoundName: String {
        switch self {
        case .start: return "Tink"
        case .finish: return "Pop"
        case .error: return "Basso"
        }
    }

    public func play() {
        guard SettingsStore.shared.soundsEnabled else { return }
        NSSound(named: systemSoundName)?.play()
    }
}
