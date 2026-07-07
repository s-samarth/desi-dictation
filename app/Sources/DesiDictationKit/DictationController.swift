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

        // Start cue plays when the mic is ACTUALLY capturing (not at keypress) —
        // "speak after the tink" then never loses first words.
        audio.onFirstAudio = { Sounds.start.play() }

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
            // NOTE: mic is NOT warmed here — the orange indicator must appear
            // only around actual dictation (user feedback, v0.4.1). Warm-up
            // happens at keypress; a 20 s post-dictation warm window keeps
            // rapid follow-ups instant (see scheduleCoolDown).
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
        stopChunkTicker()
        audio.cancelSession()
        audio.coolDown()
        phase = .disabled
    }

    /// Applies the mic-warm setting change immediately.
    public func micWarmChanged() {
        if !settings.micWarm { audio.coolDown() }
    }

    // MARK: - Warm window (privacy-respecting instant restarts)

    private var coolDownTask: Task<Void, Never>?

    /// Keep the mic warm for 20 s after a dictation (instant repeat starts,
    /// pre-roll active), then release it — the orange mic indicator must not
    /// live in the menu bar permanently (user feedback, v0.4.1).
    private func scheduleCoolDown() {
        coolDownTask?.cancel()
        guard settings.micWarm else { audio.coolDown(); return }
        coolDownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if case .recording = self.phase { return }
            self.audio.coolDown()
        }
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

    // MARK: - Incremental chunking (perceived-latency fix, v0.4)
    // While the user speaks, completed ~12 s stretches are transcribed in the
    // background (cut at quiet moments; forced at 20 s). On release only the
    // tail remains → even multi-minute dictations insert in ~1 s.

    /// Accessed only on workQueue (serial) — safe despite nonisolated access.
    private nonisolated(unsafe) var pendingParts: [String] = []
    private var chunkedUpToSample = 0
    private var chunkTicker: Task<Void, Never>?

    private func startChunkTicker(modelPath: String, mode: LanguageMode) {
        chunkedUpToSample = 0
        workQueue.async { [weak self] in self?.pendingParts = [] }
        chunkTicker = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard case .recording = self.phase else { continue }
                let total = self.audio.sessionSampleCount
                let pending = total - self.chunkedUpToSample
                guard pending >= 12 * 16000 else { continue }
                // Cut at a quiet moment, or force at 20 s so memory of a bad
                // cut is bounded to one chunk.
                let tail = self.audio.snapshotSession(fromSample: total - 4000, toSample: total)
                let quiet = (tail.map(abs).max() ?? 0) < 0.01
                guard quiet || pending >= 20 * 16000 else { continue }
                let chunk = self.audio.snapshotSession(
                    fromSample: self.chunkedUpToSample, toSample: total)
                self.chunkedUpToSample = total
                self.workQueue.async { [weak self] in
                    guard let self else { return }
                    if let text = try? self.transcribeRaw(chunk, path: modelPath, mode: mode),
                       !text.isEmpty {
                        self.pendingParts.append(text)
                    }
                }
            }
        }
    }

    private func stopChunkTicker() {
        chunkTicker?.cancel()
        chunkTicker = nil
    }

    private nonisolated func transcribeRaw(
        _ samples: [Float], path: String, mode: LanguageMode
    ) throws -> String {
        try loadModel(path: path)
        return try engine.transcribe(samples: samples, mode: mode).text
    }

    private func startRecording() {
        // Recording may start from idle OR from an error state — an earlier
        // failure must never require a relaunch (v0.2 user-reported bug).
        switch phase {
        case .idle, .error: break
        default: return
        }
        errorResetTask?.cancel()
        guard let modelPath = resolvedModelPath() else {
            transientError("No model for this mode — open Models to download one")
            return
        }
        do {
            coolDownTask?.cancel()
            let wasWarm = audio.isWarm
            if settings.micWarm, !wasWarm { try? audio.warmUp() }
            try audio.beginSession()
            phase = .recording
            if wasWarm { Sounds.start.play() }   // cold path: onFirstAudio plays it
            startChunkTicker(modelPath: modelPath, mode: settings.languageMode)
        } catch {
            transientError("Mic error: \(error.localizedDescription)")
        }
    }

    private func finishRecording() {
        stopChunkTicker()
        let samples = audio.endSession()
        scheduleCoolDown()
        let tailStart = chunkedUpToSample
        chunkedUpToSample = 0
        guard samples.count > 3200 else {  // < 0.2 s: accidental tap
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
                // Chunk jobs queued ahead of us on this serial queue have
                // already run; only the tail is left to transcribe.
                let tail = Array(samples[min(tailStart, samples.count)...])
                var parts = self.pendingParts
                self.pendingParts = []
                if tail.count > 1600 {
                    let text = try self.transcribeRaw(tail, path: modelPath, mode: mode)
                    if !text.isEmpty { parts.append(text) }
                }
                var text = parts.joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                text = PostProcessor.applyReplacements(text, rules: rules)
                if useOllama, !text.isEmpty {
                    let semaphore = DispatchSemaphore(value: 0)
                    Task { [t = text] in
                        text = await PostProcessor.ollamaCleanup(
                            t, model: ollamaModel, prompt: prompt)
                        semaphore.signal()
                    }
                    semaphore.wait()
                }
                Task { @MainActor in self.deliver(text: text, mode: mode, copyOnly: copyOnly) }
            } catch {
                // Nothing usable came out: say so explicitly (and that nothing
                // was copied), then auto-reset. State is never stuck.
                self.pendingParts = []
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
        stopChunkTicker()
        audio.cancelSession()
        scheduleCoolDown()
        workQueue.async { [weak self] in self?.pendingParts = [] }
        chunkedUpToSample = 0
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
