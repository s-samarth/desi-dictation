#if DEBUG
import AppKit
import DesiDictationKit

/// Debug-only: opens the review panel over whatever app is in front, with a
/// sample dictation, so Paste / Copy / Close can be tried without speaking.
///
///     DESI_REVIEW_DEMO=1 app/.build/debug/desi-dictation
///
/// Click into a text field within 6 s; the panel opens there. Each outcome is
/// printed, with the app in front when the paste goes out.
@MainActor
enum ReviewDemo {
    static var enabled: Bool { ProcessInfo.processInfo.environment["DESI_REVIEW_DEMO"] != nil }

    static func run() {
        setvbuf(stdout, nil, _IONBF, 0)
        ReviewCoordinator.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { show() }
    }

    private static func show() {
        let text = "Ask cloud to send the deck to Cavya before the review."
        let unsure = ReviewPlanner.unsure(
            in: text,
            words: text.split(separator: " ").map { ScoredWord(text: String($0), confidence: 0.95) },
            threshold: 0.6,
            sources: .init(entries: [DictionaryEntry(heard: "cloud", written: "Claude")], screenTerms: ["Kavya"]))
        print("demo: panel opens over \(front())")
        DictationController.shared.onReview?(ReviewRequest(
            text: text, unsure: unsure, scope: .english, offerWhenItFits: false) { outcome in
                print("demo: outcome \(outcome); in front: \(front())")
                guard case .paste(let final) = outcome else { return }
                Task { @MainActor in
                    let result = await TextInserter.insert(final, copyOnly: false)
                    print("demo: insert \(result); key window ours: \(NSApp.keyWindow != nil)")
                }
            })
        // DESI_REVIEW_DEMO=click: press Paste with a real mouse click; =close: press ⌘W.
        let mode = ProcessInfo.processInfo.environment["DESI_REVIEW_DEMO"]
        if mode == "close" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                for down in [true, false] {
                    let key = CGEvent(keyboardEventSource: nil, virtualKey: 13, keyDown: down)  // W
                    key?.flags = .maskCommand
                    key?.post(tap: .cghidEventTap)
                }
            }
        }
        guard mode == "click" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let panel = NSApp.windows.first(where: { $0 is ReviewPanel && $0.isVisible }),
                  let screen = NSScreen.screens.first else { return }
            let point = CGPoint(x: panel.frame.maxX - 46, y: screen.frame.maxY - (panel.frame.minY + 27))
            print("demo: clicking Paste at \(point)")
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
                    .post(tap: .cghidEventTap)
            }
        }
    }

    private static func front() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
    }
}
#endif
