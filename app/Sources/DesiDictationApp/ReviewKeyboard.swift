import AppKit
import DesiDictationKit

/// Digits pick an alternative (0: looks right) while an unsure word is
/// selected; otherwise they type.
final class ReviewTextView: NSTextView {
    static let plain: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.labelColor,
    ]

    static func attributed(_ request: ReviewRequest) -> NSAttributedString {
        let out = NSMutableAttributedString(string: request.text, attributes: plain)
        for (i, unsure) in request.unsure.enumerated() {
            let range = NSRange(unsure.range, in: request.text)
            out.addAttributes(
                [
                    ReviewTextEditor.unsureKey: i,
                    .underlineStyle: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue,
                    .underlineColor: Self.color(for: unsure.reason),
                ], range: range)
        }
        ReviewSpellingMarks.mark(out, questions: request.unsure)
        return out
    }

    override func keyDown(with event: NSEvent) {
        if let chars = event.charactersIgnoringModifiers, chars.count == 1,
            let digit = Int(chars), (0...ReviewAlternatives.limit).contains(digit),
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
            selectedRange().length > 0,
            let coordinator = delegate as? ReviewTextEditor.Coordinator,
            coordinator.model.currentIndex != nil
        {
            digit == 0 ? coordinator.looksRight() : coordinator.pick(digit - 1)
            return
        }
        super.keyDown(with: event)
    }
}
