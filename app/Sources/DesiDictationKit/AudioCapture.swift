import AVFoundation
import Foundation
import os.log

let audioLog = Logger(subsystem: "com.desi.dictation", category: "audio")

/// Microphone capture at 16 kHz mono Float32 with a **warm-idle** mode:
/// while dictation is enabled the engine runs continuously, keeping a ~0.3 s
/// pre-roll ring so the words spoken AT the hotkey press are never lost
/// (v0.3 feedback: "first 1–2 seconds not registered" — that was mic spin-up).
/// Self-heals from wedged engines (FM #13) by rebuilding on device changes
/// and on cold starts.
public final class AudioCapture {
    private var engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var ring: [Float] = []          // idle pre-roll, capped
    private var session: [Float] = []
    private var inSession = false
    private let preRollSamples = 4800       // 0.3 s @ 16 kHz

    public private(set) var isWarm = false
    /// Cold-path only: fires when the mic actually starts delivering buffers.
    public var onFirstAudio: (() -> Void)?
    private var firstAudioFired = false

    public static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
    )!

    public init() {
        // Device switch (AirPods ↔ built-in) invalidates the running engine —
        // rebuild instead of silently capturing nothing.
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil
        ) { [weak self] _ in self?.rebuildIfWarm() }
    }

    // MARK: - Warm idle

    public func warmUp() throws {
        guard !isWarm else { return }
        try startEngine()
        isWarm = true
    }

    public func coolDown() {
        guard isWarm, !inSession else { return }
        stopEngine()
        isWarm = false
    }

    private func rebuildIfWarm() {
        guard isWarm, !inSession else { return }
        audioLog.info("audio route changed — rebuilding engine")
        stopEngine()
        isWarm = false
        try? warmUp()
    }

    // MARK: - Session

    /// Begin capturing a dictation. Warm path: instant, includes pre-roll.
    /// Cold path: spins the engine up now (fires onFirstAudio when hot).
    public func beginSession() throws {
        lock.lock()
        session = isWarm ? Array(ring.suffix(preRollSamples)) : []
        inSession = true
        lock.unlock()
        firstAudioFired = false
        if !isWarm { try startEngine() }
    }

    /// End the session and return its samples. Keeps the engine warm.
    public func endSession() -> [Float] {
        lock.lock()
        inSession = false
        let result = session
        session = []
        lock.unlock()
        if !isWarm { stopEngine() }

        let peak = result.map(abs).max() ?? 0
        audioLog.info("endSession: \(result.count, privacy: .public) samples (\(String(format: "%.1f", Double(result.count) / 16000.0), privacy: .public)s) peak=\(peak, privacy: .public)")
        if isWarm, result.count > 16000, peak < 0.0005 {
            rebuildIfWarm()   // dead mic self-heal for the NEXT session
        }
        return result
    }

    public func cancelSession() {
        lock.lock(); inSession = false; session = []; lock.unlock()
        if !isWarm { stopEngine() }
    }

    public var sessionSeconds: Double {
        lock.lock(); defer { lock.unlock() }
        return Double(session.count) / 16000.0
    }

    /// Copy of session samples in [from, to) — used for incremental chunking.
    public func snapshotSession(fromSample: Int, toSample: Int) -> [Float] {
        lock.lock(); defer { lock.unlock() }
        guard fromSample < session.count else { return [] }
        return Array(session[fromSample..<min(toSample, session.count)])
    }

    public var sessionSampleCount: Int {
        lock.lock(); defer { lock.unlock() }
        return session.count
    }

    // MARK: - Engine plumbing

    private func startEngine() throws {
        engine = AVAudioEngine()   // always fresh: immune to wedged sessions
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        audioLog.info("engine start: \(inputFormat.sampleRate, privacy: .public)Hz \(inputFormat.channelCount, privacy: .public)ch")
        guard inputFormat.sampleRate > 0 else {
            throw NSError(domain: "AudioCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No microphone input available."])
        }
        converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer)
        }
        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); ring = []; lock.unlock()
    }

    private func append(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = 16000.0 / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity)
        else { return }

        var fed = false
        var convErr: NSError?
        converter.convert(to: out, error: &convErr) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard convErr == nil, out.frameLength > 0, let data = out.floatChannelData else { return }

        // Sanitize NaN/inf — they poison whisper's whole decode.
        let raw = UnsafeBufferPointer(start: data[0], count: Int(out.frameLength))
        let chunk = raw.map { $0.isFinite ? $0 : 0 }

        lock.lock()
        if inSession {
            session.append(contentsOf: chunk)
        } else {
            ring.append(contentsOf: chunk)
            if ring.count > preRollSamples * 2 { ring.removeFirst(ring.count - preRollSamples) }
        }
        let notify = inSession && !firstAudioFired
        lock.unlock()

        if notify {
            firstAudioFired = true
            DispatchQueue.main.async { [weak self] in self?.onFirstAudio?() }
        }
    }
}
