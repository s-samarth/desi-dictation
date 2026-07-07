import AppKit
import Foundation
import Combine
import os.log

let controllerLog = Logger(subsystem: "com.desi.dictation", category: "controller")

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
    private var errorResetTask: Task<Void, Never>?

    /// Errors never brick the app: show, beep, auto-return to idle. The user
    /// can also just start dictating again immediately (see startRecording).
    private func transientError(_ message: String) {
        controllerLog.error("transient error: \(message, privacy: .public)")
        phase = .error(message)
        Sounds.error.play()
        errorResetTask?.cancel()
        errorResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if case .error = self.phase { self.phase = .idle }
        }
    }

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
        // Recording may start from idle OR from an error state — an earlier
        // failure must never require a relaunch (v0.2 user-reported bug).
        switch phase {
        case .idle, .error: break
        default: return
        }
        errorResetTask?.cancel()
        do {
            try audio.start()
            phase = .recording
            Sounds.start.play()
        } catch {
            transientError("Mic error: \(error.localizedDescription)")
        }
    }

    private func finishRecording() {
        let samples = audio.stop()
        guard samples.count > 8000 else {  // < 0.5 s: accidental tap, not an error worth a scare
            transientError("Too short — nothing captured. Ready again.")
            return
        }
        guard let modelPath = resolvedModelPath() else {
            transientError("No model for this mode — open Models to download one")
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
                // Nothing usable came out: say so explicitly (and that nothing
                // was copied), then auto-reset. State is never stuck.
                Task { @MainActor in
                    self.transientError(
                        "Couldn't transcribe (\(error.localizedDescription)) — nothing inserted or copied.")
                }
            }
        }
    }

    private func deliver(text: String, mode: LanguageMode, copyOnly: Bool) {
        guard !text.isEmpty else {
            transientError("No speech detected — nothing inserted or copied.")
            return
        }
        controllerLog.info("deliver: \(text.count, privacy: .public) chars, copyOnly=\(copyOnly, privacy: .public)")
        // The transcript is sacred: even if pasting into the target app fails,
        // it's in lastTranscript ("Copy Last" in the menu) and History.
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
