//
//  RecorderTests.swift
//  UniControlCoreTests
//
//  Tests for the pure key-classification logic used by --record.
//

import XCTest
@testable import UniControlCore

final class RecorderTests: XCTestCase {

    func testPlainTextKeys() {
        XCTAssertEqual(classifyKey(keyCode: 0, cmd: false, ctrl: false, alt: false, shift: false, typed: "a"), .text("a"))
        XCTAssertEqual(classifyKey(keyCode: 0, cmd: false, ctrl: false, alt: false, shift: true, typed: "A"), .text("A"))
        XCTAssertEqual(classifyKey(keyCode: 49, cmd: false, ctrl: false, alt: false, shift: false, typed: " "), .text(" "))
    }

    func testCommandCombos() {
        XCTAssertEqual(classifyKey(keyCode: 8, cmd: true, ctrl: false, alt: false, shift: false, typed: "c"), .combo("cmd+c"))
        XCTAssertEqual(classifyKey(keyCode: 1, cmd: true, ctrl: false, alt: false, shift: true, typed: "s"), .combo("cmd+shift+s"))
        XCTAssertEqual(classifyKey(keyCode: 0, cmd: false, ctrl: true, alt: false, shift: false, typed: "a"), .combo("ctrl+a"))
    }

    func testSpecialKeys() {
        XCTAssertEqual(classifyKey(keyCode: 36, cmd: false, ctrl: false, alt: false, shift: false, typed: "\r"), .combo("return"))
        XCTAssertEqual(classifyKey(keyCode: 53, cmd: false, ctrl: false, alt: false, shift: false, typed: ""), .combo("escape"))
        XCTAssertEqual(classifyKey(keyCode: 48, cmd: false, ctrl: false, alt: false, shift: false, typed: "\t"), .combo("tab"))
        XCTAssertEqual(classifyKey(keyCode: 126, cmd: false, ctrl: false, alt: false, shift: false, typed: ""), .combo("up"))
    }

    func testCmdWithSpecialKey() {
        XCTAssertEqual(classifyKey(keyCode: 36, cmd: true, ctrl: false, alt: false, shift: false, typed: "\r"), .combo("cmd+return"))
    }

    func testIgnoresEmpty() {
        XCTAssertEqual(classifyKey(keyCode: 999, cmd: false, ctrl: false, alt: false, shift: false, typed: ""), .ignore)
        XCTAssertEqual(classifyKey(keyCode: 999, cmd: true, ctrl: false, alt: false, shift: false, typed: ""), .ignore)
    }

    func testOptionTextStaysText() {
        // alt-typed characters without cmd/ctrl are just text (e.g. alt+e accents)
        XCTAssertEqual(classifyKey(keyCode: 0, cmd: false, ctrl: false, alt: true, shift: false, typed: "å"), .text("å"))
    }
}
