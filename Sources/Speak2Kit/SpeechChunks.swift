import Foundation

/// Word counts are soft targets: preserve sentence context for Kokoro's prosody.
public enum SpeechChunks {
    public static func split(_ text: String, firstTarget: Int = 20, laterTarget: Int = 60) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { _, range, _, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
        }
        var chunks: [String] = []
        var pending: [String] = []
        var words = 0
        for sentence in sentences {
            pending.append(sentence)
            words += sentence.split(whereSeparator: { $0.isWhitespace }).count
            if words >= max(1, chunks.isEmpty ? firstTarget : laterTarget) {
                chunks.append(pending.joined(separator: " "))
                pending = []
                words = 0
            }
        }
        if !pending.isEmpty { chunks.append(pending.joined(separator: " ")) }
        return chunks
    }
}
