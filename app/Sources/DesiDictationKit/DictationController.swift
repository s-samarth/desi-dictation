import AppKit
import Foundation
import Combine

public enum DictationPhase: Equatable {
    case disabled
    case idle
    case recording
    case transcribing
    case error(String)
}

/// The conductor: hotkey → audio → engine → post-process → insert.
/// UI observes `phase`; everything heavy runs off the main thread on a single
/// serial queue (the engine is not thread-safe).
@MainActor
public final class DictationController: ObservableObject {
    public static let shared = DictationController()

    @Published public private(set) var phase: DictationPhase = .disabled
    @Published public private(set) var lastTranscript: String = ""

    // Accessed only on workQueue (serial) — safe despite nonisolated access.
    private nonisolated(unsafe) let engine = WhisperCppEngine()
    private let audio = AudioCapture()
    private let hotkeys = HotkeyManager()
    private let workQueue = DispatchQueue(label: "desi.dictation.engine", qos: .userInitiated)
    private var settings: SettingsStore { .shared }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        hotkeys.sessionActive = { [weak self] in
            if case .recording = self?.phase { return true }
            return false
        }
        hotkeys.onDictateDown = { [weak self] in self?.hotkeyDown() }
        hotkeys.onDictateUp = { [weak self] in self?.hotkeyUp() }
        hotkeys.onCancel = { [weak self] in self?.cancel() }

        // Mode switch may imply a different model — preload it so the next
        // dictation doesn't pay the load cost.
        SettingsStore.shared.$languageMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.modelChanged() }
            .store(in: &cancellables)
    }

    /// Best model for the current mode ("" pinned path = Auto).
    private func resolvedModelPath() -> String? {
        ModelManager.shared.resolveModel(
            for: settings.languageMode, pinnedPath: settings.modelPath)?.path
    }

    public var hotkeyTapActive: Bool { hotkeys.isActive }

    // MARK: - Lifecycle

    public func enable() {
        hotkeys.start(hotkey: settings.hotkey)
        switch hotkeys.tapMode {
        case .active, .listenOnly:
            phase = .idle
        case .failed:
            // Distinguish "never granted" from the ad-hoc-build stale-grant trap
            // (toggle shows ON in System Settings but macOS denies the new binary).
            let status = Permissions.check()
            var missing: [String] = []
            if !status.accessibility { missing.append("Accessibility") }
            if !status.inputMonitoring { missing.append("Input Monitoring") }
            phase = .error(missing.isEmpty
                ? "Stale permission — in Privacy Settings REMOVE (−) Desi Dictation from Accessibility & Input Monitoring, re-add, relaunch"
                : "Grant \(missing.joined(separator: " + ")) in Privacy Settings, then toggle Enable off/on")
        }
        preloadModelIfNeeded()
    }

    public func disable() {
        hotkeys.stop()
        audio.cancel()
        phase = .disabled
    }

    public func reloadHotkey() {
        guard phase != .disabled else { return }
        enable()
    }

    // MARK: - Hotkey handling

    private func hotkeyDown() {
        switch settings.activationMode {
        case .pushToTalk: startRecording()
        case .toggle:
            if case .recording = phase { finishRecording() } else { startRecording() }
        }
    }

    private func hotkeyUp() {
        guard settings.activationMode == .pushToTalk, case .recording = phase else { return }
        finishRecording()
    }

    // MARK: - Session

    private func startRecording() {
        guard phase == .idle else { return }
        do {
            try audio.start()
            phase = .recording
            Sounds.start.play()
        } catch {
            phase = .error(error.localizedDescription)
            Sounds.error.play()
        }
    }

    private func finishRecording() {
        let samples = audio.stop()
        guard let modelPath = resolvedModelPath() else {
            phase = .error("No model for this mode — open Models to download one")
            Sounds.error.play()
            return
        }
        phase = .transcribing
        let mode = settings.languageMode
        let rules = settings.replacementRules
        let useOllama = settings.ollamaEnabled && LicenseManager.shared.isPro
        let ollamaModel = settings.ollamaModel
        let prompt = settings.cleanupPrompt
        let copyOnly = settings.copyInsteadOfPaste

        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.loadModel(path: modelPath)
                let result = try self.engine.transcribe(samples: samples, mode: mode)
                var text = PostProcessor.applyReplacements(result.text, rules: rules)
                if useOllama, !text.isEmpty {
                    let semaphore = DispatchSemaphore(value: 0)
                    Task {
                        text = await PostProcessor.ollamaCleanup(
                            text, model: ollamaModel, prompt: prompt)
                        semaphore.signal()
                    }
                    semaphore.wait()
                }
                Task { @MainActor in self.deliver(text: text, mode: mode, copyOnly: copyOnly) }
            } catch {
                Task { @MainActor in
                    self.phase = .error(error.localizedDescription)
                    Sounds.error.play()
                }
            }
        }
    }

    private func deliver(text: String, mode: LanguageMode, copyOnly: Bool) {
        guard !text.isEmpty else {
            phase = .idle
            Sounds.error.play()
            return
        }
        lastTranscript = text
        HistoryStore.shared.add(text: text, mode: mode)
        TextInserter.insert(text, copyOnly: copyOnly)
        Sounds.finish.play()
        phase = .idle
    }

    public func cancel() {
        audio.cancel()
        if phase != .disabled { phase = .idle }
        Sounds.error.play()
    }

    // MARK: - Model management

    /// Loads a model on the worker queue (no-op if already resident).
    private nonisolated func loadModel(path: String) throws {
        if engine.isLoaded, engine.loadedModelPath == path { return }
        try engine.load(modelPath: path)
    }

    private func preloadModelIfNeeded() {
        guard let path = resolvedModelPath() else { return }
        workQueue.async { [weak self] in try? self?.loadModel(path: path) }
    }

    /// Called when the user changes model/mode — swaps the resident model.
    public func modelChanged() {
        guard let path = resolvedModelPath() else { return }
        workQueue.async { [weak self] in try? self?.loadModel(path: path) }
    }
}
