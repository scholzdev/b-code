//
//  RobotStatusTests.swift
//  BHumanKitTests
//

import XCTest
@testable import BHumanKit

final class RobotStatusTests: XCTestCase {
    private let ada = Robot(name: "Ada", wiredAddress: "10.1.5.21", wirelessAddress: "10.0.5.21")

    // MARK: Ping parsing

    func testParsesLinuxPingOutput() {
        let output = "64 bytes from 10.1.5.21: icmp_seq=1 ttl=64 time=0.456 ms"
        XCTAssertEqual(RobotStatusParser.parsePing(output), .reachable(milliseconds: 0))
    }

    func testPingTimesAreTruncated() {
        XCTAssertEqual(RobotStatusParser.parsePing("time=12.9 ms"), .reachable(milliseconds: 12))
        XCTAssertEqual(RobotStatusParser.parsePing("x time=250 ms"), .reachable(milliseconds: 250))
    }

    func testParsesATimeWithoutBlankBeforeTheUnit() {
        XCTAssertEqual(RobotStatusParser.parsePing("Reply from 10.1.5.21: time=7ms"), .reachable(milliseconds: 7))
    }

    func testTheFirstTimeWins() {
        let output = "time=3 ms\ntime=900 ms"
        XCTAssertEqual(RobotStatusParser.parsePing(output), .reachable(milliseconds: 3))
    }

    func testNoAnswerIsUnreachable() {
        XCTAssertEqual(RobotStatusParser.parsePing(""), .unreachable)
        XCTAssertEqual(
            RobotStatusParser.parsePing("1 packets transmitted, 0 received, 100% packet loss"),
            .unreachable
        )
    }

    func testGarbageTimesAreUnreachable() {
        for output in ["time=abc", "time=nan", "time=inf", "time=-4 ms", "time=1e30 ms", "time="] {
            XCTAssertEqual(RobotStatusParser.parsePing(output), .unreachable, output)
        }
    }

    // MARK: Ping severity

    func testPingSeverityThresholds() {
        XCTAssertEqual(PingResult.reachable(milliseconds: 0).severity, .normal)
        XCTAssertEqual(PingResult.reachable(milliseconds: 249).severity, .normal)
        XCTAssertEqual(PingResult.reachable(milliseconds: 250).severity, .warning)
        XCTAssertEqual(PingResult.reachable(milliseconds: 499).severity, .warning)
        XCTAssertEqual(PingResult.reachable(milliseconds: 500).severity, .critical)
        XCTAssertEqual(PingResult.unreachable.severity, .critical)
    }

    func testSlowPingsStopCountingAsUsableAtTwoSeconds() {
        XCTAssertTrue(PingResult.reachable(milliseconds: 1999).isUsable)
        XCTAssertFalse(PingResult.reachable(milliseconds: 2000).isUsable)
        XCTAssertFalse(PingResult.unreachable.isUsable)
    }

    func testSeveritiesAreOrdered() {
        XCTAssertLessThan(StatusSeverity.normal, .warning)
        XCTAssertLessThan(StatusSeverity.warning, .critical)
    }

    // MARK: Status report parsing

    func testParsesTheReportOfARunningRobot() throws {
        let report = try XCTUnwrap(RobotStatusParser.parseReport("0.83 41 5 no active no"))
        XCTAssertEqual(report, RobotStatusParser.Report(
            batteryPercent: 83,
            temperatureCelsius: 41,
            logCount: 4,
            hasNewCalibration: false,
            service: .active,
            hasCrashDump: false
        ))
    }

    func testBatteryAndTemperatureAreUnknownWhileNotRunning() throws {
        let report = try XCTUnwrap(RobotStatusParser.parseReport("0 0 3 no inactive no"))
        XCTAssertNil(report.batteryPercent)
        XCTAssertNil(report.temperatureCelsius)
        XCTAssertEqual(report.logCount, 3)
        XCTAssertEqual(report.service, .inactive)
    }

    func testParsesFlagsAndServiceStates() throws {
        let failed = try XCTUnwrap(RobotStatusParser.parseReport("0 0 2 yes failed yes"))
        XCTAssertTrue(failed.hasNewCalibration)
        XCTAssertTrue(failed.hasCrashDump)
        XCTAssertEqual(failed.service, .failed)

        let stopping = try XCTUnwrap(RobotStatusParser.parseReport("0 0 2 no deactivating no"))
        XCTAssertEqual(stopping.service, .deactivating)

        let starting = try XCTUnwrap(RobotStatusParser.parseReport("0 0 2 no activating no"))
        XCTAssertEqual(starting.service, .other("activating"))
    }

    func testLogCountNeverGoesNegative() throws {
        let report = try XCTUnwrap(RobotStatusParser.parseReport("0.9 40 0 no active no"))
        XCTAssertEqual(report.logCount, 0)
    }

    func testBatteryIsClampedToAHundredPercent() throws {
        let report = try XCTUnwrap(RobotStatusParser.parseReport("1.7 40 1 no active no"))
        XCTAssertEqual(report.batteryPercent, 100)
    }

    func testZeroTemperatureMeansUnknown() throws {
        let report = try XCTUnwrap(RobotStatusParser.parseReport("0.9 0 1 no active no"))
        XCTAssertNil(report.temperatureCelsius)
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertNotNil(RobotStatusParser.parseReport("  0.83 41 5 no active no\n"))
    }

    func testMalformedReportsAreRejected() {
        XCTAssertNil(RobotStatusParser.parseReport(""))
        XCTAssertNil(RobotStatusParser.parseReport("0.83 41 5 no active"))
        XCTAssertNil(RobotStatusParser.parseReport("0.83 41 5 no active no extra"))
        XCTAssertNil(RobotStatusParser.parseReport("full 41 5 no active no"))
        XCTAssertNil(RobotStatusParser.parseReport("0.83 hot 5 no active no"))
        XCTAssertNil(RobotStatusParser.parseReport("0.83 41 many no active no"))
    }

    // MARK: Model

    func testPrefersTheFasterInterface() {
        let wirelessFaster = RobotStatus(
            robotName: "Ada",
            wiredPing: .reachable(milliseconds: 5),
            wirelessPing: .reachable(milliseconds: 3)
        )
        XCTAssertEqual(wirelessFaster.preferredAddress(for: ada), "10.0.5.21")

        let tie = RobotStatus(
            robotName: "Ada",
            wiredPing: .reachable(milliseconds: 4),
            wirelessPing: .reachable(milliseconds: 4)
        )
        XCTAssertEqual(tie.preferredAddress(for: ada), "10.1.5.21")
    }

    func testFallsBackToTheOnlyReachableInterface() {
        let onlyWireless = RobotStatus(robotName: "Ada", wirelessPing: .reachable(milliseconds: 10))
        XCTAssertEqual(onlyWireless.preferredAddress(for: ada), "10.0.5.21")

        let onlyWired = RobotStatus(robotName: "Ada", wiredPing: .reachable(milliseconds: 1999))
        XCTAssertEqual(onlyWired.preferredAddress(for: ada), "10.1.5.21")
    }

    func testNoPreferredAddressWithoutUsableInterface() {
        XCTAssertNil(RobotStatus(robotName: "Ada").preferredAddress(for: ada))

        let tooSlow = RobotStatus(
            robotName: "Ada",
            wiredPing: .reachable(milliseconds: 2000),
            wirelessPing: .reachable(milliseconds: 5000)
        )
        XCTAssertNil(tooSlow.preferredAddress(for: ada))
        XCTAssertFalse(tooSlow.isReachable)
    }

    func testBatteryAndTemperatureSeverity() {
        XCTAssertEqual(RobotStatus(robotName: "Ada").batterySeverity, .normal)
        XCTAssertEqual(RobotStatus(robotName: "Ada", batteryPercent: 70).batterySeverity, .normal)
        XCTAssertEqual(RobotStatus(robotName: "Ada", batteryPercent: 69).batterySeverity, .warning)

        XCTAssertEqual(RobotStatus(robotName: "Ada").temperatureSeverity, .normal)
        XCTAssertEqual(RobotStatus(robotName: "Ada", temperatureCelsius: 79).temperatureSeverity, .normal)
        XCTAssertEqual(RobotStatus(robotName: "Ada", temperatureCelsius: 80).temperatureSeverity, .warning)
        XCTAssertEqual(RobotStatus(robotName: "Ada", temperatureCelsius: 94).temperatureSeverity, .warning)
        XCTAssertEqual(RobotStatus(robotName: "Ada", temperatureCelsius: 95).temperatureSeverity, .critical)
    }

    func testApplyingAReportFillsInTheDetails() throws {
        var status = RobotStatus(robotName: "Ada", wiredPing: .reachable(milliseconds: 1))
        status.apply(try XCTUnwrap(RobotStatusParser.parseReport("0.5 60 3 yes active yes")))

        XCTAssertEqual(status.wiredPing, .reachable(milliseconds: 1))
        XCTAssertEqual(status.service, .active)
        XCTAssertEqual(status.batteryPercent, 50)
        XCTAssertEqual(status.temperatureCelsius, 60)
        XCTAssertEqual(status.logCount, 2)
        XCTAssertTrue(status.hasNewCalibration)
        XCTAssertTrue(status.hasCrashDump)
    }

    // MARK: Mock provider

    func testMockProviderReturnsCannedStatuses() async {
        let canned = RobotStatus(robotName: "Ada", wiredPing: .reachable(milliseconds: 2), batteryPercent: 55)
        let provider: any RobotStatusProviding = MockRobotStatusProvider(statuses: ["Ada": canned])

        let known = await provider.status(for: ada)
        let unknown = await provider.status(for: Robot(name: "Grace", wiredAddress: "1", wirelessAddress: "2"))

        XCTAssertEqual(known, canned)
        XCTAssertEqual(unknown, RobotStatus(robotName: "Grace"))
    }

    // MARK: Shell provider

    private let root = "/work/BHumanCodeRelease"

    private func shellProvider(
        platform: HostPlatform = .linux,
        runner: FakeCommandRunner
    ) -> ShellRobotStatusProvider {
        ShellRobotStatusProvider(repositoryRoot: root, platform: platform, runner: runner)
    }

    private func pings(of runner: FakeCommandRunner) -> [CommandInvocation] {
        runner.invocations.filter { $0.executable == "ping" }
    }

    private func queries(of runner: FakeCommandRunner) -> [CommandInvocation] {
        runner.invocations.filter { $0.executable.hasSuffix("robotSSH") }
    }

    func testPingsBothInterfacesAndQueriesTheFasterOne() async {
        let fake = FakeCommandRunner { invocation in
            switch invocation.executable {
            case "ping":
                let wired = invocation.arguments.last == "10.1.5.21"
                return wired
                    ? CommandResult(standardOutput: "64 bytes from 10.1.5.21: time=1.5 ms")
                    : CommandResult(exitCode: 1, standardOutput: "100% packet loss")
            default:
                return CommandResult(standardOutput: "0.83 41 5 no active no")
            }
        }

        let status = await shellProvider(runner: fake).status(for: ada)

        XCTAssertEqual(status.wiredPing, .reachable(milliseconds: 1))
        XCTAssertEqual(status.wirelessPing, .unreachable)
        XCTAssertEqual(status.service, .active)
        XCTAssertEqual(status.batteryPercent, 83)
        XCTAssertEqual(status.logCount, 4)

        XCTAssertEqual(pings(of: fake).count, 2)
        XCTAssertTrue(pings(of: fake).allSatisfy { $0.arguments.starts(with: ["-c", "1", "-w", "1"]) })
        let query = queries(of: fake)
        XCTAssertEqual(query.count, 1)
        XCTAssertEqual(query.first?.executable, "/work/BHumanCodeRelease/Make/Common/robotSSH")
        XCTAssertEqual(query.first?.arguments, ["10.1.5.21", ShellRobotStatusProvider.remoteStatusCommand])
    }

    func testMacOSPingUsesTheTimeoutOptionOfBSDPing() async {
        let fake = FakeCommandRunner()
        _ = await shellProvider(platform: .macOS, runner: fake).status(for: ada)
        XCTAssertTrue(pings(of: fake).allSatisfy { $0.arguments.starts(with: ["-c", "1", "-t", "1"]) })
    }

    func testDoesNotQueryARobotThatDoesNotAnswer() async {
        let fake = FakeCommandRunner { _ in CommandResult(exitCode: 1) }

        let status = await shellProvider(runner: fake).status(for: ada)

        XCTAssertEqual(status, RobotStatus(robotName: "Ada"))
        XCTAssertTrue(queries(of: fake).isEmpty)
    }

    func testFailingRunnerCountsAsUnreachable() async {
        struct Boom: Error {}
        let fake = FakeCommandRunner { _ in throw Boom() }

        let status = await shellProvider(runner: fake).status(for: ada)

        XCTAssertEqual(status, RobotStatus(robotName: "Ada"))
    }

    func testUnparsableQueryOutputKeepsThePings() async {
        let fake = FakeCommandRunner { invocation in
            invocation.executable == "ping"
                ? CommandResult(standardOutput: "time=2 ms")
                : CommandResult(standardOutput: "Permission denied")
        }

        let status = await shellProvider(runner: fake).status(for: ada)

        XCTAssertEqual(status.wiredPing, .reachable(milliseconds: 2))
        XCTAssertNil(status.service)
        XCTAssertNil(status.batteryPercent)
    }

    func testRemoteCommandIsOneLineThatReadsTheServiceState() {
        let command = ShellRobotStatusProvider.remoteStatusCommand
        XCTAssertFalse(command.contains("\n"))
        XCTAssertTrue(command.contains("systemctl --user is-failed bhuman.service"))
        XCTAssertTrue(command.contains("/home/TARGET_USER/bhdump.log"))
        XCTAssertTrue(command.hasSuffix("| tr -d '\\n'"))
    }
}
