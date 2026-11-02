//
//  ConfigParserTests.swift
//  BHumanKitTests
//

import XCTest
@testable import BHumanKit

final class ConfigParserTests: XCTestCase {
    func testParsesBareAndQuotedScalars() throws {
        let entries = try ConfigParser.parse("""
        teamNumber = 5;
        name = "Team Name";
        offset = -1;
        """)
        XCTAssertEqual(entries["teamNumber"], .scalar("5"))
        XCTAssertEqual(entries["name"], .scalar("Team Name"))
        XCTAssertEqual(entries["offset"], .scalar("-1"))
    }

    func testIgnoresLineAndBlockComments() throws {
        let entries = try ConfigParser.parse("""
        // generated, do not edit
        a = 1; // trailing
        /* block
           comment */
        b = 2;
        """)
        XCTAssertEqual(entries, ["a": .scalar("1"), "b": .scalar("2")])
    }

    func testWordEndsWhereACommentStarts() throws {
        let entries = try ConfigParser.parse("a = 89// note\nb = 1;")
        XCTAssertEqual(entries["a"], .scalar("89"))
        XCTAssertEqual(entries["b"], .scalar("1"))
    }

    func testAcceptsWindowsLineEndings() throws {
        let entries = try ConfigParser.parse("a = 1;\r\nb = 2;\r\n")
        XCTAssertEqual(entries, ["a": .scalar("1"), "b": .scalar("2")])
    }

    func testFormFeedIsWhitespaceAndDoesNotHang() throws {
        let entries = try ConfigParser.parse("a = 1;\u{0C}b = 2;")
        XCTAssertEqual(entries, ["a": .scalar("1"), "b": .scalar("2")])
    }

    func testParsesListsWithAndWithoutTrailingComma() throws {
        let entries = try ConfigParser.parse("a = [x, _, z]; b = [x, y,]; c = [\n];")
        XCTAssertEqual(entries["a"], .list([.scalar("x"), .scalar("_"), .scalar("z")]))
        XCTAssertEqual(entries["b"], .list([.scalar("x"), .scalar("y")]))
        XCTAssertEqual(entries["c"], .list([]))
    }

    func testParsesRecordsInLists() throws {
        let entries = try ConfigParser.parse("""
        teams = [
          {number = 0; name = "Invisibles";},
          {number = 1; name = "Other"}
        ];
        """)
        let teams = try XCTUnwrap(entries["teams"]?.listValue)
        XCTAssertEqual(teams.count, 2)
        XCTAssertEqual(teams[0].recordValue?["number"], .scalar("0"))
        XCTAssertEqual(teams[1].recordValue?["name"], .scalar("Other"))
    }

    func testParsesEscapesInQuotedStrings() throws {
        let entries = try ConfigParser.parse(#"title = "say \"hi\"";"#)
        XCTAssertEqual(entries["title"], .scalar("say \"hi\""))
    }

    func testLastDuplicateKeyWins() throws {
        let entries = try ConfigParser.parse("a = 1; a = 2;")
        XCTAssertEqual(entries["a"], .scalar("2"))
    }

    func testEmptyTextHasNoEntries() throws {
        XCTAssertEqual(try ConfigParser.parse(""), [:])
        XCTAssertEqual(try ConfigParser.parse("  // nothing\n"), [:])
    }

    func testAccessors() {
        XCTAssertEqual(ConfigValue.scalar("12").intValue, 12)
        XCTAssertNil(ConfigValue.scalar("blue").intValue)
        XCTAssertNil(ConfigValue.list([]).stringValue)
        XCTAssertNil(ConfigValue.scalar("x").listValue)
        XCTAssertNil(ConfigValue.scalar("x").recordValue)
    }

    // MARK: Errors

    private func assertSyntaxError(
        in text: String,
        atLine expectedLine: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try ConfigParser.parse(text), file: file, line: line) { error in
            guard case .syntax(let errorLine, _)? = error as? ConfigParseError else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }
            XCTAssertEqual(errorLine, expectedLine, file: file, line: line)
        }
    }

    func testReportsUnterminatedString() {
        assertSyntaxError(in: "a = 1;\nb = \"oops;\n", atLine: 2)
    }

    func testReportsUnterminatedBlockComment() {
        assertSyntaxError(in: "a = 1;\n/* never closed\n", atLine: 2)
    }

    func testReportsMissingEqualsSign() {
        assertSyntaxError(in: "a 1;", atLine: 1)
    }

    func testReportsMissingValue() {
        assertSyntaxError(in: "a = ;", atLine: 1)
        assertSyntaxError(in: "a =", atLine: 1)
    }

    func testReportsUnclosedRecordAndList() {
        assertSyntaxError(in: "r = { a = 1;", atLine: 1)
        assertSyntaxError(in: "l = [ a, b", atLine: 1)
    }

    func testReportsStrayClosingBrace() {
        assertSyntaxError(in: "a = 1;\n}", atLine: 2)
    }
}
