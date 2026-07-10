import Foundation
import Combine

public struct HistoryEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let text: String
    public let mode: String
    /// Pre-transformation transcript when an LLM stage ran (anyToEnglish /
    /// structuring): the user can always see what was HEARD vs what was
    /// written (TRANSCRIBE_TRANSLATE.md §3.6 — trust requires both).
    public var raw: String?
    /// On-demand translation attached later (TRANSLATION.md Flow A).
    public var translation: String?

    public init(text: String, mode: String, raw: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.text = text
        self.mode = mode
        self.raw = raw
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

    public func add(text: String, mode: LanguageMode, raw: String? = nil) {
        guard !text.isEmpty, SettingsStore.shared.historyEnabled else { return }
        entries.insert(HistoryEntry(text: text, mode: mode.rawValue, raw: raw), at: 0)
        prune()
        save()
    }

    /// Attaches an on-demand translation to an existing entry (Flow A) so the
    /// original and its translation live together, same 24 h rule.
    public func attachTranslation(_ translation: String, to id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].translation = translation
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
