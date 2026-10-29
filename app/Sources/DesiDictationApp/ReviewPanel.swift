import AppKit
import SwiftUI
import Combine
import DesiDictationKit

/// Shows Review before paste (REVIEW_BEFORE_PASTE.md) for one dictation.
///
/// The panel is `.nonactivatingPanel` but *can* become key: it takes the
/// keyboard without making Desi Dictation the active app, so the app the user
/// dictated into stays active and gets the ⌘V when the panel closes. The
/// recording overlay never takes focus (OverlayPanel.swift); this one must,
/// because the user types into it.
@MainActor
final class ReviewCoordinator {
    static let shared = ReviewCoordinator()
    private var panel: ReviewPanel?
    private var model: ReviewModel?
    private var phaseWatch: AnyCancellable?

    func start() {
        DictationController.shared.onReview = { [weak self] request in self?.show(request) }
        // A new dictation while one waits: keep the old words on the clipboard.
        phaseWatch = DictationController.shared.$phase
            .filter { $0 == .recording }
            .sink { [weak self] _ in self?.model?.finish(paste: false) }
    }

    private func show(_ request: ReviewRequest) {
        model?.finish(paste: false)   // never two at once
        let model = ReviewModel(request: request)
        model.onClose = { [weak self] in self?.close() }
        self.model = model
        let panel = ReviewPanel(content: ReviewView(model: model))
        position(panel)
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
        model = nil
    }

    /// Upper third of the screen the user is on, clear of the overlay at the bottom.
    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                     y: frame.minY + frame.height * 0.62))
    }
}

/// A floating, non-activating panel that still accepts the keyboard.
final class ReviewPanel: NSPanel {
    init<Content: View>(content: Content) {
        let host = NSHostingView(rootView: content)
        host.layout()
        super.init(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                   styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
