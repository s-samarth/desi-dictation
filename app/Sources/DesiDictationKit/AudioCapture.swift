import AVFoundation
import Foundation
import os.log

let audioLog = Logger(subsystem: "com.desi.dictation", category: "audio")

/// Captures microphone audio and converts it live to 16 kHz mono Float32
/// (Whisper's input format). Buffer grows unbounded while recording — pauses
/// mid-dictation are therefore free (matching MacWhisper's behavior).
public final class AudioCapture {
    // Recreated fresh per session (see start()) — a long-lived AVAudioEngine
    // wedges after repeated start/stop cycles or audio-device changes and then
    // silently captures nothing (BUILD_LOG failure mode #13).
    private var engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    public private(set) var isRecording = false

    public static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
    )!

    public init() {}

    public func start() throws {
        guard !isRecording else { return }
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()
        engine = AVAudioEngine()   // fresh engine: immune to wedged sessions

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        audioLog.info("start: input format \(inputFormat.sampleRate, privacy: .public)Hz \(inputFormat.channelCount, privacy: .public)ch")
        guard inputFormat.sampleRate > 0 else {
            throw NSError(domain: "AudioCapture", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No microphone input available."])
        }
        converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer: buffer, inputFormat: inputFormat)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stop and return everything captured, as 16 kHz mono Float32.
    public func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        lock.lock(); defer { lock.unlock() }
        let peak = samples.map(abs).max() ?? 0
        let rms = samples.isEmpty ? 0 :
            (samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
        audioLog.info("stop: \(self.samples.count, privacy: .public) samples (\(String(format: "%.1f", Double(self.samples.count) / 16000.0), privacy: .public)s) peak=\(peak, privacy: .public) rms=\(rms, privacy: .public)")
        return samples
    }

    public func cancel() {
        _ = stop()
        lock.lock(); samples.removeAll(); lock.unlock()
    }

    public var capturedSeconds: Double {
        lock.lock(); defer { lock.unlock() }
        return Double(samples.count) / 16000.0
    }

    // MARK: - Conversion

    private func append(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard let converter else { return }
        let ratio = 16000.0 / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity)
        else { return }

        var fed = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard err == nil, out.frameLength > 0, let data = out.floatChannelData else { return }

        // Sanitize: a glitchy converter/device can emit NaN/inf samples, which
        // poison the whole transcription. Zero them out.
        let raw = UnsafeBufferPointer(start: data[0], count: Int(out.frameLength))
        let chunk = raw.map { $0.isFinite ? $0 : 0 }
        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()
    }
}
