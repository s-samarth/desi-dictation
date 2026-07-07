import AppKit
import Foundation

/// Inserts text into the frontmost app's focused field.
///
/// Strategy (MacWhisper-style layered fallbacks):
///   1. pasteboard swap + synthesized ⌘V   — works almost everywhere
///   2. copy-only mode                      — user preference / ultimate fallback
/// The previous pasteboard string is restored ~400ms after pasting.
public enum TextInserter {
    public static func insert(_ text: String, copyOnly: Bool) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard !copyOnly else { return }  // leave transcript on the clipboard

        synthesizePaste()

        // Restore what the user had on the clipboard before we hijacked it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if let previous {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
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
