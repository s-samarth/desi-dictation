import AppKit
import SwiftUI
import DesiDictationKit

/// The menu's update line, just under the status line (UPDATES.md).
struct UpdateMenuItem: View {
    @ObservedObject var updater = Updater.shared

    var body: some View {
        switch updater.state {
        case .upToDate:
            EmptyView()
        case .ready(let release, _):
            Button("⬆︎ Update to v\(release.version) (click to install)") { updater.install() }
            Divider()
        case .manual(let release):
            Button("⬆︎ v\(release.version) is out (click to download)") { updater.install() }
            Divider()
        case .restarting:
            Text("Restarting to finish the update…")
            Divider()
        case .failed(_, _, let message):
            Button("Update failed: \(message) Try again") { updater.install() }
            Divider()
        }
    }
}

/// The same, across the top of the app's window.
struct UpdateBanner: View {
    @ObservedObject var updater = Updater.shared

    var body: some View {
        if let line {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(Theme.accent)
                Text(line.text).font(.callout)
                Spacer()
                if let action = line.action {
                    Button(action) { updater.install() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.accent.opacity(0.12))
        }
    }

    private var line: (text: String, action: String?)? {
        switch updater.state {
        case .upToDate: return nil
        case .ready(let release, _):
            return ("Desi Dictation \(release.version) is ready. Nothing to set up again.", "Update now")
        case .manual(let release):
            return ("Desi Dictation \(release.version) is out.", "Download")
        case .restarting: return ("Restarting to finish the update…", nil)
        case .failed(_, _, let message): return ("Update failed: \(message)", "Try again")
        }
    }
}

/// The menu-bar mic, with a dot while an update waits. Template images, so
/// macOS tints both for a light or dark menu bar.
enum MenuBarIcon {
    static func image(_ symbol: String, dot: Bool) -> NSImage {
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Desi Dictation")
        else { return NSImage() }
        guard dot else { return base }
        // A slightly wider canvas, so the dot sits beside the mic's head
        // rather than on it.
        let side = (base.size.height * 0.36).rounded()
        let size = NSSize(width: base.size.width + side * 0.6, height: base.size.height)
        let badged = NSImage(size: size, flipped: false) { rect in
            base.draw(in: NSRect(origin: .zero, size: base.size))
            let spot = NSRect(x: rect.maxX - side, y: rect.maxY - side, width: side, height: side)
            // A clear ring around the dot keeps it apart from the mic.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: spot.insetBy(dx: -1.2, dy: -1.2)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(ovalIn: spot).fill()
            return true
        }
        badged.isTemplate = true
        badged.accessibilityDescription = "Desi Dictation, update available"
        return badged
    }
}
