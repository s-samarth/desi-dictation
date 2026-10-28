import Foundation

/// What smart vocabulary just did, in words, so a user can see it working
/// (or see why it couldn't). Memory only, newest first, cleared on quit: it
/// holds words from your text, so it is never written to disk.
public struct VocabularyActivity: Identifiable, Equatable {
    public enum Kind: Equatable { case info, suggested, learned, fixed, problem }

    public let id = UUID()
    public let kind: Kind
    public let message: String
    public let date = Date()
}

@MainActor
public final class VocabularyActivityLog: ObservableObject {
    public static let shared = VocabularyActivityLog()
    public static let limit = 12

    @Published public private(set) var entries: [VocabularyActivity] = []

    public func add(_ kind: VocabularyActivity.Kind, _ message: String) {
        entries.insert(VocabularyActivity(kind: kind, message: message), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }

    public func clear() { entries = [] }
}
