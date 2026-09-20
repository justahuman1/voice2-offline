import Foundation
import Speak2Kit

struct TextReplacementEntry: Identifiable, Equatable {
    let id: UUID
    var phrase: String
    var replacement: String

    init(id: UUID = UUID(), phrase: String, replacement: String) {
        self.id = id
        self.phrase = phrase
        self.replacement = replacement
    }
}

@Observable
@MainActor
final class TextReplacements {
    static let shared = TextReplacements()

    private(set) var entries: [TextReplacementEntry] = []
    private(set) var persistenceError: String?

    private let fileManager: FileManager
    private let configURL: URL
    private var baseConfiguration: [String: Any] = [:]

    private init() {
        fileManager = .default
        configURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Speak2/config.json")
        try? reload()
    }

    func reload() throws {
        let fallbackURL = URL(fileURLWithPath: "./config.json")
        let sourceURL: URL?
        if fileManager.fileExists(atPath: configURL.path) {
            sourceURL = configURL
        } else if fileManager.fileExists(atPath: fallbackURL.path) {
            sourceURL = fallbackURL
        } else {
            sourceURL = nil
        }

        guard let sourceURL else {
            entries = []
            baseConfiguration = [:]
            persistenceError = nil
            return
        }

        let data = try Data(contentsOf: sourceURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        baseConfiguration = json
        let replacements = json["textReplacements"] as? [String: String] ?? [:]
        entries = replacements
            .map { TextReplacementEntry(phrase: $0.key, replacement: $0.value) }
            .sorted { $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending }
        persistenceError = nil
    }

    func addEntry() {
        entries.append(TextReplacementEntry(phrase: "", replacement: ""))
    }

    func updateEntry(id: UUID, phrase: String? = nil, replacement: String? = nil) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        if let phrase { entries[index].phrase = phrase }
        if let replacement { entries[index].replacement = replacement }
        persistChanges()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        persistChanges()
    }

    func save() throws {
        var replacements: [String: String] = [:]
        var seen: Set<String> = []
        for entry in entries {
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { continue }
            let normalized = phrase.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(normalized).inserted else { continue }
            replacements[phrase] = entry.replacement
        }

        var configuration = baseConfiguration
        configuration["textReplacements"] = replacements
        let data = try JSONSerialization.data(withJSONObject: configuration, options: [.prettyPrinted, .sortedKeys])
        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: configURL, options: .atomic)
        baseConfiguration = configuration
        persistenceError = nil
    }

    func processText(_ text: String) -> String {
        TextReplacementEngine.process(text, replacements: replacementDictionary)
    }

    func isDuplicate(_ id: UUID) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }) else { return false }
        let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return false }
        return entries.contains {
            $0.id != id && $0.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
                .compare(phrase, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var replacementDictionary: [String: String] {
        var result: [String: String] = [:]
        var seen: Set<String> = []
        for entry in entries {
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = phrase.lowercased()
            guard !phrase.isEmpty, seen.insert(normalized).inserted else { continue }
            result[phrase] = entry.replacement
        }
        return result
    }

    private func persistChanges() {
        do {
            try save()
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
