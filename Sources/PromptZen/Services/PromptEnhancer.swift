import Foundation

/// Local, deterministic helpers to tighten prompts (fewer tokens, less rambling structure).
enum PromptEnhancer {
    static func trimWhitespace(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Collapse runs of blank lines to a single blank line.
    static func collapseBlankLines(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var out: [String] = []
        var lastWasEmpty = false
        for line in lines {
            let empty = line.trimmingCharacters(in: .whitespaces).isEmpty
            if empty {
                if !lastWasEmpty { out.append("") }
                lastWasEmpty = true
            } else {
                out.append(line)
                lastWasEmpty = false
            }
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripTrailingWhitespacePerLine(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")
    }
}
