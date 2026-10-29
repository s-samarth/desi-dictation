#if DEBUG
import AppKit
import SwiftUI
import DesiDictationKit

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
        // Short and long dictations, each in a panel sized the way ReviewPanel sizes it.
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 860)
        let short = ReviewLayout.size(for: "Ask cloud to send the deck to Cavya before the hakka review", on: screen)
        shots.append(("review", { AnyView(ReviewView(model: sampleReview(), size: short)) }, fitted(ReviewView(model: sampleReview(), size: short))))
        let long = ReviewLayout.size(for: longReviewText, on: screen)
        shots.append(("review-long", { AnyView(ReviewView(model: sampleReview(longReviewText), size: long)) },
                      fitted(ReviewView(model: sampleReview(longReviewText), size: long))))
        render(shots, into: directory)
    }

    typealias Shot = (String, () -> AnyView, NSSize)

    /// The size a window gives the view the way ReviewPanel hosts it.
    private static func fitted<V: View>(_ view: V) -> NSSize {
        let host = NSHostingView(rootView: view)
        host.sizingOptions = [.minSize]
        return host.fittingSize
    }

    /// A dictation with one low-confidence word and one sound-alike, and a fix already made.
    private static let longReviewText = String(repeating:
        "Ask cloud to send the deck to Cavya before the hakka review, and tell the team the numbers moved. ", count: 14)

    private static func sampleReview(_ text: String = "Ask cloud to send the deck to Cavya before the hakka review") -> ReviewModel {
        let unsure = ReviewPlanner.unsure(
            in: text,
            words: text.split(separator: " ").map {
                ScoredWord(text: String($0), confidence: $0 == "hakka" ? 0.31 : 0.95) },
            threshold: 0.61,
            sources: .init(entries: [DictionaryEntry(heard: "cloud", written: "Claude")],
                           screenTerms: ["Kavya", "Haka", "Hakka"]))
        let model = ReviewModel(request: ReviewRequest(text: text, unsure: unsure, scope: .english,
                                                       offerWhenItFits: true) { _ in })
        model.textChanged(text.replacingOccurrences(of: "Cavya", with: "Kavya"))
        model.currentIndex = 0
        return model
    }

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
