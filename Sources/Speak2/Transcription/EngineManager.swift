import FluidAudio
import Foundation

@MainActor
final class EngineManager {
    private let appState: AppState
    private var engine: ParakeetEngine?
    private var loadTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    func loadModel(version: ParakeetVersion) {
        loadTask?.cancel()
        loadTask = nil
        unloadModel()

        appState.engineLoadingState = .loading
        loadTask = Task {
            let newEngine = ParakeetEngine(version: version)
            do {
                try await newEngine.loadModel()
                guard !Task.isCancelled else { return }
                self.engine = newEngine
                self.appState.engineLoadingState = .loaded
            } catch {
                guard !Task.isCancelled else { return }
                self.appState.engineLoadingState = .notDownloaded
            }
        }
    }

    func unloadModel() {
        engine?.unloadModel()
        engine = nil

        if isModelDownloaded(version: appState.selectedVersion) {
            appState.engineLoadingState = .downloaded
        } else {
            appState.engineLoadingState = .notDownloaded
        }
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let engine, engine.isReady else {
            throw ASRError.notInitialized
        }
        return try await engine.transcribe(audioSamples: audioSamples)
    }

    func isModelDownloaded(version: ParakeetVersion) -> Bool {
        let modelVersion: AsrModelVersion = switch version {
        case .v2: .v2
        case .v3: .v3
        }
        let cacheDir = AsrModels.defaultCacheDirectory(for: modelVersion)
        return AsrModels.modelsExist(at: cacheDir, version: modelVersion)
    }
}
