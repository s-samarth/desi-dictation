import AppKit
import SwiftUI
import DesiDictationKit

/// The editable text of the review panel. Unsure words carry an attribute
/// holding their index, so the underline moves with the word as the user
/// types around it. Tab / ⇧Tab jump between them, 1–5 pick an alternative
/// while one is selected, Enter pastes, Esc copies.
struct ReviewTextEditor: NSViewRepresentable {
    @ObservedObject var model: ReviewModel

    static let unsureKey = NSAttributedString.Key("desiUnsure")

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let view = ReviewTextView(frame: .zero)
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.drawsBackground = false
        scroll.documentView = view
        let text = ReviewTextView.attributed(model.request)
        view.textStorage?.setAttributedString(text)
        view.typingAttributes = ReviewTextView.plain
        view.isRichText = false
        view.allowsUndo = true
        view.textContainerInset = NSSize(width: 6, height: 8)
        view.delegate = context.coordinator
        context.coordinator.textView = view
        model.pick = { [weak coordinator = context.coordinator] n in coordinator?.pick(n) }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
            context.coordinator.jump(forward: true, from: 0)
        }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: ReviewModel
        weak var textView: NSTextView?

        init(model: ReviewModel) { self.model = model }

        func textDidChange(_ notification: Notification) {
            guard let view = textView else { return }
            view.typingAttributes = ReviewTextView.plain   // typing never extends an underline
            model.textChanged(view.string)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = textView, let storage = view.textStorage, storage.length > 0 else { return }
            let at = min(view.selectedRange().location, storage.length - 1)
            model.currentIndex = storage.attribute(ReviewTextEditor.unsureKey, at: at, effectiveRange: nil) as? Int
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertTab(_:)):
                jump(forward: true, from: NSMaxRange(textView.selectedRange()))
            case #selector(NSResponder.insertBacktab(_:)):
                jump(forward: false, from: textView.selectedRange().location)
            case #selector(NSResponder.insertNewline(_:)):
                model.finish(paste: true)
            case #selector(NSResponder.cancelOperation(_:)):
                model.finish(paste: false)
            default:
                return false
            }
            return true
        }

        /// Selects the next (or previous) unsure word, wrapping around.
        func jump(forward: Bool, from location: Int) {
            guard let view = textView, let storage = view.textStorage else { return }
            var runs: [NSRange] = []
            storage.enumerateAttribute(ReviewTextEditor.unsureKey,
                                       in: NSRange(location: 0, length: storage.length)) { value, range, _ in
                if value != nil { runs.append(range) }
            }
            guard !runs.isEmpty else { return }
            let next = forward
                ? runs.first { $0.location >= location } ?? runs[0]
                : runs.last { NSMaxRange($0) <= location } ?? runs[runs.count - 1]
            view.setSelectedRange(next)
            view.scrollRangeToVisible(next)
        }

        /// Replaces the selected unsure word with alternative `n` (0-based).
        func pick(_ n: Int) {
            guard let view = textView, let storage = view.textStorage,
                  let index = model.currentIndex, n < model.request.unsure[index].alternatives.count else { return }
            let word = model.request.unsure[index].alternatives[n]
            var range = NSRange(location: 0, length: 0)
            guard storage.attribute(ReviewTextEditor.unsureKey, at: view.selectedRange().location,
                                    effectiveRange: &range) != nil else { return }
            guard view.shouldChangeText(in: range, replacementString: word) else { return }
            storage.replaceCharacters(in: range, with: NSAttributedString(string: word, attributes: ReviewTextView.plain))
            view.didChangeText()
            jump(forward: true, from: range.location + (word as NSString).length)
        }
    }
}

/// Digits pick an alternative while an unsure word is selected; otherwise they type.
final class ReviewTextView: NSTextView {
    static let plain: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.labelColor,
    ]

    static func attributed(_ request: ReviewRequest) -> NSAttributedString {
        let out = NSMutableAttributedString(string: request.text, attributes: plain)
        for (i, unsure) in request.unsure.enumerated() {
            let range = NSRange(unsure.range, in: request.text)
            out.addAttributes([
                ReviewTextEditor.unsureKey: i,
                .underlineStyle: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue,
                .underlineColor: NSColor(Theme.accent),
            ], range: range)
        }
        return out
    }

    override func keyDown(with event: NSEvent) {
        if let chars = event.charactersIgnoringModifiers, chars.count == 1,
           let digit = Int(chars), (1...ReviewAlternatives.limit).contains(digit),
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
           selectedRange().length > 0,
           let coordinator = delegate as? ReviewTextEditor.Coordinator,
           coordinator.model.currentIndex != nil {
            coordinator.pick(digit - 1)
            return
        }
        super.keyDown(with: event)
    }
}
