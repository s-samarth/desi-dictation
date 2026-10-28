import AppKit
import ApplicationServices
import Foundation

/// What happened to a transcript handed to `TextInserter`.
public enum InsertOutcome: Equatable {
    case pasted
    /// Copy-only mode: on the clipboard because the user chose that.
    case copied
    /// Paste was skipped: the words are on the clipboard and the user has to
    /// press ⌘V. The UI must say so (FM#31): never a silent skip.
    case pasteSkipped(PasteBlock)
}

public enum PasteBlock: Equatable {
    /// No Accessibility grant: macOS silently drops synthesized keystrokes.
    case noAccessibility
    /// A modifier was still held when the wait ran out, so ⌘V would have
    /// arrived as ⌥⌘V / ⇧⌘V, which is not paste (and ⌥⌘V moves files in Finder).
    case modifiersHeld
    /// One of our menus stayed open (it would swallow ⌘V) — FM#32.
    case menuOpen
}

/// The pure decision behind each paste attempt, split out so it is testable
/// without posting real keystrokes.
public enum PasteGate {
    /// Held modifiers that change what ⌘V means. ⌘ itself doesn't, and
    /// Caps Lock / fn don't either.
    public static let blockingModifiers: CGEventFlags = [.maskAlternate, .maskShift, .maskControl]
    /// How long to wait for the user to let go of a modifier (the Right ⌥
    /// toggle is still down at stop: stop fires on keyDown).
    public static let maxWait: TimeInterval = 1.5

    public enum Step: Equatable { case copyOnly, paste, wait, closeMenu, skip(PasteBlock) }

    public static func step(
        copyOnly: Bool, trusted: Bool, menuOpen: Bool = false, held: CGEventFlags,
        waited: TimeInterval, timeout: TimeInterval = maxWait
    ) -> Step {
        if copyOnly { return .copyOnly }
        if !trusted { return .skip(.noAccessibility) }
        // An open menu of ours owns the keyboard: ⌘V would go to it (FM#32).
        if menuOpen { return waited >= timeout ? .skip(.menuOpen) : .closeMenu }
        if held.intersection(blockingModifiers).isEmpty { return .paste }
        return waited >= timeout ? .skip(.modifiersHeld) : .wait
    }
}

/// Inserts text into the frontmost app's focused field.
///
/// Strategy (MacWhisper-style layered fallbacks):
///   1. set clipboard + synthesized ⌘V   — works almost everywhere
///   2. copy-only mode                    — user preference / ultimate fallback
///
/// The target is NOT captured at start: ⌘V goes to whatever field is focused
/// when the user stops, so switching apps or Spaces mid-dictation is fine.
///
/// The transcript deliberately STAYS on the clipboard after pasting (no
/// restore): if the target app rejected the paste, the user can always ⌘V
/// manually. "The transcript is sacred" > clipboard preservation (user-requested
/// default, v0.2 feedback).
public enum TextInserter {
    /// Clipboard only — the menu / History / window "Copy" buttons.
    public static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @MainActor
    public static func insert(_ text: String, copyOnly: Bool) async -> InsertOutcome {
        copy(text)

        // Wait for physical modifiers to come up before posting ⌘V. The HID
        // tap merges held modifiers into posted events, and a silent tail
        // transcribes in ~10 ms, so the toggle key is often still down (FM#31).
        let start = Date()
        var closedMenu = false
        while true {
            let step = PasteGate.step(
                copyOnly: copyOnly, trusted: AXIsProcessTrusted(),
                menuOpen: MenuTracker.shared.isMenuOpen,
                held: CGEventSource.flagsState(.hidSystemState),
                waited: Date().timeIntervalSince(start))
            switch step {
            case .copyOnly: return .copied
            case .skip(let reason): return .pasteSkipped(reason)
            case .closeMenu:
                if !closedMenu { MenuTracker.shared.closeAll() }
                closedMenu = true
                try? await Task.sleep(nanoseconds: 20_000_000)
            case .paste:
                // Focus goes back to the text field as the menu ends; give
                // the window server a beat before the keystroke.
                if closedMenu { try? await Task.sleep(nanoseconds: 80_000_000) }
                synthesizePaste()
                return .pasted
            case .wait:
                try? await Task.sleep(nanoseconds: 20_000_000)
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
