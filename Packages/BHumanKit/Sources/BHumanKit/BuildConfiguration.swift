//
//  BuildConfiguration.swift
//  BHumanKit
//

import Foundation

/// The build configurations of the B-Human code base.
///
/// The raw values are the exact spellings that `Make/Common/deploy` accepts as its first argument and that
/// are used for the `Build/<platform>/CMake/<configuration>` directories of the Code Release.
public enum BuildConfiguration: String, CaseIterable, Codable, Sendable {
    /// The `Release` configuration.
    case release = "Release"
    /// The `Develop` configuration.
    case develop = "Develop"
    /// The `Debug` configuration.
    case debug = "Debug"

    /// The configuration `Make/Common/deploy` falls back to when none is passed.
    public static let scriptDefault: BuildConfiguration = .develop
}
