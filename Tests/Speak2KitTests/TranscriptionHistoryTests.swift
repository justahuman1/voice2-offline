import Foundation
import Testing
@testable import Speak2Kit

@Suite("TranscriptionEntry Tests")
struct TranscriptionHistoryTests {

    @Test func codableRoundTrip() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1700000000)
        let entry = TranscriptionEntry(id: id, text: "Hello world", timestamp: date)

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TranscriptionEntry.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.text == "Hello world")
        #expect(decoded.timestamp == date)
    }

    @Test func jsonSerializationFormat() throws {
        let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let date = Date(timeIntervalSince1970: 1700000000)
        let entry = TranscriptionEntry(id: id, text: "Test", timestamp: date)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["id"] as? String == "12345678-1234-1234-1234-123456789ABC")
        #expect(json["text"] as? String == "Test")
        #expect(json["timestamp"] != nil)
    }

    @Test func propertiesPreserved() {
        let id = UUID()
        let date = Date()
        let entry = TranscriptionEntry(id: id, text: "Sample text", timestamp: date)

        #expect(entry.id == id)
        #expect(entry.text == "Sample text")
        #expect(entry.timestamp == date)
    }

    @Test func arrayRoundTrip() throws {
        let entries = [
            TranscriptionEntry(id: UUID(), text: "First", timestamp: Date(timeIntervalSince1970: 1000)),
            TranscriptionEntry(id: UUID(), text: "Second", timestamp: Date(timeIntervalSince1970: 2000)),
            TranscriptionEntry(id: UUID(), text: "Third", timestamp: Date(timeIntervalSince1970: 3000)),
        ]

        let data = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode([TranscriptionEntry].self, from: data)

        #expect(decoded.count == 3)
        for i in 0..<entries.count {
            #expect(decoded[i].id == entries[i].id)
            #expect(decoded[i].text == entries[i].text)
            #expect(decoded[i].timestamp == entries[i].timestamp)
        }
    }
}
