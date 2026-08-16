import Foundation

/// Parse a pasted shell-style command line into executable + argv.
/// Supports `\` line continuations, single/double quotes, and backslash escapes (`\$`, `\"`, `\\`).
enum CommandLineParser {
    struct Result: Equatable {
        var executable: String
        var arguments: [String]

        var argumentsText: String {
            arguments.joined(separator: "\n")
        }
    }

    enum ParseError: Error, Equatable {
        case empty
        case unbalancedSingleQuote
        case unbalancedDoubleQuote
        case trailingEscape
        case noExecutable
    }

    static func parse(_ raw: String) -> Result? {
        switch parseDetailed(raw) {
        case .success(let result): result
        case .failure: nil
        }
    }

    static func parseDetailed(_ raw: String) -> Swift.Result<Result, ParseError> {
        let joined = joinContinuations(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { return .failure(.empty) }

        let tokenized = ShellQuoteTokenizer.tokenizeDetailed(joined)
        if tokenized.inSingleQuote { return .failure(.unbalancedSingleQuote) }
        if tokenized.inDoubleQuote { return .failure(.unbalancedDoubleQuote) }
        if tokenized.trailingEscape { return .failure(.trailingEscape) }

        guard let first = tokenized.tokens.first, !first.isEmpty else {
            return .failure(.noExecutable)
        }
        return .success(Result(executable: first, arguments: Array(tokenized.tokens.dropFirst())))
    }

    /// Collapse `line \` + next line into a single logical line.
    static func joinContinuations(_ raw: String) -> String {
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var parts: [String] = []
        var buffer = ""

        for (index, line) in lines.enumerated() {
            let trimmedRight = line.replacingOccurrences(
                of: #"\s+$"#,
                with: "",
                options: .regularExpression
            )
            if trimmedRight.hasSuffix("\\"), !isEscapedTrailingBackslash(trimmedRight) {
                let withoutSlash = String(trimmedRight.dropLast())
                buffer += withoutSlash
                // Shell typically removes the newline after `\`; keep a single space if needed.
                if index < lines.count - 1 {
                    buffer += " "
                }
            } else {
                buffer += line
                parts.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty {
            parts.append(buffer)
        }
        return parts.joined(separator: "\n")
    }

    /// True when the final `\` is itself escaped (even count of trailing backslashes → not a continuation).
    private static func isEscapedTrailingBackslash(_ line: String) -> Bool {
        var count = 0
        for char in line.reversed() {
            if char == "\\" { count += 1 } else { break }
        }
        return count % 2 == 0
    }
}

enum ShellQuoteTokenizer {
    struct TokenizeResult: Equatable {
        var tokens: [String]
        var inSingleQuote: Bool
        var inDoubleQuote: Bool
        var trailingEscape: Bool
    }

    /// Splits on whitespace; respects quotes and backslash escapes.
    static func tokenize(_ input: String) -> [String] {
        tokenizeDetailed(input).tokens
    }

    static func tokenizeDetailed(_ input: String) -> TokenizeResult {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escapeNext = false

        for char in input {
            if escapeNext {
                // Inside single quotes, backslash is usually literal in bash — we still
                // accept `\'` ending only via quote toggle; escaped char is appended as-is.
                if inSingle {
                    current.append("\\")
                    current.append(char)
                } else {
                    current.append(unescape(char, inDouble: inDouble))
                }
                escapeNext = false
                continue
            }

            if char == "\\", !inSingle {
                escapeNext = true
                continue
            }

            switch char {
            case "'" where !inDouble:
                inSingle.toggle()
            case "\"" where !inSingle:
                inDouble.toggle()
            case let c where c.isWhitespace && !inSingle && !inDouble:
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            default:
                current.append(char)
            }
        }

        if escapeNext {
            current.append("\\")
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return TokenizeResult(
            tokens: tokens,
            inSingleQuote: inSingle,
            inDoubleQuote: inDouble,
            trailingEscape: escapeNext
        )
    }

    private static func unescape(_ char: Character, inDouble: Bool) -> Character {
        // Common shell escapes useful for pasted CLI prompts.
        switch char {
        case "$", "`", "\"", "\\", "\n", "\t", " ":
            return char
        default:
            // Outside quotes, unknown escapes often keep the escaped char only.
            return char
        }
    }
}
