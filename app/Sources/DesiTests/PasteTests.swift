import CoreGraphics
import Foundation
import DesiDictationKit

/// FM#31: the paste after stop, and what the user is told when it can't happen.
func runPasteTests() {
    T.begin("PasteGate — ⌘V waits for the hotkey's modifier (FM#31)")
    func step(copyOnly: Bool = false, trusted: Bool = true,
              held: CGEventFlags = [], waited: TimeInterval = 0) -> PasteGate.Step {
        PasteGate.step(copyOnly: copyOnly, trusted: trusted, held: held, waited: waited)
    }
    T.equal(step(), .paste, "nothing held → paste now")
    // The bug: toggle stop fires on Right ⌥ keyDown and a silent tail returns
    // in ~10 ms, so ⌥ is still down. Pasting then sends ⌥⌘V.
    T.equal(step(held: .maskAlternate), .wait, "⌥ still held → wait, don't send ⌥⌘V")
    T.equal(step(held: .maskShift), .wait, "⇧ held → wait")
    T.equal(step(held: .maskControl), .wait, "⌃ held → wait")
    T.equal(step(held: .maskCommand), .paste, "⌘ held doesn't change ⌘V → paste")
    T.equal(step(held: [.maskAlphaShift, .maskSecondaryFn]), .paste,
            "Caps Lock / fn don't block the paste")
    T.equal(step(held: .maskAlternate, waited: PasteGate.maxWait),
            .skip(.modifiersHeld), "still held at the timeout → skip, never ⌥⌘V")
    T.expect(PasteGate.maxWait >= 1.0, "the wait outlasts a normal key tap")
    T.equal(step(trusted: false), .skip(.noAccessibility),
            "no Accessibility → skip (macOS would drop the keystroke silently)")
    T.equal(step(copyOnly: true, trusted: false, held: .maskAlternate), .copyOnly,
            "copy-only mode never waits or posts")

    T.begin("DictationNotice — no silent endings (FM#31)")
    T.expect(DictationNotice.forOutcome(.pasted) == nil, "pasted → no notice")
    T.expect(DictationNotice.forOutcome(.copied) == nil, "copy-only by choice → no notice")
    for block in [PasteBlock.modifiersHeld, .noAccessibility] {
        let notice = DictationNotice.forOutcome(.pasteSkipped(block))
        T.equal(notice?.kind, .copied, "skipped paste (\(block)) → 'copied' notice")
        T.expect(notice?.message.contains("⌘V") == true, "…and it says to press ⌘V")
    }
    T.expect(DictationNotice.nothingHeard.hasPrefix("Didn't catch that"),
             "empty transcript says so in plain words")
    T.expect(DictationNotice.displaySeconds >= 2 && DictationNotice.displaySeconds <= 6,
             "notice is brief but readable")
}
