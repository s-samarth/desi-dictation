import AppKit
import SwiftUI
import Combine
import DesiDictationKit

/// Floating recording indicator.
///
/// CRITICAL: the panel is `.nonactivatingPanel` and never becomes key — if it
/// stole focus, the target text field would lose focus and insertion would
/// break (see docs/SYSTEM_DESIGN.md). It only *shows* state; all input is global.
@MainActor
final class OverlayCoordinator {
    static let shared = OverlayCoordinator()
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    func start() {
        cancellable = DictationController.shared.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in self?.update(for: phase) }
    }

    private func update(for phase: DictationPhase) {
        switch phase {
        case .recording, .transcribing: show()
        default: hide()
        }
    }

    private func show() {
        if panel == nil { panel = makePanel() }
        position(panel!)
        panel!.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayView())
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct OverlayView: View {
    @ObservedObject var controller = DictationController.shared

    var body: some View {
        HStack(spacing: 8) {
            switch controller.phase {
            case .recording:
                Circle().fill(.red).frame(width: 10, height: 10)
                Text("Listening… (Esc to cancel)")
            case .transcribing:
                ProgressView().controlSize(.small)
                Text("Transcribing…")
            default:
                EmptyView()
            }
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(width: 180, height: 44)
    }
}
