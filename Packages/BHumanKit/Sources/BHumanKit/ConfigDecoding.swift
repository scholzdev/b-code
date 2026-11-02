//
//  ConfigDecoding.swift
//  BHumanKit
//

import Foundation

extension Team {
    /// Parses all team presets of a `Config/teams.cfg`.
    /// - Parameter text: The contents of the file.
    /// - Returns: The presets in file order.
    /// - Throws: ``ConfigParseError`` or ``ConfigDecodingError``.
    public static func parseTeamsConfig(_ text: String) throws -> [Team] {
        let entries = try ConfigParser.parse(text)
        guard let teams = entries["teams"]?.listValue else {
            throw ConfigDecodingError.missingKey("teams")
        }
        return try teams.map { try Team(record: $0) }
    }

    private init(record value: ConfigValue) throws {
        guard let record = value.recordValue else {
            throw ConfigDecodingError.invalidValue(key: "teams", value: "<not a record>")
        }
        let players = (record["players"]?.listValue ?? []).map { element -> String? in
            guard let name = element.stringValue, name != "_" else {
                return nil
            }
            return name
        }
        self.init(
            name: try record.requiredString("name"),
            number: try record.requiredInt("number"),
            fieldPlayerColor: record.optionalString("fieldPlayerColor") ?? "",
            goalkeeperColor: record.optionalString("goalkeeperColor") ?? "",
            scenario: record.optionalString("scenario") ?? "",
            location: record.optionalString("location") ?? "",
            wlanConfig: record.optionalString("wlanConfig") ?? "",
            volume: try record.optionalInt("volume") ?? 0,
            magicNumber: try record.optionalInt("magicNumber") ?? 0,
            players: players
        )
    }
}

extension Robot {
    /// Parses a `Config/Robots/<name>/network.cfg`.
    /// - Parameters:
    ///   - text: The contents of the file (`name`, `lan` and `wlan` entries).
    ///   - type: The hardware model, if known from ``RobotType/parseRobotsConfig(_:)``.
    /// - Returns: The robot with the role ``RobotRole/pool``.
    /// - Throws: ``ConfigParseError`` or ``ConfigDecodingError``.
    public static func parseNetworkConfig(_ text: String, type: RobotType? = nil) throws -> Robot {
        let entries = try ConfigParser.parse(text)
        return Robot(
            name: try entries.requiredString("name"),
            wiredAddress: try entries.requiredString("lan"),
            wirelessAddress: try entries.requiredString("wlan"),
            type: type
        )
    }
}

extension RobotType {
    /// Parses `Config/Robots/robots.cfg`, which maps robot names to hardware models.
    /// - Parameter text: The contents of the file (`robotsIds = [{name = ...; robotType = k1;}, ...];`).
    /// - Returns: The model per robot name.
    /// - Throws: ``ConfigParseError`` or ``ConfigDecodingError``, e.g. for an unknown `robotType`.
    public static func parseRobotsConfig(_ text: String) throws -> [String: RobotType] {
        let entries = try ConfigParser.parse(text)
        guard let ids = entries["robotsIds"]?.listValue else {
            throw ConfigDecodingError.missingKey("robotsIds")
        }
        var types: [String: RobotType] = [:]
        for element in ids {
            guard let record = element.recordValue else {
                throw ConfigDecodingError.invalidValue(key: "robotsIds", value: "<not a record>")
            }
            let name = try record.requiredString("name")
            let rawType = try record.requiredString("robotType")
            guard let type = RobotType(rawValue: rawType) else {
                throw ConfigDecodingError.invalidValue(key: "robotType", value: rawType)
            }
            types[name] = type
        }
        return types
    }
}
