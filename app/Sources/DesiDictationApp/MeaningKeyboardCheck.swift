#if DEBUG
    import AppKit
    import DesiDictationKit

    /// Exercise the native Review text view without sending keys or pasting into
    /// the foreground app. All learning goes to a fresh, disposable defaults suite.
    @MainActor
    enum MeaningKeyboardCheck {
        static func run() {
            let suite = "meaning-keyboard-" + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            let learning = HinglishLearning(defaults: defaults)
            let text = "mera kam baaki hai"
            let questions = HinglishMeanings.questions(in: text)
            let context = questions[0].meaning!
            let cases = [("", text, nil), ("0", text, "kam"), ("1", "mera kaam baaki hai", "kaam")]
            func check(_ index: Int) {
                guard index < cases.count else {
                    defaults.removePersistentDomain(forName: suite)
                    print("Review keyboard passed: Enter, 0 + Enter, 1 + Enter")
                    NSApp.terminate(nil)
                    return
                }
                let (key, expected, learned) = cases[index]
                let request = ReviewRequest(
                    text: text, unsure: questions, scope: .hinglish,
                    offerWhenItFits: false, learning: true
                ) { result in
                    precondition(result == .paste(expected))
                    precondition(learning.meaningChoices.preferred(for: context) == learned)
                    check(index + 1)
                }
                let model = ReviewModel(request: request, learningStore: learning)
                let coordinator = ReviewTextEditor.Coordinator(model: model)
                let view = ReviewTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
                view.textStorage?.setAttributedString(ReviewTextView.attributed(request))
                view.delegate = coordinator
                coordinator.textView = view
                coordinator.jump(forward: true, from: 0)
                coordinator.textViewDidChangeSelection(Notification(name: NSTextView.didChangeSelectionNotification))
                precondition(model.currentIndex == 0)
                if !key.isEmpty {
                    let event = NSEvent.keyEvent(
                        with: .keyDown, location: .zero, modifierFlags: [],
                        timestamp: 0, windowNumber: 0, context: nil,
                        characters: key, charactersIgnoringModifiers: key,
                        isARepeat: false, keyCode: key == "0" ? 29 : 18)!
                    view.keyDown(with: event)
                }
                precondition(model.fixes.isEmpty)
                precondition(coordinator.textView(view, doCommandBy: #selector(NSResponder.insertNewline(_:))))
            }
            check(0)
        }
    }
#endif
