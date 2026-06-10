//
//  CommandRegistryTests.swift
//  UniControlCoreTests
//
//  Consistency checks for the unified command registry — the single source of
//  truth for DSL parsing, MCP tools, and autocomplete.
//

import XCTest
@testable import UniControlCore

final class CommandRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BuiltInCommands.registerAll()
    }

    func testVerbsAreUnique() {
        let verbs = BuiltInCommands.all.map { $0.verb }
        XCTAssertEqual(verbs.count, Set(verbs).count, "Duplicate verbs in BuiltInCommands.all")
    }

    func testMCPNamesAreUnique() {
        let names = BuiltInCommands.all.map { $0.mcpName }
        XCTAssertEqual(names.count, Set(names).count, "Duplicate MCP names in BuiltInCommands.all")
    }

    func testAliasesDoNotCollideWithVerbs() {
        let verbs = Set(BuiltInCommands.all.map { $0.verb })
        for descriptor in BuiltInCommands.all {
            for alias in descriptor.aliases {
                XCTAssertFalse(verbs.contains(alias), "Alias '\(alias)' collides with a primary verb")
            }
        }
    }

    func testRegistryLookupByVerbAndAlias() {
        XCTAssertNotNil(CommandRegistry.shared.descriptor(forVerb: "launch"))
        XCTAssertNotNil(CommandRegistry.shared.descriptor(forVerb: "LAUNCH"))
        XCTAssertNotNil(CommandRegistry.shared.descriptor(forVerb: "getwindow"), "Alias lookup failed")
        XCTAssertNotNil(CommandRegistry.shared.descriptor(forMCPName: "find_element"))
        XCTAssertNil(CommandRegistry.shared.descriptor(forVerb: "nonexistent"))
    }

    /// Every built-in DSL verb must be parseable by DSLParser. The sample-line
    /// table below must cover every descriptor — adding a command without
    /// parser support (or without updating this table) fails this test.
    func testEveryBuiltInVerbIsParseable() {
        let sampleLines: [String: String] = [
            "launch": "launch Calculator",
            "usewindow": "usewindow Untitled",
            "find": "find Save role: AXButton",
            "waitfor": "waitfor Save timeout: 2",
            "click": "click",
            "clickat": "clickat 100 200",
            "doubleclick": "doubleclick",
            "rightclick": "rightclick",
            "type": "type hello",
            "setvalue": "setvalue 42",
            "wait": "wait 1",
            "scroll": "scroll down",
            "presskey": "presskey cmd+c",
            "check": "check",
            "uncheck": "uncheck",
            "expand": "expand",
            "collapse": "collapse",
            "focus": "focus",
            "selectmenuitem": "selectmenuitem File > Save",
            "openmenu": "openmenu File",
            "increment": "increment",
            "decrement": "decrement",
            "getsystem": "getsystem",
            "getwindows": "getwindows",
            "getapps": "getapps",
            "getelement": "getelement",
            "dumptree": "dumptree 3",
            "screenshot": "screenshot",
            "assert": "assert exists Save",
            "reset": "reset",
            "log": "log hello",
            "mode": "mode strict",
            // "script" is the MCP-only execute_script wrapper; it is not a DSL line
            "script": ""
        ]

        for descriptor in BuiltInCommands.all {
            guard let sample = sampleLines[descriptor.verb] else {
                XCTFail("No sample line for verb '\(descriptor.verb)' — update this test when adding commands")
                continue
            }
            if sample.isEmpty { continue }  // MCP-only command

            let outcome = DSLParser.parseWithDiagnostics(sample)
            XCTAssertTrue(
                !outcome.hasErrors && outcome.commands.count == 1,
                "Verb '\(descriptor.verb)' failed to parse sample '\(sample)': \(outcome.errors)"
            )
        }
    }

    func testMCPToolGeneration() {
        let tools = CommandRegistry.shared.builtInMCPTools
        XCTAssertEqual(tools.count, BuiltInCommands.all.count)

        let toolNames = Set(tools.map { $0.name })
        XCTAssertTrue(toolNames.contains("launch_app"))
        XCTAssertTrue(toolNames.contains("find_element"))
        XCTAssertTrue(toolNames.contains("wait_for"))
        XCTAssertTrue(toolNames.contains("use_window"))
        XCTAssertTrue(toolNames.contains("dump_tree"))
        XCTAssertTrue(toolNames.contains("assert"))
        XCTAssertTrue(toolNames.contains("set_value"))
        XCTAssertTrue(toolNames.contains("screenshot"))
        XCTAssertTrue(toolNames.contains("click_at"))
    }

    func testMCPToolSchemaHasRequiredParameters() {
        let tool = BuiltInCommands.launch.toMCPTool()
        XCTAssertEqual(tool.name, "launch_app")

        guard case .object(let schema) = tool.inputSchema,
              case .array(let required)? = schema["required"],
              case .object(let properties)? = schema["properties"] else {
            return XCTFail("Unexpected schema shape for launch_app")
        }
        XCTAssertEqual(required.count, 1)
        XCTAssertNotNil(properties["app_name"])
    }
}
