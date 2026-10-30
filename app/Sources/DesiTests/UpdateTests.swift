import Foundation
import DesiDictationKit

/// In-app updates (UPDATES.md): which release counts as newer, and which
/// DMG the updater picks from GitHub's release JSON.
func runUpdateTests() {
    T.begin("Updates — version order")
    T.expect(AppVersion.isNewer("0.8.0", than: "0.7.1"), "0.8.0 > 0.7.1")
    T.expect(AppVersion.isNewer("0.10.0", than: "0.9.2"), "numbers, not text: 0.10 > 0.9")
    T.expect(AppVersion.isNewer("v0.7.2", than: "0.7.1"), "a tag's v is ignored")
    T.expect(!AppVersion.isNewer("0.7.1", than: "0.7.1"), "the same version isn't an update")
    T.expect(!AppVersion.isNewer("0.8", than: "0.8.0"), "a missing part counts as 0")
    T.expect(!AppVersion.isNewer("0.7.0", than: "0.7.1"), "never a downgrade")
    T.expect(!AppVersion.isNewer("0.8.0-beta", than: "0.7.1"), "an unreadable version is ignored")

    T.begin("Updates — picking the DMG from the release")
    func release(_ names: [String], tag: String = "v0.8.0") -> AppRelease? {
        let assets = names.map { ["name": $0, "browser_download_url": "https://example.com/\($0)"] }
        let json = try! JSONSerialization.data(withJSONObject: ["tag_name": tag, "assets": assets])
        return AppRelease.parse(json)
    }
    let all = ["DesiDictation-0.8.0.dmg", "DesiDictation-0.8.0.dmg.sha256", "DesiDictation.dmg",
               "DesiDictation.dmg.sha256", "DesiDictation-update.dmg", "DesiDictation-update.dmg.sha256"]
    T.equal(release(all)?.dmg.lastPathComponent, "DesiDictation-update.dmg",
            "its own copy first, so updates count apart from installs")
    T.equal(release(all)?.checksum.lastPathComponent, "DesiDictation-update.dmg.sha256", "with its checksum")
    T.equal(release(all)?.version, "0.8.0", "version from the tag")
    T.equal(release(Array(all.prefix(4)))?.dmg.lastPathComponent, "DesiDictation-0.8.0.dmg",
            "an older release: the versioned DMG")
    T.expect(release(["DesiDictation-update.dmg", "DesiDictation-0.8.0.dmg"]) == nil,
             "no checksum, no update")
    T.expect(AppRelease.parse(Data("{\"message\":\"rate limited\"}".utf8)) == nil, "an error reply is ignored")

    T.begin("Updates — only a same-certificate app is accepted")
    T.expect(!UpdateInstaller.signedLikeThisApp(URL(fileURLWithPath: "/System/Applications/Calculator.app")),
             "an app signed by someone else is refused")

    T.begin("Updates — a pending update isn't downloaded again")
    let next = release(all)!
    T.expect(UpdateInstaller.alreadyStaged(next, currentVersion: "0.7.1") == nil,
             "nothing staged: download it")
}
