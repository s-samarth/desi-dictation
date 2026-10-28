import Contacts
import Foundation

/// Contact names as vocabulary (opt-in), the way Dragon learns names from
/// sent mail and Apple's keyboards use Contacts. Names stay in memory, are
/// re-read when Contacts change, and are never copied to disk. A contact name
/// alone never overrules a real word (§3.4).
public final class ContactsVocabulary: @unchecked Sendable {
    public static let shared = ContactsVocabulary()

    private let lock = NSLock()
    private var cached: Set<String> = []
    private var observer: NSObjectProtocol?
    private let queue = DispatchQueue(label: "desi.vocab.contacts", qos: .utility)

    public var names: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return cached
    }

    public static var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    /// The bundle declares why it wants Contacts. macOS kills an app that asks
    /// without that string (e.g. a bare `swift run`), so we check first.
    public static var canAsk: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSContactsUsageDescription") != nil
    }

    /// Shows the system prompt if needed, then loads. `done` runs on main.
    public func enable(done: @escaping @MainActor (Bool) -> Void) {
        guard Self.canAsk else {
            Task { @MainActor in done(false) }
            return
        }
        CNContactStore().requestAccess(for: .contacts) { [weak self] granted, _ in
            if granted { self?.start() }
            Task { @MainActor in done(granted) }
        }
    }

    /// Loads names and follows changes. Safe to call repeatedly.
    public func start() {
        guard Self.isAuthorized else { return }
        reload()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange, object: nil, queue: nil
        ) { [weak self] _ in self?.reload() }
    }

    /// Forget everything (the toggle was turned off).
    public func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        lock.lock(); cached = []; lock.unlock()
    }

    private func reload() {
        queue.async { [weak self] in
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey] as [CNKeyDescriptor]
            var names = Set<String>()
            let request = CNContactFetchRequest(keysToFetch: keys)
            try? CNContactStore().enumerateContacts(with: request) { contact, _ in
                for part in [contact.givenName, contact.familyName, contact.nickname] {
                    for word in WordTokens.words(in: part) where word.count >= 3 { names.insert(word) }
                }
            }
            guard let self else { return }
            self.lock.lock(); self.cached = names; self.lock.unlock()
        }
    }
}
