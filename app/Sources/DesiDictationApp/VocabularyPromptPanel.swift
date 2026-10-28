import AppKit
import SwiftUI
import Combine
import DesiDictationKit

/// The "Always write Rowan as Rohan?" popup (AUTO_VOCABULARY.md §2a), shown
/// just above the dictation overlay.
///
/// Unlike the overlay it takes clicks, but it still never takes keyboard
/// focus: `canBecomeKey` is false and the panel is non-activating, so the
/// text field you were typing in keeps the caret. If you ignore the popup, the
/// proposal waits in Vocabulary → Suggestions.
@MainActor
final class VocabularyPromptCoordinator {
    static let shared = VocabularyPromptCoordinator()
    private var panel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []
    private var hideTask: Task<Void, Never>?

    /// How long each kind of message stays up.
    static let suggestionSeconds: Double = 12
    static let acknowledgementSeconds: Double = 4

    func start() {
        let store = AutoVocabularyStore.shared
        store.$liveSuggestion.combineLatest(store.$liveAcknowledgement)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] suggestion, note in
                self?.update(showing: suggestion != nil || note != nil,
                             seconds: suggestion != nil ? Self.suggestionSeconds : Self.acknowledgementSeconds)
            }
            .store(in: &cancellables)
    }

    private func update(showing: Bool, seconds: Double) {
        hideTask?.cancel()
        guard showing else { panel?.orderOut(nil); return }
        if panel == nil { panel = makePanel() }
        position(panel!)
        panel!.orderFrontRegardless()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // Timing out leaves the suggestion queued; only the popup goes.
            AutoVocabularyStore.shared.liveSuggestion = nil
            AutoVocabularyStore.shared.liveAcknowledgement = nil
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NonKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 56),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = FirstClickHostingView(rootView: VocabularyPromptView())
        return panel
    }

    /// Centered, just above the overlay capsule (OverlayCoordinator.position).
    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                     y: frame.minY + 52 + OverlayView.height + 6))
    }

    static let width: CGFloat = 580
}

/// Clicks work, focus never moves.
private final class NonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The first click on a window that isn't key must press the button, not
/// just "activate" the window.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct VocabularyPromptView: View {
    @ObservedObject var store = AutoVocabularyStore.shared

    var body: some View {
        HStack(spacing: 10) {
            if let suggestion = store.liveSuggestion {
                Image(systemName: "text.badge.plus").foregroundStyle(Color.accentColor)
                (Text("Always write ") + Text(suggestion.heard).bold()
                    + Text(" as ") + Text(suggestion.written).bold()
                    + Text(" in \(suggestion.scope.label)?"))
                    .font(.system(size: 13))
                    .lineLimit(1)
                Button("Add") { store.accept(suggestion) }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                if AutoVocabularyStore.canOfferWhenItFits(suggestion) {
                    Button("Only when it fits") { store.acceptWhenItFits(suggestion) }
                        .controlSize(.small)
                        .help("Write it only when the sentence is about it (checked on your Mac)")
                }
                Button("Not now") { store.dismiss(suggestion) }
                    .controlSize(.small)
            } else if let note = store.liveAcknowledgement {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(note).font(.system(size: 13)).lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)))
        .fixedSize()
        .frame(width: VocabularyPromptCoordinator.width, height: 56)
    }
}
