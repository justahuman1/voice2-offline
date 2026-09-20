import Foundation

public struct TextReplacementEngine {
    public static func process(_ text: String, replacements: [String: String]) -> String {
        var result = text

        // Step 1: Apply the longest whole phrases first, without cascading replacements.
        // Pipes allow multiple recognized variants to share one replacement.
        var candidates = replacements.flatMap { phraseList, replacement in
            phraseList.split(separator: "|").compactMap { part -> (phrase: String, replacement: String)? in
                let phrase = part.trimmingCharacters(in: .whitespacesAndNewlines)
                return phrase.isEmpty ? nil : (phrase, replacement)
            }
        }
        candidates.sort {
            if $0.phrase.count != $1.phrase.count { return $0.phrase.count > $1.phrase.count }
            let phraseOrder = $0.phrase.localizedCaseInsensitiveCompare($1.phrase)
            if phraseOrder != .orderedSame { return phraseOrder == .orderedAscending }
            return $0.replacement < $1.replacement
        }

        var seen: Set<String> = []
        candidates = candidates.filter {
            seen.insert($0.phrase.lowercased()).inserted
        }

        if !candidates.isEmpty {
            var patterns = candidates.map { NSRegularExpression.escapedPattern(for: $0.phrase) }
            var patternCandidates = candidates

            // If a phrase contains separators, also accept different punctuation and
            // amounts of whitespace between the same words.
            for candidate in candidates {
                let parts = candidate.phrase.components(separatedBy: separatorCharacters).filter { !$0.isEmpty }
                guard parts.count > 1 else { continue }
                patterns.append(parts.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "[\\s\\p{P}]+"))
                patternCandidates.append(candidate)
            }

            let alternatives = patterns.map { "(\($0))" }.joined(separator: "|")
            let pattern = "(?<![\\p{L}\\p{N}_])(?:\(alternatives))(?![\\p{L}\\p{N}_])"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let original = result
                let matches = regex.matches(in: original, range: NSRange(original.startIndex..., in: original))
                for match in matches.reversed() {
                    guard let range = Range(match.range, in: original),
                          let candidateIndex = (0..<patternCandidates.count).first(where: {
                              match.range(at: $0 + 1).location != NSNotFound
                          }) else { continue }
                    result.replaceSubrange(range, with: patternCandidates[candidateIndex].replacement)
                }
            }
        }

        // Step 2: Strip enclosing quotes
        result = stripEnclosingQuotes(result)

        // Step 3: Clean bullet formatting
        result = cleanBulletFormatting(result)

        return result
    }

    private static let separatorCharacters = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

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
