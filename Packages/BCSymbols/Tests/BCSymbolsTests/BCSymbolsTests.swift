//
//  BCSymbolsTests.swift
//  BCSymbolsTests
//

import XCTest
import AppKit
@testable import BCSymbols

final class BCSymbolsTests: XCTestCase {
    /// If this fails, the message names the stand-ins that are not real SF Symbols on this macOS version.
    func testEveryStandInIsARealSystemSymbol() {
        let missing = BCSymbols.standIns
            .filter { NSImage(systemSymbolName: $0.value, accessibilityDescription: nil) == nil }
            .map { "\($0.key) -> \($0.value)" }
            .sorted()
        XCTAssertTrue(missing.isEmpty, "Not SF Symbols: \(missing)")
    }

    func testDefinedNamesProduceAnImage() {
        for name in BCSymbols.standIns.keys {
            XCTAssertNotNil(NSImage.symbol(named: name), name)
        }
    }

    func testUndefinedNamesProduceNoImage() {
        XCTAssertNil(NSImage.symbol(named: "doc.text"))
        XCTAssertNil(NSImage.symbol(named: "no.such.symbol"))
        XCTAssertFalse(BCSymbols.contains("doc.text"))
    }

    func testTheNamesTheAppUsesAreAllDefined() {
        let used = [
            "vault", "vault.fill", "commit", "checkout", "branch", "breakpoint", "breakpoint.fill",
            "chevron.up.chevron.down", "github", "doc.java", "doc.javascript", "doc.json", "doc.python",
            "doc.ruby", "square.split.horizontal.plus", "square.split.vertical.plus"
        ]
        XCTAssertEqual(Set(used), Set(BCSymbols.standIns.keys))
    }
}
