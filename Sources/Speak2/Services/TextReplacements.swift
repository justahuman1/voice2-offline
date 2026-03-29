import Foundation
import Speak2Kit

final class TextReplacements {
    static let shared = TextReplacements()

    private var replacements: [String: String] = [:]

    private init() {
        reloadConfig()
    }

    func reloadConfig() {
        replacements = [:]

        let primaryPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Speak2/config.json").path
        let fallbackPath = "./config.json"

        let path: String
        if FileManager.default.fileExists(atPath: primaryPath) {
            path = primaryPath
        } else if FileManager.default.fileExists(atPath: fallbackPath) {
            path = fallbackPath
        } else {
            return
        }

        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let textReplacements = json["textReplacements"] as? [String: String] else {
            return
        }

        replacements = textReplacements
    }

    func processText(_ text: String) -> String {
        TextReplacementEngine.process(text, replacements: replacements)
    }
}
