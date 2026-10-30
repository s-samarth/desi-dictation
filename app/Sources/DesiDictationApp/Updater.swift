import AppKit
import DesiDictationKit

/// Looks for a newer release by itself and installs it on one click: no
/// "Check for updates" to remember, no Terminal, no DMG (UPDATES.md).
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case upToDate
        case available(AppRelease)
        case downloading(AppRelease, Double)
        /// Checked and unpacked: waiting for a dictation to finish, then restarting.
        case restarting
        case failed(AppRelease, String)
    }
    @Published private(set) var state: State = .upToDate {
        didSet {
            #if DEBUG
            NSLog("[update] \(state)")
            #endif
        }
    }

    var hasUpdate: Bool { state != .upToDate }

    #if DEBUG
    /// UISnapshots: show a state without a real release.
    func preview(_ state: State) { self.state = state }
    #endif

    private static let lastCheckKey = "updateLastCheck"
    /// Offline checks fail quietly; the hourly timer tries again.
    private static let checkEvery: TimeInterval = 12 * 3600
    private var timer: Timer?

    private var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Checks shortly after launch (so a relaunch shows a pending update
    /// again), then every 12 hours while the app runs.
    func start() {
        guard currentVersion != nil else { return }   // a bare binary has nothing to update
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            await check(force: true)
            // Rehearsal hook (UPDATES.md): install as soon as one is found.
            if ProcessInfo.processInfo.environment["DESI_UPDATE_INSTALL_NOW"] == "1" { install() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.check() }
        }
    }

    func check(force: Bool = false) async {
        guard let current = currentVersion, state == .upToDate else { return }
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard force || Date().timeIntervalSince1970 - last > Self.checkEvery,
              let release = try? await UpdateFeed.fetch() else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        if AppVersion.isNewer(release.version, than: current) { state = .available(release) }
    }

    func install() {
        let release: AppRelease
        switch state {
        case .available(let r), .failed(let r, _): release = r
        default: return
        }
        guard let current = currentVersion else { return }
        let bundle = Bundle.main.bundleURL
        // Can't write where the app lives (not an admin, or a read-only
        // folder): hand over the DMG, as before.
        guard UpdateInstaller.canReplace(bundle) else {
            NSWorkspace.shared.open(release.dmg)
            return
        }
        state = .downloading(release, 0)
        Task {
            do {
                let app = try await UpdateInstaller.prepare(release, currentVersion: current) { fraction in
                    Task { @MainActor in Updater.shared.downloaded(fraction) }
                }
                state = .restarting
                await waitForIdle()
                try UpdateInstaller.swapAfterExit(staged: app, into: bundle)
                NSApp.terminate(nil)
            } catch {
                state = .failed(release, Self.message(for: error))
            }
        }
    }

    private func downloaded(_ fraction: Double) {
        if case .downloading(let release, _) = state { state = .downloading(release, fraction) }
    }

    /// Never restart in the middle of someone's sentence.
    private func waitForIdle() async {
        while true {
            switch DictationController.shared.phase {
            case .recording, .transcribing, .translating, .polishing:
                try? await Task.sleep(nanoseconds: 500_000_000)
            default: return
            }
        }
    }

    static func message(for error: Error) -> String {
        switch error as? UpdateInstaller.Failure {
        case .checksum: return "The download was damaged."
        case .signature: return "The download isn't signed by Desi Dictation, so it wasn't installed."
        case .version: return "The download wasn't the expected version."
        case .unpack: return "Couldn't open the update."
        case .download, .none: return "Couldn't download it. Check your internet."
        }
    }
}
