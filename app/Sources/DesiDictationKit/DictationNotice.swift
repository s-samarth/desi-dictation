import Foundation

/// A short message the overlay shows after a dictation that didn't end in a
/// clean paste: nothing heard, an error, or "copied, press ⌘V". Before this
/// existed the overlay hid on every non-active phase, so those endings were a
/// beep and a menu-bar icon change at most — they read as silent failures
/// (FM#31).
public struct DictationNotice: Equatable {
    public enum Kind: Equatable {
        /// Nothing usable came out (no speech, an error).
        case problem
        /// The words are on the clipboard, but the paste was skipped.
        case copied
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }

    /// How long a notice stays up before the overlay hides.
    public static let displaySeconds: Double = 4

    /// Empty transcript: the engine returned "" (silence, noise, or a label
    /// the engine filtered). The clipboard was left alone.
    public static let nothingHeard = "Didn't catch that — nothing pasted. Try again."

    /// The notice for an insert outcome; nil when nothing needs saying.
    public static func forOutcome(_ outcome: InsertOutcome) -> DictationNotice? {
        switch outcome {
        case .pasted, .copied:
            return nil
        case .pasteSkipped(.modifiersHeld):
            return DictationNotice(kind: .copied, message: "Copied — press ⌘V to paste")
        case .pasteSkipped(.noAccessibility):
            return DictationNotice(
                kind: .copied,
                message: "Copied — press ⌘V. Grant Accessibility to auto-paste")
        }
    }
}
