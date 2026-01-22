# UniControl

A macOS command-line tool for programmatic control of applications using Accessibility APIs. Part of the Universal Operations system for automating any macOS application.

## Features

- **Application Control**: Launch and manage macOS applications
- **Element Discovery**: Find UI elements by title, role, state, or regex patterns
- **UI Interaction**: Click, type, scroll, and manipulate UI elements
- **DSL Support**: Simple scripting language for automation workflows
- **Vision Fallback**: OCR-based element detection when accessibility fails
- **Multiple Modes**: CLI scripts, interactive REPL, or HTTP/WebSocket server

## Quick Start

### Prerequisites

UniControl requires **Accessibility permissions** to control other applications:

1. Go to **System Settings** → **Privacy & Security** → **Accessibility**
2. Add and enable your terminal app (Terminal, iTerm, Warp, etc.)

### Build

**Using Swift Package Manager:**
```bash
swift build
# Executable at .build/debug/UniControl
```

**Using Xcode:**
```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

### Run a Script

Create a `.unictl` script:

```
# example.unictl
launch Calculator
wait 1
find 7
click
find +
click
find 3
click
find =
click
log Result: 7 + 3 = 10
```

Run it:
```bash
./UniControl example.unictl
```

### Interactive Mode

Start a REPL for entering commands interactively:

```bash
./UniControl --interactive
```

```
unictl> launch Calculator
✓ Success

unictl [Calculator]> find 7
✓ Success

unictl [Calculator] *> click
✓ Success

unictl [Calculator]> exit
```

### Server Mode

Start an HTTP/WebSocket server for remote control:

```bash
./UniControl --serve 8080
```

Execute scripts via HTTP:
```bash
curl -X POST http://localhost:8080/execute \
  -H "Content-Type: application/json" \
  -d '{"script": "launch Calculator\nfind 7\nclick"}'
```

## DSL Commands

| Command | Example | Description |
|---------|---------|-------------|
| `launch` | `launch Excel` | Launch application |
| `find` | `find Save role: AXButton` | Find UI element |
| `click` | `click` | Click current element |
| `doubleclick` | `doubleclick` | Double-click element |
| `rightclick` | `rightclick` | Right-click element |
| `type` | `type Hello World` | Type text |
| `wait` | `wait 2` | Wait seconds |
| `presskey` | `presskey cmd+s` | Press key combo |
| `scroll` | `scroll down` | Scroll element |
| `focus` | `focus` | Focus element |
| `check` | `check` | Check checkbox |
| `uncheck` | `uncheck` | Uncheck checkbox |
| `expand` | `expand` | Expand disclosure |
| `collapse` | `collapse` | Collapse disclosure |
| `selectmenuitem` | `selectmenuitem File > Save` | Select menu item |
| `log` | `log Step complete` | Print message |
| `mode` | `mode strict` | Set error handling |

## Documentation

- [**Running Modes**](docs/RUNNING_MODES.md) - CLI, interactive, and server modes
- [**DSL Reference**](docs/DSL_REFERENCE.md) - Complete command and selector reference
- [**Extension System**](docs/EXTENSION_SYSTEM.md) - Creating custom DSL extensions
- [**Excel Extension**](docs/extensions/EXCEL_EXTENSION.md) - Excel-specific commands

## Architecture

UniControl is designed as a **Control Method** in the Universal Operations architecture:

```
UniControl/
├── main.swift                # Entry point & CLI
├── DSL/                      # Domain Specific Language
│   ├── DSLTypes.swift       # Type definitions
│   ├── DSLParser.swift      # Script parser
│   ├── DSLExecutor.swift    # Command executor
│   └── DSLExtension.swift   # Extension system
├── Core/                     # Core functionality
│   ├── AppLauncher.swift    # App launching
│   ├── ElementFinder.swift  # Element discovery
│   ├── ElementInteraction.swift # UI interaction
│   ├── VisionProcessor.swift # OCR fallback
│   └── ScreenCapture.swift  # Screenshot capture
├── Server/                   # HTTP/WebSocket server
│   ├── UniControlServer.swift
│   ├── ServerTypes.swift
│   └── OutputCapture.swift
├── Extensions/               # App-specific extensions
│   └── ExcelExtension.swift
└── Utils/                    # Utilities
    ├── Permissions.swift
    └── SuggestionEngine.swift
```

## Technical Details

- **Language**: Swift 5.0+
- **Minimum macOS**: 14.0
- **Frameworks**: Foundation, Cocoa, ApplicationServices, Vision
- **Server**: Hummingbird (HTTP/WebSocket)

## License

[License information to be added]
