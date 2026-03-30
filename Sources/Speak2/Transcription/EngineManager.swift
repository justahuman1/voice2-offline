import FluidAudio
import Foundation
import Speak2Kit

@MainActor
final class EngineManager {
    private let appState: AppState
    private var engine: ParakeetEngine?
    private var loadTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Load model from local cache only — no network access.
    func loadModel(version: ParakeetVersion) {
        loadTask?.cancel()
        loadTask = nil
        unloadModel()

        appState.engineLoadingState = .loading
        loadTask = Task {
            let newEngine = ParakeetEngine(version: version)
            do {
                try await newEngine.loadFromCache()
                guard !Task.isCancelled else { return }
                self.engine = newEngine
                self.appState.engineLoadingState = .loaded
            } catch {
                guard !Task.isCancelled else { return }
                self.appState.engineLoadingState = .notDownloaded
            }
        }
    }

    /// Download model from HuggingFace, then load from cache.
    func downloadAndLoadModel(version: ParakeetVersion) {
        loadTask?.cancel()
        loadTask = nil
        unloadModel()

        appState.engineLoadingState = .downloading(progress: 0)
        loadTask = Task {
            let newEngine = ParakeetEngine(version: version)
            do {
                try await newEngine.downloadModel { [weak self] progress in
                    Task { @MainActor in
                        self?.appState.engineLoadingState = .downloading(progress: progress.fractionCompleted)
                    }
                }
                guard !Task.isCancelled else { return }

                self.appState.engineLoadingState = .loading
                try await newEngine.loadFromCache()
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
