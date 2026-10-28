import ApplicationServices
import Foundation

/// Thin, timeout-bounded reads of another app's Accessibility tree, the same
/// API TextInserter's paste already needs permission for. Every call is
/// bounded (100 ms per message), so a hung app can't stall dictation.
/// Never reads secure fields or our own windows.
enum AXReader {
    static let messageTimeout: Float = 0.1

    /// The text element that has keyboard focus in the frontmost app.
    static func focusedElement() -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messageTimeout)
        guard let element = self.element(system, kAXFocusedUIElementAttribute),
              pid(element) != getpid() else { return nil }
        AXUIElementSetMessagingTimeout(element, messageTimeout)
        return element
    }

    /// The window that holds `element` (or the app's focused window).
    static func window(of element: AXUIElement) -> AXUIElement? {
        if let window = self.element(element, kAXWindowAttribute) { return window }
        let app = AXUIElementCreateApplication(pid(element))
        AXUIElementSetMessagingTimeout(app, messageTimeout)
        return self.element(app, kAXFocusedWindowAttribute)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success
        else { return [] }
        return (value as? [AXUIElement]) ?? []
    }

    /// Where the caret is, in UTF-16 units (the AX convention).
    static func caretUTF16(_ element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range.location + range.length
    }

    /// Password fields: never read, never watched.
    static func isSecure(_ element: AXUIElement) -> Bool {
        string(element, kAXSubroleAttribute) == kAXSecureTextFieldSubrole
            || string(element, kAXRoleAttribute) == "AXSecureTextField"
    }

    /// The editable text of a focused field, or nil (secure, not text, huge).
    static func fieldValue(_ element: AXUIElement, maxLength: Int = 20_000) -> String? {
        guard !isSecure(element), let value = string(element, kAXValueAttribute),
              value.utf16.count <= maxLength else { return nil }
        return value
    }

    static func pid(_ element: AXUIElement) -> pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }
}
