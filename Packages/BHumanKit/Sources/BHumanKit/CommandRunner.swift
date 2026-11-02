//
//  CommandRunner.swift
//  BHumanKit
//

import Foundation

/// A program to run, with its arguments. No shell is involved, so arguments are never re-interpreted.
public struct CommandInvocation: Equatable, Sendable {
    /// The program, either a path or a name that is looked up in `PATH`.
    public var executable: String
    /// The arguments, not including the program itself.
    public var arguments: [String]
    /// The directory to run the program in, or `nil` to inherit the caller's.
    public var workingDirectory: String?

    /// Creates an invocation.
    public init(executable: String, arguments: [String] = [], workingDirectory: String? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
    }

    /// The invocation as one line for a POSIX shell, with every word single-quoted where necessary.
    ///
    /// This is meant for handing the invocation to something that only accepts a command string, e.g. a task
    /// that is run by a shell. The working directory is not part of the line.
    public var shellCommandLine: String {
        ([executable] + arguments).map(CommandInvocation.shellQuoted).joined(separator: " ")
    }

    private static let shellSafeCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:=@%+,"
    )

    private static func shellQuoted(_ word: String) -> String {
        let isSafe = !word.isEmpty && word.unicodeScalars.allSatisfy { shellSafeCharacters.contains($0) }
        if isSafe {
            return word
        }
        return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// What a finished program produced.
public struct CommandResult: Equatable, Sendable {
    /// The exit code of the program.
    public var exitCode: Int32
    /// Everything the program wrote to its standard output.
    public var standardOutput: String
    /// Everything the program wrote to its standard error.
    public var standardError: String

    /// Whether the program exited with code 0.
    public var succeeded: Bool { exitCode == 0 }

    /// Creates a result.
    public init(exitCode: Int32 = 0, standardOutput: String = "", standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// Runs programs on behalf of the services in this package.
///
/// The services never start processes themselves. The app provides an implementation (for example one that
/// feeds CodeEdit's task output), and tests provide a fake.
public protocol CommandRunner: Sendable {
    /// Runs the program and waits until it exits.
    /// - Parameter invocation: What to run.
    /// - Returns: The result, also if the exit code is not 0.
    /// - Throws: If the program could not be started at all.
    func run(_ invocation: CommandInvocation) async throws -> CommandResult
}
