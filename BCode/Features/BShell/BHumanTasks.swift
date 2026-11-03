//
//  BHumanTasks.swift
//  BCode
//

import Foundation

/// The tasks b-code offers for a B-Human Code Release checkout, in place of the Xcode schemes B-Human generates.
///
/// `Make/macOS/generate` creates the Xcode schemes `Booster - Debug|Develop|Release` and
/// `SimRobot - Debug|Develop|Release`. Running a `Booster` scheme builds `Booster` and opens the Deploy Dialog;
/// a `SimRobot` scheme builds SimRobot. These tasks run the same scripts, so they can be picked in the toolbar like
/// schemes in Xcode.
enum BHumanTasks {
    /// The build configurations of the Code Release.
    static let configurations = ["Debug", "Develop", "Release"]

    /// Whether a folder is a B-Human Code Release checkout, i.e. it has the deploy script and the team presets.
    /// - Parameters:
    ///   - folder: The root of the workspace.
    ///   - fileManager: Used to look for the files.
    static func isBHumanCheckout(at folder: URL, fileManager: FileManager = .default) -> Bool {
        ["Make/Common/deploy", "Config/teams.cfg"].allSatisfy { relativePath in
            fileManager.fileExists(atPath: folder.appending(path: relativePath).path(percentEncoded: false))
        }
    }

    /// The command that compiles a target the way the Code Release does on macOS.
    /// - Parameters:
    ///   - target: The CMake/Xcode target, e.g. `Booster`.
    ///   - configuration: `Debug`, `Develop` or `Release`.
    static func compileCommand(target: String, configuration: String) -> String {
        "Make/macOS/compile \(target) \(configuration)"
    }

    /// What running the scheme `Booster - <configuration>` does in Xcode: build the robot code and the Deploy Dialog,
    /// then open the dialog, which runs `Make/Common/deploy` for the robots and settings you choose.
    /// - Parameter configuration: `Debug`, `Develop` or `Release`.
    static func boosterCommand(configuration: String) -> String {
        [
            compileCommand(target: "Booster", configuration: configuration),
            compileCommand(target: "DeployDialog", configuration: configuration),
            "Make/Common/deployDialog \(configuration)"
        ].joined(separator: " && ")
    }

    /// The destination shown next to a `Booster` scheme: the code goes to the robots chosen in the Deploy Dialog.
    static let robotsDestination = "Robots"

    /// One task per generated scheme, named like the scheme. They run in the workspace folder.
    static func tasks() -> [CETask] {
        let booster = configurations.map { configuration in
            CETask(
                name: "Booster - \(configuration)",
                target: robotsDestination,
                command: boosterCommand(configuration: configuration)
            )
        }
        let simRobot = configurations.map { configuration in
            CETask(
                name: "SimRobot - \(configuration)",
                target: DestinationView.defaultDestination,
                command: compileCommand(target: "SimRobot", configuration: configuration)
            )
        }
        return booster + simRobot
    }
}
