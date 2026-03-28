import AVFoundation

actor AudioRecorder {
    // MARK: - Constants
    private let targetSampleRate: Double = 16_000
    private let bufferSize: AVAudioFrameCount = 1024
    private let maxBufferSamples = 4_800_000
    private let silenceThresholdDB: Float = -55.0
    private let minRecordingDuration: Double = 0.3
    private let shortAudioThreshold: Double = 1.5
    private let silencePaddingDuration: Double = 1.0

    // MARK: - State
    private var audioEngine: AVAudioEngine?
    private var isRecording = false

    // Buffer wrapper accessed from audio tap thread
    private final class AudioBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var _samples: [Float] = []

        var samples: [Float] {
            lock.lock()
            defer { lock.unlock() }
            return _samples
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _samples.count
        }

        func append(_ newSamples: [Float]) {
            lock.lock()
            defer { lock.unlock() }
            _samples.append(contentsOf: newSamples)
        }

        func clear() {
            lock.lock()
            defer { lock.unlock() }
            _samples.removeAll()
        }
    }

    private let audioBuffer = AudioBuffer()
    nonisolated(unsafe) var onLevelUpdate: (@Sendable (Float) -> Void)?

    // MARK: - Recording

    func startRecording(onLevelUpdate: @Sendable @escaping (Float) -> Void) throws {
        guard !isRecording else { return }

        audioBuffer.clear()
        self.onLevelUpdate = onLevelUpdate

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let deviceFormat = inputNode.outputFormat(forBus: 0)
        let deviceSampleRate = deviceFormat.sampleRate

        engine.prepare()

        let buffer = audioBuffer
        let maxSamples = maxBufferSamples
        let targetRate = targetSampleRate
        let silenceDB = silenceThresholdDB
        let levelCallback = onLevelUpdate

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: deviceFormat) { pcmBuffer, _ in
            guard let channelData = pcmBuffer.floatChannelData?[0] else { return }
            let frameCount = Int(pcmBuffer.frameLength)

            // Resample to 16kHz via stride if needed
            let resampled: [Float]
            let ratio = deviceSampleRate / targetRate
            if ratio > 1.0 {
                let stride = Int(ratio)
                resampled = Swift.stride(from: 0, to: frameCount, by: stride).map { channelData[$0] }
            } else {
                resampled = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            }

            // Auto-stop at 5 minutes
            guard buffer.count + resampled.count <= maxSamples else { return }

            buffer.append(resampled)

            // Calculate RMS dB
            var sumSquares: Float = 0
            for i in 0..<frameCount {
                let sample = channelData[i]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(frameCount))
            let db = rms > 0 ? 20 * log10(rms) : -160

            // Normalize to 0-1 range
            let normalized = max(0, min(1, (db - silenceDB) / 35))
            levelCallback(normalized)
        }

        try engine.start()
        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> [Float]? {
        isRecording = false

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        onLevelUpdate = nil

        let samples = audioBuffer.samples
        audioBuffer.clear()

        // Validate minimum duration
        let duration = Double(samples.count) / targetSampleRate
        guard duration >= minRecordingDuration else { return nil }

        // Validate RMS above silence threshold
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(samples.count))
        let db = rms > 0 ? 20 * log10(rms) : -160
        guard db >= silenceThresholdDB else { return nil }

        // Pad short audio with 1s of zeros
        if duration < shortAudioThreshold {
            let paddingSamples = Int(silencePaddingDuration * targetSampleRate)
            return samples + [Float](repeating: 0, count: paddingSamples)
        }

        return samples
    }

    func cancelRecording() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        isRecording = false
        onLevelUpdate = nil
        audioBuffer.clear()
    }
}
