import Foundation

@Observable
@MainActor
final class TranscriptionStats {
    static let shared = TranscriptionStats()
    private(set) var totalTranscriptions: Int = 0

    private var fileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Speak2", isDirectory: true)
        return dir.appendingPathComponent("transcription_stats.json")
    }

    func increment() {
        totalTranscriptions += 1
        save()
    }

    func load() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: Int].self, from: data)
            totalTranscriptions = decoded["totalTranscriptions"] ?? 0
        } catch {
            totalTranscriptions = 0
        }
    }

    private func save() {
        let url = fileURL
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(["totalTranscriptions": totalTranscriptions])
            try data.write(to: url, options: .atomic)
        } catch {
            // Silently fail on write errors
        }
    }
}
