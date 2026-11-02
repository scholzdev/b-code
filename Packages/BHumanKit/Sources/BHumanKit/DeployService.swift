//
//  DeployService.swift
//  BHumanKit
//

import Foundation

/// The platform the B-Human tools run on. It decides how the code is compiled.
public enum HostPlatform: Sendable {
    /// macOS: compiled with `Make/macOS/compile`, which drives `xcodebuild`.
    case macOS
    /// Linux or WSL: compiled with CMake.
    case linux

    /// The platform this process is running on.
    public static var current: HostPlatform {
        #if os(macOS)
        return .macOS
        #else
        return .linux
        #endif
    }
}

/// A robot to deploy to.
public struct DeployTarget: Equatable, Sendable {
    /// The IP address to copy to.
    public var address: String
    /// The player number to configure (1-20). Required if more than one robot is deployed to.
    public var playerNumber: Int?

    /// Creates a target.
    public init(address: String, playerNumber: Int? = nil) {
        self.address = address
        self.playerNumber = playerNumber
    }
}

/// Everything needed for one run of `Make/Common/deploy`.
///
/// The options correspond to the flags of the script; the property documentation names them.
public struct DeployRequest: Equatable, Sendable {
    /// The build configuration to compile and copy.
    public var configuration: BuildConfiguration
    /// The robots to deploy to. At least one.
    public var targets: [DeployTarget]
    /// Compile before deploying. If `false`, the existing build is copied (`-nc` is passed either way, see
    /// ``DeployService``).
    public var compileFirst: Bool
    /// Team number written to the robot's `settings.cfg` (`-t`).
    public var teamNumber: Int?
    /// Jersey color of the field players (`-c`).
    public var fieldPlayerColor: String?
    /// Jersey color of the goalkeeper (`-g`).
    public var goalkeeperColor: String?
    /// Scenario (`-s`).
    public var scenario: String?
    /// Location (`-l`).
    public var location: String?
    /// Magic number for the team communication (`-m`).
    public var magicNumber: Int?
    /// Wireless profile to activate (`-w`).
    public var wlanProfile: String?
    /// Playback volume in percent (`-v`).
    public var volume: Int?
    /// Delete the logs on the robot (`-d`).
    public var deleteLogs: Bool
    /// Restart `bhuman` after copying (`-b`).
    public var restartAfterDeploy: Bool
    /// Remember the robot's address for SimRobot (`-k`). The Deploy Dialog sets this when deploying to
    /// exactly one robot.
    public var keepRemoteAddress: Bool
    /// Do not check whether the robots answer a ping first (`-nr`).
    public var skipReachabilityCheck: Bool

    /// Creates a request. Only the targets are mandatory.
    public init(
        targets: [DeployTarget],
        configuration: BuildConfiguration = .scriptDefault,
        compileFirst: Bool = true,
        teamNumber: Int? = nil,
        fieldPlayerColor: String? = nil,
        goalkeeperColor: String? = nil,
        scenario: String? = nil,
        location: String? = nil,
        magicNumber: Int? = nil,
        wlanProfile: String? = nil,
        volume: Int? = nil,
        deleteLogs: Bool = false,
        restartAfterDeploy: Bool = false,
        keepRemoteAddress: Bool = false,
        skipReachabilityCheck: Bool = false
    ) {
        self.targets = targets
        self.configuration = configuration
        self.compileFirst = compileFirst
        self.teamNumber = teamNumber
        self.fieldPlayerColor = fieldPlayerColor
        self.goalkeeperColor = goalkeeperColor
        self.scenario = scenario
        self.location = location
        self.magicNumber = magicNumber
        self.wlanProfile = wlanProfile
        self.volume = volume
        self.deleteLogs = deleteLogs
        self.restartAfterDeploy = restartAfterDeploy
        self.keepRemoteAddress = keepRemoteAddress
        self.skipReachabilityCheck = skipReachabilityCheck
    }
}

/// Why a deployment did not happen or did not succeed.
public enum DeployError: Error, Equatable, Sendable {
    /// The request contains no robots.
    case noTargets
    /// A player number is outside of 1-20, the range `Make/Common/deploy` accepts.
    case invalidPlayerNumber(Int)
    /// More than one robot is deployed to, but this one has no player number.
    case missingPlayerNumber(address: String)
    /// Compiling failed. Nothing was copied.
    case compileFailed(CommandResult)
    /// The `deploy` script exited with a non-zero code.
    case deployFailed(CommandResult)
}

/// A step of a deployment, reported while it runs.
public enum DeployStep: Equatable, Sendable {
    /// Compiling the given configuration.
    case compiling(BuildConfiguration)
    /// Copying to the given number of robots.
    case deploying(robotCount: Int)
    /// Everything succeeded.
    case finished
}

/// The outcome of a successful deployment.
public struct DeployReport: Equatable, Sendable {
    /// The compile step, or `nil` if compiling was not requested.
    public var compile: CommandResult?
    /// The `deploy` script.
    public var deploy: CommandResult

    /// Creates a report.
    public init(compile: CommandResult?, deploy: CommandResult) {
        self.compile = compile
        self.deploy = deploy
    }
}

/// Compiles the B-Human code and deploys it to robots by running the scripts of the Code Release.
///
/// This mirrors what B-Human's Deploy Dialog does: the code is compiled first, then
/// `Make/Common/deploy <Configuration> <robots> -nc <options>` is run. `-nc` is always passed because this
/// service compiles on its own, which lets callers show compile errors separately and stop early.
///
/// `deploy` copies to several robots in parallel and does not forward the failure of an individual robot as
/// its exit code. Inspect ``DeployReport/deploy`` output for lines starting with `[<address>]`.
public struct DeployService: Sendable {
    /// The root of the B-Human checkout, the directory that contains `Make` and `Config`.
    public let repositoryRoot: String
    /// The platform to compile for.
    public let platform: HostPlatform
    /// The build target that is compiled and deployed.
    public let compileTarget: String
    private let runner: any CommandRunner

    /// Creates a service.
    /// - Parameters:
    ///   - repositoryRoot: The root of the B-Human checkout.
    ///   - platform: The platform to compile for.
    ///   - compileTarget: The build target. The Code Release deploys `Booster`.
    ///   - runner: Runs the commands.
    public init(
        repositoryRoot: String,
        platform: HostPlatform = .current,
        compileTarget: String = "Booster",
        runner: any CommandRunner
    ) {
        self.repositoryRoot = repositoryRoot
        self.platform = platform
        self.compileTarget = compileTarget
        self.runner = runner
    }

    // MARK: Building the commands

    /// The command that compiles a configuration.
    public func compileInvocation(for configuration: BuildConfiguration) -> CommandInvocation {
        switch platform {
        case .macOS:
            return CommandInvocation(
                executable: path("Make/macOS/compile"),
                arguments: [compileTarget, configuration.rawValue],
                workingDirectory: path("Make/macOS")
            )
        case .linux:
            return CommandInvocation(
                executable: "cmake",
                arguments: [
                    "--build", path("Build/Linux/CMake/\(configuration.rawValue)"),
                    "--target", compileTarget,
                    "--config", configuration.rawValue
                ],
                workingDirectory: path("Make/Linux")
            )
        }
    }

    /// The command that copies the build to the robots.
    /// - Throws: ``DeployError`` if the request is invalid.
    public func deployInvocation(for request: DeployRequest) throws -> CommandInvocation {
        CommandInvocation(
            executable: path("Make/Common/deploy"),
            arguments: try deployArguments(for: request),
            workingDirectory: path("Make/Common")
        )
    }

    /// The arguments for `Make/Common/deploy`, in the order the Deploy Dialog produces them.
    /// - Throws: ``DeployError`` if the request is invalid.
    public func deployArguments(for request: DeployRequest) throws -> [String] {
        var arguments = [request.configuration.rawValue]
        arguments += try targetArguments(for: request.targets)
        if request.keepRemoteAddress {
            arguments.append("-k")
        }
        arguments.append("-nc")
        if request.skipReachabilityCheck {
            arguments.append("-nr")
        }
        appendOption("-t", request.teamNumber.map { String($0) }, to: &arguments)
        appendOption("-c", request.fieldPlayerColor, to: &arguments)
        appendOption("-g", request.goalkeeperColor, to: &arguments)
        appendOption("-s", request.scenario, to: &arguments)
        appendOption("-l", request.location, to: &arguments)
        appendOption("-m", request.magicNumber.map { String($0) }, to: &arguments)
        appendOption("-w", request.wlanProfile, to: &arguments)
        appendOption("-v", request.volume.map { String($0) }, to: &arguments)
        if request.deleteLogs {
            arguments.append("-d")
        }
        if request.restartAfterDeploy {
            arguments.append("-b")
        }
        return arguments
    }

    // MARK: Running

    /// Compiles a configuration.
    /// - Throws: ``DeployError/compileFailed(_:)`` if the compiler exits with a non-zero code, or whatever the
    ///   runner throws.
    @discardableResult
    public func compile(_ configuration: BuildConfiguration) async throws -> CommandResult {
        let result = try await runner.run(compileInvocation(for: configuration))
        guard result.succeeded else {
            throw DeployError.compileFailed(result)
        }
        return result
    }

    /// Compiles (if requested) and deploys.
    ///
    /// The request is validated before anything runs, so an invalid request never starts a long compile.
    ///
    /// - Parameters:
    ///   - request: What to deploy where.
    ///   - progress: Called when a step starts and when everything is done.
    /// - Returns: The results of both steps.
    /// - Throws: ``DeployError`` or whatever the runner throws.
    public func deploy(
        _ request: DeployRequest,
        progress: (@Sendable (DeployStep) -> Void)? = nil
    ) async throws -> DeployReport {
        let deployCommand = try deployInvocation(for: request)

        var compileResult: CommandResult?
        if request.compileFirst {
            progress?(.compiling(request.configuration))
            compileResult = try await compile(request.configuration)
        }

        progress?(.deploying(robotCount: request.targets.count))
        let deployResult = try await runner.run(deployCommand)
        guard deployResult.succeeded else {
            throw DeployError.deployFailed(deployResult)
        }

        progress?(.finished)
        return DeployReport(compile: compileResult, deploy: deployResult)
    }

    // MARK: Helpers

    private static let playerNumbers = 1...20

    private func path(_ relativePath: String) -> String {
        URL(fileURLWithPath: repositoryRoot).appendingPathComponent(relativePath).path
    }

    private func appendOption(_ flag: String, _ value: String?, to arguments: inout [String]) {
        if let value {
            arguments += [flag, value]
        }
    }

    private func targetArguments(for targets: [DeployTarget]) throws -> [String] {
        guard !targets.isEmpty else {
            throw DeployError.noTargets
        }
        for target in targets {
            if let player = target.playerNumber, !DeployService.playerNumbers.contains(player) {
                throw DeployError.invalidPlayerNumber(player)
            }
        }
        // A single robot is addressed as `<ip> -p <n>`, several as `-r <n> <ip>` for each of them.
        if targets.count == 1 {
            let target = targets[0]
            if let player = target.playerNumber {
                return [target.address, "-p", String(player)]
            }
            return [target.address]
        }
        var arguments: [String] = []
        for target in targets {
            guard let player = target.playerNumber else {
                throw DeployError.missingPlayerNumber(address: target.address)
            }
            arguments += ["-r", String(player), target.address]
        }
        return arguments
    }
}
