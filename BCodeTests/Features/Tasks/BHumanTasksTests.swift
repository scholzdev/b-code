//
//  BHumanTasksTests.swift
//  BCodeTests
//

import XCTest
@testable import BCode

@MainActor
final class BHumanTasksTests: XCTestCase {
    /// Creates a temporary folder that contains empty files at the given relative paths.
    private func makeFolder(containing files: [String]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "BHumanTasksTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        for file in files {
            let url = folder.appending(path: file)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: url)
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func makeCodeRelease() throws -> URL {
        try makeFolder(containing: ["Make/Common/deploy", "Config/teams.cfg"])
    }

    // MARK: Detection

    func testRecognisesACodeReleaseCheckout() throws {
        XCTAssertTrue(BHumanTasks.isBHumanCheckout(at: try makeCodeRelease()))
    }

    func testIgnoresOtherFolders() throws {
        XCTAssertFalse(BHumanTasks.isBHumanCheckout(at: try makeFolder(containing: ["README.md"])))
        XCTAssertFalse(BHumanTasks.isBHumanCheckout(at: try makeFolder(containing: ["Make/Common/deploy"])))
        XCTAssertFalse(BHumanTasks.isBHumanCheckout(at: try makeFolder(containing: ["Config/teams.cfg"])))
    }

    // MARK: Tasks

    func testThereIsOneTaskPerGeneratedScheme() {
        XCTAssertEqual(BHumanTasks.tasks().map(\.name), [
            "Booster - Debug", "Booster - Develop", "Booster - Release",
            "SimRobot - Debug", "SimRobot - Develop", "SimRobot - Release"
        ])
    }

    func testBoosterTasksBuildThenOpenTheDeployDialog() throws {
        let task = try XCTUnwrap(BHumanTasks.tasks().first { $0.name == "Booster - Develop" })
        XCTAssertEqual(
            task.command,
            "Make/macOS/compile Booster Develop && Make/macOS/compile DeployDialog Develop"
            + " && Make/Common/deployDialog Develop"
        )
    }

    func testSimRobotTasksOnlyBuild() throws {
        let task = try XCTUnwrap(BHumanTasks.tasks().first { $0.name == "SimRobot - Release" })
        XCTAssertEqual(task.command, "Make/macOS/compile SimRobot Release")
    }

    func testAllTasksAreValidAndRunInTheWorkspaceFolder() {
        for task in BHumanTasks.tasks() {
            XCTAssertFalse(task.isInvalid, task.name)
            XCTAssertEqual(task.workingDirectory, "", task.name)
        }
    }

    // MARK: TaskManager

    func testTheTaskManagerOffersTheTasksForACodeRelease() throws {
        let manager = TaskManager(workspaceSettings: CEWorkspaceSettingsData(), workspaceURL: try makeCodeRelease())
        XCTAssertEqual(manager.availableTasks.count, 6)
    }

    func testOwnTasksFollowTheBuiltInOnes() throws {
        let settings = CEWorkspaceSettingsData()
        settings.tasks = [CETask(name: "Mine", command: "echo hi")]
        let manager = TaskManager(workspaceSettings: settings, workspaceURL: try makeCodeRelease())
        XCTAssertEqual(manager.availableTasks.count, 7)
        XCTAssertEqual(manager.availableTasks.last?.name, "Mine")
    }

    func testOtherProjectsKeepOnlyTheirOwnTasks() throws {
        let settings = CEWorkspaceSettingsData()
        let folder = try makeFolder(containing: ["README.md"])
        XCTAssertTrue(TaskManager(workspaceSettings: settings, workspaceURL: folder).availableTasks.isEmpty)

        settings.tasks = [CETask(name: "Mine", command: "echo hi")]
        XCTAssertEqual(TaskManager(workspaceSettings: settings, workspaceURL: folder).availableTasks.count, 1)
        XCTAssertEqual(TaskManager(workspaceSettings: settings, workspaceURL: nil).availableTasks.count, 1)
    }
}
