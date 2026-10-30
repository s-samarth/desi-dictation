import CryptoKit
import Foundation
import Security

/// Downloads a release, checks it three ways and swaps it in after the app
/// quits: what install.sh does, without a Terminal (UPDATES.md).
public enum UpdateInstaller {
    public enum Failure: Error, Equatable {
        case download, checksum, unpack, signature, version
    }

    /// Where the download and the unpacked app wait. Cleared on each try.
    static var stage: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.desi.dictation/Update", isDirectory: true)
    }

    /// The app can only replace itself where the user may write, which an
    /// admin account can in /Applications. Otherwise the DMG opens instead.
    public static func canReplace(_ bundle: URL) -> Bool {
        let fm = FileManager.default
        return bundle.pathExtension == "app"
            && fm.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
            && fm.isWritableFile(atPath: bundle.path)
    }

    /// Downloads `release` (or reuses one an earlier launch fetched) and
    /// returns the unpacked app, after checking that
    /// its SHA-256 matches the published one, that it is the version
    /// advertised and newer than `currentVersion`, and that it is signed by
    /// the same certificate as this app. That last check is what keeps the
    /// user's permissions: macOS ties them to the certificate.
    public static func prepare(_ release: AppRelease, currentVersion: String) async throws -> URL {
        if let app = alreadyStaged(release, currentVersion: currentVersion) { return app }
        let fm = FileManager.default
        try? fm.removeItem(at: stage)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        let dmg = stage.appendingPathComponent("DesiDictation.dmg")
        try await download(release.dmg, to: dmg)

        let expected = try await published(checksum: release.checksum)
        let actual = SHA256.hash(data: try Data(contentsOf: dmg)).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw Failure.checksum }

        let app = try unpack(dmg)
        try? fm.removeItem(at: dmg)
        try check(app, is: release, newerThan: currentVersion)
        return app
    }

    /// The app a previous launch already downloaded and checked for
    /// `release`, so a pending update isn't fetched again on every launch.
    /// Its signature is checked again; the DMG's checksum is gone with it.
    public static func alreadyStaged(_ release: AppRelease, currentVersion: String) -> URL? {
        let app = stage.appendingPathComponent("Desi Dictation.app")
        guard FileManager.default.fileExists(atPath: app.path),
              (try? check(app, is: release, newerThan: currentVersion)) != nil else { return nil }
        return app
    }

    private static func check(_ app: URL, is release: AppRelease, newerThan currentVersion: String) throws {
        let version = Bundle(url: app)?.infoDictionary?["CFBundleShortVersionString"] as? String
        guard version == release.version, AppVersion.isNewer(release.version, than: currentVersion)
        else { throw Failure.version }
        guard signedLikeThisApp(app) else { throw Failure.signature }
    }

    /// Starts a helper that waits for this process to exit, swaps `staged`
    /// into `destination` (restoring the old app if the copy fails) and opens
    /// it. Call it, then quit.
    public static func swapAfterExit(staged: URL, into destination: URL) throws {
        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).old")
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$4"
        if mv "$2" "$4"; then
          if ditto "$3" "$2"; then rm -rf "$4"; else rm -rf "$2"; mv "$4" "$2"; fi
        fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        rm -rf "$5"
        open "$2"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "desi-update", String(ProcessInfo.processInfo.processIdentifier),
                            destination.path, staged.path, backup.path, stage.path]
        try helper.run()
    }

    /// True when `bundle` satisfies this app's designated requirement: same
    /// bundle ID, same signing certificate. An ad-hoc build's requirement is
    /// its own hash, so a dev build never accepts an update.
    public static func signedLikeThisApp(_ bundle: URL) -> Bool {
        var me: SecCode?, myStatic: SecStaticCode?, requirement: SecRequirement?, other: SecStaticCode?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me,
              SecCodeCopyStaticCode(me, [], &myStatic) == errSecSuccess, let myStatic,
              SecCodeCopyDesignatedRequirement(myStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(bundle as CFURL, [], &other) == errSecSuccess, let other
        else { return false }
        let flags = SecCSFlags(rawValue: UInt32(kSecCSCheckNestedCode | kSecCSStrictValidate))
        return SecStaticCodeCheckValidity(other, flags, requirement) == errSecSuccess
    }

    private static func download(_ url: URL, to file: URL) async throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            let task = session.downloadTask(with: url) { location, response, _ in
                guard let location, (response as? HTTPURLResponse)?.statusCode == 200,
                      (try? FileManager.default.moveItem(at: location, to: file)) != nil
                else { return done.resume(throwing: Failure.download) }
                done.resume()
            }
            task.resume()
        }
    }

    /// The hex digest from a `shasum -a 256` line: "<hash>  DesiDictation.dmg".
    private static func published(checksum url: URL) async throws -> String {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let line = String(data: data, encoding: .utf8),
              let hash = line.split(separator: " ").first, hash.count == 64
        else { throw Failure.checksum }
        return hash.lowercased()
    }

    /// Mounts the DMG read-only, copies the app out and unmounts it.
    private static func unpack(_ dmg: URL) throws -> URL {
        let mount = stage.appendingPathComponent("mnt"), app = stage.appendingPathComponent("Desi Dictation.app")
        guard run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-quiet",
                                       "-mountpoint", mount.path, dmg.path]) else { throw Failure.unpack }
        defer { _ = run("/usr/bin/hdiutil", ["detach", "-quiet", "-force", mount.path]) }
        guard run("/usr/bin/ditto", [mount.appendingPathComponent("Desi Dictation.app").path, app.path])
        else { throw Failure.unpack }
        return app
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
