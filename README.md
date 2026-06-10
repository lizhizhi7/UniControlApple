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

```bash
swift build
# Executable at .build/debug/UniControl
```

Run the unit tests (no Accessibility permission needed):
```bash
swift test
```

### Run a Script

Create a `.unictl` script:

```
# example.unictl
launch Calculator
waitfor 7 role: AXButton timeout: 10
click
waitfor Add role: AXButton
click
waitfor 3 role: AXButton
click
waitfor Equals role: AXButton
click
log Result: 7 + 3 = 10
```

Tip: element titles come from the accessibility tree, which doesn't always match the visible label (Calculator's plus button is titled `Add`). Use `dumptree` to discover what an app actually exposes:

```
usewindow Calculator
dumptree 10
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

### MCP Mode (Model Context Protocol)

UniControl supports [MCP](https://modelcontextprotocol.io/) for integration with AI assistants like Claude Desktop. This enables LLMs to control macOS applications through natural language.

```bash
./UniControl --mcp
```

#### Claude Desktop Integration

Add to `~/.config/claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "unicontrol": {
      "command": "/path/to/UniControl",
      "args": ["--mcp"]
    }
  }
}
```

After configuration, Claude can control your Mac:
- "Open Calculator and compute 7 + 3"
- "Launch Safari and navigate to the search bar"
- "Find the Save button in the current window and click it"

#### Available MCP Tools

| Tool | Description |
|------|-------------|
| `launch_app` | Launch a macOS application |
| `use_window` | Attach to an already-open window (frontmost or by title) |
| `find_element` | Find UI element by title, role, pattern, or state |
| `wait_for` | Poll until an element appears (preferred over fixed waits) |
| `click`, `double_click`, `right_click` | Click actions |
| `type_text` | Type into text fields |
| `set_value` | Set an element's value directly |
| `press_key` | Keyboard shortcuts (e.g., `cmd+c`) |
| `scroll` | Scroll in a direction |
| `wait` | Wait for specified seconds |
| `check`, `uncheck` | Toggle checkboxes |
| `expand`, `collapse` | Toggle disclosure elements |
| `focus` | Set keyboard focus |
| `assert` | Verify a condition (exists/missing/enabled/disabled/value) |
| `get_system_info` | Get macOS version, hostname, etc. |
| `get_windows` | List visible windows |
| `get_apps` | List running applications |
| `get_element` | Get info about current element |
| `dump_tree` | Dump the UI element tree for discovery |
| `execute_script` | Run multi-command DSL script |
| `reset_session` | Clear session context |

#### HTTP MCP Endpoint

The server mode also exposes an MCP endpoint:

```bash
# Start server
./UniControl --serve 8080

# MCP request
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## DSL Commands

| Command | Example | Description |
|---------|---------|-------------|
| `launch` | `launch Excel` | Launch application |
| `usewindow` | `usewindow Untitled` | Attach to an open window (frontmost if no title) |
| `find` | `find Save role: AXButton` | Find UI element |
| `waitfor` | `waitfor Save timeout: 10` | Wait until an element appears |
| `click` | `click` | Click current element |
| `doubleclick` | `doubleclick` | Double-click element |
| `rightclick` | `rightclick` | Right-click element |
| `type` | `type Hello World` | Type text |
| `setvalue` | `setvalue 42` | Set element value directly |
| `wait` | `wait 2` | Wait seconds |
| `presskey` | `presskey cmd+s` | Press key combo |
| `scroll` | `scroll down` | Scroll element |
| `focus` | `focus` | Focus element |
| `check` | `check` | Check checkbox |
| `uncheck` | `uncheck` | Uncheck checkbox |
| `expand` | `expand` | Expand disclosure |
| `collapse` | `collapse` | Collapse disclosure |
| `selectmenuitem` | `selectmenuitem File > Save` | Select menu item |
| `assert` | `assert exists Saved` | Verify a condition |
| `dumptree` | `dumptree 3` | Dump UI element tree |
| `reset` | `reset` | Clear session context |
| `log` | `log Step complete` | Print message |
| `mode` | `mode strict` | Set error handling |

Invalid lines no longer fail silently: scripts with unknown commands or malformed arguments are rejected before execution, with line numbers and "did you mean" suggestions.

## Documentation

- [**Quick Start**](docs/QUICK_START.md) - Get started in 5 minutes
- [**Running Modes**](docs/RUNNING_MODES.md) - CLI, interactive, and server modes
- [**DSL Reference**](docs/DSL_REFERENCE.md) - Complete command and selector reference
- [**Testing Guide**](docs/TESTING_GUIDE.md) - Testing strategies and examples
- [**Accessibility Permissions**](docs/ACCESSIBILITY_PERMISSIONS.md) - Permission setup guide
- [**Troubleshooting**](docs/TROUBLESHOOTING.md) - Common errors and solutions
- [**Extension System**](docs/EXTENSION_SYSTEM.md) - Creating custom DSL extensions
- [**Excel Extension**](docs/extensions/EXCEL_EXTENSION.md) - Excel-specific commands

## Architecture

UniControl is designed as a **Control Method** in the Universal Operations architecture:

```
Sources/
├── UniControlCLI/
│   └── main.swift            # Entry point & CLI
└── UniControlCore/           # Shared library (also used by the GUI app)
    ├── DSL/                  # Domain Specific Language
    │   ├── DSLTypes.swift           # Type definitions
    │   ├── DSLParser.swift          # Script parser with diagnostics
    │   ├── DSLExecutor.swift        # Command executor
    │   ├── BuiltInCommands.swift    # Command descriptors (single source of truth)
    │   ├── CommandRegistry.swift    # Verb/MCP-name registry
    │   └── DSLExtension.swift       # Extension system
    ├── Core/                 # Core functionality
    │   ├── AppLauncher.swift        # App launching & window attachment
    │   ├── ElementFinder.swift      # Element discovery & tree dumping
    │   ├── ElementInteraction.swift # UI interaction
    │   ├── SystemState.swift        # System/app/window queries
    │   ├── VisionProcessor.swift    # OCR fallback
    │   └── ScreenCapture.swift      # Screenshot capture
    ├── Server/               # HTTP/WebSocket server (Hummingbird)
    ├── MCP/                  # Model Context Protocol (stdio + HTTP transports)
    ├── Extensions/           # App-specific extensions (Excel, ...)
    └── Utils/                # Permissions, suggestions, debugging

Tests/
└── UniControlCoreTests/      # Unit tests (pure logic, no permissions needed)

UniControlApp/                # Menu bar GUI app (consumes UniControlCore via SPM)
```

## Technical Details

- **Language**: Swift 5.0+
- **Minimum macOS**: 14.0
- **Frameworks**: Foundation, Cocoa, ApplicationServices, Vision
- **Server**: Hummingbird (HTTP/WebSocket)

## License

[License information to be added]
