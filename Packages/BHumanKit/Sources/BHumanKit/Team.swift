//
//  Team.swift
//  BHumanKit
//

import Foundation

/// A team preset as stored in `Config/teams.cfg`.
///
/// A preset bundles everything that is written to the robots' `settings.cfg` when deploying, plus the list
/// of robots that play in it.
public struct Team: Equatable, Identifiable, Sendable {
    /// The name of the preset.
    public var name: String
    /// The team number.
    public var number: Int
    /// The jersey color of the field players, e.g. `blue`.
    public var fieldPlayerColor: String
    /// The jersey color of the goalkeeper, e.g. `red`.
    public var goalkeeperColor: String
    /// The scenario, a file name in `Config/Scenarios`.
    public var scenario: String
    /// The location, a file name in `Config/Locations`.
    public var location: String
    /// The wireless profile to activate when deploying, or `NONE`.
    public var wlanConfig: String
    /// The playback volume in percent.
    public var volume: Int
    /// The magic number for the team communication (0-255, -1 for random).
    public var magicNumber: Int
    /// The names of the robots for the player numbers 1, 2, 3, ... `nil` means no robot (`_` in the file).
    public var players: [String?]

    /// The identity of a preset is its name.
    public var id: String { name }

    /// Creates a team preset.
    public init(
        name: String,
        number: Int,
        fieldPlayerColor: String = "",
        goalkeeperColor: String = "",
        scenario: String = "",
        location: String = "",
        wlanConfig: String = "",
        volume: Int = 0,
        magicNumber: Int = 0,
        players: [String?] = []
    ) {
        self.name = name
        self.number = number
        self.fieldPlayerColor = fieldPlayerColor
        self.goalkeeperColor = goalkeeperColor
        self.scenario = scenario
        self.location = location
        self.wlanConfig = wlanConfig
        self.volume = volume
        self.magicNumber = magicNumber
        self.players = players
    }

    /// The player number a robot is assigned to in this team.
    /// - Parameter robotName: The name of the robot.
    /// - Returns: The player number (starting at 1) or `nil` if the robot does not play in this team.
    public func playerNumber(of robotName: String) -> Int? {
        guard let index = players.firstIndex(where: { $0 == robotName }) else {
            return nil
        }
        return index + 1
    }

    /// Derives the role of every robot with respect to this team.
    ///
    /// The result is ordered like the rows of B-Human's Deploy Dialog: playing robots by player number, then
    /// the substitutes in the order given, then all remaining robots (the pool) by name. A robot that is listed
    /// more than once only counts the first time, as in the Deploy Dialog.
    ///
    /// - Parameters:
    ///   - robots: All known robots. Their current role is ignored.
    ///   - substitutes: The ordered names of the substitutes.
    /// - Returns: Copies of the robots with ``Robot/role`` set.
    public func assigningRoles(to robots: [Robot], substitutes: [String] = []) -> [Robot] {
        var assigned = Set<String>()
        var result: [Robot] = []

        for (index, entry) in players.enumerated() {
            guard let playerName = entry, !assigned.contains(playerName),
                  var robot = robots.first(where: { $0.name == playerName }) else {
                continue
            }
            robot.role = .playing(playerNumber: index + 1)
            assigned.insert(playerName)
            result.append(robot)
        }

        for substituteName in substitutes where !assigned.contains(substituteName) {
            guard var robot = robots.first(where: { $0.name == substituteName }) else {
                continue
            }
            robot.role = .substitute
            assigned.insert(substituteName)
            result.append(robot)
        }

        let pool = robots
            .filter { !assigned.contains($0.name) }
            .sorted { $0.name < $1.name }
        for var robot in pool {
            robot.role = .pool
            result.append(robot)
        }
        return result
    }
}
