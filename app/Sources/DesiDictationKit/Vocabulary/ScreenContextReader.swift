import ApplicationServices
import Foundation

/// What was on screen when a dictation started. Held in RAM for that one
/// dictation, then dropped (§2b). Never written to disk, history or logs.
public struct ScreenContext: Sendable {
    public var fieldText: String = ""
    public var windowTitle: String = ""
    public var windowTexts: [String] = []

    public init(fieldText: String = "", windowTitle: String = "", windowTexts: [String] = []) {
        self.fieldText = fieldText
        self.windowTitle = windowTitle
        self.windowTexts = windowTexts
    }
}

/// Reads the focused field, the window title and nearby text through
/// Accessibility, the way Superwhisper and Aqua do: at recording start,
/// bounded in time and size, from the app the user is dictating into.
///
/// Electron and Chrome expose web text only when their own accessibility
/// mode is on; we don't force it on (it slows those apps), so names there come
/// from the field and title only.
public enum ScreenContextReader {
    /// Run off the main thread: AX calls are cross-process messages.
    public static func read(includeWindow: Bool, budget: TimeInterval = 0.15,
                            maxNodes: Int = 1500, maxTexts: Int = 400) -> ScreenContext? {
        guard let focused = AXReader.focusedElement() else { return nil }
        var context = ScreenContext()
        if let value = AXReader.fieldValue(focused) {
            context.fieldText = around(caret: AXReader.caretUTF16(focused), in: value, radius: 2000)
        }
        guard includeWindow, let window = AXReader.window(of: focused) else { return context }
        AXUIElementSetMessagingTimeout(window, AXReader.messageTimeout)
        context.windowTitle = AXReader.string(window, kAXTitleAttribute) ?? ""
        context.windowTexts = visibleTexts(in: window, budget: budget, maxNodes: maxNodes, maxTexts: maxTexts)
        return context
    }

    /// Breadth-first walk of the window, nearest-to-the-top text first, so a
    /// chat's header and recent messages beat a long scrolled history.
    static func visibleTexts(in window: AXUIElement, budget: TimeInterval,
                             maxNodes: Int, maxTexts: Int) -> [String] {
        let deadline = Date().addingTimeInterval(budget)
        var queue = [window]
        var head = 0
        var texts: [String] = []
        while head < queue.count, head < maxNodes, texts.count < maxTexts, Date() < deadline {
            let node = queue[head]
            head += 1
            let role = AXReader.string(node, kAXRoleAttribute) ?? ""
            if role == kAXStaticTextRole || role == "AXHeading" || role == kAXTextFieldRole,
               !AXReader.isSecure(node),
               let text = AXReader.string(node, kAXValueAttribute) ?? AXReader.string(node, kAXTitleAttribute),
               !text.isEmpty {
                texts.append(String(text.prefix(500)))
            }
            queue += AXReader.children(node)
        }
        return texts
    }

    /// ±radius characters around the caret: a long document's relevant part.
    static func around(caret: Int?, in text: String, radius: Int) -> String {
        guard text.count > radius * 2 else { return text }
        let utf16 = text.utf16
        let caretIndex = caret.flatMap { utf16.index(utf16.startIndex, offsetBy: $0, limitedBy: utf16.endIndex) }
            ?? text.endIndex
        let center = text.distance(from: text.startIndex, to: caretIndex)
        let lower = text.index(text.startIndex, offsetBy: max(0, center - radius))
        let upper = text.index(text.startIndex, offsetBy: min(text.count, center + radius))
        return String(text[lower..<upper])
    }
}
