import AVFoundation

/// A bounded PCM queue. Completion means heard, not merely rendered or scheduled.
@MainActor
final class SpeechPlayback {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var queued = 0
    private var stopped = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let format: AVAudioFormat

    init(sampleRate: Int, onLevel: @escaping @MainActor @Sendable (CGFloat) -> Void) throws {
        format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        // Meter output at about 12 Hz; rendering/inference never waits for UI work.
        node.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) {
                sum += samples[index] * samples[index]
            }
            let rms = sqrt(sum / Float(buffer.frameLength))
            let level = CGFloat(min(1, rms * 5))
            Task { @MainActor in onLevel(level) }
        }
        do {
            try engine.start()
        } catch {
            node.removeTap(onBus: 0)
            throw error
        }
    }

    func waitForCapacity() async {
        while queued >= 3 && !stopped {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    func enqueue(_ chunk: KokoroSpeechEngine.AudioChunk) throws {
        guard !stopped else { throw CancellationError() }
        guard Double(chunk.sampleRate) == format.sampleRate,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk.samples.count)),
              let channel = buffer.floatChannelData?[0] else {
            throw NSError(domain: "Speak2.AudioPlayback", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid speech audio format."])
        }
        buffer.frameLength = buffer.frameCapacity
        chunk.samples.withUnsafeBufferPointer { samples in
            if let base = samples.baseAddress { channel.update(from: base, count: samples.count) }
        }
        guard buffer.frameLength > 0 else { return }
        queued += 1
        node.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.stopped else { return }
                self.queued -= 1
                self.wakeWaiters()
            }
        }
        if !node.isPlaying { node.play() }
    }

    func finish() async {
        while queued > 0 && !stopped {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        node.removeTap(onBus: 0)
        node.stop()
        engine.stop()
        queued = 0
        wakeWaiters()
    }

    private func wakeWaiters() {
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
