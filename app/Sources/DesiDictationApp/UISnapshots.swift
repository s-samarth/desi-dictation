#if DEBUG
import AppKit
import SwiftUI

/// Debug-only UI review: renders every window and tab to PNGs, then quits.
///
///     DESI_UI_SNAPSHOTS=/tmp/shots app/.build/debug/DesiDictationApp
///
/// Exists because a menu-bar (accessory) app's windows can't be captured by
/// screen-recording tools from a shell, and UI changes need before/after
/// pictures to be reviewed at all. Never compiled into release builds.
@MainActor
enum UISnapshots {
    static var directory: URL? {
        ProcessInfo.processInfo.environment["DESI_UI_SNAPSHOTS"].map(URL.init(fileURLWithPath:))
    }

    static func run(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var shots: [Shot] = SidebarItem.visible.map { item in
            ("main-\(item.rawValue)", {
                MainNav.shared.selection = item
                return AnyView(MainWindow())
            }, MainWindow.size)
        }
        // Long pages, whole: what a reader scrolls through.
        shots.append(("guide-full", { AnyView(GuidePane()) }, NSSize(width: 560, height: 2300)))
        shots.append(("onboarding", { AnyView(OnboardingView()) }, NSSize(width: 560, height: 640)))
        render(shots, into: directory)
    }

    typealias Shot = (String, () -> AnyView, NSSize)

    private static func render(_ shots: [Shot], into directory: URL) {
        guard let (name, makeView, size) = shots.first else {
            NSApp.terminate(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -4000, y: 0), size: size),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: makeView())
        // cacheDisplay skips the window's own background, so paint it here or
        // plain (non-Form) views come out as text on nothing.
        host.wantsLayer = true
        host.appearance = NSApp.effectiveAppearance
        host.effectiveAppearance.performAsCurrentDrawingAppearance {
            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        window.contentView = host
        window.orderFrontRegardless()
        // SwiftUI lays out on the next run-loop turns; AppKit-backed controls
        // (toggles, pickers) need a beat longer to draw.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            host.layoutSubtreeIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                let url = directory.appendingPathComponent("\(name).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
            window.orderOut(nil)
            render(Array(shots.dropFirst()), into: directory)
        }
    }
}
#endif
