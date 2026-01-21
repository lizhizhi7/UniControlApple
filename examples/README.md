# UniControl Example Scripts

This directory contains example `.unictl` scripts demonstrating various automation capabilities.

## Quick Start Examples

### 🧮 Calculator (No Excel Required)

**`example-calculator-simple.unictl`**
- Simple Calculator automation
- Best for quick testing and learning
- No external apps required (uses built-in Calculator)
- Runs in ~10 seconds

```bash
./build/Debug/UniControl examples/example-calculator-simple.unictl
```

**What it does:**
- Launches Calculator
- Performs: 7 + 3 = 10
- Copies result to clipboard
- Performs: 5 × 4 = 20
- Demonstrates keyboard shortcuts

---

## Excel Automation Examples

### 📊 Excel: Developer Tab & Checkbox

**`example-excel-developer-checkbox.unictl`**
- Real-world Excel automation workflow
- Demonstrates ribbon navigation
- Requires Microsoft Excel

```bash
./build/Debug/UniControl examples/example-excel-developer-checkbox.unictl
```

**What it does:**
1. Launches Excel
2. Creates a blank workbook
3. Clicks the Developer tab in the ribbon
4. Inserts a Check Box control

### 🔍 Excel: Element Explorer

**`example-excel-explorer.unictl`**
- Debugging/exploration tool
- Discovers available UI elements
- Shows element suggestions with similarity scores
- Requires Microsoft Excel

```bash
./build/Debug/UniControl examples/example-excel-explorer.unictl
```

**What it does:**
- Intentionally searches for wrong element names
- Shows you what elements ARE available
- Demonstrates the suggestion engine
- Helps you write accurate scripts

**Use this when:**
- You're not sure what element names to use
- Your script can't find an element
- You want to explore what's clickable

---

## Test Scripts

These scripts test specific UniControl features. See `TEST_README.md` for details.

### Basic Tests

**`test-basic-actions.unictl`**
- Tests fundamental actions (click, focus, keyboard)
- Uses Calculator app
- Duration: ~10 seconds

**`test-menu-navigation.unictl`**
- Tests menu hierarchy navigation
- Uses TextEdit app
- Duration: ~15 seconds

**`test-extended-actions.unictl`**
- Tests all Stage 1 actions (doubleClick, pressKey, etc.)
- Uses Calculator and TextEdit
- Duration: ~20 seconds

### Execution Mode Tests

**`test-execution-modes.unictl`**
- Tests strict/continue modes
- Error handling demonstration
- Duration: ~15 seconds

**`test-suggestion-engine.unictl`**
- Tests fuzzy matching and suggestions
- Typo detection demonstration
- Duration: ~15 seconds

### Comprehensive Test

**`test-comprehensive.unictl`**
- Integration test for all 3 stages
- Calculator + TextEdit workflows
- Tests vision fallback (if available)
- Duration: ~45 seconds

---

## Running Examples

### Basic Usage

```bash
# Run with debug output (default)
./build/Debug/UniControl examples/example-calculator-simple.unictl

# Run quietly (minimal output)
./build/Debug/UniControl --quiet examples/example-excel-developer-checkbox.unictl

# Show help
./build/Debug/UniControl --help
```

### Prerequisites

1. **Accessibility Permission** (required for all scripts)
   - Open System Settings → Privacy & Security → Accessibility
   - Add your Terminal app
   - See `ACCESSIBILITY_PERMISSIONS_GUIDE.md` for details

2. **Application Requirements**
   - Calculator examples: Built-in macOS Calculator
   - Excel examples: Microsoft Excel must be installed
   - TextEdit examples: Built-in macOS TextEdit

---

## Script Categories

### 📚 Learning & Getting Started
- `example-calculator-simple.unictl` - Start here!
- `example-excel-developer-checkbox.unictl` - Real automation

### 🔧 Development & Debugging
- `example-excel-explorer.unictl` - Discover UI elements
- `test-suggestion-engine.unictl` - See fuzzy matching

### ✅ Testing & Validation
- `test-basic-actions.unictl` - Verify basic features
- `test-comprehensive.unictl` - Full feature test

---

## Creating Your Own Scripts

### Basic Script Structure

```unictl
# Comments start with #
mode continue  # or strict, or interactive

log Starting my automation

# Launch app and wait
launch Calculator
wait 2

# Find and click elements
find 5
click
wait 0.3

# Use keyboard shortcuts
pressKey Cmd+C

log Automation complete
```

### Available Commands

**Application Control:**
- `launch <app-name>` - Launch application
- `wait <seconds>` - Wait/sleep

**Element Finding:**
- `find <title>` - Find by title
- `find <title> role: <role>` - Find by title and role
- `find role: <role>` - Find by role only

**Actions:**
- `click` - Click current element
- `doubleClick` - Double-click
- `rightClick` - Right-click (context menu)
- `type <text>` - Type text
- `pressKey <combo>` - Keyboard shortcut (Cmd+C, Cmd+Shift+V)
- `focus` - Set focus to element
- `scroll <direction>` - Scroll (up/down/left/right)
- `check` / `uncheck` - Checkbox operations
- `expand` / `collapse` - Tree controls

**Menu Navigation:**
- `openMenu <name>` - Open menu
- `selectMenuItem <path>` - Navigate menu hierarchy (File/Save As)

**Control Flow:**
- `mode <mode>` - Set execution mode (strict/continue/interactive)
- `log <message>` - Print message

### Execution Modes

**`mode strict`** (default)
- Stops on first error
- Best for production automation

**`mode continue`**
- Logs errors but continues
- Shows error summary at end
- Best for development/testing

**`mode interactive`**
- Pauses before each command
- Lets you inspect elements
- Best for debugging

---

## Tips & Best Practices

### 1. Start Simple
Begin with Calculator before moving to Excel:
```bash
./build/Debug/UniControl examples/example-calculator-simple.unictl
```

### 2. Use Continue Mode During Development
```unictl
mode continue  # See all errors, not just the first
```

### 3. Add Waits After Clicks
```unictl
find Submit
click
wait 1  # Give UI time to update
```

### 4. Use the Explorer for Discovery
When you don't know element names:
```bash
./build/Debug/UniControl examples/example-excel-explorer.unictl
```

### 5. Use Roles for Specificity
```unictl
# Less specific
find Developer

# More specific (finds buttons only)
find Developer role: AXButton
```

### 6. Log Your Progress
```unictl
log Step 1: Opening document
find File
log Step 2: Selecting template
find Template
```

### 7. Test with Debug Mode
```bash
# See detailed output
./build/Debug/UniControl examples/my-script.unictl

# Quiet for production
./build/Debug/UniControl --quiet examples/my-script.unictl
```

---

## Troubleshooting

### "Accessibility permission required"
1. Open System Settings → Privacy & Security → Accessibility
2. Add your Terminal app (Terminal, iTerm, Warp, etc.)
3. Toggle ON
4. Restart terminal

See: `ACCESSIBILITY_PERMISSIONS_GUIDE.md`

### "Could not find element"
1. Run with debug mode to see suggestions
2. Use the explorer script to discover correct names
3. Add role specification for accuracy

```bash
# See suggestions
./build/Debug/UniControl examples/example-excel-explorer.unictl
```

### Script runs but nothing happens
1. Check that the app launched successfully
2. Increase wait times after `launch` command
3. Verify element names are correct

### Vision fallback not working
- Vision requires macOS 12.3+
- Screen Recording permission may be needed
- Fallback activates automatically when AX fails

---

## Documentation

- **CLAUDE.md** - Project overview and architecture
- **DEBUG_MODE_GUIDE.md** - Debug/quiet mode details
- **ACCESSIBILITY_PERMISSIONS_GUIDE.md** - Permission setup
- **TEST_README.md** - Testing guide (this file)
- **IMPLEMENTATION_COMPLETE.md** - Implementation details

---

## Script Compatibility

| Script | App Required | Duration | Difficulty |
|--------|--------------|----------|------------|
| `example-calculator-simple.unictl` | Calculator (built-in) | ~10s | ⭐ Easy |
| `example-excel-developer-checkbox.unictl` | Microsoft Excel | ~15s | ⭐⭐ Medium |
| `example-excel-explorer.unictl` | Microsoft Excel | ~20s | ⭐ Easy |
| `test-basic-actions.unictl` | Calculator | ~10s | ⭐ Easy |
| `test-comprehensive.unictl` | Calculator, TextEdit | ~45s | ⭐⭐⭐ Advanced |

---

## Getting Help

```bash
# Show all options
./build/Debug/UniControl --help

# Show version
./build/Debug/UniControl --version
```

For issues or questions, see the main documentation in `CLAUDE.md`.
