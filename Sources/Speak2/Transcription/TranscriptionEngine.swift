protocol TranscriptionEngine {
    var isReady: Bool { get }
    func loadModel() async throws
    func unloadModel()
    func transcribe(audioSamples: [Float]) async throws -> String
}
