//
//  ConfigParser.swift
//  BHumanKit
//

import Foundation

/// Thrown when the text of a config file is not well-formed.
public enum ConfigParseError: Error, Equatable, Sendable {
    /// The text is malformed at the given line (starting at 1).
    case syntax(line: Int, message: String)
}

/// Parses B-Human's `.cfg` files (`Config/settings.cfg`, `Config/teams.cfg`, `Config/Robots/*/network.cfg`, ...).
///
/// Supported syntax: `key = value;` entries, bare words, `"quoted strings"`, `[lists, ...]`,
/// `{records = ...;}`, as well as `//` and `/* */` comments. Duplicate keys: the last one wins.
public enum ConfigParser {
    /// Parses the text of a config file.
    /// - Parameter text: The contents of the file.
    /// - Returns: The top-level entries of the file.
    /// - Throws: ``ConfigParseError`` if the text is malformed.
    public static func parse(_ text: String) throws -> [String: ConfigValue] {
        var lexer = Lexer(text)
        let lexemes = try lexer.tokenize()
        var parser = Parser(lexemes: lexemes)
        return try parser.parseDocument()
    }
}

// MARK: - Lexer

private enum Token: Equatable {
    case word(String)
    case quoted(String)
    case equals
    case semicolon
    case comma
    case openBrace
    case closeBrace
    case openBracket
    case closeBracket
}

private struct Lexeme {
    let token: Token
    let line: Int
}

private struct Lexer {
    private static let punctuation: [Unicode.Scalar: Token] = [
        "=": .equals,
        ";": .semicolon,
        ",": .comma,
        "{": .openBrace,
        "}": .closeBrace,
        "[": .openBracket,
        "]": .closeBracket
    ]

    private let scalars: [Unicode.Scalar]
    private var position = 0
    private var line = 1

    init(_ text: String) {
        scalars = Array(text.unicodeScalars)
    }

    mutating func tokenize() throws -> [Lexeme] {
        var lexemes: [Lexeme] = []
        while let lexeme = try nextLexeme() {
            lexemes.append(lexeme)
        }
        return lexemes
    }

    private func peek(offset: Int = 0) -> Unicode.Scalar? {
        let index = position + offset
        return index < scalars.count ? scalars[index] : nil
    }

    private func isCommentStart(offset: Int = 0) -> Bool {
        peek(offset: offset) == "/" && (peek(offset: offset + 1) == "/" || peek(offset: offset + 1) == "*")
    }

    private mutating func skipTrivia() throws {
        while let scalar = peek() {
            if scalar == "\n" {
                line += 1
                position += 1
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                // Must match `isDelimiter`, otherwise `readWord` would not make progress on such a scalar.
                position += 1
            } else if scalar == "/" && peek(offset: 1) == "/" {
                while let next = peek(), next != "\n" {
                    position += 1
                }
            } else if scalar == "/" && peek(offset: 1) == "*" {
                try skipBlockComment()
            } else {
                return
            }
        }
    }

    private mutating func skipBlockComment() throws {
        let startLine = line
        position += 2
        while let scalar = peek() {
            if scalar == "*" && peek(offset: 1) == "/" {
                position += 2
                return
            }
            if scalar == "\n" {
                line += 1
            }
            position += 1
        }
        throw ConfigParseError.syntax(line: startLine, message: "unterminated comment")
    }

    private mutating func nextLexeme() throws -> Lexeme? {
        try skipTrivia()
        guard let scalar = peek() else {
            return nil
        }
        let startLine = line
        if let punctuation = Lexer.punctuation[scalar] {
            position += 1
            return Lexeme(token: punctuation, line: startLine)
        }
        if scalar == "\"" {
            let text = try readQuoted()
            return Lexeme(token: .quoted(text), line: startLine)
        }
        return Lexeme(token: .word(readWord()), line: startLine)
    }

    private mutating func readQuoted() throws -> String {
        let startLine = line
        position += 1
        var text = ""
        while let scalar = peek() {
            position += 1
            if scalar == "\"" {
                return text
            }
            if scalar == "\n" {
                break
            }
            if scalar == "\\", let escaped = peek() {
                position += 1
                let replacement: Unicode.Scalar = escaped == "n" ? "\n" : escaped
                text.unicodeScalars.append(replacement)
            } else {
                text.unicodeScalars.append(scalar)
            }
        }
        throw ConfigParseError.syntax(line: startLine, message: "unterminated string")
    }

    private mutating func readWord() -> String {
        var text = ""
        while let scalar = peek(), !isDelimiter(scalar), !isCommentStart() {
            text.unicodeScalars.append(scalar)
            position += 1
        }
        return text
    }

    private func isDelimiter(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "\"" || Lexer.punctuation[scalar] != nil || CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}

// MARK: - Parser

private struct Parser {
    private let lexemes: [Lexeme]
    private var position = 0

    init(lexemes: [Lexeme]) {
        self.lexemes = lexemes
    }

    mutating func parseDocument() throws -> [String: ConfigValue] {
        try parseEntries(closing: nil)
    }

    private var current: Lexeme? {
        position < lexemes.count ? lexemes[position] : nil
    }

    private var lastLine: Int {
        lexemes.last?.line ?? 1
    }

    private mutating func consumeIfPresent(_ token: Token) {
        if current?.token == token {
            position += 1
        }
    }

    private mutating func parseEntries(closing: Token?) throws -> [String: ConfigValue] {
        var entries: [String: ConfigValue] = [:]
        while true {
            guard let lexeme = current else {
                if closing == nil {
                    return entries
                }
                throw ConfigParseError.syntax(line: lastLine, message: "missing closing brace")
            }
            if let closing, lexeme.token == closing {
                position += 1
                return entries
            }
            let key = try parseKey()
            try expect(.equals)
            entries[key] = try parseValue()
            consumeIfPresent(.semicolon)
        }
    }

    private mutating func parseKey() throws -> String {
        guard let lexeme = current else {
            throw ConfigParseError.syntax(line: lastLine, message: "unexpected end of file, expected a key")
        }
        switch lexeme.token {
        case .word(let text), .quoted(let text):
            position += 1
            return text
        default:
            throw ConfigParseError.syntax(line: lexeme.line, message: "expected a key")
        }
    }

    private mutating func expect(_ token: Token) throws {
        guard let lexeme = current else {
            throw ConfigParseError.syntax(line: lastLine, message: "unexpected end of file")
        }
        guard lexeme.token == token else {
            throw ConfigParseError.syntax(line: lexeme.line, message: "expected '=' after the key")
        }
        position += 1
    }

    private mutating func parseValue() throws -> ConfigValue {
        guard let lexeme = current else {
            throw ConfigParseError.syntax(line: lastLine, message: "unexpected end of file, expected a value")
        }
        position += 1
        switch lexeme.token {
        case .word(let text), .quoted(let text):
            return .scalar(text)
        case .openBracket:
            return .list(try parseListElements())
        case .openBrace:
            return .record(try parseEntries(closing: .closeBrace))
        default:
            throw ConfigParseError.syntax(line: lexeme.line, message: "expected a value")
        }
    }

    private mutating func parseListElements() throws -> [ConfigValue] {
        var values: [ConfigValue] = []
        while true {
            guard let lexeme = current else {
                throw ConfigParseError.syntax(line: lastLine, message: "missing closing bracket")
            }
            if lexeme.token == .closeBracket {
                position += 1
                return values
            }
            values.append(try parseValue())
            consumeIfPresent(.comma)
        }
    }
}
