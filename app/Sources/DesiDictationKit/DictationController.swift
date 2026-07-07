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

    private init() {
        hotkeys.sessionActive = { [weak self] in
            if case .recording = self?.phase { return true }
            return false
        }
        hotkeys.onDictateDown = { [weak self] in self?.hotkeyDown() }
        hotkeys.onDictateUp = { [weak self] in self?.hotkeyUp() }
        hotkeys.onCancel = { [weak self] in self?.cancel() }
    }

    public var hotkeyTapActive: Bool { hotkeys.isActive }

    // MARK: - Lifecycle

    public func enable() {
        hotkeys.start(hotkey: settings.hotkey)
        phase = hotkeys.isActive ? .idle : .error("Hotkey needs Input Monitoring permission")
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
                try self.loadModelIfNeeded()
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

    /// Loads the selected model on the worker queue (blocking that queue only).
    private nonisolated func loadModelIfNeeded() throws {
        let path = SettingsStore.shared.modelPath
        guard !path.isEmpty else { throw EngineError.modelNotLoaded }
        if engine.isLoaded, engine.loadedModelPath == path { return }
        try engine.load(modelPath: path)
    }

    private func preloadModelIfNeeded() {
        workQueue.async { [weak self] in try? self?.loadModelIfNeeded() }
    }

    /// Called when the user changes model in settings.
    public func modelChanged() {
        workQueue.async { [weak self] in
            self?.engine.unload()
            try? self?.loadModelIfNeeded()
        }
    }
}
