# UniControl Extension System

The UniControl DSL supports extensions that add application-specific commands. This guide explains how to create custom extensions.

## Overview

The extension system allows you to:
- Add new DSL verbs for specific applications (e.g., `range` for Excel)
- Parse custom command syntax
- Execute commands with access to the full execution context
- Integrate seamlessly with the base DSL

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    DSLParser                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Built-in commands: launch, find, click, etc.   │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Unknown verb? Check ExtensionRegistry          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 ExtensionRegistry                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Excel     │  │   Finder    │  │   Custom    │    │
│  │  Extension  │  │  Extension  │  │  Extension  │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### The `DSLExtension` Protocol

Every extension must conform to the `DSLExtension` protocol:

```swift
public protocol DSLExtension {
    /// Unique identifier for this extension (e.g., "excel", "finder")
    static var identifier: String { get }

    /// List of command verbs this extension handles
    static var supportedCommands: [String] { get }

    /// Parse a DSL line into an ExtensionCommand
    static func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand?

    /// Execute an extension command
    func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult

    /// Required initializer
    init()
}
```

### The `ExtensionCommand` Structure

When your extension parses a command, it returns an `ExtensionCommand`:

```swift
public struct ExtensionCommand {
    public let extensionId: String    // Your extension's identifier
    public let verb: String           // The command verb (e.g., "range")
    public let arguments: [String]    // Parsed arguments
    public let metadata: [String: Any] // Optional extra data

    public init(extensionId: String, verb: String, arguments: [String], metadata: [String: Any] = [:])
}
```

### The `ExtensionRegistry`

The `ExtensionRegistry` is a singleton that manages all registered extensions:

```swift
// Register an extension
ExtensionRegistry.shared.register(MyExtension.self)

// Check if a verb is handled
ExtensionRegistry.shared.canHandle(verb: "mycommand")

// Get all registered verbs
let verbs = ExtensionRegistry.shared.registeredVerbs()
```

### The `ExecutionContext`

Extensions receive the current execution context, providing access to:

```swift
public class ExecutionContext {
    public var currentWindow: AXUIElement?      // The current window
    public var currentElement: AXUIElement?     // The currently selected element
    public var foundElements: [AXUIElement]     // All elements from last search
    public var variables: [String: Any]         // User-defined variables
    public var mode: ExecutionMode              // Current execution mode
    public var errorLog: [(commandIndex: Int, command: String, error: String)]
    public var visionElement: VisionElement?    // Vision fallback element
    public var lastScreenshot: CGImage?         // Last captured screenshot
}
```

### The `CommandResult`

Extension commands return a `CommandResult`:

```swift
public enum CommandResult {
    case success(value: Any?)
    case failure(error: String)

    public var isSuccess: Bool
}
```

## Step-by-Step: Creating an Extension

### Step 1: Create the Extension File

Create a new Swift file in `UniControl/Extensions/`:

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

    // ... implementation
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

In your `main.swift` or initialization code, register the extension:

```swift
// Register extensions before executing any scripts
ExtensionRegistry.shared.register(FinderExtension.self)
ExtensionRegistry.shared.register(ExcelExtension.self)
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

### 7. Document Your Commands

Create documentation for your extension (see [Excel Extension](extensions/EXCEL_EXTENSION.md) as an example).

## Complete Example: Excel Extension

Here's the structure of the built-in Excel extension:

```swift
public class ExcelExtension: DSLExtension {
    public static let identifier = "excel"

    public static let supportedCommands = [
        "range",        // Navigate to a cell: range A1
        "typeincell",   // Type into cell: typeincell A1 "Hello"
        "getcell"       // Read cell: getcell A1 as myvar
    ]

    public required init() {}

    public static func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand? {
        switch verb {
        case "range":
            guard parts.count >= 2 else { return nil }
            return ExtensionCommand(
                extensionId: identifier,
                verb: verb,
                arguments: [parts[1]]
            )
        // ... other commands
        default:
            return nil
        }
    }

    public func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult {
        guard let window = context.currentWindow else {
            return .failure(error: "No active window. Launch Excel first.")
        }

        switch command.verb {
        case "range":
            return executeRange(command.arguments, window: window, context: context, verbose: verbose)
        // ... other commands
        default:
            return .failure(error: "Unknown Excel command: \(command.verb)")
        }
    }
}
```

## Testing Your Extension

1. **Unit Test Parsing**:
```swift
let result = MyExtension.parse("mycommand arg1 arg2", verb: "mycommand", parts: ["mycommand", "arg1", "arg2"])
assert(result != nil)
assert(result?.arguments == ["arg1", "arg2"])
```

2. **Integration Test**:
```swift
ExtensionRegistry.shared.register(MyExtension.self)

let script = """
launch MyApp
wait 2
mycommand arg1
"""

let commands = DSLParser.parse(script)
let executor = DSLExecutor()
let success = executor.execute(commands)
```

## See Also

- [DSL Reference](DSL_REFERENCE.md) - Built-in DSL commands
- [Excel Extension](extensions/EXCEL_EXTENSION.md) - Example extension implementation
