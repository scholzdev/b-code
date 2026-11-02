//
//  BHumanSettingsTests.swift
//  BHumanKitTests
//

import XCTest
import Foundation
@testable import BHumanKit

final class BHumanSettingsTests: XCTestCase {
    private let sample = """
    teamNumber = 5;
    fieldPlayerColor = blue;
    goalkeeperColor = red;
    playerNumber = 3;
    location = Default;
    scenario = Default;
    magicNumber = 17;
    """

    func testParsesAllKnownKeys() throws {
        let settings = try BHumanSettings(parsing: sample)
        XCTAssertEqual(settings, BHumanSettings(
            teamNumber: 5,
            fieldPlayerColor: "blue",
            goalkeeperColor: "red",
            playerNumber: 3,
            location: "Default",
            scenario: "Default",
            magicNumber: 17
        ))
    }

    func testOnlyTheTeamNumberIsRequired() throws {
        let settings = try BHumanSettings(parsing: "teamNumber = 89;")
        XCTAssertEqual(settings, BHumanSettings(teamNumber: 89))
    }

    func testUnknownKeysAndCommentsAreIgnored() throws {
        let settings = try BHumanSettings(parsing: "// hi\nsomethingNew = [1, 2];\nteamNumber = 4; /* x */")
        XCTAssertEqual(settings.teamNumber, 4)
    }

    func testMagicNumberMayBeNegative() throws {
        let settings = try BHumanSettings(parsing: "teamNumber = 4;\nmagicNumber = -1;")
        XCTAssertEqual(settings.magicNumber, -1)
    }

    func testMissingTeamNumberIsAnError() {
        XCTAssertThrowsError(try BHumanSettings(parsing: "playerNumber = 1;")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .missingKey("teamNumber"))
        }
    }

    func testNonNumericTeamNumberIsAnError() {
        XCTAssertThrowsError(try BHumanSettings(parsing: "teamNumber = five;")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .invalidValue(key: "teamNumber", value: "five"))
        }
    }

    func testNonNumericOptionalNumberIsAnError() {
        XCTAssertThrowsError(try BHumanSettings(parsing: "teamNumber = 5;\nplayerNumber = x;")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .invalidValue(key: "playerNumber", value: "x"))
        }
    }

    func testListAsTeamNumberIsAnError() {
        XCTAssertThrowsError(try BHumanSettings(parsing: "teamNumber = [5];")) { error in
            XCTAssertEqual(error as? ConfigDecodingError, .invalidValue(key: "teamNumber", value: "<not a scalar>"))
        }
    }

    func testMalformedFileSurfacesTheParseError() {
        XCTAssertThrowsError(try BHumanSettings(parsing: "teamNumber 5")) { error in
            XCTAssertTrue(error is ConfigParseError)
        }
    }

    func testLoadsFromAFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BHumanKitTests-\(UUID().uuidString).cfg")
        try sample.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(try BHumanSettings.load(from: url).teamNumber, 5)
    }

    func testPathIsRelativeToTheCheckout() {
        XCTAssertEqual(BHumanSettings.relativePath, "Config/settings.cfg")
    }
}
