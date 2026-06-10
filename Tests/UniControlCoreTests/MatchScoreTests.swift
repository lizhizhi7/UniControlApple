//
//  MatchScoreTests.swift
//  UniControlCoreTests
//
//  Tests for the find-ranking score function.
//

import XCTest
@testable import UniControlCore

final class MatchScoreTests: XCTestCase {

    private func score(title: String? = nil, description: String? = nil, help: String? = nil, value: String? = nil, query: String) -> Int? {
        textMatchScore(title: title, description: description, help: help, value: value, query: query)
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(score(title: "Cancel", query: "Save"))
        XCTAssertNil(score(query: "Save"))
        XCTAssertNil(score(title: "", query: "Save"))
    }

    func testExactBeatsPrefixBeatsContains() {
        let exact = score(title: "Save", query: "Save")!
        let prefix = score(title: "Save As...", query: "Save")!
        let contains = score(title: "Auto Save", query: "Save")!
        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, contains)
    }

    func testCaseSensitiveExactBeatsCaseInsensitiveExact() {
        let exact = score(title: "Save", query: "Save")!
        let caseInsensitive = score(title: "SAVE", query: "Save")!
        XCTAssertGreaterThan(exact, caseInsensitive)
        XCTAssertGreaterThan(caseInsensitive, score(title: "Save As", query: "Save")!)
    }

    func testCaseInsensitiveMatching() {
        XCTAssertNotNil(score(title: "SAVE DOCUMENT", query: "save"))
        XCTAssertNotNil(score(description: "add", query: "Add"))
    }

    func testTitleBeatsDescriptionBeatsValue() {
        let titleMatch = score(title: "Save", query: "Save")!
        let descMatch = score(description: "Save", query: "Save")!
        let valueMatch = score(value: "Save", query: "Save")!
        XCTAssertGreaterThan(titleMatch, descMatch)
        XCTAssertGreaterThan(descMatch, valueMatch)
    }

    func testBestAttributeWins() {
        // contains-in-title (10+4) loses to exact-in-description (40+3)
        let s = score(title: "Save As...", description: "Save", query: "Save")!
        XCTAssertEqual(s, 43)
    }
}
