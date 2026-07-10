import AppKit
import Foundation
import Combine

/// One per-app rule: dictating while this app is frontmost uses this language.
public struct AppModeRule: Codable, Identifiable, Equatable {
    public var id: String { bundleID }
    public let bundleID: String
    public let appName: String
    public var mode: LanguageMode
}

/// Per-app language memory (IDEAS.md #4; competitors/PATTERNS.md §1 — all four
/// majors have it). WhatsApp → Hinglish, Mail → English, once — then zero
/// mode-switches a day. Rules are explicit (user sets them from the menu), so
/// behavior stays predictable; we deliberately do NOT auto-learn from usage,
/// which would lock in whatever mode a user happened to try once.
public final class AppModeStore: ObservableObject {
    public static let shared = AppModeStore()

    @Published public private(set) var rules: [AppModeRule] = []
    /// The app the user is actually working in (our own menu clicks excluded) —
    /// where a dictation would paste. Tracked continuously because at
    /// menu-interaction time the frontmost app can already be us.
    @Published public private(set) var currentTarget: (bundleID: String, appName: String)?

    private let fileURL: URL
    private var observer: NSObjectProtocol?

    public init(fileURL: URL = AppPaths.supportDirectory
        .appendingPathComponent("appmodes.json")) {
        self.fileURL = fileURL
        load()
        if let front = NSWorkspace.shared.frontmostApplication {
            noteActivated(front)
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
            self?.noteActivated(app)
        }
    }

    private func noteActivated(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier
        else { return }
        currentTarget = (bundleID, app.localizedName ?? bundleID)
    }

    // MARK: - Rules

    public func mode(for bundleID: String) -> LanguageMode? {
        rules.first { $0.bundleID == bundleID }?.mode
    }

    /// The language this dictation should use, given the app the user is in.
    /// nil = no rule → follow the global setting.
    public func modeForCurrentTarget() -> LanguageMode? {
        guard let target = currentTarget else { return nil }
        return mode(for: target.bundleID)
    }

    public func set(_ mode: LanguageMode, bundleID: String, appName: String) {
        rules.removeAll { $0.bundleID == bundleID }
        rules.append(AppModeRule(bundleID: bundleID, appName: appName, mode: mode))
        rules.sort { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        save()
    }

    public func removeRule(bundleID: String) {
        rules.removeAll { $0.bundleID == bundleID }
        save()
    }

    // MARK: - Persistence (same pattern as HistoryStore)

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AppModeRule].self, from: data)
        else { return }
        rules = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
