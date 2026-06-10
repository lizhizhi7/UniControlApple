//
//  SuggestionEngineTests.swift
//  UniControlCoreTests
//

import XCTest
@testable import UniControlCore

final class SuggestionEngineTests: XCTestCase {

    func testLevenshteinDistance() {
        XCTAssertEqual(levenshteinDistance("launch", "launch"), 0)
        XCTAssertEqual(levenshteinDistance("lauch", "launch"), 1)
        XCTAssertEqual(levenshteinDistance("click", "clickk"), 1)
        XCTAssertEqual(levenshteinDistance("", "abc"), 3)
        XCTAssertEqual(levenshteinDistance("kitten", "sitting"), 3)
    }

    func testSimilarityScore() {
        XCTAssertEqual(similarityScore("save", "save"), 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(similarityScore("save", "Save As"), similarityScore("save", "Cancel"))
    }
}
