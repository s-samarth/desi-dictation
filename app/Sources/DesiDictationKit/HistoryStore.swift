import Foundation
import Combine

public struct HistoryEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let text: String
    public let mode: String

    public init(text: String, mode: String) {
        self.id = UUID()
        self.date = Date()
        self.text = text
        self.mode = mode
    }
}

/// Keeps the last 50 dictations, persisted as JSON in Application Support.
/// Local-only and clearable — privacy is a product feature.
public final class HistoryStore: ObservableObject {
    public static let shared = HistoryStore()
    @Published public private(set) var entries: [HistoryEntry] = []

    /// Rolling window: 24 hours, hard cap 200 entries (whichever is smaller).
    private let maxEntries = 200
    private let retention: TimeInterval = 24 * 3600
    private let fileURL: URL

    private init() {
        fileURL = AppPaths.supportDirectory.appendingPathComponent("history.json")
        load()
        prune()
    }

    public func add(text: String, mode: LanguageMode) {
        guard !text.isEmpty, SettingsStore.shared.historyEnabled else { return }
        entries.insert(HistoryEntry(text: text, mode: mode.rawValue), at: 0)
        prune()
        save()
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-retention)
        entries = Array(entries.filter { $0.date > cutoff }.prefix(maxEntries))
    }

    public func clear() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Shared filesystem locations.
public enum AppPaths {
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DesiDictation", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var modelsDirectory: URL {
        let dir = supportDirectory.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
