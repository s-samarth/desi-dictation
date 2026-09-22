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
    /// anyToEnglish mode: LLM translation stage (shown as its own overlay
    /// stage so the longer wait is understood, not mysterious).
    case translating
    /// Tone rewrite / thought structuring stage.
    case polishing
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
    /// Stage timings for the last dictation (PERF_RCA_2026-08.md).
    @Published public private(set) var lastTimings: DictationTimings?

    /// Engine-call accounting for the session in progress. Touched on the
    /// workQueue and on main between sessions — never concurrently.
    private nonisolated(unsafe) var engineCalls = 0
    private nonisolated(unsafe) var engineSeconds = 0.0
    private var releaseTime: Date?
    private var sessionAudioSeconds = 0.0

    // Accessed only on workQueue (serial) — safe despite nonisolated access.
    // The router picks whisper.cpp or Parakeet from the model file.
    private nonisolated(unsafe) let engine = EngineRouter()
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
            switch self?.phase {
            // Esc must also work while an LLM stage runs — a hung local model
            // must never hold the user's words hostage (cancel pastes them).
            case .recording, .translating, .polishing: return true
            default: return false
            }
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

        // Same reason, for per-app rules: switching apps can change the mode,
        // and a mode can imply a different model. Without this the swap runs
        // lazily inside the transcribing phase and the user pays the load time
        // as dictation latency (PERF_RCA_2026-08.md RC5).
        AppModeStore.shared.$currentTarget
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.settings.perAppModes, self.phase == .idle else { return }
                self.modelChanged()
            }
            .store(in: &cancellables)
    }

    /// Best model for a mode — the language's own pin, or Auto if it has none.
    private func resolvedModelPath(for mode: LanguageMode) -> String? {
        ModelManager.shared.resolveModel(
            for: mode, pinnedPath: settings.modelPath(for: mode))?.path
    }

    /// Language for the NEXT dictation: a per-app rule for the app the user is
    /// in wins over the global setting (IDEAS #4 — zero mode-switches a day).
    /// With AI features switched off, LLM modes degrade to plain Hinglish.
    private func effectiveMode() -> LanguageMode {
        var mode = settings.languageMode
        if settings.perAppModes, let ruled = AppModeStore.shared.modeForCurrentTarget() {
            mode = ruled
        }
        if mode.needsLLM, !settings.aiFeaturesEnabled { return .hinglish }
        return mode
    }

    /// Mode captured at session start — per-app rules must not flip mid-session
    /// if the user switches apps while speaking.
    private var sessionMode: LanguageMode = .hinglish

    public var hotkeyTapActive: Bool { hotkeys.isActive }

    // MARK: - Lifecycle

    public func enable() {
        // enable() is also the "settings changed" path (reloadHotkey). If it
        // runs mid-session it must tear the session down, or the chunk ticker
        // is orphaned: it keeps polling forever and the NEXT dictation starts a
        // second one, so every chunk gets transcribed twice — compounding for
        // the life of the process (PERF_RCA_2026-08.md RC5).
        stopChunkTicker()
        audio.cancelSession()
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

    /// Frees the model before the process exits. ggml's Metal backend checks,
    /// in a static destructor run by exit(), that every GPU buffer was freed —
    /// a model still resident at Quit made every quit a SIGABRT crash report
    /// (FM#27). `sync` waits out an in-flight transcription: freeing the
    /// model under it would crash too.
    public func shutdown() {
        disable()
        workQueue.sync { engine.unload() }
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
    // While the user speaks, completed stretches are transcribed in the
    // background; on release only the tail remains → even multi-minute
    // dictations insert quickly.
    //
    // Thresholds re-derived from measurement in v0.6.1 (PERF_RCA_2026-08.md):
    // whisper always encodes a padded 30 s window, so a chunk call costs the
    // SAME ~1.5 s (M3) / ~3 s (M1 Air) whether it holds 2 s of speech or 30 s.
    // The old 12 s cut therefore taxed every ordinary dictation with extra
    // full-price calls — and the tail queues behind any chunk still decoding on
    // this serial queue. So: don't chunk short dictations at all, and when we
    // do chunk, make each chunk far longer than the call it costs.

    /// No chunking below this — a normal dictation should cost exactly one call.
    public nonisolated static let chunkFloorSamples = 30 * 16000        // 30 s of speech
    /// Minimum audio per chunk once chunking starts.
    public nonisolated static let chunkEverySamples = 25 * 16000        // 25 s
    /// Cut here even mid-sentence, so one bad cut can't poison more than this.
    public nonisolated static let chunkForceSamples = 35 * 16000        // 35 s
    /// Below this the "tail" is key-release noise, not speech.
    public nonisolated static let tailFloorSamples = 5600               // 0.35 s

    /// The (floor, every, force) chunk thresholds for a session in `mode`.
    /// हिन्दी is the exception (FM#26): the engine splits anything over 12 s
    /// into separate whisper calls to stay under the decoder's token budget,
    /// so those calls are paid either way — make them while the user is still
    /// talking. Force is one ticker second under the cap, so the engine never
    /// has to split a chunk again.
    public nonisolated static func chunkThresholds(
        for mode: LanguageMode
    ) -> (floor: Int, every: Int, force: Int) {
        guard let cap = WhisperCppEngine.maxCallSamples(for: mode) else {
            return (chunkFloorSamples, chunkEverySamples, chunkForceSamples)
        }
        return (cap, cap * 2 / 3, cap - 16000)
    }

    /// Accessed only on workQueue (serial) — safe despite nonisolated access.
    private nonisolated(unsafe) var pendingParts: [String] = []
    private var chunkedUpToSample = 0
    private var chunkTicker: Task<Void, Never>?

    private func startChunkTicker(modelPath: String, mode: LanguageMode) {
        chunkedUpToSample = 0
        engineCalls = 0
        engineSeconds = 0
        workQueue.async { [weak self] in self?.pendingParts = [] }
        let limits = Self.chunkThresholds(for: mode)
        chunkTicker = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard case .recording = self.phase else { continue }
                let total = self.audio.sessionSampleCount
                // Short dictations never chunk: one call is cheaper than two.
                guard total >= limits.floor else { continue }
                let pending = total - self.chunkedUpToSample
                guard pending >= limits.every else { continue }
                // Cut at a quiet moment, or force so a bad cut is bounded.
                let tail = self.audio.snapshotSession(fromSample: total - 4000, toSample: total)
                let quiet = (tail.map(abs).max() ?? 0) < 0.01
                guard quiet || pending >= limits.force else { continue }
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

    /// The ONE place an engine call happens — so counting them is honest.
    private nonisolated func transcribeRaw(
        _ samples: [Float], path: String, mode: LanguageMode
    ) throws -> String {
        try loadModel(path: path)
        let result = try engine.transcribe(samples: samples, mode: mode)
        engineCalls += 1
        engineSeconds += result.duration
        return result.text
    }

    private func startRecording() {
        // Recording may start from idle OR from an error state — an earlier
        // failure must never require a relaunch (v0.2 user-reported bug).
        switch phase {
        case .idle, .error: break
        default: return
        }
        errorResetTask?.cancel()
        let mode = effectiveMode()
        guard let modelPath = resolvedModelPath(for: mode) else {
            transientError("No model for this mode — open Models to download one")
            return
        }
        do {
            coolDownTask?.cancel()
            let wasWarm = audio.isWarm
            if settings.micWarm, !wasWarm { try? audio.warmUp() }
            try audio.beginSession()
            sessionMode = mode
            phase = .recording
            if wasWarm { Sounds.start.play() }   // cold path: onFirstAudio plays it
            startChunkTicker(modelPath: modelPath, mode: mode)
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
        let mode = sessionMode
        guard let modelPath = resolvedModelPath(for: mode) else {
            transientError("No model for this mode — open Models to download one")
            return
        }
        phase = .transcribing
        releaseTime = Date()
        sessionAudioSeconds = Double(samples.count) / 16000.0
        let rules = settings.replacementRules
        // Snapshot on main; applied off-main via the pure static core.
        let dictionary = PersonalDictionary.shared.entries
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
                if tail.count > Self.tailFloorSamples {
                    if parts.isEmpty {
                        // Nothing else to show — a failure here must surface.
                        let text = try self.transcribeRaw(tail, path: modelPath, mode: mode)
                        if !text.isEmpty { parts.append(text) }
                    } else if let text = try? self.transcribeRaw(tail, path: modelPath, mode: mode),
                              !text.isEmpty {
                        // Chunks already succeeded: a silent/failed tail must
                        // never throw away words we already have.
                        parts.append(text)
                    }
                }
                var text = parts.joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                text = PostProcessor.applyReplacements(text, rules: rules)
                text = PersonalDictionary.apply(text, entries: dictionary)
                if useOllama, !text.isEmpty {
                    let semaphore = DispatchSemaphore(value: 0)
                    Task { [t = text] in
                        text = await PostProcessor.ollamaCleanup(
                            t, model: ollamaModel, prompt: prompt)
                        semaphore.signal()
                    }
                    semaphore.wait()
                }
                Task { @MainActor in self.finishPipeline(text: text, mode: mode, copyOnly: copyOnly) }
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

    // MARK: - Post-transcription stages (translate / structure / tone)

    /// A thinking session routes the transcript to the thought structurer
    /// instead of pasting (STRUCTURE_THOUGHTS.md). The UI layer sets the sink;
    /// the kit stays UI-free. Armed per-session, disarmed on delivery/cancel.
    public var thinkingSessionArmed = false
    public var onThinkingTranscript: ((String) -> Void)?

    /// Runs after transcription+replacements: routes thinking sessions, runs
    /// the anyToEnglish translation stage, applies the tone mode — then
    /// delivers. Every LLM failure falls back to the raw words (house rule:
    /// the transcript is sacred, never lost to a flaky model).
    private func finishPipeline(text: String, mode: LanguageMode, copyOnly: Bool) {
        if thinkingSessionArmed {
            thinkingSessionArmed = false
            guard !text.isEmpty else {
                transientError("No speech detected — nothing captured.")
                return
            }
            phase = .idle
            Sounds.finish.play()
            onThinkingTranscript?(text)
            return
        }
        guard !text.isEmpty else {
            deliver(text: text, mode: mode, copyOnly: copyOnly)   // surfaces the error
            return
        }
        if mode.needsLLM {
            let token = beginLLMStage(.translating, raw: (text, mode, copyOnly))
            Task { @MainActor [weak self] in
                guard let self else { return }
                let english = try? await LLMServices.shared.translator
                    .translate(text, to: .english)
                guard self.llmStageToken == token else { return }  // user cancelled
                self.inFlightRaw = nil
                if let english, !english.isEmpty {
                    self.deliver(text: english, mode: mode, copyOnly: copyOnly, raw: text)
                } else {
                    // Never lose the user's words: paste the original, say why.
                    self.deliver(text: text, mode: mode, copyOnly: copyOnly)
                    self.transientError("Translation failed — pasted your original words.")
                }
            }
            return
        }
        let tone = settings.toneMode
        // Skip the stage outright when the engine isn't ready — a "Polishing"
        // overlay that changes nothing reads as a broken feature.
        if tone != .faithful, LLMServices.shared.status.isReady {
            let token = beginLLMStage(.polishing, raw: (text, mode, copyOnly))
            Task { @MainActor [weak self] in
                guard let self else { return }
                // applyTone returns the original on any failure.
                let rendered = await LLMServices.shared.applyTone(tone, to: text)
                guard self.llmStageToken == token else { return }  // user cancelled
                self.inFlightRaw = nil
                let changed = rendered != text
                self.deliver(text: rendered, mode: mode, copyOnly: copyOnly,
                             raw: changed ? text : nil)
            }
            return
        }
        deliver(text: text, mode: mode, copyOnly: copyOnly)
    }

    // MARK: - LLM-stage cancellation (Esc pastes the raw words immediately)

    private var llmStageToken = 0
    private var inFlightRaw: (text: String, mode: LanguageMode, copyOnly: Bool)?

    private func beginLLMStage(
        _ stage: DictationPhase, raw: (String, LanguageMode, Bool)
    ) -> Int {
        phase = stage
        llmStageToken += 1
        inFlightRaw = raw
        return llmStageToken
    }

    private func deliver(text: String, mode: LanguageMode, copyOnly: Bool, raw: String? = nil) {
        guard !text.isEmpty else {
            transientError("No speech detected — nothing inserted or copied.")
            return
        }
        controllerLog.info("deliver: \(text.count, privacy: .public) chars, copyOnly=\(copyOnly, privacy: .public)")
        // The transcript is sacred: even if pasting into the target app fails,
        // it's in lastTranscript ("Copy Last" in the menu) and History.
        recordTimings(llmStage: raw != nil)
        lastTranscript = text
        HistoryStore.shared.add(text: text, mode: mode, raw: raw)
        TextInserter.insert(text, copyOnly: copyOnly)
        Sounds.finish.play()
        phase = .idle
    }

    /// Snapshots what this dictation cost, publishes it, and writes it to the
    /// system log — the data the next "why is it slow?" report will need.
    private func recordTimings(llmStage: Bool) {
        guard let releaseTime else { return }
        var timings = DictationTimings()
        timings.audioSeconds = sessionAudioSeconds
        timings.engineCalls = engineCalls
        timings.engineSeconds = engineSeconds
        timings.releaseToPaste = Date().timeIntervalSince(releaseTime)
        timings.llmStage = llmStage
        timings.log()
        lastTimings = timings
        self.releaseTime = nil
    }

    public func cancel() {
        // Esc during translate/polish: abandon the LLM result, paste the words
        // as heard — the user keeps everything, immediately.
        if case .translating = phase { return cancelLLMStage() }
        if case .polishing = phase { return cancelLLMStage() }
        stopChunkTicker()
        audio.cancelSession()
        scheduleCoolDown()
        workQueue.async { [weak self] in self?.pendingParts = [] }
        chunkedUpToSample = 0
        thinkingSessionArmed = false
        if phase != .disabled { phase = .idle }
        Sounds.error.play()
    }

    private func cancelLLMStage() {
        llmStageToken += 1   // in-flight Task result will be dropped
        guard let raw = inFlightRaw else { phase = .idle; return }
        inFlightRaw = nil
        deliver(text: raw.text, mode: raw.mode, copyOnly: raw.copyOnly)
    }

    /// Starts a thinking session (STRUCTURE_THOUGHTS.md): toggle-style capture
    /// regardless of the push-to-talk setting — nobody holds a key for five
    /// minutes. The next finished recording routes to `onThinkingTranscript`.
    public func startThinkingSession() {
        guard phase == .idle || { if case .error = phase { return true }; return false }() else { return }
        thinkingSessionArmed = true
        startRecording()
        if case .recording = phase {} else { thinkingSessionArmed = false }   // mic failed
    }

    /// Ends a thinking session's capture (the menu's "Finish" action).
    public func finishThinkingSession() {
        guard thinkingSessionArmed, case .recording = phase else { return }
        finishRecording()
    }

    // MARK: - Model management

    /// Loads a model on the worker queue (no-op if already resident).
    private nonisolated func loadModel(path: String) throws {
        try engine.load(modelPath: path)
    }

    private func preloadModelIfNeeded() {
        guard let path = resolvedModelPath(for: effectiveMode()) else { return }
        workQueue.async { [weak self] in try? self?.loadModel(path: path) }
    }

    /// Called when the user changes model/mode — swaps the resident model.
    public func modelChanged() {
        guard let path = resolvedModelPath(for: effectiveMode()) else { return }
        workQueue.async { [weak self] in try? self?.loadModel(path: path) }
    }
}
