# UniControl

A macOS command-line tool for programmatic control of applications using Accessibility APIs. Part of the Universal Operations system for automating any macOS application.

## Features

- 🚀 **Launch Applications**: Automatically find and launch apps
- 🎯 **Element Discovery**: Find UI elements by title, role, or attributes
- 🖱️ **UI Interaction**: Click, type, and manipulate UI elements
- 📝 **DSL Support**: Simple scripting language for automation workflows
- 🔄 **Async Operations**: Robust retry logic for app launching and window management
- 🎨 **Flexible Selectors**: Multiple ways to locate UI elements

## Quick Start

### Build

```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

The executable will be located at:
```
/Users/<username>/Library/Developer/Xcode/DerivedData/UniControl-*/Build/Products/Debug/UniControl
```

### Prerequisites

UniControl requires **Accessibility permissions** to control other applications:

1. Go to **System Settings** → **Privacy & Security** → **Accessibility**
2. Add and enable UniControl (or Terminal if running from command line)

## Usage

### 1. Text-based DSL Scripts

Create a `.unictl` script file:

```
# automate-excel.unictl
launch Excel
wait 2

log Opening Developer tab
find Developer role: AXButton
click
wait 1

log Inserting checkbox
find Check Box
click

log Automation complete!
```

Run the script:
```bash
./UniControl automate-excel.unictl
```

### 2. Programmatic DSL

Construct workflows in Swift code:

```swift
let commands: [Command] = [
    .launch(appName: "Excel"),
    .perform(action: .wait(2.0)),
    .find(selector: .byTitleAndRole(title: "Developer", role: "AXButton")),
    .perform(action: .click),
    .find(selector: .byTitle("Check Box")),
    .perform(action: .click)
]

let executor = DSLExecutor()
executor.execute(commands)
```

### 3. Direct Function Calls

Use low-level functions for fine-grained control:

```swift
launchAppAndGetFocusedWindow(appName: "Excel") { window in
    guard let window = window else { return }

    if let button = findElement(in: window, title: "Developer", role: "AXButton") {
        clickElement(button)
    }
}
```

## DSL Reference

### Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| **launch** | `launch <app-name>` | Launch an application by name |
| **find** | `find <title>` | Find element by title |
| | `find <title> role: <role>` | Find element by title and role |
| | `find role: <role>` | Find element by role only |
| **click** | `click` | Click the current element |
| **type** | `type <text>` | Type text into current element |
| **wait** | `wait <seconds>` | Wait for specified duration |
| **log** | `log <message>` | Print message to console |

### Element Roles

Common AX roles you can use:
- `AXButton` - Buttons
- `AXTextField` - Text input fields
- `AXStaticText` - Text labels
- `AXCheckBox` - Checkboxes
- `AXRadioButton` - Radio buttons
- `AXMenuItem` - Menu items
- `AXWindow` - Windows

### Element Selectors

The DSL supports multiple selector types:

```swift
// By title (searches title, description, help, value attributes)
.byTitle("Developer")

// By role (finds all elements of that type)
.byRole("AXButton")

// By title and role (most specific)
.byTitleAndRole(title: "Developer", role: "AXButton")

// By index (from previously found elements)
.byIndex(0)

// All elements
.all
```

## Examples

### Example 1: Simple Button Click

```
launch Safari
wait 2
find Bookmarks role: AXButton
click
```

### Example 2: Form Automation

```
launch Notes
wait 1

find New Note role: AXButton
click
wait 0.5

find role: AXTextArea
type Hello from UniControl!
```

### Example 3: Multi-step Workflow

```
# Complex Excel automation
launch Excel
wait 2

log Step 1: Open Developer tab
find Developer role: AXButton
click
wait 1

log Step 2: Insert controls
find Check Box
click
wait 0.5

find Button
click
wait 0.5

log Workflow complete!
```

## Architecture

UniControl is designed as a **Control Method** in the Universal Operations architecture:

- **Position**: Sits between Software Adapters and Target Applications
- **Purpose**: Provides UI automation when native APIs/CLI are unavailable
- **Scope**: Can control any macOS application with Accessibility support

### Project Structure

```
UniControl/
├── main.swift                      # Entry point
├── DSL/                            # Domain Specific Language
│   ├── DSLTypes.swift             # Type definitions
│   ├── DSLParser.swift            # Script parser
│   └── DSLExecutor.swift          # Command executor
├── Core/                          # Core functionality
│   ├── AppLauncher.swift          # App launching & window mgmt
│   ├── ElementFinder.swift        # Element discovery
│   └── ElementInteraction.swift   # Element interaction
├── Utils/                         # Utilities
│   └── Permissions.swift          # Permission handling
└── Examples/                      # Examples
    ├── DirectControlExample.swift # Direct control
    └── DSLExamples.swift          # DSL usage
```

### Layers

1. **DSL Layer** (`DSL/`): Parser and executor for automation scripts
2. **Core Layer** (`Core/`): Element discovery, interaction, window management
3. **Utils Layer** (`Utils/`): Cross-cutting concerns (permissions, etc.)
4. **Examples Layer** (`Examples/`): Usage demonstrations

## Roadmap

- [ ] Menu navigation support
- [ ] Drag and drop operations
- [ ] Keyboard shortcuts simulation
- [ ] Screenshot capture and verification
- [ ] Recording mode (record user actions to generate scripts)
- [ ] Variables and conditionals in DSL
- [ ] JSON/API mode for adapter integration
- [ ] Multi-application workflows

## Contributing

This is part of the Universal Operations system for construction design automation. While initially focused on CAD/BIM software, UniControl can automate any macOS application.

## License

[License information to be added]

## Technical Details

- **Language**: Swift 5.0
- **Minimum macOS**: 15.2
- **Frameworks**: Foundation, Cocoa, ApplicationServices
- **Architecture**: Single-file command-line tool
