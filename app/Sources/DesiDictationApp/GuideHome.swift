import SwiftUI
import DesiDictationKit

/// The Guide's first section: where the app lives, and why there's no window
/// (user review 2026-10-30: opened from Spotlight, it "just shows in the top
/// bar"). It says this is by design, shows the real menu, and covers the
/// two shortcut settings people look for: the key, and hold vs tap.
struct GuideHome: View {
    @ObservedObject var settings = SettingsStore.shared

    var body: some View {
        Section {
            Text("Desi Dictation has no Dock icon and no window to keep open. **That's by design:** it stays out of your way and works in whatever app you're typing in.")
            Text("So opening it again, with ⌘ Space or from Applications, doesn't open a window. It's already running: it's the **mic at the top-right** of your screen. Click it and you get this menu:")
            HStack(alignment: .top, spacing: 18) {
                if let picture = Self.menuPicture {
                    Image(nsImage: picture)
                        .resizable().scaledToFit()
                        .frame(width: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(radius: 6, y: 2)
                }
                VStack(alignment: .leading, spacing: 10) {
                    step(1, "**To change anything** (language, model, your words, this Guide): click the mic → **Open Desi Dictation…**")
                    step(2, "**Otherwise, leave it be.** \(settings.activationMode == .pushToTalk ? "Hold" : "Tap") **\(settings.hotkey.displayName)** in any app and speak.")
                    step(3, "**Hold or tap?** Dictation → Shortcut → **Mode**. Push to Talk: hold while you speak, let go to insert. Toggle: tap to start, tap again to insert.")
                    step(4, "**A different key?** Dictation → Shortcut → **Key**: Right ⌘, Fn 🌐, Right ⌃, F13 and more.")
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 8) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Theme.accent, in: Circle())
                Text("Where it lives: your menu bar").font(.headline)
            }
        }
    }

    /// From the app bundle (build_app.sh copies it); a bare debug binary
    /// has no bundle, so it reads the repo's copy instead.
    private static var menuPicture: NSImage? {
        if let bundled = NSImage(named: "guide-menu") { return bundled }
        #if DEBUG
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return NSImage(contentsOf: repo.appendingPathComponent("Resources/guide-menu.png"))
        #else
        return nil
        #endif
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(.init(text)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
