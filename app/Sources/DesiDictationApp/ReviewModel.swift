import SwiftUI
import DesiDictationKit

/// State of one review (REVIEW_BEFORE_PASTE.md): the text being edited, the
/// underlined word under the caret, and the word fixes the user may keep.
@MainActor
final class ReviewModel: ObservableObject {
    /// How a fix made in review is kept.
    enum Keep: String, CaseIterable, Identifiable {
        case once, whenItFits, always   // the picker's order
        var id: String { rawValue }
        var label: String {
            switch self {
            case .once: return "Just this once"
            case .always: return "Always"
            case .whenItFits: return "When it fits"
            }
        }
        var mode: EntryMode? {
            switch self {
            case .once: return nil
            case .always: return .always
            case .whenItFits: return .whenItFits
            }
        }
    }

    struct Fix: Identifiable, Equatable {
        let pair: EditPair
        var keep: Keep
        var id: String { "\(pair.heard)→\(pair.typed)" }
    }

    let request: ReviewRequest
    @Published private(set) var text: String
    /// Index into `request.unsure` of the word at the caret, if any.
    @Published var currentIndex: Int?
    /// Underlines still in the text: a word fixed, deleted or marked
    /// "looks right" no longer counts.
    @Published var remaining: Int
    @Published var fixes: [Fix] = []
    private var finished = false
    /// Set by the panel: hides it before the paste goes out.
    var onClose: (() -> Void)?
    /// Set by the text view: replace the selected unsure word with alternative n.
    var pick: ((Int) -> Void)?
    /// Set by the text view: drop the underline of the selected word, unchanged.
    var looksRight: (() -> Void)?

    init(request: ReviewRequest) {
        self.request = request
        self.text = request.text
        self.remaining = request.unsure.count
    }

    var current: UnsureWord? { currentIndex.map { request.unsure[$0] } }

    /// Remembering needs a word list (not हिन्दी).
    var canRemember: Bool { request.scope != nil }

    var keepChoices: [Keep] {
        request.offerWhenItFits ? Keep.allCases : [.once, .always]
    }

    /// A fix is kept "Just this once" unless changed (user decision
    /// 2026-10-29, reversing the earlier "When it fits" default): remembering
    /// a word is the user's choice, never a side effect of fixing it.
    var defaultKeep: Keep { .once }

    func textChanged(_ new: String) {
        text = new
        let previous = Dictionary(fixes.map { ($0.id, $0.keep) }, uniquingKeysWith: { a, _ in a })
        fixes = ReviewPlanner.fixes(from: request.text, to: new).map { pair in
            var fix = Fix(pair: pair, keep: defaultKeep)
            fix.keep = previous[fix.id] ?? defaultKeep
            return fix
        }
    }

    /// Enter pastes, Esc copies; either way the chosen fixes are kept.
    func finish(paste: Bool) {
        guard !finished else { return }
        finished = true
        ReviewPlanner.remember(fixes.map { ($0.pair, $0.keep.mode) }, scope: request.scope)
        onClose?()
        let outcome: ReviewOutcome = paste ? .paste(text) : .copy(text)
        // Let focus settle back in the app we dictated into before ⌘V (FM#31).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [request] in
            request.complete(outcome)
        }
    }
}
