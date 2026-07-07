import AppKit
import Foundation

/// Global hotkey listener built on a CGEventTap.
/// - Push-to-talk: keyDown/flags-on = start, keyUp/flags-off = stop.
/// - Toggle: each press flips recording.
/// - Escape while a session is active cancels it (event is swallowed).
/// Requires Accessibility + Input Monitoring permissions; `isActive` reports
/// whether the tap could actually be created.
public final class HotkeyManager {
    public var onDictateDown: (() -> Void)?
    public var onDictateUp: (() -> Void)?
    public var onCancel: (() -> Void)?
    /// Controller sets this true while recording so Esc gets intercepted.
    public var sessionActive: () -> Bool = { false }

    /// How the tap was created. `.listenOnly` is the degraded mode (can't swallow
    /// the hotkey/Esc keystrokes, but dictation fully works) used when macOS
    /// denies an active tap — e.g. stale TCC grants on ad-hoc dev builds.
    public enum TapMode { case active, listenOnly, failed }
    public private(set) var tapMode: TapMode = .failed
    public var isActive: Bool { tapMode != .failed }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkey: HotkeyChoice = .rightOption
    private var modifierIsDown = false
    private var comboActive = false

    public init() {}
    deinit { stop() }

    public func start(hotkey: HotkeyChoice) {
        stop()
        self.hotkey = hotkey

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return manager.handle(type: type, event: event)
        }

        tapMode = .active
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: callback, userInfo: selfPtr)

        if tap == nil {  // active tap denied — fall back to listen-only
            tapMode = .listenOnly
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .listenOnly, eventsOfInterest: mask,
                callback: callback, userInfo: selfPtr)
        }
        guard let tap else { tapMode = .failed; return }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        tapMode = .failed
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables taps that stall; re-enable immediately.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Esc cancels an active session and is swallowed.
        if type == .keyDown, keyCode == 53, sessionActive() {
            DispatchQueue.main.async { self.onCancel?() }
            return nil
        }

        if hotkey.isModifier, let mask = hotkey.modifierMask {
            guard type == .flagsChanged, keyCode == hotkey.keyCode else {
                return Unmanaged.passUnretained(event)
            }
            let isDown = event.flags.contains(mask)
            guard isDown != modifierIsDown else { return Unmanaged.passUnretained(event) }
            modifierIsDown = isDown
            DispatchQueue.main.async { isDown ? self.onDictateDown?() : self.onDictateUp?() }
            return Unmanaged.passUnretained(event)  // never swallow modifier state
        }

        guard keyCode == hotkey.keyCode else { return Unmanaged.passUnretained(event) }

        // Combo hotkeys (e.g. ⌥+Space): the modifier must be held at keyDown;
        // keyUp always ends the press (even if ⌥ was released first).
        if let combo = hotkey.comboModifier {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if type == .keyDown, !isRepeat, event.flags.contains(combo) {
                comboActive = true
                DispatchQueue.main.async { self.onDictateDown?() }
                return nil  // swallow so ⌥Space doesn't type a non-breaking space
            }
            if type == .keyUp, comboActive {
                comboActive = false
                DispatchQueue.main.async { self.onDictateUp?() }
                return nil
            }
            return Unmanaged.passUnretained(event)  // plain Space passes through
        }

        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if type == .keyDown, !isRepeat {
            DispatchQueue.main.async { self.onDictateDown?() }
        } else if type == .keyUp {
            DispatchQueue.main.async { self.onDictateUp?() }
        }
        return nil  // swallow the dedicated hotkey so it doesn't type anything
    }
}
