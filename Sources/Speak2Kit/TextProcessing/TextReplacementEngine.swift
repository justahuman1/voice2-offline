import Foundation

public struct TextReplacementEngine {
    public static func process(_ text: String, replacements: [String: String]) -> String {
        var result = text

        // Step 1: Apply find/replace
        for (find, replace) in replacements {
            result = result.replacingOccurrences(of: find, with: replace)
        }

        // Step 2: Strip enclosing quotes
        result = stripEnclosingQuotes(result)

        // Step 3: Clean bullet formatting
        result = cleanBulletFormatting(result)

        return result
    }

    private static func stripEnclosingQuotes(_ text: String) -> String {
        let quotePairs: [(Character, Character)] = [
            ("\"", "\""),
            ("'", "'"),
            ("\u{201C}", "\u{201D}"), // left/right double quotes
            ("\u{2018}", "\u{2019}"), // left/right single quotes
        ]

        for (open, close) in quotePairs {
            if text.first == open && text.last == close && text.count >= 2 {
                return String(text.dropFirst().dropLast())
            }
        }
        return text
    }

    private static func cleanBulletFormatting(_ text: String) -> String {
        var result = text

        // Remove "- " prefix
        if result.hasPrefix("- ") {
            result = String(result.dropFirst(2))
        }

        // Remove single leading space, preserve double+ spaces
        if result.hasPrefix(" ") && !result.hasPrefix("  ") {
            result = String(result.dropFirst())
        }

        return result
    }
}
