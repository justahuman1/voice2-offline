import Foundation
import Speak2Kit

@Observable
@MainActor
final class TranscriptionHistory {
    static let shared = TranscriptionHistory()
    private(set) var entries: [TranscriptionEntry] = []

    private static let maxEntries = 100

    private var fileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Speak2", isDirectory: true)
        return dir.appendingPathComponent("transcription_history.json")
    }

    func addEntry(_ text: String) {
        let entry = TranscriptionEntry(id: UUID(), text: text, timestamp: Date.now)
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        save()
        TranscriptionStats.shared.increment()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    func load() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([TranscriptionEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func save() {
        let url = fileURL
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            // Silently fail on write errors
        }
    }
}
