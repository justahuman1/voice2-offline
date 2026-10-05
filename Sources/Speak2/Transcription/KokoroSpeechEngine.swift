import Foundation
import Kokoro

actor KokoroSpeechEngine {
    static let shared = KokoroSpeechEngine()

    private let voice = "af_heart"
    private var pipeline: KPipeline?

    private var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Speak2/Kokoro", isDirectory: true)
    }

    func isDownloaded() -> Bool {
        let files = [
            supportDirectory.appendingPathComponent("config.json"),
            supportDirectory.appendingPathComponent("kokoro-v1_0.safetensors"),
            supportDirectory.appendingPathComponent("voices/\(voice).npy"),
        ]
        return files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    func downloadAssets(onStatus: @MainActor @Sendable (String) -> Void) async throws {
        let downloader = VoiceDownloader(cacheDirectory: supportDirectory)
        let configPath = supportDirectory.appendingPathComponent("config.json")
        let weightsPath = supportDirectory.appendingPathComponent("kokoro-v1_0.safetensors")
        let voicePath = supportDirectory.appendingPathComponent("voices/\(voice).npy")

        if !FileManager.default.fileExists(atPath: configPath.path) {
            await onStatus("Downloading Kokoro configuration…")
        }
        _ = try await downloader.downloadConfig()

        if !FileManager.default.fileExists(atPath: weightsPath.path) {
            await onStatus("Downloading Kokoro model (~310 MB)…")
        }
        _ = try await downloader.downloadMLXWeights()

        if !FileManager.default.fileExists(atPath: voicePath.path) {
            await onStatus("Downloading Kokoro voice (\(voice))…")
        }
        _ = try await downloader.downloadVoice(voice)
    }

    struct AudioChunk: Sendable {
        let samples: [Float]
        let sampleRate: Int
    }

    func synthesize(
        text: String,
        onDownloadStatus: @MainActor @Sendable (String) -> Void,
        onDownloadComplete: @MainActor @Sendable () -> Void
    ) async throws -> AudioChunk {
        try Task.checkCancellation()
        if pipeline == nil {
            try await downloadAssets(onStatus: onDownloadStatus)
            await onDownloadComplete()
            try Task.checkCancellation()
            let configURL = supportDirectory.appendingPathComponent("config.json")
            let weightsURL = supportDirectory.appendingPathComponent("kokoro-v1_0.safetensors")
            let model = try KModel(configURL: configURL, weightsURL: weightsURL)
            let voices = VoiceLoader(
                baseDirectory: supportDirectory.appendingPathComponent("voices", isDirectory: true)
            )
            pipeline = KPipeline(model: model, voices: voices, langCode: "en-us")
            NSLog("[Kokoro] MLX model loaded; voice=%@", voice)
        }

        guard let pipeline else {
            throw NSError(domain: "Speak2.Kokoro", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Kokoro model failed to initialize."
            ])
        }
        try Task.checkCancellation()
        let start = ContinuousClock.now
        let result = try pipeline.synthesize(text: text, voice: voice)
        try Task.checkCancellation()
        NSLog("[Kokoro] Synthesized %d characters in %@", text.count, String(describing: start.duration(to: .now)))
        return AudioChunk(samples: result.audio, sampleRate: result.sampleRate)
    }
}
