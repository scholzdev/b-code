//
//  RobotStatusProvider.swift
//  BHumanKit
//

import Foundation

/// Something that can tell how a robot is doing right now.
///
/// Views and view models depend on this protocol, so previews and tests can use ``MockRobotStatusProvider``.
public protocol RobotStatusProviding: Sendable {
    /// Determines the current status of a robot. Never fails: what could not be determined is unknown or
    /// unreachable.
    func status(for robot: Robot) async -> RobotStatus
}

/// A provider that returns canned statuses.
public struct MockRobotStatusProvider: RobotStatusProviding {
    /// The status to return per robot name.
    public var statuses: [String: RobotStatus]

    /// Creates a provider. Robots without an entry are reported as unreachable.
    public init(statuses: [String: RobotStatus] = [:]) {
        self.statuses = statuses
    }

    /// Returns the canned status of the robot, or an unreachable one.
    public func status(for robot: Robot) async -> RobotStatus {
        statuses[robot.name] ?? RobotStatus(robotName: robot.name)
    }
}

/// A provider that pings the robot on both interfaces and asks it for details over SSH.
///
/// The SSH step goes through `Make/Common/robotSSH`, so keys and options are those of the Code Release. It is
/// only attempted if the robot answers a ping. The remote command is the one the Deploy Dialog uses (see
/// `Src/Apps/DeployDialog/DeployDialog.cpp` in the B-Human Code Release, Copyright (c) 2026 B-Human, see its
/// `License.md`).
public struct ShellRobotStatusProvider: RobotStatusProviding {
    private let repositoryRoot: String
    private let platform: HostPlatform
    private let runner: any CommandRunner

    /// Creates a provider.
    /// - Parameters:
    ///   - repositoryRoot: The root of the B-Human checkout.
    ///   - platform: The platform `ping` runs on. It decides how its timeout is passed.
    ///   - runner: Runs `ping` and `robotSSH`.
    public init(repositoryRoot: String, platform: HostPlatform = .current, runner: any CommandRunner) {
        self.repositoryRoot = repositoryRoot
        self.platform = platform
        self.runner = runner
    }

    /// The command line of the status query. `robotSSH` replaces `TARGET_USER` with the robot's user.
    static let remoteStatusCommand: String = [
        "( cat /var/volatile/tmp/internalState.txt 2>/dev/null || echo '0 0';",
        "echo -n ' '; ls /home/TARGET_USER/logs | wc -l;",
        "echo -n ' '; ls /home/TARGET_USER/Config/settings.cfg",
        "/home/TARGET_USER/Config/Robots/*/cameraCalibration.cfg",
        "/home/TARGET_USER/Config/Robots/*/imuCalibration.cfg 2>/dev/null",
        "| xargs ls -t | head -1 | grep settings.cfg >/dev/null && echo no || echo yes;",
        "echo -n ' '; systemctl --user is-failed bhuman.service;",
        "echo -n ' '; [ -e /home/TARGET_USER/bhdump.log ] && echo yes || echo no ) | tr -d '\\n'"
    ].joined(separator: " ")

    /// Pings both interfaces and, if one answers, queries the robot.
    public func status(for robot: Robot) async -> RobotStatus {
        async let wired = ping(robot.wiredAddress)
        async let wireless = ping(robot.wirelessAddress)
        var status = RobotStatus(robotName: robot.name, wiredPing: await wired, wirelessPing: await wireless)
        if let address = status.preferredAddress(for: robot), let report = await queryReport(address: address) {
            status.apply(report)
        }
        return status
    }

    private func ping(_ address: String) async -> PingResult {
        // Same options as `Make/Common/deploy`: one packet, one second.
        let timeoutOption = platform == .macOS ? "-t" : "-w"
        let invocation = CommandInvocation(executable: "ping", arguments: ["-c", "1", timeoutOption, "1", address])
        guard let result = try? await runner.run(invocation) else {
            return .unreachable
        }
        return RobotStatusParser.parsePing(result.standardOutput)
    }

    private func queryReport(address: String) async -> RobotStatusParser.Report? {
        let robotSSH = URL(fileURLWithPath: repositoryRoot).appendingPathComponent("Make/Common/robotSSH").path
        let invocation = CommandInvocation(
            executable: robotSSH,
            arguments: [address, ShellRobotStatusProvider.remoteStatusCommand]
        )
        guard let result = try? await runner.run(invocation) else {
            return nil
        }
        return RobotStatusParser.parseReport(result.standardOutput)
    }
}
