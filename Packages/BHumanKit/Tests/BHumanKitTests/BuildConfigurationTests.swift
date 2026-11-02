//
//  BuildConfigurationTests.swift
//  BHumanKitTests
//

import XCTest
@testable import BHumanKit

final class BuildConfigurationTests: XCTestCase {
    func testRawValuesAreTheSpellingsOfTheDeployScript() {
        XCTAssertEqual(BuildConfiguration.release.rawValue, "Release")
        XCTAssertEqual(BuildConfiguration.develop.rawValue, "Develop")
        XCTAssertEqual(BuildConfiguration.debug.rawValue, "Debug")
    }

    func testAllCasesAreListed() {
        XCTAssertEqual(Set(BuildConfiguration.allCases), [.release, .develop, .debug])
    }

    func testScriptDefaultIsDevelop() {
        XCTAssertEqual(BuildConfiguration.scriptDefault, .develop)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode([BuildConfiguration.release, .debug])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "[\"Release\",\"Debug\"]")
        XCTAssertEqual(try JSONDecoder().decode([BuildConfiguration].self, from: data), [.release, .debug])
    }
}
