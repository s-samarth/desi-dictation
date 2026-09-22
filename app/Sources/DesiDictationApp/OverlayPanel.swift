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
        case .recording, .transcribing, .translating, .polishing: show()
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
            contentRect: NSRect(x: 0, y: 0, width: OverlayView.width, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0.92   // see-through: user asked to see what's behind
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
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            switch controller.phase {
            case .recording:
                Circle()
                    .fill(.red)
                    .frame(width: 9, height: 9)
                    .scaleEffect(pulse ? 1.0 : 0.65)
                    .opacity(pulse ? 1.0 : 0.55)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                               value: pulse)
                    .onAppear { pulse = true }
                    .onDisappear { pulse = false }
                // Thinking sessions look different — the user must know this
                // recording won't paste (it opens the review window instead).
                Text(controller.thinkingSessionArmed ? "🧠 Thinking — take your time" : "Listening")
                    .font(.system(size: 13, weight: .semibold))
                languageBadge
                Text("esc to cancel")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            case .transcribing:
                ProgressView().controlSize(.small)
                Text("Transcribing")
                    .font(.system(size: 13, weight: .semibold))
                languageBadge
            case .translating:
                // Second pipeline stage shown honestly (TRANSCRIBE_TRANSLATE.md
                // §3.4): the extra wait is a visible step, not a mystery.
                ProgressView().controlSize(.small)
                Text("Translating ✨")
                    .font(.system(size: 13, weight: .semibold))
                Text("esc pastes as heard")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            case .polishing:
                ProgressView().controlSize(.small)
                Text("Polishing ✨")
                    .font(.system(size: 13, weight: .semibold))
                Text("esc pastes as heard")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        )
        .fixedSize()   // capsule hugs its content; the clear panel is wider
        .frame(width: Self.width, height: 48)
    }

    /// Room for the longest row: "Listening · English · WhatsApp rule · esc…".
    static let width: CGFloat = 420

    /// Which language this dictation is in. Orange + the app's name when a
    /// per-app rule overrode the global language, so the switch is never silent.
    @ViewBuilder private var languageBadge: some View {
        if let language = controller.sessionLanguage {
            let text = language.ruleApp.map { "\(Self.shortName(language.mode)) · \($0) rule" }
                ?? Self.shortName(language.mode)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(language.ruleApp == nil
                    ? Color.secondary.opacity(0.18) : Color.orange.opacity(0.35)))
        }
    }

    private static func shortName(_ mode: LanguageMode) -> String {
        switch mode {
        case .english: return "English"
        case .hinglish: return "Hinglish"
        case .hindi: return "हिन्दी"
        case .anyToEnglish: return "→ English"
        }
    }
}
