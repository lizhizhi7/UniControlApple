# UniControl Extension System

The UniControl DSL supports extensions that add application-specific commands. This guide explains how to create custom extensions and integrate them with all system components.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Creating an Extension](#creating-an-extension)
5. [Autocomplete Integration](#autocomplete-integration)
6. [MCP Integration](#mcp-integration)
7. [Complete Checklist](#complete-checklist)
8. [Best Practices](#best-practices)
9. [Future: Unified Command Registry](#future-unified-command-registry)

---

## Overview

The extension system allows you to:
- Add new DSL verbs for specific applications (e.g., `range` for Excel)
- Parse custom command syntax
- Execute commands with access to the full execution context
- Integrate with autocomplete in UniControlApp
- Expose commands through MCP for LLM automation

### Integration Points

With the **unified CommandRegistry**, adding an extension is streamlined:

| Component | Location | Purpose |
|-----------|----------|---------|
| Extension Implementation | `Extensions/*.swift` | Implement `commandDescriptors`, `parse()`, `execute()` |
| Extension Registration | `main.swift` | Register at startup |
| Autocomplete | *(auto-generated)* | Generated from `CommandRegistry` |
| MCP Tools | *(auto-generated)* | Generated from `CommandRegistry` |

When you register an extension, its `commandDescriptors` are automatically added to `CommandRegistry`, making them available in both autocomplete and MCP tools.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          User Input                                  │
│         (Script file, REPL, HTTP API, MCP tool call)                │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          DSLParser                                   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  1. Try built-in commands: launch, find, click, etc.         │   │
│  │  2. If unknown verb → Check ExtensionRegistry                │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┴───────────────────────┐
        │                                               │
        ▼                                               ▼
┌───────────────────┐                    ┌──────────────────────────────┐
│   Built-in        │                    │    ExtensionRegistry         │
│   Command         │                    │  ┌──────────────────────┐   │
│                   │                    │  │  ExcelExtension      │   │
└─────────┬─────────┘                    │  │  - range             │   │
          │                              │  │  - typeincell        │   │
          │                              │  │  - getcell           │   │
          │                              │  └──────────────────────┘   │
          │                              │  ┌──────────────────────┐   │
          │                              │  │  CustomExtension     │   │
          │                              │  │  - mycommand         │   │
          │                              │  └──────────────────────┘   │
          │                              └────────────┬─────────────────┘
          │                                           │
          └─────────────────┬─────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DSLExecutor                                   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Execution Context: window, element, variables, mode         │   │
│  │  Routes to appropriate handler based on Command type         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Core Functions                                │
│  AppLauncher | ElementFinder | ElementInteraction | SystemState      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. The `DSLExtension` Protocol

Every extension must conform to this protocol:

```swift
// Location: Sources/UniControlCore/DSL/DSLExtension.swift

public protocol DSLExtension {
    // MARK: - Identity
    static var identifier: String { get }
    static var supportedCommands: [String] { get }
    static var commandDescriptors: [CommandDescriptor] { get }

    // MARK: - Metadata (all have defaults)
    static var displayName: String { get }         // defaults to identifier.capitalized
    static var version: String { get }             // defaults to "1.0.0"
    static var author: String { get }              // defaults to "Unknown"
    static var extensionDescription: String { get } // defaults to "Extension: <id>"
    static var targetApplication: String? { get }  // defaults to nil
    static var systemImageName: String { get }     // defaults to "puzzlepiece.extension"

    // MARK: - Lifecycle
    func onActivate()    // called when extension is enabled
    func onDeactivate()  // called when extension is disabled

    // MARK: - Execution Hooks
    func willExecuteCommand(_ command: Command, context: ExecutionContext)
    func didExecuteCommand(_ command: Command, result: CommandResult, context: ExecutionContext)

    // MARK: - Configuration
    static var configDescriptors: [ExtensionConfigDescriptor] { get }

    // MARK: - Core
    static func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand?
    func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult
    init()
}
```

All metadata, lifecycle, hook, and config properties have default no-op implementations via protocol extension, so existing extensions continue to work without changes.

### 2. The `ExtensionCommand` Structure

When your extension parses a command, it returns an `ExtensionCommand`:

```swift
// Location: Sources/UniControlCore/DSL/DSLExtension.swift

public struct ExtensionCommand {
    public let extensionId: String    // Your extension's identifier
    public let verb: String           // The command verb (e.g., "range")
    public let arguments: [String]    // Parsed arguments
    public let metadata: [String: Any] // Optional extra data

    public init(extensionId: String, verb: String, arguments: [String], metadata: [String: Any] = [:])
}
```

### 3. The `ExtensionRegistry`

The `ExtensionRegistry` is a singleton that manages all registered extensions:

```swift
// Location: Sources/UniControlCore/DSL/ExtensionRegistry.swift

// Register an extension
ExtensionRegistry.shared.register(MyExtension.self)

// Check if a verb is handled (returns false for disabled extensions)
ExtensionRegistry.shared.canHandle(verb: "mycommand")

// Get all registered verbs
let verbs = ExtensionRegistry.shared.registeredVerbs()

// Get extension ID for a verb
let extId = ExtensionRegistry.shared.extensionId(for: "range")  // "excel"

// Enable/disable extensions
ExtensionRegistry.shared.setEnabled(false, for: "excel")
ExtensionRegistry.shared.isEnabled("excel")  // false

// Get metadata about all extensions (for UI)
let extensions: [ExtensionInfo] = ExtensionRegistry.shared.registeredExtensions()

// Extension configuration
ExtensionRegistry.shared.setConfig(extensionId: "excel", key: "navigationDelay", value: "0.5")
let delay = ExtensionRegistry.shared.getConfig(extensionId: "excel", key: "navigationDelay")
```

The `ExtensionInfo` struct provides all metadata needed for UI display (identifier, displayName, version, author, description, commands, config descriptors, enabled state).

### 4. The `ExecutionContext`

Extensions receive the current execution context:

```swift
// Location: Sources/UniControlCore/DSL/DSLTypes.swift

public class ExecutionContext {
    public var currentWindow: AXUIElement?      // The current window
    public var currentElement: AXUIElement?     // The currently selected element
    public var foundElements: [AXUIElement]     // All elements from last search
    public var variables: [String: Any]         // User-defined variables
    public var mode: ExecutionMode              // Current execution mode
    public var errorLog: [(commandIndex: Int, command: String, error: String)]
    public var visionElement: VisionElement?    // Vision fallback element
    public var lastScreenshot: CGImage?         // Last captured screenshot
    public var outputCapture: OutputCapture?    // Server mode output capture
}
```

### 5. The `CommandResult`

Extension commands return a `CommandResult`:

```swift
// Location: Sources/UniControlCore/DSL/DSLTypes.swift

public enum CommandResult {
    case success(value: Any?)
    case failure(error: String)

    public var isSuccess: Bool
}
```

---

## Creating an Extension

### Step 1: Create the Extension File

Create a new Swift file in `Sources/UniControlCore/Extensions/`:

```swift
// FinderExtension.swift

import Foundation
import ApplicationServices

public class FinderExtension: DSLExtension {
    public static let identifier = "finder"

    public static let supportedCommands = [
        "goto",       // Navigate to a folder
        "newwindow",  // Open a new Finder window
        "getpath"     // Get the current path
    ]

    public required init() {}

    // ... implementation below
}
```

### Step 2: Implement the Parser

The `parse` method receives the full line and pre-split parts:

```swift
public static func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand? {
    switch verb {
    case "goto":
        // goto /Users/username/Documents
        guard parts.count >= 2 else { return nil }
        let path = parts[1...].joined(separator: " ")
        return ExtensionCommand(
            extensionId: identifier,
            verb: verb,
            arguments: [path]
        )

    case "newwindow":
        // newwindow or newwindow /path/to/folder
        let path = parts.count >= 2 ? parts[1...].joined(separator: " ") : nil
        return ExtensionCommand(
            extensionId: identifier,
            verb: verb,
            arguments: path != nil ? [path!] : []
        )

    case "getpath":
        // getpath or getpath as varname
        var varName: String? = nil
        if parts.count >= 3 && parts[1].lowercased() == "as" {
            varName = parts[2]
        }
        return ExtensionCommand(
            extensionId: identifier,
            verb: verb,
            arguments: varName != nil ? [varName!] : []
        )

    default:
        return nil
    }
}
```

### Step 3: Implement Command Execution

```swift
public func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult {
    guard let window = context.currentWindow else {
        return .failure(error: "No active window. Launch Finder first.")
    }

    switch command.verb {
    case "goto":
        return executeGoto(command.arguments, window: window, verbose: verbose)

    case "newwindow":
        return executeNewWindow(command.arguments, verbose: verbose)

    case "getpath":
        return executeGetPath(command.arguments, window: window, context: context, verbose: verbose)

    default:
        return .failure(error: "Unknown Finder command: \(command.verb)")
    }
}

private func executeGoto(_ args: [String], window: AXUIElement, verbose: Bool) -> CommandResult {
    guard !args.isEmpty else {
        return .failure(error: "goto requires a path")
    }

    let path = args[0]

    if verbose {
        print("📁 Navigating to \(path)")
    }

    // Use keyboard shortcut Cmd+Shift+G to open "Go to Folder" dialog
    if pressKeyCombo("cmd+shift+g") {
        Thread.sleep(forTimeInterval: 0.5)

        // Type the path
        if typeWithKeyboard(path) {
            Thread.sleep(forTimeInterval: 0.2)

            // Press Enter to navigate
            if pressKeyCombo("return") {
                if verbose {
                    print("✅ Navigated to \(path)")
                }
                return .success(value: path)
            }
        }
    }

    return .failure(error: "Could not navigate to \(path)")
}
```

### Step 4: Register the Extension

In `Sources/UniControlCLI/main.swift`, register the extension:

```swift
// Location: main.swift, around line 347

// Register extensions before executing any scripts
ExtensionRegistry.shared.register(ExcelExtension.self)
ExtensionRegistry.shared.register(FinderExtension.self)  // Add your extension
```

### Step 5: Use in Scripts

Your extension commands are now available in DSL scripts:

```
# finder-workflow.unictl
launch Finder
wait 1

goto /Users/username/Documents
wait 0.5

getpath as currentPath
log Current path stored in variable

newwindow /Users/username/Downloads
```

---

## Autocomplete Integration

Extension commands **automatically appear** in UniControlApp's script editor autocomplete when the extension provides `commandDescriptors`.

### How It Works

`DSLCompletionProvider` generates completions from `CommandRegistry`:

```swift
// UniControlApp/UniControlApp/Services/DSLCompletionProvider.swift

static var commands: [Completion] {
    CommandRegistry.shared.allDescriptors.flatMap { descriptor in
        // Creates completion for main verb and all aliases
        var completions = [Completion(
            command: descriptor.verb,
            syntax: descriptor.syntax,
            description: descriptor.description
        )]
        for alias in descriptor.aliases {
            completions.append(Completion(command: alias, ...))
        }
        return completions
    }
}
```

### Requirements for Auto-Discovery

1. Your extension must implement `commandDescriptors` (or use the default implementation)
2. The extension must be registered before autocomplete is accessed

### No Manual Updates Needed

Unlike the previous system, you do **not** need to manually add entries to `DSLCompletionProvider.swift`. Simply provide `commandDescriptors` in your extension and register it.

---

## MCP Integration

Extension commands **automatically appear** as MCP tools when the extension provides `commandDescriptors`.

### How It Works

`MCPToolRegistry` generates tools from `CommandRegistry`:

```swift
// Sources/UniControlCore/MCP/MCPToolRegistry.swift

public static var tools: [MCPTool] {
    CommandRegistry.shared.mcpTools  // Auto-generated from all descriptors
}
```

Each `CommandDescriptor` has a `toMCPTool()` method that generates the JSON Schema:

```swift
// CommandDescriptor.toMCPTool() generates:
MCPTool(
    name: "finder_goto",  // from mcpName
    description: "Navigate to a folder path...",  // from detailedDescription
    inputSchema: /* generated from parameters */
)
```

### Requirements for Auto-Discovery

1. Your extension must implement `commandDescriptors` with proper `mcpName` and `parameters`
2. The extension must be registered before MCP tools are listed

### Tool Execution

MCP tool calls are routed through `MCPHandler.executeTool()`. For extension commands, add a case that delegates to `ExtensionRegistry`:

```swift
case "finder_goto":
    let command = ExtensionCommand(extensionId: "finder", verb: "goto", arguments: [path])
    let result = ExtensionRegistry.shared.execute(command, context: executor.context, verbose: true)
    // Convert result to MCPToolCallResult
```

### Alternative: Use execute_script Tool

LLMs can also use the `execute_script` tool to run extension commands directly:

```json
{
  "name": "execute_script",
  "arguments": {
    "script": "launch Finder\nwait 1\ngoto /Users/username/Documents"
  }
}
```

This requires no additional MCP handler code but is less discoverable to LLMs.

---

## Complete Checklist

When adding a new extension, follow this simplified checklist:

### Required Steps

- [ ] **1. Create Extension File**
  - Location: `Sources/UniControlCore/Extensions/YourExtension.swift`
  - Implement `DSLExtension` protocol
  - Define `identifier` and `supportedCommands`
  - Define `commandDescriptors` with full metadata
  - Implement `parse()` and `execute()` methods

- [ ] **2. Register Extension**
  - Location: `Sources/UniControlCLI/main.swift`
  - Add: `ExtensionRegistry.shared.register(YourExtension.self)`

### Auto-Generated (No Action Needed)

- [x] **Autocomplete Entries** - Generated from `commandDescriptors`
- [x] **MCP Tool Definitions** - Generated from `commandDescriptors`

### Recommended Steps

- [ ] **3. Add MCP Tool Handler** (for direct tool calls)
  - Location: `Sources/UniControlCore/MCP/MCPHandler.swift`
  - Add switch case in `executeTool()` to delegate to extension
  - *(Optional: LLMs can use `execute_script` instead)*

- [ ] **4. Create Extension Documentation**
  - Location: `docs/extensions/YOUR_EXTENSION.md`
  - Document syntax, examples, and error handling

- [ ] **5. Update SKILL.md**
  - Location: `SKILL.md`
  - Add extension commands to the reference

---

## Best Practices

### 1. Use Descriptive Identifiers

Choose clear, unique identifiers that won't conflict:

```swift
public static let identifier = "excel"      // Good
public static let identifier = "app"        // Too generic
```

### 2. Handle Missing Context Gracefully

Always check for required context before executing:

```swift
guard let window = context.currentWindow else {
    return .failure(error: "No active window. Launch the app first.")
}
```

### 3. Provide Verbose Output

Use the `verbose` flag for debugging information:

```swift
if verbose {
    print("📊 Processing cell \(cellRef)")
}
```

### 4. Store Results in Variables

Allow users to capture command results:

```swift
// Support "as varname" syntax
if let varName = args.last, args.count > 1 {
    context.variables[varName] = result
    if verbose {
        print("📝 Stored in variable: $\(varName)")
    }
}
```

### 5. Use Meaningful Error Messages

Help users understand what went wrong:

```swift
// Bad
return .failure(error: "Failed")

// Good
return .failure(error: "Could not find Name Box. Is Excel's main window focused?")
```

### 6. Leverage Core Functions

Use UniControl's core functions rather than reimplementing:

```swift
// Use existing element finder
if let element = findElement(in: window, title: "Submit") {
    // ...
}

// Use existing click functions
if clickElementWithRetry(element, debug: verbose) {
    // ...
}

// Use keyboard simulation
if pressKeyCombo("cmd+s") {
    // ...
}
```

### 7. Keep Commands Focused

Each command should do one thing well:

```swift
// Good: Separate focused commands
public static let supportedCommands = [
    "range",        // Navigate to a cell
    "typeincell",   // Type into current cell
    "getcell"       // Read cell value
]

// Bad: Monolithic command
public static let supportedCommands = [
    "cellop"  // Does everything based on flags
]
```

---

## Unified Command Registry

UniControl now uses a **unified CommandRegistry** that serves as the single source of truth for all command metadata. This eliminates the need to manually update multiple files when adding commands.

### Architecture

```
                      CommandRegistry (Single Source of Truth)
                               |
        +----------------------+----------------------+
        |                      |                      |
   DSLParser              MCPToolRegistry       DSLCompletionProvider
   (lookup)               (auto-generated)      (auto-generated)
        |                      |                      |
  Command enum           MCPTool[]              Completion[]
```

### Core Components

**Location:** `Sources/UniControlCore/DSL/`

| File | Purpose |
|------|---------|
| `CommandDescriptor.swift` | Core types: `ParameterDescriptor`, `CommandCategory`, `CommandDescriptor` |
| `CommandRegistry.swift` | Singleton registry with lookup by verb/MCP name |
| `BuiltInCommands.swift` | All 27 built-in command definitions |

### CommandDescriptor Structure

```swift
public struct CommandDescriptor: Sendable {
    let verb: String           // DSL verb: "launch"
    let mcpName: String        // MCP tool: "launch_app"
    let syntax: String         // "launch <app-name>"
    let description: String    // Short desc for autocomplete
    let detailedDescription: String?  // Long desc for MCP
    let category: CommandCategory
    let parameters: [ParameterDescriptor]
    let requiresWindow: Bool
    let requiresElement: Bool
    let aliases: [String]      // e.g., ["getwindow"] for "getwindows"
    let extensionId: String?   // nil for built-in

    func toMCPTool() -> MCPTool  // Auto-generates MCP schema
}

public struct ParameterDescriptor: Sendable {
    let name: String
    let type: ParameterType    // .string, .integer, .number, .boolean
    let description: String
    let isRequired: Bool
    let enumValues: [String]?  // For restricted choices
}
```

### Benefits

1. **Single source of truth**: Define command once, use everywhere
2. **Auto-generation**:
   - MCP tool schemas generated via `toMCPTool()`
   - Autocomplete entries generated from `CommandRegistry.shared.allDescriptors`
3. **Consistency**: All interfaces stay in sync automatically
4. **Discoverability**: Extension commands automatically appear in autocomplete and MCP

### Adding a Built-in Command

Add a `CommandDescriptor` to `BuiltInCommands.swift`:

```swift
public static let myCommand = CommandDescriptor(
    verb: "mycommand",
    mcpName: "my_command",
    syntax: "mycommand <arg>",
    description: "Short description",
    detailedDescription: "Longer MCP description",
    category: .basicActions,
    parameters: [
        ParameterDescriptor(
            name: "arg",
            type: .string,
            description: "The argument",
            isRequired: true
        )
    ]
)

// Add to the `all` array
public static let all: [CommandDescriptor] = [
    // ... existing commands ...
    myCommand
]
```

Then add parsing in `DSLParser` and execution in `DSLExecutor`. MCP tools and autocomplete are **automatically generated**.

### Extension with Descriptors

Extensions can provide full `commandDescriptors` for auto-integration:

```swift
public class FinderExtension: DSLExtension {
    public static let identifier = "finder"

    public static let supportedCommands = ["goto", "newwindow", "getpath"]

    // Full descriptors for MCP and autocomplete
    public static let commandDescriptors: [CommandDescriptor] = [
        CommandDescriptor(
            verb: "goto",
            mcpName: "finder_goto",
            syntax: "goto <path>",
            description: "Navigate to a folder path",
            detailedDescription: "Navigate to a folder path in the current Finder window.",
            category: .extension_,
            parameters: [
                ParameterDescriptor(
                    name: "path",
                    type: .string,
                    description: "The folder path to navigate to",
                    isRequired: true
                )
            ],
            requiresWindow: true,
            extensionId: identifier
        ),
        // ... more descriptors
    ]

    // ... parse() and execute() implementations
}
```

When registered via `ExtensionRegistry.shared.register(FinderExtension.self)`, descriptors are automatically added to `CommandRegistry` and appear in MCP tools and autocomplete.

### Default Implementation

Extensions that don't provide `commandDescriptors` get a default implementation that generates basic descriptors from `supportedCommands`:

```swift
// Default implementation in DSLExtension protocol extension
public static var commandDescriptors: [CommandDescriptor] {
    supportedCommands.map { verb in
        CommandDescriptor(
            verb: verb,
            mcpName: "\(identifier)_\(verb)",
            syntax: verb,
            description: "\(identifier.capitalized) extension command: \(verb)",
            category: .extension_,
            extensionId: identifier
        )
    }
}
```

---

## Extension Management GUI

UniControlApp includes an **Extensions** tab that provides a visual interface for managing extensions.

### Features

- **Extension Cards**: Each extension displays its icon, name, version, description, target application, author, and command count
- **Enable/Disable Toggle**: Extensions can be enabled or disabled per-extension. Disabled extensions cannot handle commands and their verbs are rejected during script execution
- **Command List**: Expandable section showing all commands with syntax and descriptions
- **Configuration**: If an extension defines `configDescriptors`, the UI shows editable settings (text fields, toggles) for each config key

### Persistence

Extension enable/disable state and configuration values are persisted in `AppSettings` via UserDefaults. On app launch, the saved state is synced to `ExtensionRegistry`.

### Adding UI for New Extensions

No manual UI work is needed. When you register a new extension, it automatically appears in the Extensions tab with all metadata, commands, and config settings.

---

## Extension Lifecycle & Hooks

### Lifecycle Hooks

Extensions can implement `onActivate()` and `onDeactivate()` to perform setup/teardown when enabled or disabled:

```swift
func onActivate() {
    // Called when extension is enabled
}

func onDeactivate() {
    // Called when extension is disabled
}
```

### Execution Hooks

Extensions can observe all command executions (not just their own) via `willExecuteCommand` and `didExecuteCommand`:

```swift
func willExecuteCommand(_ command: Command, context: ExecutionContext) {
    // Called before any command executes
}

func didExecuteCommand(_ command: Command, result: CommandResult, context: ExecutionContext) {
    // Called after any command executes
}
```

These hooks are only called for enabled extensions.

### Extension Configuration

Extensions can define configurable settings using `ExtensionConfigDescriptor`:

```swift
public static let configDescriptors: [ExtensionConfigDescriptor] = [
    ExtensionConfigDescriptor(
        key: "retryCount",
        displayName: "Retry Count",
        type: .integer,
        defaultValue: "3",
        description: "Number of retries for cell navigation"
    )
]
```

Config values are stored in `ExtensionRegistry` and can be read at runtime:

```swift
let value = ExtensionRegistry.shared.getConfig(extensionId: "excel", key: "retryCount")
```

---

## See Also

- [DSL Reference](DSL_REFERENCE.md) - Built-in DSL commands
- [Excel Extension](extensions/EXCEL_EXTENSION.md) - Example extension implementation
- [MCP Documentation](../README.md#mcp-mode) - MCP server setup
- [SKILL.md](../SKILL.md) - LLM automation guidance
