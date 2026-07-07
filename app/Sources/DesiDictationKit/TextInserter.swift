import AppKit
import Foundation

/// Inserts text into the frontmost app's focused field.
///
/// Strategy (MacWhisper-style layered fallbacks):
///   1. set clipboard + synthesized ⌘V   — works almost everywhere
///   2. copy-only mode                    — user preference / ultimate fallback
///
/// The transcript deliberately STAYS on the clipboard after pasting (no
/// restore): if the target app rejected the paste, the user can always ⌘V
/// manually. "The transcript is sacred" > clipboard preservation (user-requested
/// default, v0.2 feedback).
public enum TextInserter {
    public static func insert(_ text: String, copyOnly: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard !copyOnly else { return }
        synthesizePaste()
    }

    private static func synthesizePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // 9 = kVK_ANSI_V
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
