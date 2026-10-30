import Foundation

/// The newest release on GitHub, as the in-app updater needs it (UPDATES.md).
public struct AppRelease: Equatable, Sendable {
    /// "0.8.0": the tag without its "v".
    public let version: String
    public let dmg: URL
    /// The DMG's published SHA-256 (release.sh writes one per DMG).
    public let checksum: URL

    public init(version: String, dmg: URL, checksum: URL) {
        self.version = version
        self.dmg = dmg
        self.checksum = checksum
    }

    /// The DMG the updater downloads, best first: its own copy (so GitHub's
    /// per-file counts show updates apart from new installs), then the
    /// versioned one older releases have.
    static func preferredNames(version: String) -> [String] {
        ["DesiDictation-update.dmg", "DesiDictation-\(version).dmg", "DesiDictation.dmg"]
    }

    /// Reads GitHub's `releases/latest` JSON. nil when it has no DMG with a
    /// checksum beside it: the updater never installs an unchecked file.
    public static func parse(_ json: Data) -> AppRelease? {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let tag = object["tag_name"] as? String,
              let assets = object["assets"] as? [[String: Any]] else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        var urls: [String: URL] = [:]
        for asset in assets {
            if let name = asset["name"] as? String,
               let link = asset["browser_download_url"] as? String, let url = URL(string: link) {
                urls[name] = url
            }
        }
        for name in preferredNames(version: version) {
            if let dmg = urls[name], let checksum = urls[name + ".sha256"] {
                return AppRelease(version: version, dmg: dmg, checksum: checksum)
            }
        }
        return nil
    }
}

public enum AppVersion {
    /// "0.10.0" is newer than "0.9.2": compared number by number, with a
    /// missing part counting as 0 ("0.8" == "0.8.0").
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        guard !a.isEmpty, !b.isEmpty else { return false }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int] {
        let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
        let numbers = trimmed.split(separator: ".").map { Int($0) }
        return numbers.contains(nil) ? [] : numbers.compactMap { $0 }
    }
}

/// Asks GitHub for the latest release. The request carries nothing about the
/// user: no IDs, no cookies, a fixed User-Agent (SECURITY_AUDIT.md).
public enum UpdateFeed {
    public static let latest = URL(string: "https://api.github.com/repos/s-samarth/desi-dictation/releases/latest")!

    /// `DESI_UPDATE_FEED` points it at a local file server, to rehearse an
    /// update end to end (UPDATES.md). The signature check still applies.
    public static var url: URL {
        ProcessInfo.processInfo.environment["DESI_UPDATE_FEED"].flatMap(URL.init(string:)) ?? latest
    }

    public static func fetch() async throws -> AppRelease? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Desi-Dictation-Updater", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return AppRelease.parse(data)
    }
}
