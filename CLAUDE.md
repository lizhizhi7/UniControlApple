# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UniControl is a macOS automation system written in Swift that provides programmatic control over macOS applications using the Accessibility (AX) APIs. It consists of two components:

1. **UniControl CLI** - A command-line tool for scripted automation
2. **UniControlApp** - A menu bar GUI application with a script editor, execution history, and HTTP server for remote control

Both serve as **control method implementations** for the broader Universal Operations system, providing keyboard/mouse and UI automation capabilities for any macOS application.

### Role in Universal Operations System

UniControl is a foundational component in the **Control Methods layer** of the universal operations architecture:
- **Position in Stack**: Sits between Software Adapters and Target Applications
- **Primary Purpose**: Provides UI automation when native APIs or command-line interfaces are unavailable
- **Control Capabilities**: Application launching, window management, UI element discovery and interaction
- **Fallback Strategy**: Used by adapters when higher-level control methods (native APIs, CLI) fail or are unsupported
- **Application Scope**: Can control any macOS application, not limited to CAD/BIM software

## Build Commands

### UniControl CLI
```bash
# Build the CLI tool
swift build

# Run the CLI
.build/debug/UniControl   # or .build/release/UniControl
```

### UniControlApp (GUI)
```bash
# Build the GUI app
xcodebuild -project UniControlApp/UniControlApp.xcodeproj -scheme UniControlApp -configuration Debug build

# The app is output to DerivedData, or open UniControlApp.xcodeproj in Xcode and run
```

## Development Environment

- **Language**: Swift 5.0
- **Minimum macOS**: 15.2
- **Xcode Version**: 16.2+
- **Build System**: Xcode build system (objectVersion 77 with file-system synchronized groups)
- **Product Type**: Command-line tool (com.apple.product-type.tool)

## Project Structure

### UniControl CLI

```
Sources/
├── UniControlCLI/
│   └── main.swift                  # CLI entry point
└── UniControlCore/                 # Shared library
    ├── DSL/                        # Domain Specific Language
    │   ├── CommandDescriptor.swift # Command metadata types (ParameterDescriptor, CommandCategory)
    │   ├── CommandRegistry.swift   # Central registry for all commands
    │   ├── BuiltInCommands.swift   # All built-in command definitions
    │   ├── DSLTypes.swift          # Type definitions (Command, Action, Selector, Assertion, etc.)
    │   ├── DSLParser.swift         # Text script parser with line-numbered diagnostics
    │   ├── DSLExecutor.swift       # Command executor with context management
    │   ├── DSLExtension.swift      # Extension protocol definition
    │   └── ExtensionRegistry.swift # Extension registration and lookup
    ├── Extensions/                 # Application-specific extensions
    │   └── ExcelExtension.swift    # Excel-specific commands (range, typeincell, getcell)
    ├── MCP/                        # Model Context Protocol support
    │   ├── MCPTypes.swift          # JSON-RPC and MCP type definitions
    │   ├── MCPToolRegistry.swift   # MCP tool generation from CommandRegistry
    │   ├── MCPHandler.swift        # MCP request handling
    │   ├── MCPStdioTransport.swift # stdio transport (Claude Desktop)
    │   └── MCPHTTPTransport.swift  # HTTP transport
    ├── Server/                     # HTTP/WebSocket server (Hummingbird)
    │   ├── UniControlServer.swift  # Server routes and execution
    │   ├── ServerTypes.swift       # Request/response types
    │   └── OutputCapture.swift     # Structured output capture for server/MCP modes
    ├── Core/                       # Core automation functionality
    │   ├── AppLauncher.swift       # Application launching and window management
    │   ├── ElementFinder.swift     # UI element discovery, search, and tree dumping
    │   ├── ElementInteraction.swift # Element interaction (click, type, keys, etc.)
    │   ├── SystemState.swift       # System/app/window state retrieval
    │   ├── ScreenCapture.swift     # Window screenshots for vision fallback
    │   └── VisionProcessor.swift   # OCR-based element finding fallback
    └── Utils/                      # Utility functions
        ├── Permissions.swift       # Accessibility permission handling
        ├── SuggestionEngine.swift  # "Did you mean" suggestions for failed finds
        └── ElementDebugger.swift   # Element debugging helpers

Tests/
└── UniControlCoreTests/            # Unit tests (pure logic, no Accessibility permission needed)
    ├── DSLParserTests.swift        # Parser and diagnostics tests
    ├── CommandRegistryTests.swift  # Registry/MCP-tool consistency tests
    └── SuggestionEngineTests.swift # Suggestion scoring tests
```

Run tests with `swift test` — they exercise only pure logic and never trigger an Accessibility permission prompt.

### UniControlApp (GUI)

```
UniControlApp/
├── UniControlAppApp.swift          # App entry point (@main)
├── AppDelegate.swift               # NSApplicationDelegate for menu bar
├── MenuBarController.swift         # Menu bar popover management
├── Views/
│   ├── ContentView.swift           # Main container with tabs (Scripts, Extensions, Settings)
│   ├── ScriptEditorView.swift      # Script library + editor + execution history
│   ├── ExtensionsView.swift        # Extension management (enable/disable, config, commands)
│   ├── SettingsView.swift          # Server and permission settings
│   ├── ViewHelpers.swift           # Shared utilities (Formatters, badges, sheets)
│   └── Components/
│       └── DSLTextEditor.swift     # Syntax-highlighted editor with autocomplete
├── ViewModels/
│   ├── AppState.swift              # App-wide observable state
│   └── ServerManager.swift         # HTTP server lifecycle
├── Models/
│   ├── AppSettings.swift           # User preferences (port, execution mode)
│   └── SavedScript.swift           # Script, version, and execution history models
└── Services/
    ├── ScriptLibrary.swift         # Script CRUD and selection
    ├── PersistenceManager.swift    # File-based JSON storage
    └── DSLCompletionProvider.swift # Autocomplete suggestions
```

## Architecture

### Module Overview

#### 1. DSL Layer (`Sources/UniControlCore/DSL/`)

**Purpose**: Provides a declarative domain-specific language for automation workflows.

**Key Components**:
- **DSLTypes.swift**
  - `ElementSelector`: Flexible element selection (byTitle, byRole, byTitleAndRole, byIndex, byState, byRegex, all)
  - `Action`: Actions to perform (click, type, setValue, wait, scroll, pressKey, menu/checkbox/stepper actions)
  - `Command`: High-level commands (launch, useWindow, find, waitFor, perform, assert, dumpTree, reset, log, getSystem, getWindows, getElement, getApps)
  - `Assertion`: Verifiable conditions (exists/notExists/enabled/value)
  - `CommandResult`: Result wrapper (success/failure)
  - `ExecutionContext`: Maintains state across commands (window, element, variables)
  - State info structs: `ElementInfo`, `SystemInfo`, `WindowInfo`, `AppInfo` for structured responses

- **DSLParser.swift**
  - Parses text-based `.unictl` scripts
  - `parseWithDiagnostics()` returns commands plus line-numbered `ParseError`s with "did you mean" suggestions; invalid scripts are rejected before execution in CLI, server, and MCP modes
  - Supports comments (`#` and `//`)
  - Flexible selector syntax (`role:`, `type:`, `index:`, `pattern:`, `state:`)

- **DSLExecutor.swift**
  - Executes parsed commands sequentially
  - Manages execution context
  - Error handling and reporting
  - Verbose logging option
  - Calls extension `willExecuteCommand`/`didExecuteCommand` hooks around each command

- **DSLExtension.swift**
  - `DSLExtension` protocol with metadata (displayName, version, author, description, targetApplication, systemImageName)
  - Lifecycle hooks (`onActivate`, `onDeactivate`)
  - Execution hooks (`willExecuteCommand`, `didExecuteCommand`)
  - Configuration via `ExtensionConfigDescriptor`
  - All new properties have default implementations

- **ExtensionRegistry.swift**
  - Singleton managing extension registration, lookup, enable/disable, and configuration
  - `ExtensionInfo` struct for UI display of extension metadata
  - `registeredExtensions()` returns metadata for all registered extensions
  - `setEnabled`/`isEnabled` for enable/disable with persistence support
  - `getConfig`/`setConfig` for extension-scoped configuration

#### 2. Core Layer (`Sources/UniControlCore/Core/`)

**Purpose**: Low-level accessibility API wrappers and automation primitives.

**Key Components**:
- **AppLauncher.swift**
  - `launchApp()`: Search and launch applications by name
  - `getFrontmostAppFocusedWindow()`: Get active window
  - `moveWindow()`: Reposition windows
  - `launchAppAndGetFocusedWindow()`: Async launch with retry logic

- **ElementFinder.swift**
  - `getAttribute()`: Get AX attribute values
  - `findElements()`: Recursive element search with role filtering
  - `findElement()`: Find by title/description/help/value attributes
  - `findAllButtons()`: Legacy button-specific search
  - `buildElementInfo()`: Build rich ElementInfo from AXUIElement

- **SystemState.swift**
  - `getSystemInfo()`: Get OS version, hostname, architecture, username
  - `getRunningApps()`: Get running applications with metadata
  - `getWindowsInfo()`: Get window information using AX API

- **ElementInteraction.swift**
  - `clickElement()`: Perform click action
  - `printElementInfo()`: Debug element details

#### 3. Utils Layer (`Sources/UniControlCore/Utils/`)

**Purpose**: Cross-cutting utility functions.

**Key Components**:
- **Permissions.swift**
  - `checkAccessibilityPermission()`: Check permission status
  - `requestAccessibilityPermission()`: Prompt user for permissions

#### 4. Tests (`Tests/UniControlCoreTests/`)

**Purpose**: Fast unit tests for the pure-logic layers (parser, registry, MCP tool generation, suggestions). They run with `swift test`, need no Accessibility permission, and are enforced in CI. Example `.unictl` scripts in `examples/` serve as manual integration tests (these do need permission; see `docs/ACCESSIBILITY_PERMISSIONS.md`).

### UniControlApp Architecture

**View Layer** (`Views/`):
- `ContentView` - Tab container (Scripts, Extensions, Settings) with header showing server status
- `ScriptEditorView` - HSplitView with script library (left) and editor + history (right)
- `ExtensionsView` - Extension management with cards showing metadata, enable/disable toggle, command list, and config settings
- `DSLTextEditor` - HighlightedTextEditor wrapper with syntax highlighting and autocomplete popup
- `ViewHelpers` - Shared components: `Formatters` (time/duration), `RemoteBadge`, `VersionBadge`, `ScriptNameSheet`

**ViewModel Layer** (`ViewModels/`):
- `AppState` - @Observable class holding settings, server manager, script library, and UI state
- `ServerManager` - Manages HTTP server lifecycle (start/stop/restart) with status enum

**Model Layer** (`Models/`):
- `SavedScript` - Script with name, content, versions array, and execution history
- `SavedScript.ScriptVersion` - Versioned snapshot with content, timestamp, and optional note
- `SavedScript.VersionExecution` - Execution record with session ID, duration, command results
- `AppSettings` - User preferences persisted to UserDefaults (includes disabled extensions list and extension configs)

**Service Layer** (`Services/`):
- `ScriptLibrary` - Script CRUD, selection, search, sort, and content change tracking
- `PersistenceManager` - JSON file persistence to Application Support directory
- `DSLCompletionProvider` - Provides command completions based on cursor position

### Key Technical Details

- **Accessibility APIs**: Extensively uses `ApplicationServices` framework's AX functions (`AXUIElementCreate*`, `AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`)
- **Asynchronous Operations**: Uses GCD (`DispatchQueue`) for launching apps and polling for window readiness
- **Permission Requirements**: Requires Accessibility permissions to control other applications (prompted on first run if not granted)
- **Search Strategy**: Scans `/Applications`, `/System/Applications`, and `~/Applications` for matching app bundles
- **Public API**: All modules expose public functions for use by main.swift and future integrations
- **SwiftUI Patterns**: Uses @Observable, @Bindable, and environment for state management

## DSL Syntax

UniControl includes a simple but powerful DSL for defining automation workflows. Scripts can be written in text files (`.unictl` extension) or constructed programmatically.

### Basic Commands

```
# Comments start with # or //

# Launch or attach to an application
launch <app-name>                      # Launch app and use its window
usewindow                              # Attach to the frontmost window
usewindow <title-substring>            # Attach to an open window by title

# Find UI elements
find <element-title>                    # Find by title
find <title> role: <role-name>         # Find by title and role
find role: <role-name>                 # Find by role only
find pattern: <regex>                  # Find by regex on title/description/value
find index: <n>                        # Pick nth element from last multi-result find
waitfor <selector> [timeout: <sec>]    # Poll until element appears (default 5s)

# Perform actions
click / doubleclick / rightclick       # Click current element
clickat <x> <y> [right|double]         # Click at absolute screen coordinates
type <text>                            # Type text into current element
setvalue <value>                       # Set current element's value directly
presskey <combo>                       # Keyboard shortcut (e.g. cmd+s)
scroll <up|down|left|right>            # Scroll
wait <seconds>                         # Wait for specified duration

# Verification
assert exists <selector>               # Fail unless a matching element exists
assert missing <selector>              # Fail if a matching element exists
assert enabled / assert disabled      # Check current element state
assert value <text>                    # Check current element's value

# State retrieval commands
getsystem                              # Get OS version, hostname, architecture, username
getwindows                             # Get all visible windows (alias: getwindow)
getapps                                # Get all running applications (alias: getapp)
getelement                             # Get detailed info about current element
dumptree [depth]                       # Dump UI element tree (default depth 4)
screenshot [path]                      # Capture current window to PNG (needs Screen Recording permission)

# Session
reset                                  # Clear window/element context
log <message>                          # Print message to console
```

### Example Script

```
# Launch Excel and automate Developer tab
launch Excel
wait 2

log Navigating to Developer tab
find Developer role: AXButton
click
wait 1

log Inserting checkbox
find Check Box
click

log Done!
```

### Programmatic Usage

```swift
let commands: [Command] = [
    .launch(appName: "Excel"),
    .perform(action: .wait(2.0)),
    .find(selector: .byTitleAndRole(title: "Developer", role: "AXButton")),
    .perform(action: .click)
]

let executor = DSLExecutor()
executor.execute(commands)
```

## Adding New Features

### Adding a New Built-in DSL Command

UniControl uses a **unified CommandRegistry** that auto-generates MCP tools and autocomplete from a single source of truth. To add a new built-in command:

1. **Define the CommandDescriptor** in `Sources/UniControlCore/DSL/BuiltInCommands.swift`:

```swift
public static let myCommand = CommandDescriptor(
    verb: "mycommand",
    mcpName: "my_command",
    syntax: "mycommand <arg>",
    description: "Short description for autocomplete",
    detailedDescription: "Longer description for MCP tools",
    category: .basicActions,
    parameters: [
        ParameterDescriptor(
            name: "arg",
            type: .string,
            description: "The argument"
        )
    ],
    requiresElement: true  // if it needs a selected element
)
```

2. **Add to the `all` array** in `BuiltInCommands.swift`

3. **Add parsing logic** in `DSLParser.parseCommand()` in `DSL/DSLParser.swift` (return `.failure(ParseFailure("..."))` with a helpful message for malformed arguments)

4. **Add execution logic** in `DSLExecutor.executeCommandCore()` in `DSL/DSLExecutor.swift`

5. **Add a sample line** to the table in `Tests/UniControlCoreTests/CommandRegistryTests.swift` (`testEveryBuiltInVerbIsParseable` fails until you do — this guards against descriptors without parser support)

MCP tools, autocomplete suggestions, and editor syntax highlighting are **automatically generated** from the CommandDescriptor.

### Adding an Extension Command

For application-specific commands (like Excel's `range`, `typeincell`):

1. Create or update an extension in `Sources/UniControlCore/Extensions/`
2. Add `CommandDescriptor` entries to the extension's `commandDescriptors` array
3. Register the extension in `main.swift`: `ExtensionRegistry.shared.register(MyExtension.self)`

See `docs/EXTENSION_SYSTEM.md` for detailed extension development guide.

### Adding a New Element Selector

1. Add selector case to `ElementSelector` enum in `DSL/DSLTypes.swift`
2. Add parsing logic in `DSLParser.parseSelector()` in `DSL/DSLParser.swift`
3. Add execution logic in `DSLExecutor.executeFind()` in `DSL/DSLExecutor.swift`

### Adding a New Action

1. Add action case to `Action` enum in `DSL/DSLTypes.swift`
2. Add parsing logic in `DSLParser.parseCommand()` in `DSL/DSLParser.swift`
3. Add execution logic in `DSLExecutor.executeAction()` in `DSL/DSLExecutor.swift`
4. Implement the action function in `Core/ElementInteraction.swift`

### Adding Features to UniControlApp

**New View**:
1. Create view file in `UniControlApp/Views/`
2. Add to tab picker in `ContentView.swift` if it's a main tab
3. Use shared components from `ViewHelpers.swift` for consistent styling

**New Setting**:
1. Add property to `AppSettings.swift` with UserDefaults key
2. Add UI control in `SettingsView.swift`

**Syntax Highlighting for New Commands**:
1. Update regex in `DSLHighlightRules` in `DSLTextEditor.swift`
2. Autocomplete is auto-generated from CommandRegistry (no manual update needed)

## Example Workflows

### 1. DSL Script Execution (`exampleDSLSimple`)
- Parses and executes text-based automation script
- Demonstrates launching app, finding elements, clicking, waiting
- Location: `Examples/DSLExamples.swift`

### 2. Programmatic DSL (`exampleDSLComplex`)
- Constructs commands programmatically
- Shows more complex multi-step workflow
- Location: `Examples/DSLExamples.swift`

### 3. Direct Control (`exampleControlFlow`)
- Low-level control using Swift functions directly
- Useful for debugging or one-off tasks
- Location: `Examples/DirectControlExample.swift`

### 4. File-based Scripts (`exampleDSLFromFile`)
- Load `.unictl` script from file
- Usage: `./UniControl script.unictl`
- Location: `Examples/DSLExamples.swift`

## Development Workflow

### Documentation Requirements

**All implementation plans must include documentation updates as a final step.** When implementing a feature or refactoring, always check and update:

1. **CLAUDE.md** - Project structure, adding new features sections
2. **docs/EXTENSION_SYSTEM.md** - If extension-related changes
3. **README.md** - User-facing documentation
4. **SKILL.md** - LLM automation guidance (command references)

This ensures documentation stays in sync with the codebase.

## Important Considerations

- **Permissions**: The tool will fail silently or prompt for Accessibility permissions if not already granted. Users must manually grant these in System Settings > Privacy & Security > Accessibility.
- **Timing**: The async launch function includes retry logic with ~10 second timeout for app launch and ~5 second retry for window focus.
- **App Name Matching**: Uses substring matching for app names (e.g., "Excel" matches "Microsoft Excel.app").
- **Modularity**: Functions are organized by responsibility for easy testing and extension.
- **Public APIs**: All module functions are public for use by other parts of the system.

## Future Development Roadmap

As part of the universal operations system, UniControl will evolve to support:

1. **Extended UI Interaction**: Menu navigation, drag and drop, keyboard shortcuts
2. **Advanced Selectors**: XPath-like queries, visual matching, coordinate-based selection
3. **State Verification**: Query element states to verify operation success
4. **Screenshot Integration**: Capture screenshots for vision-based verification (GenericAdapter)
5. **Operation Recording**: Record UI interactions for playback and learning
6. **DSL Enhancements**: Variables, conditionals, loops, functions/macros
7. **Adapter Integration**: JSON/API mode for software-specific adapters
8. **Multi-Application Support**: Handle workflows spanning multiple macOS applications
9. **Testing Framework**: Assertions and test reporting

The current modular implementation provides a clean foundation that these features will build upon.
