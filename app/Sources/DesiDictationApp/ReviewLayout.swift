import AppKit

/// How big the review panel opens: wide enough to read comfortably, and tall
/// enough that the whole dictation shows at once: up to 20 lines without a
/// scroll bar (most of the screen on a laptop), so it can be checked in one
/// look. Short text still gets a roomy box. It can be dragged bigger.
enum ReviewLayout {
    struct Size {
        var width: CGFloat
        var editorHeight: CGFloat
    }

    /// Lines shown before the text scrolls.
    static let maxLines: CGFloat = 20
    /// The smallest box, even for one line.
    static let minLines: CGFloat = 6
    /// Longer than this many characters opens the wide panel.
    static let wideAfter = 400

    static func size(for text: String, on screen: NSRect) -> Size {
        let width = min(text.count > wideAfter ? 820 : 680, screen.width - 80)
        return Size(width: width, editorHeight: editorHeight(for: text, width: width, on: screen))
    }

    /// Height that shows all of `text` at this panel width, between 6 and 20
    /// lines, and never more than the screen leaves room for.
    static func editorHeight(for text: String, width: CGFloat, on screen: NSRect) -> CGFloat {
        let font = ReviewTextView.plain[.font] as? NSFont ?? .systemFont(ofSize: 15)
        let line = ceil(NSLayoutManager().defaultLineHeight(for: font))
        // Panel padding (16 each side), text inset (6), line-fragment padding (5), scroller room.
        let textWidth = width - 32 - 12 - 10 - 16
        let bounds = NSAttributedString(string: text, attributes: ReviewTextView.plain)
            .boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading])
        let inset: CGFloat = 16 + line                  // text inset top and bottom, one spare line
        let needed = min(max(ceil(bounds.height), minLines * line), maxLines * line) + inset
        // Leave room for the panel's header, suggestions, fixes and buttons (~200 pt).
        return min(needed, screen.height - 240)
    }
}
