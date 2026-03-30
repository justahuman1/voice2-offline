import FluidAudio
import Foundation
import Speak2Kit

final class ParakeetEngine {
    private let version: ParakeetVersion
    private var asrManager: AsrManager?

    var isReady: Bool { asrManager != nil }

    init(version: ParakeetVersion) {
        self.version = version
    }

    private var modelVersion: AsrModelVersion {
        switch version {
        case .v2: .v2
        case .v3: .v3
        }
    }

    func loadFromCache() async throws {
        let models = try await AsrModels.loadFromCache(version: modelVersion)
        let manager = AsrManager()
        try await manager.initialize(models: models)
        self.asrManager = manager
    }

    func downloadModel(progressHandler: DownloadUtils.ProgressHandler? = nil) async throws {
        try await AsrModels.download(version: modelVersion, progressHandler: progressHandler)
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
