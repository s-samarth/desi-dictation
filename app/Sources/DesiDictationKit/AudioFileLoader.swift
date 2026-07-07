import AVFoundation
import Foundation

/// Loads an audio file (wav/m4a/mp3/…) and converts it to 16 kHz mono Float32.
/// Used by the CLI verification target — the app itself captures live audio.
public enum AudioFileLoader {
    public static func loadSamples(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { throw err("could not allocate read buffer") }
        try file.read(into: inBuffer)

        let target = AudioCapture.targetFormat
        if format.sampleRate == target.sampleRate,
           format.channelCount == 1,
           format.commonFormat == .pcmFormatFloat32 {
            return extract(inBuffer)
        }

        guard let converter = AVAudioConverter(from: format, to: target)
        else { throw err("unsupported audio format") }
        let ratio = target.sampleRate / format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(frameCount) * ratio) + 64
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCapacity)
        else { throw err("could not allocate conversion buffer") }

        var fed = false
        var convErr: NSError?
        converter.convert(to: outBuffer, error: &convErr) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return inBuffer
        }
        if let convErr { throw convErr }
        return extract(outBuffer)
    }

    private static func extract(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let data = buffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength)))
    }

    private static func err(_ message: String) -> NSError {
        NSError(domain: "AudioFileLoader", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
