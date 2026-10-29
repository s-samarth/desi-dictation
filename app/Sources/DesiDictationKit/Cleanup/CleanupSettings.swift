import Foundation
import Combine

/// The clean-up switches (FILLERS_AND_CORRECTIONS.md), apart from
/// SettingsStore so that file stays small.
public final class CleanupSettings: ObservableObject {
    public static let shared = CleanupSettings()
    private let d: UserDefaults

    /// um, uh, hmm, er are never words: on by default (user decision 2026-10-29).
    @Published public var removeSounds: Bool { didSet { d.set(removeSounds, forKey: "removeFillerSounds") } }
    /// Sometimes-fillers the context checker is sure of are removed without
    /// asking. Off by default: the user turns it on.
    @Published public var removeSureFillers: Bool { didSet { d.set(removeSureFillers, forKey: "removeSureFillers") } }

    public init(defaults: UserDefaults = .standard) {
        d = defaults
        removeSounds = defaults.object(forKey: "removeFillerSounds") as? Bool ?? true
        removeSureFillers = defaults.object(forKey: "removeSureFillers") as? Bool ?? false
    }
}
