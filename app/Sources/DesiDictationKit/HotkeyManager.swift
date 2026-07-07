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

    public private(set) var isActive = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkey: HotkeyChoice = .rightOption
    private var modifierIsDown = false

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
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: selfPtr
        )
        guard let tap else { isActive = false; return }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isActive = true
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        isActive = false
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

        if hotkey.isModifier {
            guard type == .flagsChanged, keyCode == hotkey.keyCode else {
                return Unmanaged.passUnretained(event)
            }
            let relevantFlag: CGEventFlags = hotkey == .rightOption ? .maskAlternate : .maskCommand
            let isDown = event.flags.contains(relevantFlag)
            guard isDown != modifierIsDown else { return Unmanaged.passUnretained(event) }
            modifierIsDown = isDown
            DispatchQueue.main.async { isDown ? self.onDictateDown?() : self.onDictateUp?() }
            return Unmanaged.passUnretained(event)  // never swallow modifier state
        }

        guard keyCode == hotkey.keyCode else { return Unmanaged.passUnretained(event) }
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if type == .keyDown, !isRepeat {
            DispatchQueue.main.async { self.onDictateDown?() }
        } else if type == .keyUp {
            DispatchQueue.main.async { self.onDictateUp?() }
        }
        return nil  // swallow the dedicated hotkey so it doesn't type anything
    }
}
