import SwiftUI
import DesiDictationKit

/// Setup's first page: what the app is, in three lines.
struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.bottom, 6)
                Text("Namaste! 🙏").font(.system(size: 40, weight: .bold))
                Text("Speak in English, Hinglish or हिन्दी. Your words appear wherever you type.")
                    .font(.title2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
            VStack(alignment: .leading, spacing: 18) {
                point("lock.shield", "Private by design",
                      "Everything runs on your Mac. Your voice and words never leave it.")
                point("text.cursor", "Works in every app",
                      "Mail, Slack, WhatsApp, Notes, your code editor: wherever your cursor is.")
                point("keyboard", "One key",
                      "Hold Right ⌥ Option, speak, let go. That's it.")
            }
            Text("Setup takes about two minutes.").font(.body).foregroundStyle(.secondary)
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title).foregroundStyle(Theme.accent).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.semibold))
                Text(detail).font(.title3).foregroundStyle(.secondary)
            }
        }
    }
}

/// Setup's last page: where the app lives and how to use it.
struct DoneStep: View {
    @ObservedObject var flow: OnboardingModel
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepTitle(title: "You're all set",
                      subtitle: "Desi Dictation lives in your menu bar, at the top-right of your screen.")
            MenuBarSketch()
            VStack(alignment: .leading, spacing: 12) {
                Text("Every day, it's three steps").font(.title3.weight(.semibold))
                howTo(1, Text("Click where you want to type."))
                howTo(2, Text("Hold \(Text(settings.hotkey.displayName).bold()) and speak."))
                howTo(3, Text("Let go. Your words appear. **Esc** cancels."))
            }
            Tip(symbol: "menubar.arrow.up.rectangle",
                text: "There's no Dock icon and no window to keep open. When you press Finish, the app restarts and points at the mic so you can't miss it.")
            if !flow.allDownloaded {
                Text("Finish unlocks when your models are downloaded.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func howTo(_ number: Int, _ text: Text) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.bold)).foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.accent, in: Circle())
            text.font(.title3)
        }
    }
}

/// A drawing of the menu bar's right end with the mic ringed in saffron,
/// so "look top-right" has a picture.
struct MenuBarSketch: View {
    var body: some View {
        HStack(spacing: 18) {
            Spacer()
            ForEach(["wifi", "battery.75percent", "magnifyingglass"], id: \.self) {
                Image(systemName: $0).foregroundStyle(.secondary)
            }
            Image(systemName: "mic")
                .font(.title3.weight(.semibold))
                .padding(8)
                .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 3))
            Text("Fri 9:41").foregroundStyle(.secondary)
        }
        .font(.title3)
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Text("Desi Dictation").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                .offset(x: -96, y: 18)
        }
        .padding(.bottom, 14)
    }
}
