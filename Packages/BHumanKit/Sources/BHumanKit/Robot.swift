//
//  Robot.swift
//  BHumanKit
//

import Foundation

/// The hardware model of a robot as recorded in `Config/Robots/robots.cfg` (`robotType = k1;`).
public enum RobotType: String, Codable, Sendable {
    /// A Booster K1 (`k1`).
    case boosterK1 = "k1"
    /// A Booster T1 (`t1`).
    case boosterT1 = "t1"
}

/// What a robot is used for in the currently selected team.
///
/// B-Human does not store the role on the robot. It is derived from the team's `players` list in
/// `Config/teams.cfg` (playing), the ordered substitutes list the Deploy Dialog keeps in its own settings
/// (substitute), and everything else (pool). See ``Team/assigningRoles(to:substitutes:)``.
public enum RobotRole: Hashable, Sendable {
    /// The robot is assigned to a player number (starting at 1) and is deployed.
    case playing(playerNumber: Int)
    /// The robot is a substitute. It is not deployed, but ordered ahead of the pool.
    case substitute
    /// The robot is known, but not assigned to anything.
    case pool

    /// The player number if the robot is playing, `nil` otherwise.
    public var playerNumber: Int? {
        if case .playing(let number) = self {
            return number
        }
        return nil
    }
}

/// A robot as described by `Config/Robots/<name>/network.cfg`.
public struct Robot: Hashable, Identifiable, Sendable {
    /// The name of the robot. It is also the name of its directory in `Config/Robots`.
    public var name: String
    /// The IP address of the wired (ethernet) interface (`lan` in `network.cfg`).
    public var wiredAddress: String
    /// The IP address of the wireless interface (`wlan` in `network.cfg`).
    public var wirelessAddress: String
    /// The hardware model if it is known from `robots.cfg`.
    public var type: RobotType?
    /// What the robot is used for.
    public var role: RobotRole

    /// The identity of a robot is its name.
    public var id: String { name }

    /// Creates a robot.
    /// - Parameters:
    ///   - name: The name of the robot.
    ///   - wiredAddress: The IP address of the wired interface.
    ///   - wirelessAddress: The IP address of the wireless interface.
    ///   - type: The hardware model, if known.
    ///   - role: What the robot is used for.
    public init(
        name: String,
        wiredAddress: String,
        wirelessAddress: String,
        type: RobotType? = nil,
        role: RobotRole = .pool
    ) {
        self.name = name
        self.wiredAddress = wiredAddress
        self.wirelessAddress = wirelessAddress
        self.type = type
        self.role = role
    }
}
