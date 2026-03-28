import Foundation

public struct TranscriptionEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let timestamp: Date

    public init(id: UUID, text: String, timestamp: Date) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}
