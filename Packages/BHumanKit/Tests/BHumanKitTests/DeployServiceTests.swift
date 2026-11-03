//
//  DeployServiceTests.swift
//  BHumanKitTests
//

import XCTest
import Foundation
@testable import BHumanKit

final class DeployServiceTests: XCTestCase {
    private let root = "/work/BHumanCodeRelease"

    private struct SpawnError: Error, Equatable {}

    private func service(platform: HostPlatform = .linux, runner: FakeCommandRunner = FakeCommandRunner())
        -> DeployService {
        DeployService(repositoryRoot: root, platform: platform, runner: runner)
    }

    /// A runner that answers the `deploy` script with one result and every other command with another.
    private func runner(compile: CommandResult = CommandResult(), deploy: CommandResult = CommandResult())
        -> FakeCommandRunner {
        FakeCommandRunner { invocation in
            invocation.executable.hasSuffix("/Make/Common/deploy") ? deploy : compile
        }
    }

    private let twoRobots = [
        DeployTarget(address: "10.1.5.21", playerNumber: 1),
        DeployTarget(address: "10.1.5.23", playerNumber: 3)
    ]

    // MARK: Compile command

    func testCompilesWithCMakeOnLinux() {
        let invocation = service(platform: .linux).compileInvocation(for: .release)
        XCTAssertEqual(invocation, CommandInvocation(
            executable: "cmake",
            arguments: [
                "--build", "/work/BHumanCodeRelease/Build/Linux/CMake/Release",
                "--target", "Booster",
                "--config", "Release"
            ],
            workingDirectory: "/work/BHumanCodeRelease/Make/Linux"
        ))
    }

    func testCompilesWithTheCompileScriptOnMacOS() {
        let invocation = service(platform: .macOS).compileInvocation(for: .debug)
        XCTAssertEqual(invocation, CommandInvocation(
            executable: "/work/BHumanCodeRelease/Make/macOS/compile",
            arguments: ["Booster", "Debug"],
            workingDirectory: "/work/BHumanCodeRelease/Make/macOS"
        ))
    }

    func testCompileTargetCanBeChanged() {
        let custom = DeployService(
            repositoryRoot: root,
            platform: .macOS,
            compileTarget: "Other",
            runner: FakeCommandRunner()
        )
        XCTAssertEqual(custom.compileInvocation(for: .develop).arguments, ["Other", "Develop"])
    }

    // MARK: Deploy arguments

    func testSingleRobotWithPlayerNumber() throws {
        let request = DeployRequest(targets: [DeployTarget(address: "10.1.5.21", playerNumber: 3)])
        XCTAssertEqual(
            try service().deployArguments(for: request),
            ["Develop", "10.1.5.21", "-p", "3", "-nc"]
        )
    }

    func testSingleRobotWithoutPlayerNumber() throws {
        let request = DeployRequest(targets: [DeployTarget(address: "10.1.5.21")], configuration: .release)
        XCTAssertEqual(try service().deployArguments(for: request), ["Release", "10.1.5.21", "-nc"])
    }

    func testSeveralRobotsUseOneReplacementFlagEach() throws {
        let request = DeployRequest(targets: twoRobots, configuration: .release)
        XCTAssertEqual(
            try service().deployArguments(for: request),
            ["Release", "-r", "1", "10.1.5.21", "-r", "3", "10.1.5.23", "-nc"]
        )
    }

    func testAllOptionsComeInTheOrderOfTheDeployDialog() throws {
        let request = DeployRequest(
            targets: [DeployTarget(address: "10.1.5.21", playerNumber: 2)],
            configuration: .debug,
            teamNumber: 5,
            fieldPlayerColor: "blue",
            goalkeeperColor: "red",
            scenario: "Default",
            location: "Lab",
            magicNumber: 17,
            wlanProfile: "HSL_A",
            volume: 50,
            deleteLogs: true,
            restartAfterDeploy: true,
            keepRemoteAddress: true,
            skipReachabilityCheck: true
        )
        XCTAssertEqual(
            try service().deployArguments(for: request),
            [
                "Debug", "10.1.5.21", "-p", "2", "-k", "-nc", "-nr",
                "-t", "5", "-c", "blue", "-g", "red", "-s", "Default", "-l", "Lab",
                "-m", "17", "-w", "HSL_A", "-v", "50", "-d", "-b"
            ]
        )
    }

    func testDeployInvocationRunsTheScriptInItsDirectory() throws {
        let invocation = try service().deployInvocation(for: DeployRequest(targets: twoRobots))
        XCTAssertEqual(invocation.executable, "/work/BHumanCodeRelease/Make/Common/deploy")
        XCTAssertEqual(invocation.workingDirectory, "/work/BHumanCodeRelease/Make/Common")
    }

    // MARK: Validation

    func testRequestWithoutTargetsIsRejected() {
        XCTAssertThrowsError(try service().deployArguments(for: DeployRequest(targets: []))) { error in
            XCTAssertEqual(error as? DeployError, .noTargets)
        }
    }

    func testPlayerNumbersOutsideOneToTwentyAreRejected() {
        for number in [0, 21, -1] {
            let request = DeployRequest(targets: [DeployTarget(address: "10.1.5.21", playerNumber: number)])
            XCTAssertThrowsError(try service().deployArguments(for: request)) { error in
                XCTAssertEqual(error as? DeployError, .invalidPlayerNumber(number))
            }
        }
    }

    func testBoundaryPlayerNumbersAreAccepted() throws {
        for number in [1, 20] {
            let request = DeployRequest(targets: [DeployTarget(address: "10.1.5.21", playerNumber: number)])
            XCTAssertNoThrow(try service().deployArguments(for: request))
        }
    }

    func testSeveralRobotsNeedPlayerNumbers() {
        let request = DeployRequest(targets: [
            DeployTarget(address: "10.1.5.21", playerNumber: 1),
            DeployTarget(address: "10.1.5.23")
        ])
        XCTAssertThrowsError(try service().deployArguments(for: request)) { error in
            XCTAssertEqual(error as? DeployError, .missingPlayerNumber(address: "10.1.5.23"))
        }
    }

    // MARK: Running

    func testCompilesThenDeploysAndReportsProgress() async throws {
        let fake = runner()
        let steps = EventRecorder<DeployStep>()

        let report = try await service(runner: fake).deploy(DeployRequest(targets: twoRobots)) { steps.append($0) }

        XCTAssertEqual(fake.invocations.map(\.executable), ["cmake", "/work/BHumanCodeRelease/Make/Common/deploy"])
        XCTAssertEqual(steps.events, [.compiling(.develop), .deploying(robotCount: 2), .finished])
        XCTAssertNotNil(report.compile)
        XCTAssertTrue(report.deploy.succeeded)
    }

    func testSkipsCompilingIfNotRequested() async throws {
        let fake = runner()
        let steps = EventRecorder<DeployStep>()
        let request = DeployRequest(targets: twoRobots, compileFirst: false)

        let report = try await service(runner: fake).deploy(request) { steps.append($0) }

        XCTAssertEqual(fake.invocations.map(\.executable), ["/work/BHumanCodeRelease/Make/Common/deploy"])
        XCTAssertEqual(steps.events, [.deploying(robotCount: 2), .finished])
        XCTAssertNil(report.compile)
    }

    func testDeployPassesNoCompileFlagEvenAfterCompiling() async throws {
        let fake = runner()
        _ = try await service(runner: fake).deploy(DeployRequest(targets: twoRobots))
        XCTAssertTrue(fake.invocations.last?.arguments.contains("-nc") ?? false)
    }

    func testFailedCompileStopsBeforeDeploying() async {
        let failure = CommandResult(exitCode: 2, standardOutput: "", standardError: "error: nope")
        let fake = runner(compile: failure)
        let steps = EventRecorder<DeployStep>()

        do {
            _ = try await service(runner: fake).deploy(DeployRequest(targets: twoRobots)) { steps.append($0) }
            XCTFail("expected the compile to fail")
        } catch {
            XCTAssertEqual(error as? DeployError, .compileFailed(failure))
        }
        XCTAssertEqual(fake.invocations.count, 1)
        XCTAssertEqual(steps.events, [.compiling(.develop)])
    }

    func testFailedDeployIsReported() async {
        let failure = CommandResult(exitCode: 1, standardOutput: "", standardError: "10.1.5.21 not reachable")
        let fake = runner(deploy: failure)
        let steps = EventRecorder<DeployStep>()

        do {
            _ = try await service(runner: fake).deploy(DeployRequest(targets: twoRobots)) { steps.append($0) }
            XCTFail("expected the deployment to fail")
        } catch {
            XCTAssertEqual(error as? DeployError, .deployFailed(failure))
        }
        XCTAssertEqual(steps.events, [.compiling(.develop), .deploying(robotCount: 2)])
    }

    func testInvalidRequestRunsNothing() async {
        let fake = runner()
        do {
            _ = try await service(runner: fake).deploy(DeployRequest(targets: []))
            XCTFail("expected the request to be rejected")
        } catch {
            XCTAssertEqual(error as? DeployError, .noTargets)
        }
        XCTAssertTrue(fake.invocations.isEmpty)
    }

    func testRunnerErrorsPropagate() async {
        let fake = FakeCommandRunner { _ in throw SpawnError() }
        do {
            _ = try await service(runner: fake).compile(.release)
            XCTFail("expected the runner error")
        } catch {
            XCTAssertEqual(error as? SpawnError, SpawnError())
        }
    }

    // MARK: Shell command line

    func testShellCommandLineLeavesSafeWordsAlone() {
        let invocation = CommandInvocation(executable: "/work/deploy", arguments: ["Develop", "-r", "1", "10.1.5.21"])
        XCTAssertEqual(invocation.shellCommandLine, "/work/deploy Develop -r 1 10.1.5.21")
    }

    func testShellCommandLineQuotesEverythingElse() {
        let invocation = CommandInvocation(executable: "/a b/deploy", arguments: ["it's", "", "$HOME", "a;b"])
        XCTAssertEqual(invocation.shellCommandLine, "'/a b/deploy' 'it'\\''s' '' '$HOME' 'a;b'")
    }
}
