import AVFoundation
import CoreAudio
import AudioToolbox

private let auhalInputCallback: AURenderCallback = { refCon, flags, timestamp, _, frameCount, _ in
    let context = Unmanaged<AUHALCaptureContext>.fromOpaque(refCon).takeUnretainedValue()
    return context.render(flags: flags, timestamp: timestamp, frameCount: frameCount)
}

private final class AUHALCaptureContext: @unchecked Sendable {
    let audioUnit: AudioUnit
    let inputFormat: AVAudioFormat
    let outputFormat: AVAudioFormat
    let converter: AVAudioConverter
    let append: @Sendable ([Float]) -> Void
    let levelUpdate: @Sendable (Float) -> Void
    let silenceThresholdDB: Float

    private let diagnosticLock = NSLock()
    private var loggedFirstBuffer = false

    init(
        audioUnit: AudioUnit,
        inputFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        append: @Sendable @escaping ([Float]) -> Void,
        levelUpdate: @Sendable @escaping (Float) -> Void,
        silenceThresholdDB: Float
    ) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioConverterErr_FormatNotSupported))
        }
        self.audioUnit = audioUnit
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.converter = converter
        self.append = append
        self.levelUpdate = levelUpdate
        self.silenceThresholdDB = silenceThresholdDB
    }

    func render(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, timestamp: UnsafePointer<AudioTimeStamp>, frameCount: UInt32) -> OSStatus {
        guard let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else { return kAudio_ParamError }
        input.frameLength = frameCount
        let status = AudioUnitRender(audioUnit, flags, timestamp, 1, frameCount, input.mutableAudioBufferList)
        guard status == noErr else { return status }

        diagnosticLock.lock()
        if !loggedFirstBuffer {
            loggedFirstBuffer = true
            NSLog("[AudioDebug] First AUHAL buffer: sampleRate=%.0f channels=%u frames=%u", inputFormat.sampleRate, inputFormat.channelCount, frameCount)
        }
        diagnosticLock.unlock()

        guard let channel = input.floatChannelData?[0], frameCount > 0 else { return noErr }
        var sumSquares: Float = 0
        for index in 0..<Int(frameCount) {
            let sample = channel[index]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameCount))
        let db = rms > 0 ? 20 * log10(rms) : -160
        levelUpdate(max(0, min(1, (db - silenceThresholdDB) / 35)))

        let capacity = AVAudioFrameCount(ceil(Double(frameCount) * outputFormat.sampleRate / inputFormat.sampleRate)) + 8
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return kAudio_ParamError }
        var suppliedInput = false
        var conversionError: NSError?
        let conversionStatus = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return input
        }
        if conversionStatus == .error {
            NSLog("[AudioDebug] Conversion failed: %@", conversionError?.localizedDescription ?? "unknown error")
            return conversionError.map { OSStatus($0.code) } ?? kAudio_ParamError
        }
        if let converted = output.floatChannelData?[0], output.frameLength > 0 {
            append(Array(UnsafeBufferPointer(start: converted, count: Int(output.frameLength))))
        }
        return noErr
    }
}

actor AudioRecorder {
    private let targetSampleRate: Double = 16_000
    private let maxBufferSamples = 4_800_000
    private let silenceThresholdDB: Float = -55.0
    private let minRecordingDuration: Double = 0.3
    private let shortAudioThreshold: Double = 1.5
    private let silencePaddingDuration: Double = 1.0

    private var audioUnit: AudioUnit?
    private var captureContext: AUHALCaptureContext?
    private var isRecording = false

    private final class AudioBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [Float] = []

        var samples: [Float] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }

        func append(_ samples: [Float], limit: Int) {
            lock.lock(); defer { lock.unlock() }
            guard storage.count + samples.count <= limit else { return }
            storage.append(contentsOf: samples)
        }

        func clear() {
            lock.lock(); defer { lock.unlock() }
            storage.removeAll()
        }
    }

    private let audioBuffer = AudioBuffer()
    nonisolated(unsafe) var onLevelUpdate: (@Sendable (Float) -> Void)?

    func startRecording(deviceID requestedDeviceID: AudioDeviceID?, onLevelUpdate: @Sendable @escaping (Float) -> Void) throws {
        guard !isRecording else { return }
        audioBuffer.clear()
        self.onLevelUpdate = onLevelUpdate

        var unit: AudioUnit?
        do {
            var description = AudioComponentDescription(
                componentType: kAudioUnitType_Output,
                componentSubType: kAudioUnitSubType_HALOutput,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0,
                componentFlagsMask: 0
            )
            guard let component = AudioComponentFindNext(nil, &description) else {
                throw audioError(kAudio_ParamError, "AUHAL component is unavailable")
            }
            try check(AudioComponentInstanceNew(component, &unit), "create AUHAL")
            guard let unit else { throw audioError(kAudio_ParamError, "AUHAL creation returned no instance") }

            var enabled: UInt32 = 1
            try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enabled, UInt32(MemoryLayout.size(ofValue: enabled))), "enable AUHAL input")
            var disabled: UInt32 = 0
            try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &disabled, UInt32(MemoryLayout.size(ofValue: disabled))), "disable AUHAL output")

            let selectedDeviceID = try requestedDeviceID ?? defaultInputDeviceID()
            var deviceID = selectedDeviceID
            try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &deviceID, UInt32(MemoryLayout.size(ofValue: deviceID))), "select input device")

            var hardwareFormat = AudioStreamBasicDescription()
            var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &hardwareFormat, &formatSize), "read input format")
            guard hardwareFormat.mSampleRate > 0 else { throw audioError(kAudio_ParamError, "input device has no valid sample rate") }

            guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: hardwareFormat.mSampleRate, channels: 1, interleaved: false),
                  let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false) else {
                throw audioError(kAudio_ParamError, "could not create capture formats")
            }
            var clientFormat = inputFormat.streamDescription.pointee
            try check(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &clientFormat, UInt32(MemoryLayout.size(ofValue: clientFormat))), "set AUHAL client format")

            let buffer = audioBuffer
            let limit = maxBufferSamples
            let context = try AUHALCaptureContext(audioUnit: unit, inputFormat: inputFormat, outputFormat: outputFormat, append: { buffer.append($0, limit: limit) }, levelUpdate: onLevelUpdate, silenceThresholdDB: silenceThresholdDB)
            var callback = AURenderCallbackStruct(inputProc: auhalInputCallback, inputProcRefCon: Unmanaged.passUnretained(context).toOpaque())
            try check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, UInt32(MemoryLayout.size(ofValue: callback))), "set AUHAL callback")
            try check(AudioUnitInitialize(unit), "initialize AUHAL")
            try check(AudioOutputUnitStart(unit), "start AUHAL")

            NSLog("[AudioDebug] AUHAL started: requestedID=%@ currentDevice=%u hardwareRate=%.0f targetRate=%.0f", requestedDeviceID.map(String.init) ?? "default", selectedDeviceID, hardwareFormat.mSampleRate, targetSampleRate)
            self.audioUnit = unit
            captureContext = context
            isRecording = true
        } catch {
            if let unit {
                AudioOutputUnitStop(unit)
                AudioUnitUninitialize(unit)
                AudioComponentInstanceDispose(unit)
            }
            self.onLevelUpdate = nil
            audioBuffer.clear()
            throw error
        }
    }

    func stopRecording() -> [Float]? {
        disposeCapture()
        let samples = audioBuffer.samples
        audioBuffer.clear()

        let duration = Double(samples.count) / targetSampleRate
        guard duration >= minRecordingDuration else { return nil }
        var sumSquares: Float = 0
        for sample in samples { sumSquares += sample * sample }
        let rms = sqrt(sumSquares / Float(samples.count))
        let db = rms > 0 ? 20 * log10(rms) : -160
        guard db >= silenceThresholdDB else { return nil }
        if duration < shortAudioThreshold {
            return samples + [Float](repeating: 0, count: Int(silencePaddingDuration * targetSampleRate))
        }
        return samples
    }

    func cancelRecording() {
        disposeCapture()
        audioBuffer.clear()
    }

    private func disposeCapture() {
        isRecording = false
        if let audioUnit {
            AudioOutputUnitStop(audioUnit)
            AudioUnitUninitialize(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
        }
        audioUnit = nil
        captureContext = nil
        onLevelUpdate = nil
    }

    private func defaultInputDeviceID() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID), "read default input device")
        guard deviceID != kAudioObjectUnknown else { throw audioError(kAudioHardwareBadDeviceError, "no default input device") }
        return deviceID
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw audioError(status, operation) }
    }

    private func audioError(_ status: OSStatus, _ operation: String) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to \(operation) (OSStatus \(status))."])
    }
}
