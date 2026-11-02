//
//  RobotStatusParser.swift
//  BHumanKit
//

import Foundation

/// Turns the output of `ping` and of the status query into values. All functions are pure.
public enum RobotStatusParser {
    /// The values reported by the status query on a robot.
    public struct Report: Equatable, Sendable {
        /// The battery level in percent, only known while `bhuman` is running.
        public var batteryPercent: Int?
        /// The temperature in degrees Celsius, only known while `bhuman` is running.
        public var temperatureCelsius: Int?
        /// The number of log files, not counting the one that is currently written.
        public var logCount: Int
        /// Whether a calibration file is newer than `settings.cfg`.
        public var hasNewCalibration: Bool
        /// The state of the `bhuman` service.
        public var service: ServiceState
        /// Whether a crash dump exists.
        public var hasCrashDump: Bool

        /// Creates a report.
        public init(
            batteryPercent: Int?,
            temperatureCelsius: Int?,
            logCount: Int,
            hasNewCalibration: Bool,
            service: ServiceState,
            hasCrashDump: Bool
        ) {
            self.batteryPercent = batteryPercent
            self.temperatureCelsius = temperatureCelsius
            self.logCount = logCount
            self.hasNewCalibration = hasNewCalibration
            self.service = service
            self.hasCrashDump = hasCrashDump
        }
    }

    /// Reads the round-trip time from the output of `ping`, e.g. `64 bytes from ...: time=0.456 ms`.
    /// - Parameter output: What `ping` printed.
    /// - Returns: ``PingResult/reachable(milliseconds:)`` for the first `time=` found, truncated to whole
    ///   milliseconds, otherwise ``PingResult/unreachable``.
    public static func parsePing(_ output: String) -> PingResult {
        for word in output.split(whereSeparator: { $0.isWhitespace }) where word.hasPrefix("time=") {
            var value = word.dropFirst("time=".count)
            if value.hasSuffix("ms") {
                value = value.dropLast(2)
            }
            if let parsed = Double(value), parsed.isFinite, parsed >= 0,
               let milliseconds = Int(exactly: parsed.rounded(.towardZero)) {
                return .reachable(milliseconds: milliseconds)
            }
        }
        return .unreachable
    }

    /// Reads the single line the status query prints.
    ///
    /// The line has six fields separated by blanks: the battery level as fraction, the temperature, the number
    /// of log files, `yes`/`no` for a new calibration, the state of the `bhuman` service, and `yes`/`no` for a
    /// crash dump.
    ///
    /// As in the Deploy Dialog, battery and temperature only count while the service is `active`, and the log
    /// that is currently written is not counted. Deliberately differing from the Deploy Dialog: the calibration
    /// flag is read from the fourth field (the Dialog's highlighting looks at the fifth), and the log count
    /// never drops below 0.
    ///
    /// - Parameter output: What the status query printed.
    /// - Returns: The report, or `nil` if the output is not in the expected format.
    public static func parseReport(_ output: String) -> Report? {
        let fields = output.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        guard fields.count == 6,
              let battery = Float(fields[0]), battery.isFinite,
              let temperature = Int(fields[1]),
              let logs = Int(fields[2]) else {
            return nil
        }
        let service = ServiceState(systemdState: fields[4])
        let isActive = service == .active
        let percent = Int(exactly: (battery * 100 + 0.5).rounded(.down)).map { min(max($0, 0), 100) }
        return Report(
            batteryPercent: isActive ? percent : nil,
            temperatureCelsius: isActive && temperature > 0 ? temperature : nil,
            logCount: max(logs - (isActive ? 1 : 0), 0),
            hasNewCalibration: fields[3] == "yes",
            service: service,
            hasCrashDump: fields[5] == "yes"
        )
    }
}

extension RobotStatus {
    /// Copies the values of a status query into this status.
    /// - Parameter report: The parsed output of the status query.
    public mutating func apply(_ report: RobotStatusParser.Report) {
        service = report.service
        batteryPercent = report.batteryPercent
        temperatureCelsius = report.temperatureCelsius
        logCount = report.logCount
        hasNewCalibration = report.hasNewCalibration
        hasCrashDump = report.hasCrashDump
    }
}
