//
//  ConfigValue.swift
//  BHumanKit
//

import Foundation

/// A value in one of B-Human's `.cfg` files.
///
/// The files use a small `key = value;` format. A value is a bare word or a quoted string, a list in
/// square brackets, or a record in curly braces.
public enum ConfigValue: Equatable, Sendable {
    /// A bare word or a quoted string, e.g. `blue`, `89`, `_` or `"10.0.5.14"`.
    case scalar(String)
    /// A list, e.g. `[a, b, c]`.
    case list([ConfigValue])
    /// A record, e.g. `{number = 0; name = "x";}`.
    case record([String: ConfigValue])

    /// The text if this is a scalar.
    public var stringValue: String? {
        if case .scalar(let text) = self {
            return text
        }
        return nil
    }

    /// The integer if this is a scalar that holds one.
    public var intValue: Int? {
        stringValue.flatMap { Int($0) }
    }

    /// The elements if this is a list.
    public var listValue: [ConfigValue]? {
        if case .list(let elements) = self {
            return elements
        }
        return nil
    }

    /// The entries if this is a record.
    public var recordValue: [String: ConfigValue]? {
        if case .record(let entries) = self {
            return entries
        }
        return nil
    }
}

/// Describes why a syntactically valid config file could not be turned into a model.
public enum ConfigDecodingError: Error, Equatable, Sendable {
    /// A required key is not present.
    case missingKey(String)
    /// A key is present, but its value has the wrong type or format.
    case invalidValue(key: String, value: String)
}

extension Dictionary where Key == String, Value == ConfigValue {
    func requiredString(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw ConfigDecodingError.missingKey(key)
        }
        guard let text = value.stringValue else {
            throw ConfigDecodingError.invalidValue(key: key, value: "<not a scalar>")
        }
        return text
    }

    func requiredInt(_ key: String) throws -> Int {
        let text = try requiredString(key)
        guard let number = Int(text) else {
            throw ConfigDecodingError.invalidValue(key: key, value: text)
        }
        return number
    }

    func optionalString(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func optionalInt(_ key: String) throws -> Int? {
        guard self[key] != nil else {
            return nil
        }
        return try requiredInt(key)
    }
}
