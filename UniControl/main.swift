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
      UniControl --interactive, -i
      UniControl --serve [port]

    Options:
      --debug, -d       Enable debug/verbose output (default: on)
      --quiet, -q       Disable verbose output
      --interactive, -i Start interactive REPL mode
      --serve [port]    Start HTTP/WebSocket server (default port: 8080)
      --help, -h        Show this help message
      --version, -v     Show version information

    Examples:
      # Run script with debug output (default)
      UniControl examples/example-calculator-simple.unictl

      # Run script quietly (minimal output)
      UniControl --quiet examples/example-excel-developer-checkbox.unictl

      # Run with explicit debug mode
      UniControl --debug examples/test-comprehensive.unictl

      # Start interactive REPL
      UniControl --interactive

      # Start server on default port (8080)
      UniControl --serve

      # Start server on custom port
      UniControl --serve 3000

    Interactive Mode:
      Enter commands one at a time. Context is preserved between commands.
      Type 'help' for available commands, 'exit' or 'quit' to exit.

    Server Mode:
      When running in server mode, UniControl listens for HTTP requests:
      - POST /execute - Execute DSL script (JSON body: {"script": "...", "mode": "continue"})
      - GET  /health  - Health check endpoint
      - WS   /ws      - WebSocket for real-time log streaming

      Example curl request:
        curl -X POST http://localhost:8080/execute \\
          -H "Content-Type: application/json" \\
          -d '{"script": "launch Calculator\\nwait 1\\nfind 7\\nclick"}'

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
      - Success/failure indicators
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

/// Print interactive mode help
func printInteractiveHelp() {
    print("""

    Available Commands:
      launch <app>              - Launch an application
      find <element>            - Find UI element by title
      find <title> role: <role> - Find element by title and role
      find role: <role>         - Find elements by role
      click                     - Click current element
      doubleclick               - Double-click current element
      rightclick                - Right-click current element
      type <text>               - Type text into current element
      wait <seconds>            - Wait for specified duration
      log <message>             - Print a message
      press <key-combo>         - Press key combination (e.g., cmd+c)

    REPL Commands:
      help                      - Show this help
      status                    - Show current context (window, element)
      clear                     - Clear current context
      exit, quit                - Exit interactive mode

    """)
}

/// Run interactive REPL mode
func runInteractiveMode(verbose: Bool) {
    print("UniControl Interactive Mode")
    print("Type 'help' for commands, 'exit' to quit.\n")

    let executor = DSLExecutor()

    while true {
        // Print prompt with context info
        var prompt = "unictl"
        if let window = executor.context.currentWindow {
            let title = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String ?? "?"
            let shortTitle = title.count > 20 ? String(title.prefix(17)) + "..." : title
            prompt += " [\(shortTitle)]"
        }
        if executor.context.currentElement != nil {
            prompt += " *"
        }
        print("\(prompt)> ", terminator: "")

        // Read input
        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
            // EOF (Ctrl+D)
            print("\nGoodbye!")
            break
        }

        // Skip empty lines
        if input.isEmpty {
            continue
        }

        // Handle REPL-specific commands
        let lowercased = input.lowercased()
        switch lowercased {
        case "exit", "quit":
            print("Goodbye!")
            return

        case "help":
            printInteractiveHelp()
            continue

        case "status":
            print("\nCurrent Context:")
            if let window = executor.context.currentWindow {
                let title = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String ?? "Unknown"
                print("  Window: \"\(title)\"")
            } else {
                print("  Window: (none)")
            }
            if let element = executor.context.currentElement {
                let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String ?? "Unknown"
                let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
                print("  Element: \(role)" + (title.map { " \"\($0)\"" } ?? ""))
            } else {
                print("  Element: (none)")
            }
            if executor.context.visionElement != nil {
                print("  Vision Element: (active)")
            }
            print("")
            continue

        case "clear":
            executor.context.currentWindow = nil
            executor.context.currentElement = nil
            executor.context.foundElements = []
            executor.context.visionElement = nil
            print("Context cleared.\n")
            continue

        default:
            break
        }

        // Parse and execute as DSL command
        let commands = DSLParser.parse(input)

        if commands.isEmpty {
            print("Unknown command. Type 'help' for available commands.\n")
            continue
        }

        // Execute commands (preserving context between invocations)
        _ = executor.execute(commands, verbose: verbose)
        print("")
    }
}

// MARK: - Main Entry Point

// Parse command line arguments
var scriptPath: String? = nil
var verboseMode = true  // Default: debug/verbose mode ON
var showHelp = false
var showVersion = false
var serverMode = false
var serverPort = 8080
var interactiveMode = false

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
    case "--serve":
        serverMode = true
        // Check if next argument is a port number
        if i + 1 < CommandLine.arguments.count {
            let nextArg = CommandLine.arguments[i + 1]
            if let port = Int(nextArg), port > 0 && port <= 65535 {
                serverPort = port
                i += 1
            }
        }
    case "--interactive", "-i":
        interactiveMode = true
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

// Register DSL extensions
ExtensionRegistry.shared.register(ExcelExtension.self)

// Run in appropriate mode
if serverMode {
    // In server mode, warn about accessibility but don't block startup
    // The server can still handle health checks, and permissions will be checked when scripts run
    if !checkAccessibilityPermission() {
        print("⚠️  Warning: Accessibility permission not granted.")
        print("    Script execution will fail until permissions are granted.")
        print("    See ACCESSIBILITY_PERMISSIONS_GUIDE.md for instructions.")
        print("")
    }
    // Start HTTP/WebSocket server
    let server = UniControlServer(port: serverPort)
    Task {
        do {
            try await server.start()
        } catch {
            print("Server error: \(error)")
            exit(1)
        }
    }
    // Keep the main thread alive
    RunLoop.main.run()
} else if interactiveMode {
    // Check accessibility permission for interactive mode
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
    // Run interactive REPL
    runInteractiveMode(verbose: verboseMode)
} else if let path = scriptPath {
    // Check accessibility permission for script execution
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
    // Run script file
    executeScriptFromFile(path, verbose: verboseMode)
} else {
    // No script provided - show help
    print("No script file specified.\n")
    printUsage()
    exit(1)
}
