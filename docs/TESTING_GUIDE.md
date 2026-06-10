# UniControl Testing Guide

This guide shows you how to test UniControl with different applications and workflows.

## Unit Tests (no permissions needed)

The fast path — parser, command registry, MCP tool generation, and suggestion logic are covered by unit tests that need **no Accessibility permission**:

```bash
swift test          # or: ./run-tests.sh
```

These run in CI on every push. The rest of this guide covers *integration* testing against real applications, which does require permissions.

## Prerequisites for Integration Testing

### 1. Grant Accessibility Permissions

UniControl requires Accessibility permissions to control other applications. Grant the permission **once to your terminal app** and it covers every rebuilt binary — see [ACCESSIBILITY_PERMISSIONS.md](ACCESSIBILITY_PERMISSIONS.md) for why and for MCP/GUI setups.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Add your terminal app (Terminal, iTerm, …) and enable it
3. Restart the terminal completely

### 2. Build UniControl

```bash
swift build
# Executable at .build/debug/UniControl
```

## Testing Methods

### Method 1: Bundled Example Scripts (Easiest)

Run any of the ready-made scripts in `examples/`:

```bash
.build/debug/UniControl examples/test-calculator.unictl
.build/debug/UniControl examples/test-textedit.unictl
# or the shortcuts:
./run-tests.sh calculator
./run-tests.sh textedit
```

### Method 2: Test with Script Files

Create a `.unictl` script file and run it.

**Example 1: Test with TextEdit** (simpler than Excel)

Create `test-textedit.unictl`:
```bash
cat > test-textedit.unictl << 'EOF'
# Test TextEdit automation
log Starting TextEdit test
launch TextEdit
wait 2

log Looking for New Document button
find New Document role: AXButton
click
wait 1

log Test complete!
EOF
```

Run it:
```bash
.build/debug/UniControl test-textedit.unictl
```

**Example 2: Test with Calculator**

Create `test-calculator.unictl`:
```bash
cat > test-calculator.unictl << 'EOF'
# Test Calculator automation
log Launching Calculator
launch Calculator
wait 2

log Finding buttons
find 5 role: AXButton
click
wait 0.5

find Add role: AXButton
click
wait 0.5

find 3 role: AXButton
click
wait 0.5

log Calculation complete!
EOF
```

**Example 3: Test with Safari**

Create `test-safari.unictl`:
```bash
cat > test-safari.unictl << 'EOF'
# Test Safari automation
log Opening Safari
launch Safari
wait 3

log Looking for toolbar buttons
find Bookmarks role: AXButton
click
wait 1

log Test complete!
EOF
```

### Method 3: Interactive Exploration

Use the REPL plus `dumptree` to discover what elements an app exposes — element titles come from the accessibility tree and often differ from the visible label (e.g. Calculator's `+` button is titled `Add`):

```bash
.build/debug/UniControl --interactive
```

```
unictl> usewindow Calculator
unictl [Calculator]> dumptree 10
  AXButton "7"
  AXButton "Add"
  AXButton "Equals"
  ...
unictl [Calculator]> waitfor Add role: AXButton
unictl [Calculator] *> click
```

### Method 4: Unit Tests

Unit tests live in `Tests/UniControlCoreTests/` and run with `swift test`. They cover the parser (including diagnostics), command registry consistency, MCP tool generation, and the suggestion engine. When adding a new DSL command, add a sample line to `CommandRegistryTests.testEveryBuiltInVerbIsParseable` — it fails if a registered verb has no parser support.

## Recommended Test Applications

Here are apps that work well for testing (ordered by complexity):

### ✅ Easy to Test

1. **Calculator** (`/System/Applications/Calculator.app`)
   - Simple UI
   - Clear button labels
   - Good for testing basic clicking

2. **TextEdit** (`/Applications/TextEdit.app`)
   - Text input testing
   - Menu interaction
   - File operations

3. **Notes** (`/System/Applications/Notes.app`)
   - Text editing
   - Button clicking
   - Simple navigation

### ⚠️ Medium Complexity

4. **Safari** (`/Applications/Safari.app`)
   - Toolbar buttons
   - Tab management
   - URL bar interaction

5. **Finder** (`/System/Library/CoreServices/Finder.app`)
   - Window management
   - List/Grid views
   - File operations

### 🔴 Complex (Like Excel)

6. **Excel** (`/Applications/Microsoft Excel.app`)
   - Ribbon interface
   - Complex UI hierarchy
   - Many buttons and controls

## Sample Test Scripts

### Test 1: Basic Click Test (Calculator)

```bash
cat > test-basic.unictl << 'EOF'
launch Calculator
wait 2
find 7 role: AXButton
click
log Clicked 7
EOF
```

### Test 2: Text Input Test (Notes)

```bash
cat > test-text.unictl << 'EOF'
launch Notes
wait 2
log Creating new note
find New Note role: AXButton
click
wait 1
log Test complete - check Notes app for new note
EOF
```

### Test 3: Multi-Step Test (TextEdit)

```bash
cat > test-multistep.unictl << 'EOF'
# Complete TextEdit workflow
launch TextEdit
wait 2

log Step 1: Create new document
find New Document role: AXButton
click
wait 1

log Step 2: Make it bold
find Bold role: AXButton
click
wait 0.5

log Step 3: All steps completed!
EOF
```

## Debugging Tips

### 1. Enable Verbose Logging

When running DSL scripts, verbose mode is enabled by default. To see what's happening:

```swift
let executor = DSLExecutor()
let success = executor.execute(commands, verbose: true)  // Shows each step
```

### 2. Use Element Explorer

Add this to any example to see all available elements:

```swift
let allElements = findElements(in: window)
print("Found \(allElements.count) total elements")

let buttons = findElements(in: window, role: kAXButtonRole as String)
for (i, btn) in buttons.enumerated() {
    printElementInfo(btn)
    print("---")
}
```

### 3. Check Permissions

If nothing works, verify permissions:

```swift
if checkAccessibilityPermission() {
    print("✅ Has accessibility permission")
} else {
    print("❌ No accessibility permission - grant it in System Settings")
}
```

### 4. Add Delays

If elements aren't found, the app might not be ready. Increase wait times:

```
launch Excel
wait 5  # Increase from 2 to 5 seconds
find Developer role: AXButton
```

### 5. Test Element Search

Create a simple finder test:

```swift
launchAppAndGetFocusedWindow(appName: "Calculator") { window in
    guard let win = window else { return }

    // Try to find a button
    if let button = findElement(in: win, title: "5") {
        print("✅ Found button '5'")
        printElementInfo(button)
    } else {
        print("❌ Could not find button '5'")

        // Show what IS available
        let allButtons = findElements(in: win, role: kAXButtonRole as String)
        print("Available buttons:")
        for btn in allButtons {
            let title = getAttribute(btn, attribute: kAXTitleAttribute as CFString)
            print("  - \(title ?? "unknown")")
        }
    }
    exit(0)
}
RunLoop.current.run()
```

## Common Issues

### Issue 1: "App did not launch"
**Solution**: Verify app name matches exactly:
```bash
# Check available apps
ls /Applications/*.app | sed 's|/Applications/||' | sed 's|.app||'
```

### Issue 2: "Could not find element"
**Solution**: Use element explorer to see what's actually available
```swift
let allButtons = findElements(in: window, role: kAXButtonRole as String)
for btn in allButtons {
    printElementInfo(btn)
}
```

### Issue 3: "Failed to get focused window"
**Solution**: Increase retry timeout or launch delay
```swift
// In AppLauncher.swift, increase:
for _ in 0..<40 {  // Was 20, now 40 = ~20 seconds
```

### Issue 4: Build fails
**Solution**:
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/UniControl-*
# Rebuild
swift build
```

## Quick Start Test

Want to test immediately? Use this simple workflow:

1. **Build**:
```bash
swift build
```

2. **Create test script**:
```bash
cat > quick-test.unictl << 'EOF'
launch Calculator
wait 2
find 1 role: AXButton
click
log Test passed!
EOF
```

3. **Update `main.swift`**:
```swift
exampleDSLFromFile()  // Uncomment this line
```

4. **Rebuild and run**:
```bash
swift build
./UniControl quick-test.unictl
```

If Calculator launches and you see "Test passed!", everything is working! 🎉

## Next Steps

Once basic testing works:
1. Try more complex apps (Safari, Notes, TextEdit)
2. Create multi-step workflows
3. Test different element types (text fields, checkboxes, menus)
4. Build custom automation scripts for your specific needs

For help, check the examples in `UniControl/Examples/` directory!
