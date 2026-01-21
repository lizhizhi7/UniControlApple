//
//  DSLExamples.swift
//  UniControl
//
//  Examples demonstrating DSL usage
//

import Foundation

/// Simple DSL script example
public func exampleDSLSimple() {
    if !checkAccessibilityPermission() {
        print("Accessibility permission required.")
        _ = requestAccessibilityPermission()
        exit(1)
    }

    print("=== DSL Example: Simple Script ===\n")

    let script = """
    # Launch Excel and interact with UI
    launch Excel
    wait 2
    log Finding Developer button
    find Blank Workbook role: AXButton
    click
    wait 1
    find Developer role: AXButton
    click
    wait 1
    find Check Box
    click
    log Done!
    """

    let commands = DSLParser.parse(script)
    let executor = DSLExecutor()

    if executor.execute(commands) {
        print("\n✅ Script executed successfully!")
    } else {
        print("\n❌ Script execution failed")
    }

    exit(0)
}

/// Complex programmatic DSL example
public func exampleDSLComplex() {
    if !checkAccessibilityPermission() {
        print("Accessibility permission required.")
        _ = requestAccessibilityPermission()
        exit(1)
    }

    print("=== DSL Example: Complex Workflow ===\n")

    // More complex example with programmatic DSL construction
    let commands: [Command] = [
        .log(message: "Starting Excel automation workflow"),
        .launch(appName: "Excel"),
        .perform(action: .wait(2.0)),

        .log(message: "Step 1: Navigate to Developer tab"),
        .find(selector: .byTitleAndRole(title: "Blank Workbook", role: "AXButton")),
        .perform(action: .click),
        .perform(action: .wait(1.0)),

        .find(selector: .byTitleAndRole(title: "Developer", role: "AXButton")),
        .perform(action: .click),
        .perform(action: .wait(1.0)),

        .log(message: "Step 2: Insert Check Box control"),
        .find(selector: .byTitle("Check Box")),
        .perform(action: .click),
        .perform(action: .wait(0.5)),

        .log(message: "Workflow completed")
    ]

    let executor = DSLExecutor()

    if executor.execute(commands) {
        print("\n✅ Workflow executed successfully!")
    } else {
        print("\n❌ Workflow execution failed")
    }

    exit(0)
}

/// Load and execute DSL script from file
public func exampleDSLFromFile(_ filePath: String? = nil, verbose: Bool = true) {
    if !checkAccessibilityPermission() {
        print("Accessibility permission required.")
        _ = requestAccessibilityPermission()
        exit(1)
    }

    print("=== DSL Example: Load from File ===\n")

    // Example of loading a script from a file
    let scriptPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil

    let pathToUse = filePath ?? scriptPath

    if let path = pathToUse, let scriptContent = try? String(contentsOfFile: path) {
        print("Loading script from: \(path)\n")
        let commands = DSLParser.parse(scriptContent)
        let executor = DSLExecutor()

        if executor.execute(commands, verbose: verbose) {
            print("\n✅ Script executed successfully!")
        } else {
            print("\n❌ Script execution failed")
        }
    } else {
        print("Usage: UniControl <script-file>")
        print("\nOr run without arguments to use example script:")
        exampleDSLSimple()
    }

    exit(0)
}
