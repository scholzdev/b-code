//
//  ShellClient+StartupOutput.swift
//  BCode
//

import Foundation

extension ShellClient {
    /// The line ``runSkippingStartupOutput(_:)`` prints right before the command.
    static let startupOutputMarker = "__BCODE_COMMAND_OUTPUT_BEGINS__"

    /// Runs `command` like ``run(_:)``, but returns only what the command printed.
    ///
    /// The shell is a login shell, so it reads the user's `.zprofile` and `.zshrc` first. Anything they print,
    /// for example `zsh: command not found: …` from a broken line, would otherwise come before the command's
    /// output and end up in parsed values such as the current branch name.
    /// - Parameter command: The command to run.
    /// - Returns: The output of the command (stdout and stderr), without the shell's startup output.
    func runSkippingStartupOutput(_ command: String) throws -> String {
        let output = try run("echo \(Self.startupOutputMarker);\(command)")
        return Self.removingStartupOutput(output)
    }

    /// Removes everything up to and including the line with ``startupOutputMarker``.
    /// - Parameter output: The output of a command started by ``runSkippingStartupOutput(_:)``.
    /// - Returns: The output after the marker, or `output` unchanged if it has no marker.
    static func removingStartupOutput(_ output: String) -> String {
        guard let range = output.range(of: startupOutputMarker + "\n") else {
            return output
        }
        return String(output[range.upperBound...])
    }
}
