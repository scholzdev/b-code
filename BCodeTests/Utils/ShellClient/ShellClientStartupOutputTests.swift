//
//  ShellClientStartupOutputTests.swift
//  BCodeTests
//

import Testing
@testable import BCode

@Suite
struct ShellClientStartupOutputTests {
    private let marker = ShellClient.startupOutputMarker

    @Test
    func dropsWhatTheStartupFilesPrinted() {
        let output = "zsh: command not found: docker --version\n\(marker)\nmain\n"
        #expect(ShellClient.removingStartupOutput(output) == "main\n")
    }

    @Test
    func keepsOutputWithoutStartupNoise() {
        #expect(ShellClient.removingStartupOutput("\(marker)\nmain\n") == "main\n")
    }

    @Test
    func keepsOutputWithoutMarker() {
        #expect(ShellClient.removingStartupOutput("main\n") == "main\n")
    }

    @Test
    func keepsErrorsOfTheCommandItself() {
        let output = "noise\n\(marker)\nfatal: not a git repository\n"
        #expect(ShellClient.removingStartupOutput(output) == "fatal: not a git repository\n")
    }

    @Test
    func runReturnsOnlyTheCommandOutput() throws {
        let output = try ShellClient.live().runSkippingStartupOutput("echo hello")
        // A login shell may still print something when it exits (`.zlogout`), so only check the start.
        #expect(output.hasPrefix("hello\n"))
    }
}
