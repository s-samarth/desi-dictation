import AVFoundation
import CoreAudio
import Foundation
import os.log

let audioLog = Logger(subsystem: "com.desi.dictation", category: "audio")

/// Microphone capture at 16 kHz mono Float32 with a **warm-idle** mode:
/// while dictation is enabled the mic can stay open, keeping a ~0.3 s
/// pre-roll ring so the words spoken AT the hotkey press are never lost
/// (v0.3 feedback: "first 1–2 seconds not registered" — that was mic spin-up).
///
/// Capture goes through `MicrophoneUnit` (input-only, the mic's native
/// format) — never through the output device (BUILD_LOG FM#22). Self-heals
/// from wedged or vanished devices (FM #13) by reopening on device changes,
/// including mid-session, and on dead sessions.
public final class AudioCapture {
    private let mic = MicrophoneUnit()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var ring: [Float] = []          // idle pre-roll, capped
    private var session: [Float] = []
    private var inSession = false
    private var running = false
    private let preRollSamples = 4800       // 0.3 s @ 16 kHz
    private var watchedDevice: AudioDeviceID?

    public private(set) var isWarm = false
    /// Cold-path only: fires when the mic actually starts delivering buffers.
    public var onFirstAudio: (() -> Void)?
    private var firstAudioFired = false

    public static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
    )!

    public init() {
        mic.onBuffer = { [weak self] buffer in self?.append(buffer: buffer) }
        // The user picked another mic (or plugged one in) in System Settings.
        MicrophoneUnit.listen(AudioObjectID(kAudioObjectSystemObject),
                    kAudioHardwarePropertyDefaultInputDevice) { [weak self] in
            self?.deviceChanged("default input changed")
        }
    }

    // MARK: - Warm idle

    public func warmUp() throws {
        guard !isWarm else { return }
        try startMic()
        isWarm = true
    }

    public func coolDown() {
        guard isWarm, !inSession else { return }
        stopMic()
        isWarm = false
    }

    /// Reopen on whatever the default input is now. Mid-session too: the
    /// session buffer lives here, so capture simply continues on the new mic
    /// instead of silently recording nothing until the next dictation.
    private func deviceChanged(_ reason: String) {
        guard running else { return }
        audioLog.notice("mic reopen: \(reason, privacy: .public)")
        stopMic()
        try? startMic()
    }

    // MARK: - Session

    /// Begin capturing a dictation. Warm path: instant, includes pre-roll.
    /// Cold path: opens the mic now (fires onFirstAudio when hot).
    public func beginSession() throws {
        lock.lock()
        session = isWarm ? Array(ring.suffix(preRollSamples)) : []
        inSession = true
        firstAudioFired = false
        lock.unlock()
        if !isWarm { try startMic() }
    }

    /// End the session and return its samples. Keeps a warm mic open.
    public func endSession() -> [Float] {
        lock.lock()
        inSession = false
        let result = session
        session = []
        lock.unlock()
        if !isWarm { stopMic() }

        let peak = result.map(abs).max() ?? 0
        audioLog.info("endSession: \(result.count, privacy: .public) samples (\(String(format: "%.1f", Double(result.count) / 16000.0), privacy: .public)s) peak=\(peak, privacy: .public)")
        if isWarm, result.count > 16000, peak < 0.0005 {
            deviceChanged("dead session")   // self-heal for the NEXT session
        }
        return result
    }

    public func cancelSession() {
        lock.lock(); inSession = false; session = []; lock.unlock()
        if !isWarm { stopMic() }
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

    // MARK: - Mic plumbing

    private func startMic() throws {
        try mic.start { device in
            let converter = AVAudioConverter(from: device.format, to: Self.targetFormat)
            converter?.downmix = true   // stereo USB mics: mix, don't drop a channel
            lock.lock(); self.converter = converter; lock.unlock()
        }
        guard let device = mic.device else { return }
        running = true
        // .notice so "which mic was it?" survives in `log show` after a complaint.
        audioLog.notice("mic open: \(device.name, privacy: .public) \(Int(device.format.sampleRate), privacy: .public)Hz \(device.format.channelCount, privacy: .public)ch")
        watch(device.id)
    }

    private func stopMic() {
        mic.stop()   // synchronous: no callback runs after this returns
        running = false
        lock.lock(); converter = nil; ring = []; lock.unlock()
    }

    /// Unplugged, or another app (a call) changed its sample rate — either
    /// way the open format is stale and the mic must be reopened.
    private func watch(_ id: AudioDeviceID) {
        guard watchedDevice != id else { return }
        watchedDevice = id
        for selector in [kAudioDevicePropertyDeviceIsAlive, kAudioDevicePropertyNominalSampleRate] {
            MicrophoneUnit.listen(id, selector) { [weak self] in
                guard self?.mic.device?.id == id else { return }
                self?.deviceChanged("device \(id) changed")
            }
        }
    }

    /// HAL I/O thread. The buffer is reused by the mic next cycle — it is
    /// fully consumed (converted) before this returns.
    private func append(buffer: AVAudioPCMBuffer) {
        lock.lock(); let converter = self.converter; lock.unlock()
        guard let converter else { return }
        let ratio = Self.targetFormat.sampleRate / buffer.format.sampleRate
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
        if notify { firstAudioFired = true }
        lock.unlock()

        if notify {
            DispatchQueue.main.async { [weak self] in self?.onFirstAudio?() }
        }
    }
}
