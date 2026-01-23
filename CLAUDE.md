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
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build

# Run the CLI
./build/Debug/UniControl   # or ./build/Release/UniControl
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
UniControl/
├── main.swift                      # Entry point
├── DSL/                            # Domain Specific Language
│   ├── DSLTypes.swift             # Type definitions (Command, Action, Selector, etc.)
│   ├── DSLParser.swift            # Text script parser
│   └── DSLExecutor.swift          # Command executor with context management
├── Core/                          # Core automation functionality
│   ├── AppLauncher.swift          # Application launching and window management
│   ├── ElementFinder.swift        # UI element discovery and search
│   ├── ElementInteraction.swift   # Element interaction (click, type, etc.)
│   └── SystemState.swift          # System/app/window state retrieval
├── Utils/                         # Utility functions
│   └── Permissions.swift          # Accessibility permission handling
└── Examples/                      # Example implementations
    ├── DirectControlExample.swift # Direct function call examples
    └── DSLExamples.swift          # DSL usage examples
```

### UniControlApp (GUI)

```
UniControlApp/
├── UniControlAppApp.swift          # App entry point (@main)
├── AppDelegate.swift               # NSApplicationDelegate for menu bar
├── MenuBarController.swift         # Menu bar popover management
├── Views/
│   ├── ContentView.swift           # Main container with tabs
│   ├── ScriptEditorView.swift      # Script library + editor + execution history
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

#### 1. DSL Layer (`UniControl/DSL/`)

**Purpose**: Provides a declarative domain-specific language for automation workflows.

**Key Components**:
- **DSLTypes.swift**
  - `ElementSelector`: Flexible element selection (byTitle, byRole, byTitleAndRole, byIndex, all)
  - `Action`: Actions to perform (click, type, setValue, wait)
  - `Command`: High-level commands (launch, find, perform, assert, log, getSystem, getWindows, getElement, getApps)
  - `CommandResult`: Result wrapper (success/failure)
  - `ExecutionContext`: Maintains state across commands (window, element, variables)
  - State info structs: `ElementInfo`, `SystemInfo`, `WindowInfo`, `AppInfo` for structured responses

- **DSLParser.swift**
  - Parses text-based `.unictl` scripts
  - Supports comments (`#` and `//`)
  - Flexible selector syntax (`role:`, `type:`)

- **DSLExecutor.swift**
  - Executes parsed commands sequentially
  - Manages execution context
  - Error handling and reporting
  - Verbose logging option

#### 2. Core Layer (`UniControl/Core/`)

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

#### 3. Utils Layer (`UniControl/Utils/`)

**Purpose**: Cross-cutting utility functions.

**Key Components**:
- **Permissions.swift**
  - `checkAccessibilityPermission()`: Check permission status
  - `requestAccessibilityPermission()`: Prompt user for permissions

#### 4. Examples Layer (`UniControl/Examples/`)

**Purpose**: Demonstrate usage patterns and serve as integration tests.

**Key Components**:
- **DirectControlExample.swift**
  - `exampleOld()`: Legacy demonstration
  - `exampleControlFlow()`: Step-by-step Excel automation

- **DSLExamples.swift**
  - `exampleDSLSimple()`: Text-based script parsing
  - `exampleDSLComplex()`: Programmatic command construction
  - `exampleDSLFromFile()`: Load scripts from files

### UniControlApp Architecture

**View Layer** (`Views/`):
- `ContentView` - Tab container (Scripts, Settings) with header showing server status
- `ScriptEditorView` - HSplitView with script library (left) and editor + history (right)
- `DSLTextEditor` - HighlightedTextEditor wrapper with syntax highlighting and autocomplete popup
- `ViewHelpers` - Shared components: `Formatters` (time/duration), `RemoteBadge`, `VersionBadge`, `ScriptNameSheet`

**ViewModel Layer** (`ViewModels/`):
- `AppState` - @Observable class holding settings, server manager, script library, and UI state
- `ServerManager` - Manages HTTP server lifecycle (start/stop/restart) with status enum

**Model Layer** (`Models/`):
- `SavedScript` - Script with name, content, versions array, and execution history
- `SavedScript.ScriptVersion` - Versioned snapshot with content, timestamp, and optional note
- `SavedScript.VersionExecution` - Execution record with session ID, duration, command results
- `AppSettings` - User preferences persisted to UserDefaults

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

# Launch an application
launch <app-name>

# Find UI elements
find <element-title>                    # Find by title
find <title> role: <role-name>         # Find by title and role
find role: <role-name>                 # Find by role only

# Perform actions
click                                   # Click current element
type <text>                            # Type text into current element
wait <seconds>                         # Wait for specified duration

# State retrieval commands
getsystem                              # Get OS version, hostname, architecture, username
getwindows                             # Get all visible windows
getwindows active                      # Get active window only (alias: getwindow)
getapps                                # Get all running applications
getapps frontmost                      # Get frontmost app only (alias: getapp)
getelement                             # Get detailed info about current element

# Logging
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

### Adding a New DSL Command

1. Add command case to `Command` enum in `DSL/DSLTypes.swift`
2. Add parsing logic in `DSLParser.parseCommand()` in `DSL/DSLParser.swift`
3. Add execution logic in `DSLExecutor.executeCommand()` in `DSL/DSLExecutor.swift`
4. Implement the underlying functionality in appropriate Core module

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
2. Add completion entries in `DSLCompletionProvider.swift`

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
