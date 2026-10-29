// rec <out.wav>: record the default input (48 kHz, 16-bit, mono) until Enter.
//
// macOS's own recorder. ffmpeg's avfoundation input spliced its 512-sample
// buffers on this Mac, which made the voice crackle and break; this doesn't.
// record-voice.sh builds it on first use.
import AVFoundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: rec <out.wav>\n".data(using: .utf8)!)
    exit(2)
}
let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVSampleRateKey: 48_000,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
]
let url = URL(fileURLWithPath: CommandLine.arguments[1])
do {
    let recorder = try AVAudioRecorder(url: url, settings: settings)
    recorder.prepareToRecord()
    guard recorder.record() else {
        FileHandle.standardError.write("Couldn't start recording. Does Terminal have the microphone?\n".data(using: .utf8)!)
        exit(1)
    }
    print("● Recording. Enter to stop. ", terminator: "")
    fflush(stdout)
    _ = readLine()
    recorder.stop()
} catch {
    FileHandle.standardError.write("rec: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
