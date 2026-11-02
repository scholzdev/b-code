//
//  BHumanSettings.swift
//  BHumanKit
//

import Foundation

/// The contents of `Config/settings.cfg`.
///
/// The file is part of the robot's deployed configuration. `Make/Common/deploy` rewrites its values on the
/// robot (`-t` sets the team number, `-p` the player number, ...). Only `teamNumber` is mandatory here.
public struct BHumanSettings: Equatable, Sendable {
    /// The location of the file relative to the root of the B-Human checkout.
    public static let relativePath = "Config/settings.cfg"

    /// The team number (`teamNumber`).
    public var teamNumber: Int
    /// The jersey color of the field players (`fieldPlayerColor`).
    public var fieldPlayerColor: String?
    /// The jersey color of the goalkeeper (`goalkeeperColor`).
    public var goalkeeperColor: String?
    /// The player number (`playerNumber`).
    public var playerNumber: Int?
    /// The location (`location`).
    public var location: String?
    /// The scenario (`scenario`).
    public var scenario: String?
    /// The magic number of the team communication (`magicNumber`).
    public var magicNumber: Int?

    /// Creates settings.
    public init(
        teamNumber: Int,
        fieldPlayerColor: String? = nil,
        goalkeeperColor: String? = nil,
        playerNumber: Int? = nil,
        location: String? = nil,
        scenario: String? = nil,
        magicNumber: Int? = nil
    ) {
        self.teamNumber = teamNumber
        self.fieldPlayerColor = fieldPlayerColor
        self.goalkeeperColor = goalkeeperColor
        self.playerNumber = playerNumber
        self.location = location
        self.scenario = scenario
        self.magicNumber = magicNumber
    }

    /// Parses the text of a `settings.cfg`.
    /// - Parameter text: The contents of the file.
    /// - Throws: ``ConfigParseError`` if the text is malformed, ``ConfigDecodingError`` if `teamNumber` is
    ///   missing or a number is not an integer.
    public init(parsing text: String) throws {
        let entries = try ConfigParser.parse(text)
        self.init(
            teamNumber: try entries.requiredInt("teamNumber"),
            fieldPlayerColor: entries.optionalString("fieldPlayerColor"),
            goalkeeperColor: entries.optionalString("goalkeeperColor"),
            playerNumber: try entries.optionalInt("playerNumber"),
            location: entries.optionalString("location"),
            scenario: entries.optionalString("scenario"),
            magicNumber: try entries.optionalInt("magicNumber")
        )
    }

    /// Reads and parses a `settings.cfg`.
    /// - Parameter url: The location of the file.
    /// - Returns: The parsed settings.
    public static func load(from url: URL) throws -> BHumanSettings {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try BHumanSettings(parsing: text)
    }
}
