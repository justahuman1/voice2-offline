import Testing
@testable import Speak2Kit

struct SpeechChunksTests {
    @Test func emptyInput() {
        #expect(SpeechChunks.split(" \n ").isEmpty)
    }

    @Test func combinesShortSentencesAtNaturalBoundaries() {
        #expect(SpeechChunks.split("Hi. How are you? Fine!", firstTarget: 4) == ["Hi. How are you?", "Fine!"])
    }

    @Test func preservesLongSentencesAndTrailingText() {
        let sentence = "This is a long sentence that must remain intact despite the small word target."
        #expect(SpeechChunks.split(sentence + " Unpunctuated ending", firstTarget: 2) == [sentence, "Unpunctuated ending"])
    }

    @Test func usesLargerTargetAfterFirstChunk() {
        #expect(SpeechChunks.split("One two. Three four. Five six. Seven eight.", firstTarget: 2, laterTarget: 4)
                == ["One two.", "Three four. Five six.", "Seven eight."])
    }

    @Test func retainsDecimalAndAbbreviationText() {
        let text = "Dr. Smith paid 3.14 dollars. Then he left."
        let chunks = SpeechChunks.split(text, firstTarget: 1)
        #expect(chunks.joined(separator: " ") == text)
        #expect(chunks.contains { $0.contains("3.14") })
    }
}
