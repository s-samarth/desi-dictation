import AppKit
import DesiDictationKit

/// Looks for a newer release by itself, downloads and checks it quietly, and
/// only then shows it: one click restarts into it. No "Check for updates" to
/// remember, no Terminal, no DMG, no waiting on a slow download (UPDATES.md).
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case upToDate
        /// Downloaded and checked: one click restarts into it.
        case ready(AppRelease, URL)
        /// Can't install it here (a folder the app can't write, or a
        /// download not signed like this app): the click opens the DMG.
        case manual(AppRelease)
        /// Waiting for a dictation to finish, then restarting.
        case restarting
        case failed(AppRelease, URL, String)
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
    private var checking = false

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
            // Rehearsal hook (UPDATES.md): install as soon as one is ready.
            if ProcessInfo.processInfo.environment["DESI_UPDATE_INSTALL_NOW"] == "1",
               case .ready = state { install() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.check() }
        }
    }

    /// Asks for the latest release and, if it's newer, downloads and checks
    /// it before showing anything. A failed download stays invisible and is
    /// tried again on the next hourly tick: the last-check time is only
    /// saved once there's nothing left to fetch.
    func check(force: Bool = false) async {
        guard let current = currentVersion, state == .upToDate, !checking else { return }
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard force || Date().timeIntervalSince1970 - last > Self.checkEvery else { return }
        checking = true
        defer { checking = false }
        guard let release = try? await UpdateFeed.fetch() else { return }
        guard AppVersion.isNewer(release.version, than: current) else { return markChecked() }
        guard UpdateInstaller.canReplace(Bundle.main.bundleURL) else {
            state = .manual(release)
            return markChecked()
        }
        do {
            state = .ready(release, try await UpdateInstaller.prepare(release, currentVersion: current))
            markChecked()
        } catch {
            #if DEBUG
            NSLog("[update] failed(\"\(Self.message(for: error))\")")
            #endif
            // Signed by someone else, or not the version promised: retrying
            // won't help, so hand over the DMG instead.
            if let failure = error as? UpdateInstaller.Failure, failure == .signature || failure == .version {
                state = .manual(release)
                markChecked()
            }
        }
    }

    private func markChecked() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
    }

    func install() {
        switch state {
        case .manual(let release):
            NSWorkspace.shared.open(release.dmg)
        case .ready(let release, let app), .failed(let release, let app, _):
            state = .restarting
            Task {
                await waitForIdle()
                do {
                    try UpdateInstaller.swapAfterExit(staged: app, into: Bundle.main.bundleURL)
                    NSApp.terminate(nil)
                } catch {
                    state = .failed(release, app, "Couldn't start the update.")
                }
            }
        default: return
        }
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
