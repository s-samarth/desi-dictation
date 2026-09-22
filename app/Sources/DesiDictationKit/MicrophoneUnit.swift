import AVFoundation
import AudioToolbox
import CoreAudio
import os.log

/// An **input-only** CoreAudio unit (AUHAL) bound to one physical microphone,
/// delivering buffers in that mic's native format.
///
/// Why not AVAudioEngine's `inputNode` (the pre-v0.6.2 path): on macOS the
/// engine drives input and output as ONE device, so the mic was clocked and
/// resampled to whatever the *speaker* was. Measured 2026-09-22: a Maono DGM20
/// running at 48 kHz was delivered at 44.1 kHz because the default output was a
/// Bluetooth Echo Dot, and macOS 27 logs that this conversion "no longer
/// enables drift correction by default" — two free-running clocks, glitches
/// accumulating over a long dictation (BUILD_LOG FM#22). This unit never
/// touches the output device, so the speaker can't affect the words.
final class MicrophoneUnit {
    struct Device {
        let id: AudioDeviceID
        let name: String
        let format: AVAudioFormat
    }

    private(set) var device: Device?
    private var unit: AudioUnit?
    private var renderBuffer: AVAudioPCMBuffer?
    /// Called on the HAL I/O thread with a buffer that is reused next cycle —
    /// the receiver must copy what it needs before returning.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    /// Opens the current system-default input and starts it. `prepare` runs
    /// with the device's format BEFORE the first buffer can arrive.
    func start(prepare: (Device) -> Void) throws {
        stop()
        guard let id = Self.defaultInputDevice() else {
            throw Self.error("No microphone input available.")
        }
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0)
        guard let component = AudioComponentFindNext(nil, &desc) else {
            throw Self.error("CoreAudio HAL unit unavailable.")
        }
        var newUnit: AudioUnit?
        try Self.check(AudioComponentInstanceNew(component, &newUnit), "open unit")
        guard let au = newUnit else { throw Self.error("CoreAudio HAL unit unavailable.") }
        unit = au

        // Bus 1 = input from the device, bus 0 = output to it. Input only.
        var on: UInt32 = 1, off: UInt32 = 0
        try Self.check(AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO,
                                            kAudioUnitScope_Input, 1, &on, 4), "enable input")
        try Self.check(AudioUnitSetProperty(au, kAudioOutputUnitProperty_EnableIO,
                                            kAudioUnitScope_Output, 0, &off, 4), "disable output")
        var deviceID = id
        try Self.check(AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
                                            kAudioUnitScope_Global, 0, &deviceID, 4), "bind device")

        // Ask for the device's own rate and channel count as Float32 — the
        // HAL unit can't resample on the input side, so this must match.
        var hw = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try Self.check(AudioUnitGetProperty(au, kAudioUnitProperty_StreamFormat,
                                            kAudioUnitScope_Input, 1, &hw, &size), "read format")
        guard hw.mSampleRate > 0, hw.mChannelsPerFrame > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: hw.mSampleRate,
                                         channels: hw.mChannelsPerFrame, interleaved: false)
        else { throw Self.error("Microphone reports no usable format.") }
        var client = format.streamDescription.pointee
        try Self.check(AudioUnitSetProperty(au, kAudioUnitProperty_StreamFormat,
                                            kAudioUnitScope_Output, 1, &client, size), "set format")

        // Size the render buffer to the most the unit will ever hand us, so a
        // device with large I/O blocks can't have its audio silently dropped.
        var maxFrames: UInt32 = 0
        var maxSize = UInt32(MemoryLayout<UInt32>.size)
        AudioUnitGetProperty(au, kAudioUnitProperty_MaximumFramesPerSlice,
                             kAudioUnitScope_Global, 0, &maxFrames, &maxSize)
        renderBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(8192, maxFrames))
        var callback = AURenderCallbackStruct(
            inputProc: MicrophoneUnit.inputProc,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        try Self.check(AudioUnitSetProperty(
            au, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0,
            &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size)), "set callback")
        try Self.check(AudioUnitInitialize(au), "initialize")
        let opened = Device(id: id, name: Self.name(of: id), format: format)
        prepare(opened)
        device = opened
        try Self.check(AudioOutputUnitStart(au), "start")
    }

    func stop() {
        if let unit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
        unit = nil
        device = nil
    }

    deinit { stop() }

    private static let inputProc: AURenderCallback = { refCon, flags, timeStamp, bus, frames, _ in
        let mic = Unmanaged<MicrophoneUnit>.fromOpaque(refCon).takeUnretainedValue()
        guard let unit = mic.unit, let buffer = mic.renderBuffer,
              frames <= buffer.frameCapacity else { return noErr }
        buffer.frameLength = frames
        let status = AudioUnitRender(unit, flags, timeStamp, bus, frames, buffer.mutableAudioBufferList)
        if status == noErr { mic.onBuffer?(buffer) }
        return status
    }

    // MARK: - Device queries

    static func defaultInputDevice() -> AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    static func name(of id: AudioDeviceID) -> String {
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr,
              let value = name?.takeRetainedValue() else { return "device \(id)" }
        return value as String
    }

    /// Calls `handler` on main whenever the property changes. Listeners live
    /// as long as the process — AudioCapture is a singleton's member.
    static func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       _ handler: @escaping () -> Void) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(object, &address, .main) { _, _ in handler() }
    }

    private static func check(_ status: OSStatus, _ step: String) throws {
        guard status != noErr else { return }
        audioLog.error("mic \(step, privacy: .public) failed: \(status, privacy: .public)")
        throw error("Microphone \(step) failed (\(status)).")
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "AudioCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
