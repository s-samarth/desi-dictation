import AppKit

/// How big the review panel opens: wide enough to read comfortably, and tall
/// enough that the whole dictation shows without scrolling, up to half the
/// screen. The user can drag it bigger; a width they pick is kept.
enum ReviewLayout {
    struct Size {
        var width: CGFloat
        var editorHeight: CGFloat
    }

    static let minWidth: CGFloat = 480
    static let minEditorHeight: CGFloat = 70
    /// Longer than this many characters opens the wide panel.
    static let wideAfter = 280
    private static let widthKey = "reviewPanelWidth"

    static func size(for text: String, on screen: NSRect) -> Size {
        let width = width(for: text, on: screen)
        return Size(width: width, editorHeight: editorHeight(for: text, width: width, on: screen))
    }

    /// The width the user last dragged the panel to, else wider for long text.
    static func width(for text: String, on screen: NSRect) -> CGFloat {
        let saved = CGFloat(UserDefaults.standard.double(forKey: widthKey))
        let auto: CGFloat = text.count > wideAfter ? 720 : 560
        return min(max(saved > 0 ? saved : auto, minWidth), screen.width - 80)
    }

    static func remember(width: CGFloat) {
        UserDefaults.standard.set(Double(width), forKey: widthKey)
    }

    /// Height that shows all of `text` at this panel width, capped at half the screen.
    static func editorHeight(for text: String, width: CGFloat, on screen: NSRect) -> CGFloat {
        // Panel padding (16 each side), text inset (6), line-fragment padding (5), scroller room.
        let textWidth = width - 32 - 12 - 10 - 16
        let bounds = NSAttributedString(string: text, attributes: ReviewTextView.plain)
            .boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading])
        let needed = ceil(bounds.height) + 16 + 8   // text inset top and bottom, one spare line gap
        return min(max(needed, minEditorHeight), screen.height * 0.5)
    }
}
