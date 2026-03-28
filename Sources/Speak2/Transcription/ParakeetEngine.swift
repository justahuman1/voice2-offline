import FluidAudio
import Foundation

final class ParakeetEngine: TranscriptionEngine {
    private let version: ParakeetVersion
    private var asrManager: AsrManager?

    var isReady: Bool { asrManager != nil }

    init(version: ParakeetVersion) {
        self.version = version
    }

    func loadModel() async throws {
        let manager = AsrManager()

        let modelVersion: AsrModelVersion = switch version {
        case .v2: .v2
        case .v3: .v3
        }

        let models = try await AsrModels.downloadAndLoad(version: modelVersion)
        try await manager.initialize(models: models)
        self.asrManager = manager
    }

    func unloadModel() {
        asrManager = nil
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let manager = asrManager else {
            throw ASRError.notInitialized
        }
        let result = try await manager.transcribe(audioSamples)
        return result.text
    }
}
