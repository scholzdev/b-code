//
//  RobotStatus.swift
//  BHumanKit
//

import Foundation

/// How bad a measured value is. The thresholds are the ones of B-Human's Deploy Dialog.
public enum StatusSeverity: Int, Comparable, Sendable {
    /// Nothing to worry about.
    case normal = 0
    /// Worth a look (shown in orange by the Deploy Dialog).
    case warning = 1
    /// Needs attention (shown in red by the Deploy Dialog).
    case critical = 2

    /// Orders by how bad the severity is.
    public static func < (lhs: StatusSeverity, rhs: StatusSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The thresholds that decide when a measurement is considered slow, low or hot.
///
/// The values equal the constants in B-Human's `DeployDialog.h`.
public enum StatusThresholds {
    /// From this ping time (milliseconds) on, the ping is slow.
    public static let pingWarningMilliseconds = 250
    /// From this ping time (milliseconds) on, the ping is very slow.
    public static let pingCriticalMilliseconds = 500
    /// From this ping time (milliseconds) on, a robot counts as not reachable over that interface.
    public static let pingUnreachableMilliseconds = 2000
    /// Below this battery level (percent), the battery is worth a warning.
    public static let batteryWarningPercent = 70
    /// From this temperature (degrees Celsius) on, the robot is hot.
    public static let temperatureWarningCelsius = 80
    /// From this temperature (degrees Celsius) on, the robot is critically hot.
    public static let temperatureCriticalCelsius = 95
}

/// The result of pinging one network interface of a robot.
public enum PingResult: Equatable, Sendable {
    /// The robot answered after the given time, truncated to whole milliseconds.
    case reachable(milliseconds: Int)
    /// The robot did not answer.
    case unreachable

    /// The round-trip time, or `nil` if there was no answer.
    public var milliseconds: Int? {
        if case .reachable(let milliseconds) = self {
            return milliseconds
        }
        return nil
    }

    /// Whether the robot can be used over this interface. Slow answers (2000 ms and more) do not count.
    public var isUsable: Bool {
        guard let time = milliseconds else {
            return false
        }
        return time < StatusThresholds.pingUnreachableMilliseconds
    }

    /// How bad the ping is.
    public var severity: StatusSeverity {
        guard let time = milliseconds else {
            return .critical
        }
        if time >= StatusThresholds.pingCriticalMilliseconds {
            return .critical
        }
        return time >= StatusThresholds.pingWarningMilliseconds ? .warning : .normal
    }
}

/// The state of the `bhuman` systemd user service on the robot.
public enum ServiceState: Equatable, Sendable {
    /// Running.
    case active
    /// Not running, no failure.
    case inactive
    /// Shutting down.
    case deactivating
    /// Stopped because of a failure, probably a crash.
    case failed
    /// Any other state that `systemctl is-failed` printed.
    case other(String)

    /// Creates a state from the output of `systemctl --user is-failed bhuman.service`.
    public init(systemdState: String) {
        switch systemdState {
        case "active":
            self = .active
        case "inactive":
            self = .inactive
        case "deactivating":
            self = .deactivating
        case "failed":
            self = .failed
        default:
            self = .other(systemdState)
        }
    }
}

/// What is known about a robot right now.
public struct RobotStatus: Equatable, Sendable {
    /// The name of the robot.
    public var robotName: String
    /// The result of pinging the wired interface.
    public var wiredPing: PingResult
    /// The result of pinging the wireless interface.
    public var wirelessPing: PingResult
    /// The state of the `bhuman` service, `nil` if the robot could not be queried.
    public var service: ServiceState?
    /// The battery level in percent. Only known while `bhuman` is running.
    public var batteryPercent: Int?
    /// The temperature in degrees Celsius. Only known while `bhuman` is running.
    public var temperatureCelsius: Int?
    /// The number of log files on the robot, not counting the one `bhuman` currently writes.
    public var logCount: Int?
    /// Whether a calibration file on the robot is newer than its `settings.cfg`.
    public var hasNewCalibration: Bool
    /// Whether the robot left a crash dump (`bhdump.log`).
    public var hasCrashDump: Bool

    /// Creates a status. Everything that was not measured stays unknown.
    public init(
        robotName: String,
        wiredPing: PingResult = .unreachable,
        wirelessPing: PingResult = .unreachable,
        service: ServiceState? = nil,
        batteryPercent: Int? = nil,
        temperatureCelsius: Int? = nil,
        logCount: Int? = nil,
        hasNewCalibration: Bool = false,
        hasCrashDump: Bool = false
    ) {
        self.robotName = robotName
        self.wiredPing = wiredPing
        self.wirelessPing = wirelessPing
        self.service = service
        self.batteryPercent = batteryPercent
        self.temperatureCelsius = temperatureCelsius
        self.logCount = logCount
        self.hasNewCalibration = hasNewCalibration
        self.hasCrashDump = hasCrashDump
    }

    /// Whether the robot answers over at least one interface.
    public var isReachable: Bool {
        wiredPing.isUsable || wirelessPing.isUsable
    }

    /// How bad the battery level is. Unknown levels are not a problem.
    public var batterySeverity: StatusSeverity {
        guard let level = batteryPercent else {
            return .normal
        }
        return level < StatusThresholds.batteryWarningPercent ? .warning : .normal
    }

    /// How bad the temperature is. Unknown temperatures are not a problem.
    public var temperatureSeverity: StatusSeverity {
        guard let temperature = temperatureCelsius else {
            return .normal
        }
        if temperature >= StatusThresholds.temperatureCriticalCelsius {
            return .critical
        }
        return temperature >= StatusThresholds.temperatureWarningCelsius ? .warning : .normal
    }

    /// The address to talk to the robot at: the one of the interface with the shorter ping.
    /// The wired interface wins a tie.
    /// - Parameter robot: The robot this status belongs to.
    /// - Returns: The address, or `nil` if neither interface is usable.
    public func preferredAddress(for robot: Robot) -> String? {
        let limit = StatusThresholds.pingUnreachableMilliseconds
        let wired = wiredPing.milliseconds ?? limit
        let wireless = wirelessPing.milliseconds ?? limit
        if wired >= limit && wireless >= limit {
            return nil
        }
        return wired <= wireless ? robot.wiredAddress : robot.wirelessAddress
    }
}
