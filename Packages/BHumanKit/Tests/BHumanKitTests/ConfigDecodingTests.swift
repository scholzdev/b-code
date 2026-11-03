//
//  ConfigDecodingTests.swift
//  BHumanKitTests
//

import XCTest
import Foundation
@testable import BHumanKit

final class ConfigDecodingTests: XCTestCase {
    private let teamsConfig = """
    teams = [
      {
        name = "Alpha";
        number = 5;
        fieldPlayerColor = blue;
        goalkeeperColor = red;
        scenario = Default;
        location = Lab;
        wlanConfig = NONE;
        volume = 60;
        magicNumber = -1;
        players = [
          Ada,
          _,
          Grace,
          _
        ];
      },
      {
        name = "Beta";
        number = 6;
        players = [
          _
        ];
      }
    ];
    """

    // MARK: Team

    func testParsesTeamPresets() throws {
        let teams = try Team.parseTeamsConfig(teamsConfig)
        XCTAssertEqual(teams.count, 2)
        XCTAssertEqual(teams[0], Team(
            name: "Alpha",
            number: 5,
            fieldPlayerColor: "blue",
            goalkeeperColor: "red",
            scenario: "Default",
            location: "Lab",
            wlanConfig: "NONE",
            volume: 60,
            magicNumber: -1,
            players: ["Ada", nil, "Grace", nil]
        ))
    }

    func testMissingOptionalTeamKeysTakeDefaults() throws {
        let beta = try Team.parseTeamsConfig(teamsConfig)[1]
        XCTAssertEqual(beta, Team(name: "Beta", number: 6, players: [nil]))
    }

    func testTeamsWithoutTheTeamsKeyAreAnError() {
        XCTAssertThrowsError(try Team.parseTeamsConfig("other = [];")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .missingKey("teams"))
        }
    }

    func testTeamWithoutNameIsAnError() {
        XCTAssertThrowsError(try Team.parseTeamsConfig("teams = [{number = 1;}];")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .missingKey("name"))
        }
    }

    func testTeamThatIsNotARecordIsAnError() {
        XCTAssertThrowsError(try Team.parseTeamsConfig("teams = [oops];")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .invalidValue(key: "teams", value: "<not a record>"))
        }
    }

    func testPlayerNumberOfARobot() throws {
        let alpha = try Team.parseTeamsConfig(teamsConfig)[0]
        XCTAssertEqual(alpha.playerNumber(of: "Ada"), 1)
        XCTAssertEqual(alpha.playerNumber(of: "Grace"), 3)
        XCTAssertNil(alpha.playerNumber(of: "Linus"))
    }

    // MARK: Robot

    func testParsesNetworkConfig() throws {
        let robot = try Robot.parseNetworkConfig("""
        name = "Ada";
        lan = "10.1.5.21";
        wlan = "10.0.5.21";
        """, type: .boosterK1)
        XCTAssertEqual(robot, Robot(
            name: "Ada",
            wiredAddress: "10.1.5.21",
            wirelessAddress: "10.0.5.21",
            type: .boosterK1,
            role: .pool
        ))
    }

    func testNetworkConfigWithoutWiredAddressIsAnError() {
        XCTAssertThrowsError(try Robot.parseNetworkConfig("name = \"Ada\"; wlan = \"10.0.5.21\";")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .missingKey("lan"))
        }
    }

    func testParsesRobotTypes() throws {
        let types = try RobotType.parseRobotsConfig("""
        //WARNING: generated file
        robotsIds = [
          {name = "Ada"; robotType = k1;},
          {name = "Grace"; robotType = t1;}
        ];
        """)
        XCTAssertEqual(types, ["Ada": .boosterK1, "Grace": .boosterT1])
    }

    func testEmptyRobotsConfigHasNoTypes() throws {
        XCTAssertEqual(try RobotType.parseRobotsConfig("//WARNING\nrobotsIds = [\n];"), [:])
    }

    func testUnknownRobotTypeIsAnError() {
        let text = "robotsIds = [{name = \"Ada\"; robotType = x9;}];"
        XCTAssertThrowsError(try RobotType.parseRobotsConfig(text)) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .invalidValue(key: "robotType", value: "x9"))
        }
    }

    // MARK: Roles

    private func robot(_ name: String) -> Robot {
        Robot(name: name, wiredAddress: "10.1.5.\(name.count)", wirelessAddress: "10.0.5.\(name.count)")
    }

    func testRolesAreOrderedPlayingSubstitutePool() throws {
        let alpha = try Team.parseTeamsConfig(teamsConfig)[0]
        let robots = ["Linus", "Edsger", "Grace", "Barbara", "Ada"].map(robot)

        let assigned = alpha.assigningRoles(to: robots, substitutes: ["Linus", "Ghost", "Ada"])

        XCTAssertEqual(assigned.map(\.name), ["Ada", "Grace", "Linus", "Barbara", "Edsger"])
        XCTAssertEqual(assigned.map(\.role), [
            .playing(playerNumber: 1),
            .playing(playerNumber: 3),
            .substitute,
            .pool,
            .pool
        ])
    }

    func testARobotListedTwiceOnlyPlaysOnce() {
        let team = Team(name: "Dup", number: 1, players: ["Ada", "Ada", nil])
        let assigned = team.assigningRoles(to: [robot("Ada")])
        XCTAssertEqual(assigned.map(\.role), [.playing(playerNumber: 1)])
    }

    func testPlayersWithoutAKnownRobotAreSkipped() {
        let team = Team(name: "Gone", number: 1, players: ["Nobody", "Ada"])
        let assigned = team.assigningRoles(to: [robot("Ada")])
        XCTAssertEqual(assigned.map(\.role), [.playing(playerNumber: 2)])
    }

    func testPreviousRolesAreIgnored() {
        var ada = robot("Ada")
        ada.role = .playing(playerNumber: 9)
        let assigned = Team(name: "Empty", number: 1).assigningRoles(to: [ada])
        XCTAssertEqual(assigned.map(\.role), [.pool])
    }

    func testPlayerNumberOfARole() {
        XCTAssertEqual(RobotRole.playing(playerNumber: 4).playerNumber, 4)
        XCTAssertNil(RobotRole.substitute.playerNumber)
        XCTAssertNil(RobotRole.pool.playerNumber)
    }
}
