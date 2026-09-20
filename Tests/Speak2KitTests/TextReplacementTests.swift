import Testing
@testable import Speak2Kit

@Suite("TextReplacementEngine Tests")
struct TextReplacementTests {

    @Test func singleReplacement() {
        let result = TextReplacementEngine.process("hello world", replacements: ["world": "there"])
        #expect(result == "hello there")
    }

    @Test func multipleReplacements() {
        let result = TextReplacementEngine.process("aaa bbb ccc", replacements: ["aaa": "xxx", "ccc": "zzz"])
        #expect(result == "xxx bbb zzz")
    }

    @Test func stripDoubleQuotes() {
        let result = TextReplacementEngine.process("\"hello\"", replacements: [:])
        #expect(result == "hello")
    }

    @Test func stripSingleQuotes() {
        let result = TextReplacementEngine.process("'hello'", replacements: [:])
        #expect(result == "hello")
    }

    @Test func stripSmartDoubleQuotes() {
        let result = TextReplacementEngine.process("\u{201C}hello\u{201D}", replacements: [:])
        #expect(result == "hello")
    }

    @Test func stripSmartSingleQuotes() {
        let result = TextReplacementEngine.process("\u{2018}hello\u{2019}", replacements: [:])
        #expect(result == "hello")
    }

    @Test func mismatchedQuotesNotStripped() {
        let result = TextReplacementEngine.process("\"hello'", replacements: [:])
        #expect(result == "\"hello'")

        let result2 = TextReplacementEngine.process("\u{201C}hello\u{2019}", replacements: [:])
        #expect(result2 == "\u{201C}hello\u{2019}")
    }

    @Test func bulletDashRemoval() {
        let result = TextReplacementEngine.process("- item", replacements: [:])
        #expect(result == "item")
    }

    @Test func singleLeadingSpaceRemoved() {
        let result = TextReplacementEngine.process(" hello", replacements: [:])
        #expect(result == "hello")
    }

    @Test func doubleLeadingSpacePreserved() {
        let result = TextReplacementEngine.process("  hello", replacements: [:])
        #expect(result == "  hello")
    }

    @Test func emptyInputReturnsEmpty() {
        let result = TextReplacementEngine.process("", replacements: [:])
        #expect(result == "")
    }

    @Test func emptyReplacementsReturnsOriginal() {
        let result = TextReplacementEngine.process("unchanged text", replacements: [:])
        #expect(result == "unchanged text")
    }

    @Test func combinedPipeline() {
        let result = TextReplacementEngine.process("\"- fix typo helo\"", replacements: ["helo": "hello"])
        #expect(result == "fix typo hello")
    }

    @Test func matchingIsCaseInsensitive() {
        let result = TextReplacementEngine.process("Use GIT and Git", replacements: ["git": "GitHub"])
        #expect(result == "Use GitHub and GitHub")
    }

    @Test func phraseMatchesAtBoundaries() {
        let result = TextReplacementEngine.process("I use visual studio code, daily.", replacements: ["Visual Studio Code": "VS Code"])
        #expect(result == "I use VS Code, daily.")
    }

    @Test func longerOverlappingPhraseWins() {
        let result = TextReplacementEngine.process(
            "new york and york",
            replacements: ["york": "Yorkshire", "new york": "NYC"]
        )
        #expect(result == "NYC and Yorkshire")
    }

    @Test func doesNotReplaceInsideLargerWords() {
        let result = TextReplacementEngine.process("cat concatenate bobcat cat", replacements: ["cat": "dog"])
        #expect(result == "dog concatenate bobcat dog")
    }

    @Test func pipeSeparatedAlternatives() {
        let result = TextReplacementEngine.process(
            "Ty K V, Ty KV, and Thai KV",
            replacements: ["Ty K V | Ty KV | Thai KV": "TiKV"]
        )
        #expect(result == "TiKV, TiKV, and TiKV")
    }

    @Test func commaCanBePartOfPhrase() {
        let result = TextReplacementEngine.process(
            "hello, world",
            replacements: ["hello, world | hello there": "greeting"]
        )
        #expect(result == "greeting")
    }

    @Test func normalizesPunctuationAndWhitespaceBetweenWords() {
        let result = TextReplacementEngine.process(
            "visual, studio   code",
            replacements: ["visual studio code": "VS Code"]
        )
        #expect(result == "VS Code")
    }
}
