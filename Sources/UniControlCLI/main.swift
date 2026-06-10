//
//  main.swift
//  UniControlCLI
//
//  CLI entry point for UniControl - macOS UI automation tool
//

import Foundation
import Cocoa
import ApplicationServices
import UniControlCore

// MARK: - Command Line Interface

/// Print usage information
func printUsage() {
    print("""
    UniControl - macOS UI Automation Tool

    Usage:
      UniControl [options] <script-file>
      UniControl --interactive, -i
      UniControl --serve [port]
      UniControl --mcp

    Options:
      --debug, -d       Enable debug/verbose output (default: on)
      --quiet, -q       Disable verbose output
      --interactive, -i Start interactive REPL mode
      --serve [port]    Start HTTP/WebSocket server (default port: 8080)
      --mcp             Start MCP server (Model Context Protocol for Claude Desktop)
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

      # Start MCP server for Claude Desktop
      UniControl --mcp

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

    MCP Mode (Model Context Protocol):
      Enables Claude Desktop and other MCP-compatible LLMs to control macOS.
      Communicates via stdin/stdout using JSON-RPC 2.0 protocol.

      Available tools:
        - launch_app, use_window: Launch apps or attach to open windows
        - find_element, wait_for: Find UI elements (wait_for polls until present)
        - click, double_click, right_click: Click actions
        - click_at: Click at absolute screen coordinates
        - type_text, set_value: Type into or set value of text fields
        - press_key: Keyboard shortcuts
        - scroll, wait: Navigation and timing
        - get_system_info, get_windows, get_apps, get_element: State queries
        - dump_tree: Dump the UI element tree for discovery
        - screenshot: Capture the current window (returns the image)
        - assert: Verify conditions (exists/missing/enabled/disabled/value)
        - execute_script: Run multi-command DSL scripts

      Claude Desktop configuration (~/.config/claude/claude_desktop_config.json):
        {
          "mcpServers": {
            "unicontrol": {
              "command": "/path/to/UniControl",
              "args": ["--mcp"]
            }
          }
        }

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
      docs/TROUBLESHOOTING.md           - Troubleshooting guide
      docs/ACCESSIBILITY_PERMISSIONS.md - Permission setup guide
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

    let outcome = DSLParser.parseWithDiagnostics(scriptContent)

    if outcome.hasErrors {
        print("❌ Script has \(outcome.errors.count) parse error(s) — nothing was executed:")
        for error in outcome.errors {
            print("   \(error)")
        }
        exit(1)
    }

    let commands = outcome.commands
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
      usewindow [title]         - Attach to an open window (frontmost if no title)
      find <element>            - Find UI element by title
      find <title> role: <role> - Find element by title and role
      find role: <role>         - Find elements by role
      waitfor <sel> [timeout: n] - Wait until an element appears
      click                     - Click current element
      doubleclick               - Double-click current element
      rightclick                - Right-click current element
      type <text>               - Type text into current element
      setvalue <value>          - Set current element's value directly
      wait <seconds>            - Wait for specified duration
      assert <condition>        - Verify exists/missing/enabled/disabled/value
      dumptree [depth]          - Dump UI element tree for discovery
      screenshot [path]         - Capture current window to PNG
      clickat <x> <y> [right|double] - Click at screen coordinates
      log <message>             - Print a message
      presskey <key-combo>      - Press key combination (e.g., cmd+c)

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
        let outcome = DSLParser.parseWithDiagnostics(input)

        if let error = outcome.errors.first {
            print("\(error.message). Type 'help' for available commands.\n")
            continue
        }

        let commands = outcome.commands
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
var mcpMode = false

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
    case "--mcp":
        mcpMode = true
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
if mcpMode {
    // MCP mode - stdio transport for Claude Desktop and other MCP clients
    // Note: Don't check permissions here - MCP clients will get permission errors
    // when they try to execute commands, which is more informative
    runMCPStdioServer()
} else if serverMode {
    // In server mode, warn about accessibility but don't block startup
    // The server can still handle health checks, and permissions will be checked when scripts run
    if !checkAccessibilityPermission() {
        print("⚠️  Warning: Accessibility permission not granted.")
        print("    Script execution will fail until permissions are granted.")
        print("    See docs/ACCESSIBILITY_PERMISSIONS.md for instructions.")
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
        print("\nSee docs/ACCESSIBILITY_PERMISSIONS.md for detailed instructions.")
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
        print("\nSee docs/ACCESSIBILITY_PERMISSIONS.md for detailed instructions.")
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
