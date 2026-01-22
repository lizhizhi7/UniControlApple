//
//  main.swift
//  UniControl
//
//  Created by Oliver Li on 2025/7/15.
//
//  Main entry point for UniControl - macOS UI automation tool
//

import Foundation
import Cocoa
import ApplicationServices

// MARK: - Command Line Interface

/// Print usage information
func printUsage() {
    print("""
    UniControl - macOS UI Automation Tool

    Usage:
      UniControl [options] <script-file>

    Options:
      --debug, -d       Enable debug/verbose output (default: on)
      --quiet, -q       Disable verbose output
      --help, -h        Show this help message
      --version, -v     Show version information

    Examples:
      # Run script with debug output (default)
      UniControl examples/example-calculator-simple.unictl

      # Run script quietly (minimal output)
      UniControl --quiet examples/example-excel-developer-checkbox.unictl

      # Run with explicit debug mode
      UniControl --debug examples/test-comprehensive.unictl

    Example Scripts:
      examples/example-calculator-simple.unictl
        - Simple Calculator automation (no Excel required)
        - Good for quick testing

      examples/example-excel-developer-checkbox.unictl
        - Excel automation: Insert checkbox control
        - Requires Microsoft Excel

      examples/example-excel-explorer.unictl
        - Explore available UI elements (debugging tool)
        - Shows element suggestions

      examples/test-comprehensive.unictl
        - Full test suite for all UniControl features

    Debug Mode:
      When debug mode is enabled (default), you'll see:
      - Command execution progress [1/10], [2/10], etc.
      - Success/failure indicators (✅/❌)
      - Vision fallback activation messages
      - Element suggestions when searches fail
      - Error summaries at the end

    Quiet Mode:
      When quiet mode is enabled (--quiet), you'll only see:
      - Explicit log commands from your script
      - Critical errors
      - Final success/failure status

    Documentation:
      CLAUDE.md                        - Project overview and architecture
      DEBUG_MODE_GUIDE.md              - Debug mode usage guide
      ACCESSIBILITY_PERMISSIONS_GUIDE.md - Permission setup guide
      examples/TEST_README.md          - Testing guide
    """)
}

/// Print version information
func printVersion() {
    print("UniControl v1.0.0")
    print("macOS UI Automation Tool")
    print("https://github.com/yourusername/UniControl")
}

/// Load and execute DSL script from file
func executeScriptFromFile(_ filePath: String, verbose: Bool) {
    guard let scriptContent = try? String(contentsOfFile: filePath) else {
        print("❌ Error: Could not read file: \(filePath)")
        exit(1)
    }

    if verbose {
        print("Loading script from: \(filePath)\n")
    }

    let commands = DSLParser.parse(scriptContent)
    let executor = DSLExecutor()

    if executor.execute(commands, verbose: verbose) {
        if verbose {
            print("\n✅ Script executed successfully!")
        }
        exit(0)
    } else {
        if verbose {
            print("\n❌ Script execution failed")
        }
        exit(1)
    }
}

// MARK: - Main Entry Point

// Parse command line arguments
var scriptPath: String? = nil
var verboseMode = true  // Default: debug/verbose mode ON
var showHelp = false
var showVersion = false

var i = 1
while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]

    switch arg {
    case "--debug", "-d":
        verboseMode = true
    case "--quiet", "-q":
        verboseMode = false
    case "--help", "-h":
        showHelp = true
    case "--version", "-v":
        showVersion = true
    default:
        if arg.hasPrefix("-") {
            print("Unknown option: \(arg)")
            print("Use --help for usage information")
            exit(1)
        } else {
            scriptPath = arg
        }
    }
    i += 1
}

// Handle flags
if showHelp {
    printUsage()
    exit(0)
}

if showVersion {
    printVersion()
    exit(0)
}

// Check accessibility permission
if !checkAccessibilityPermission() {
    print("❌ Accessibility permission required.")
    print("\nTo grant permission:")
    print("1. Open System Settings → Privacy & Security → Accessibility")
    print("2. Add your Terminal app (Terminal, iTerm, Warp, etc.)")
    print("3. Toggle it ON")
    print("4. Restart your terminal")
    print("\nSee ACCESSIBILITY_PERMISSIONS_GUIDE.md for detailed instructions.")
    _ = requestAccessibilityPermission()
    exit(1)
}

// Register DSL extensions
ExtensionRegistry.shared.register(ExcelExtension.self)

// Run the script
if let path = scriptPath {
    executeScriptFromFile(path, verbose: verboseMode)
} else {
    // No script provided - show help
    print("No script file specified.\n")
    printUsage()
    exit(1)
}
