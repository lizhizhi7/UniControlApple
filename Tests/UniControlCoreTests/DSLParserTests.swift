//
//  DSLParserTests.swift
//  UniControlCoreTests
//
//  Pure-logic parser tests — no Accessibility permission required.
//

import XCTest
@testable import UniControlCore

final class DSLParserTests: XCTestCase {

    // MARK: - Basic parsing

    func testParsesSimpleScript() {
        let script = """
        # A comment
        launch Calculator
        wait 0.5
        find 7 role: AXButton
        click
        """
        let outcome = DSLParser.parseWithDiagnostics(script)
        XCTAssertFalse(outcome.hasErrors, "Unexpected errors: \(outcome.errors)")
        XCTAssertEqual(outcome.commands.count, 4)

        guard case .launch(let appName) = outcome.commands[0] else {
            return XCTFail("Expected launch, got \(outcome.commands[0])")
        }
        XCTAssertEqual(appName, "Calculator")
    }

    func testSkipsCommentsAndBlankLines() {
        let script = "# comment\n\n// another comment\n   \nlog hello"
        let outcome = DSLParser.parseWithDiagnostics(script)
        XCTAssertEqual(outcome.commands.count, 1)
        XCTAssertFalse(outcome.hasErrors)
    }

    func testMultiWordAppName() {
        let outcome = DSLParser.parseWithDiagnostics("launch Microsoft Excel")
        guard case .launch(let appName) = outcome.commands.first else {
            return XCTFail("Expected launch")
        }
        XCTAssertEqual(appName, "Microsoft Excel")
    }

    // MARK: - Diagnostics

    func testUnknownVerbReportsErrorWithLineNumber() {
        let script = "launch Calculator\nclickk\nwait 1"
        let outcome = DSLParser.parseWithDiagnostics(script)
        XCTAssertEqual(outcome.commands.count, 2)
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertEqual(outcome.errors[0].line, 2)
        XCTAssertTrue(outcome.errors[0].message.contains("clickk"))
    }

    func testUnknownVerbSuggestsClosestMatch() {
        let outcome = DSLParser.parseWithDiagnostics("lauch Calculator")
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertTrue(
            outcome.errors[0].message.contains("launch"),
            "Expected a 'did you mean launch' suggestion, got: \(outcome.errors[0].message)"
        )
    }

    func testMissingArgumentsReportError() {
        for line in ["launch", "find", "type", "wait", "log", "presskey", "openmenu", "selectmenuitem", "setvalue", "scroll", "mode"] {
            let outcome = DSLParser.parseWithDiagnostics(line)
            XCTAssertEqual(outcome.errors.count, 1, "Expected error for bare '\(line)'")
            XCTAssertTrue(outcome.commands.isEmpty, "Expected no command for bare '\(line)'")
        }
    }

    func testInvalidWaitDurationReportsError() {
        let outcome = DSLParser.parseWithDiagnostics("wait abc")
        XCTAssertEqual(outcome.errors.count, 1)
        XCTAssertTrue(outcome.errors[0].message.contains("number"))
    }

    func testInvalidScrollDirectionReportsError() {
        let outcome = DSLParser.parseWithDiagnostics("scroll sideways")
        XCTAssertEqual(outcome.errors.count, 1)
    }

    func testLegacyParseDropsInvalidLines() {
        let commands = DSLParser.parse("launch Calculator\nbogus command\nwait 1")
        XCTAssertEqual(commands.count, 2)
    }

    // MARK: - Selectors

    func testSelectorVariants() {
        guard case .find(let byTitle) = DSLParser.parse("find Save")[0],
              case .byTitle(let title) = byTitle else {
            return XCTFail("Expected byTitle selector")
        }
        XCTAssertEqual(title, "Save")

        guard case .find(let byRole) = DSLParser.parse("find role: AXButton")[0],
              case .byRole(let role) = byRole else {
            return XCTFail("Expected byRole selector")
        }
        XCTAssertEqual(role, "AXButton")

        guard case .find(let byBoth) = DSLParser.parse("find Save role: AXButton")[0],
              case .byTitleAndRole(let t, let r) = byBoth else {
            return XCTFail("Expected byTitleAndRole selector")
        }
        XCTAssertEqual(t, "Save")
        XCTAssertEqual(r, "AXButton")

        guard case .find(let byIndex) = DSLParser.parse("find index: 2")[0],
              case .byIndex(let index) = byIndex else {
            return XCTFail("Expected byIndex selector")
        }
        XCTAssertEqual(index, 2)

        guard case .find(let byPattern) = DSLParser.parse("find pattern: ^Sub.*")[0],
              case .byRegex(let pattern) = byPattern else {
            return XCTFail("Expected byRegex selector")
        }
        XCTAssertEqual(pattern, "^Sub.*")

        guard case .find(let byState) = DSLParser.parse("find role: AXButton state: enabled")[0],
              case .byState(let sRole, let state) = byState else {
            return XCTFail("Expected byState selector")
        }
        XCTAssertEqual(sRole, "AXButton")
        XCTAssertEqual(state, "enabled")
    }

    // MARK: - waitfor

    func testWaitForDefaultTimeout() {
        guard case .waitFor(let selector, let timeout) = DSLParser.parse("waitfor Save role: AXButton")[0] else {
            return XCTFail("Expected waitFor")
        }
        XCTAssertEqual(timeout, 5.0)
        guard case .byTitleAndRole = selector else {
            return XCTFail("Expected byTitleAndRole selector")
        }
    }

    func testWaitForExplicitTimeout() {
        guard case .waitFor(let selector, let timeout) = DSLParser.parse("waitfor Save timeout: 2.5")[0] else {
            return XCTFail("Expected waitFor")
        }
        XCTAssertEqual(timeout, 2.5)
        guard case .byTitle(let title) = selector else {
            return XCTFail("Expected byTitle selector")
        }
        XCTAssertEqual(title, "Save")
    }

    func testWaitForInvalidTimeoutReportsError() {
        let outcome = DSLParser.parseWithDiagnostics("waitfor Save timeout: soon")
        XCTAssertEqual(outcome.errors.count, 1)
    }

    // MARK: - assert

    func testAssertConditions() {
        guard case .assert(.exists) = DSLParser.parse("assert exists Save role: AXButton")[0] else {
            return XCTFail("Expected assert exists")
        }
        guard case .assert(.notExists) = DSLParser.parse("assert missing Error")[0] else {
            return XCTFail("Expected assert missing")
        }
        guard case .assert(.enabled(true)) = DSLParser.parse("assert enabled")[0] else {
            return XCTFail("Expected assert enabled")
        }
        guard case .assert(.enabled(false)) = DSLParser.parse("assert disabled")[0] else {
            return XCTFail("Expected assert disabled")
        }
        guard case .assert(.value(let expected)) = DSLParser.parse("assert value 42")[0] else {
            return XCTFail("Expected assert value")
        }
        XCTAssertEqual(expected, "42")
    }

    func testAssertUnknownConditionReportsError() {
        let outcome = DSLParser.parseWithDiagnostics("assert visible Save")
        XCTAssertEqual(outcome.errors.count, 1)
    }

    // MARK: - usewindow / dumptree / reset / setvalue

    func testUseWindow() {
        guard case .useWindow(let title) = DSLParser.parse("usewindow My Document")[0] else {
            return XCTFail("Expected useWindow")
        }
        XCTAssertEqual(title, "My Document")

        guard case .useWindow(nil) = DSLParser.parse("usewindow")[0] else {
            return XCTFail("Expected useWindow with nil title")
        }
    }

    func testDumpTree() {
        guard case .dumpTree(let depth) = DSLParser.parse("dumptree")[0] else {
            return XCTFail("Expected dumpTree")
        }
        XCTAssertEqual(depth, 4)

        guard case .dumpTree(2) = DSLParser.parse("dumptree 2")[0] else {
            return XCTFail("Expected dumpTree depth 2")
        }

        XCTAssertEqual(DSLParser.parseWithDiagnostics("dumptree deep").errors.count, 1)
    }

    func testReset() {
        guard case .reset = DSLParser.parse("reset")[0] else {
            return XCTFail("Expected reset")
        }
    }

    func testSetValue() {
        guard case .perform(.setValue(let value)) = DSLParser.parse("setvalue hello world")[0] else {
            return XCTFail("Expected setValue")
        }
        XCTAssertEqual(value, "hello world")
    }

    // MARK: - screenshot / clickat

    func testScreenshot() {
        guard case .screenshot(nil) = DSLParser.parse("screenshot")[0] else {
            return XCTFail("Expected screenshot with default path")
        }
        guard case .screenshot(let path) = DSLParser.parse("screenshot /tmp/shot.png")[0] else {
            return XCTFail("Expected screenshot with path")
        }
        XCTAssertEqual(path, "/tmp/shot.png")
    }

    func testClickAt() {
        guard case .perform(.clickAt(let x, let y, let kind)) = DSLParser.parse("clickat 100 250.5")[0] else {
            return XCTFail("Expected clickAt")
        }
        XCTAssertEqual(x, 100)
        XCTAssertEqual(y, 250.5)
        XCTAssertEqual(kind, .left)

        guard case .perform(.clickAt(_, _, .right)) = DSLParser.parse("clickat 10 20 right")[0] else {
            return XCTFail("Expected right clickAt")
        }
        guard case .perform(.clickAt(_, _, .double)) = DSLParser.parse("clickat 10 20 double")[0] else {
            return XCTFail("Expected double clickAt")
        }

        XCTAssertEqual(DSLParser.parseWithDiagnostics("clickat 10").errors.count, 1)
        XCTAssertEqual(DSLParser.parseWithDiagnostics("clickat ten twenty").errors.count, 1)
        XCTAssertEqual(DSLParser.parseWithDiagnostics("clickat 10 20 triple").errors.count, 1)
    }

    // MARK: - Aliases

    func testAliases() {
        guard case .getWindows = DSLParser.parse("getwindow")[0] else {
            return XCTFail("Expected getWindows for alias 'getwindow'")
        }
        guard case .getApps = DSLParser.parse("getapp")[0] else {
            return XCTFail("Expected getApps for alias 'getapp'")
        }
    }
}
