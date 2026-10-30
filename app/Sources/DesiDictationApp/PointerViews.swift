import SwiftUI

/// The callout under the menu-bar mic (MenuBarPointer). `arrowX` is where its
/// arrow sits from the left edge, so it points at the icon.
struct PointerCallout: View {
    let style: MenuBarPointer.Style
    let arrowX: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Arrow()
                .fill(Theme.accent)
                .frame(width: 20, height: 10)
                .offset(x: max(0, arrowX - 12))   // -10 for half the arrow, -2 for the shadow padding
            bubble
        }
        .padding(.horizontal, 2).padding(.bottom, 4)   // room for the shadow
        .fixedSize()
    }

    @ViewBuilder private var bubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch style {
            case .tour:
                Text("Desi Dictation lives up here")
                    .font(.system(size: 24, weight: .bold))
                Text("No Dock icon, no window to keep open. It waits in your menu bar, out of your way, ready in any app.")
                    .font(.system(size: 14))
                Text("Hold **Right ⌥**, speak, let go: your words land wherever you're typing.")
                    .font(.system(size: 14))
                Text("Click the mic for language, settings and history.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                HStack {
                    Button("Show me the menu") { MenuBarPointer.openMenu() }
                        .buttonStyle(PointerButton(prominent: true))
                    Button("Got it") { MenuBarPointer.shared.hide() }
                        .buttonStyle(PointerButton(prominent: false))
                }
                .padding(.top, 4)
            case .reminder:
                Text("Desi Dictation is up here")
                    .font(.system(size: 17, weight: .bold))
                Text("Click the mic for the menu, or hold **Right ⌥** to dictate.")
                    .font(.system(size: 13))
                Button("Open Desi Dictation") {
                    MenuBarPointer.shared.hide()
                    AppWindows.shared.showMain()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(width: style == .tour ? 380 : 290, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent, lineWidth: 2))
        .tint(Theme.accent)
    }
}

/// Shown when there's no icon to point at: behind the notch, or off screen.
struct PointerNotice: View {
    enum Reason { case behindNotch, offScreen }
    let reason: Reason

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(reason == .behindNotch ? "Your menu bar is full" : "Desi Dictation lives in your menu bar")
                .font(.system(size: 22, weight: .bold))
            Text(reason == .behindNotch
                 ? "Desi Dictation's mic icon is hidden behind the notch. Hold **⌘** and drag a few other icons out of the menu bar to make room."
                 : "Look for the mic at the top of your screen. If your menu bar hides itself, move the pointer to the top edge.")
                .font(.system(size: 14))
            Text("Dictation works either way: hold **Right ⌥**, speak, let go.")
                .font(.system(size: 14))
            HStack {
                Button("Open Desi Dictation") {
                    MenuBarPointer.shared.hide()
                    AppWindows.shared.showMain()
                }
                .buttonStyle(PointerButton(prominent: true))
                Button("Got it") { MenuBarPointer.shared.hide() }
                    .buttonStyle(PointerButton(prominent: false))
            }
            .padding(.top, 4)
        }
        .frame(width: 420, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent, lineWidth: 2))
        .tint(Theme.accent)
        .padding(4)
        .fixedSize()
    }
}

/// A saffron ring around the icon that breathes, so the eye finds it.
struct PulsingRing: View {
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Theme.accent, lineWidth: 2.5)
            .opacity(pulse ? 0.35 : 1)
            .scaleEffect(pulse ? 1.08 : 0.94)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

/// Saffron whether or not the panel is key: the pointer never takes focus,
/// and macOS greys a prominent button in a window that isn't key.
private struct PointerButton: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(prominent ? Theme.accent : Color.primary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

/// The callout's arrow, pointing up at the icon.
private struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
