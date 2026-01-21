# Debug Mode Guide for UniControl

## Quick Start

UniControl now has built-in command-line options for controlling debug output!

### Enable Debug Mode (Default)

Debug mode is **ON by default**. Just run your script normally:

```bash
./build/Debug/UniControl examples/test-basic-actions.unictl
```

Or explicitly enable it:

```bash
./build/Debug/UniControl --debug examples/test-basic-actions.unictl
# or short form:
./build/Debug/UniControl -d examples/test-basic-actions.unictl
```

### Disable Debug Mode (Quiet)

Run in quiet mode for minimal output:

```bash
./build/Debug/UniControl --quiet examples/test-basic-actions.unictl
# or short form:
./build/Debug/UniControl -q examples/test-basic-actions.unictl
```

---

## What You See in Each Mode

### Debug Mode (--debug or default)

When debug mode is enabled, you'll see detailed output:

```
=== DSL Example: Load from File ===

Loading script from: examples/test-basic-actions.unictl

[1/10] Executing: launch("Calculator")
✓ Success

[2/10] Executing: wait(2.0)
✓ Success

[3/10] Executing: find(byTitle("5"))
✓ Success

[4/10] Executing: click
✅ Clicked using AXPress
✓ Success

[5/10] Executing: find(byTitle("NonExistent"))
❌ Error: Could not find element with title: NonExistent

🪟 Window: "Calculator"

📋 Available buttons (showing 5):
  [0] "5" (40% match)
  [1] "Clear" (35% match)
  [2] "Equals" (28% match)
  ...

💡 Suggestion: Did you mean "Clear"?

[6/10] Executing: click
❌ Error: No element currently selected

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Execution Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total commands: 10
✅ Succeeded: 7
❌ Failed: 3

Failed commands:
  [5] find NonExistent
      Error: Element not found
  [6] click
      Error: No element selected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Script executed successfully!
```

**Debug mode shows:**
- ✅ Command-by-command execution progress: `[1/10]`, `[2/10]`, etc.
- ✅ Success/failure indicators for each step
- ✅ Detailed error messages with suggestions
- ✅ Element suggestions when searches fail (with similarity scores)
- ✅ Vision fallback activation messages
- ✅ Click method details (AXPress, AXPick, etc.)
- ✅ Screenshot verification results
- ✅ Error summary at the end

### Quiet Mode (--quiet)

When quiet mode is enabled, you'll only see:

```
=== DSL Example: Load from File ===

Loading script from: examples/test-basic-actions.unictl

Navigating to Developer tab
Inserting checkbox
Done!

✅ Script executed successfully!
```

**Quiet mode shows:**
- ✅ Explicit `log` commands from your script
- ✅ Critical errors (if any)
- ✅ Final success/failure status
- ❌ No command-by-command progress
- ❌ No element suggestions
- ❌ No detailed execution info

---

## Command-Line Options

### All Available Flags

```bash
# Help (shows usage)
./build/Debug/UniControl --help
./build/Debug/UniControl -h

# Version
./build/Debug/UniControl --version
./build/Debug/UniControl -v

# Debug mode (verbose, on by default)
./build/Debug/UniControl --debug script.unictl
./build/Debug/UniControl -d script.unictl

# Quiet mode (minimal output)
./build/Debug/UniControl --quiet script.unictl
./build/Debug/UniControl -q script.unictl
```

### Flag Positioning

Flags can come before or after the script path:

```bash
# Both work:
./build/Debug/UniControl --debug examples/test.unictl
./build/Debug/UniControl examples/test.unictl --debug
```

---

## Use Cases

### When to Use Debug Mode

**Use `--debug` (or default) when:**
- Developing and testing new scripts
- Troubleshooting why a script isn't working
- Learning how UniControl works
- Diagnosing permission issues
- Understanding element search failures
- Verifying vision fallback is working

**Example:**
```bash
./build/Debug/UniControl examples/test-suggestion-engine.unictl
# Shows detailed suggestions when typos are detected
```

### When to Use Quiet Mode

**Use `--quiet` when:**
- Running production automation
- Only want to see your custom log messages
- Script output is being parsed by another tool
- Running in CI/CD pipelines
- You know the script works and don't need details

**Example:**
```bash
./build/Debug/UniControl --quiet examples/excel-automation.unictl
# Only shows your log messages and final status
```

---

## Examples

### Example 1: Debug a Failing Script

```bash
# Script keeps failing - use debug to see why
./build/Debug/UniControl examples/my-script.unictl

# You'll see:
# [5/10] Executing: find(byTitle("Developer"))
# ❌ Error: Could not find element
# 💡 Suggestion: Did you mean "Develop"? (88% match)
```

### Example 2: Test Vision Fallback

```bash
# See vision fallback in action
./build/Debug/UniControl examples/test-comprehensive.unictl

# You'll see:
# 🔍 Trying vision fallback (OCR)...
# ✅ Found via vision: "Submit" (confidence: 87%)
# 🎯 Using vision coordinates: (342, 156)
# 📊 Screenshot similarity: 78%
# ✅ Action verified (UI changed)
```

### Example 3: Production Automation (Quiet)

```bash
# Run daily automation quietly
./build/Debug/UniControl --quiet scripts/daily-report.unictl > report.log

# Only shows:
# Starting daily report generation
# Processing data...
# Report saved to output.xlsx
# ✅ Script executed successfully!
```

### Example 4: Compare Debug vs Quiet

```bash
# Run with debug (verbose)
./build/Debug/UniControl examples/test-basic-actions.unictl

# vs

# Run quietly
./build/Debug/UniControl --quiet examples/test-basic-actions.unictl
```

The quiet version will have ~80% less output!

---

## Interaction with DSL Execution Modes

Debug mode (`--debug` / `--quiet`) is **separate** from DSL execution modes:

### DSL Execution Modes (in your script)
- `mode strict` - Stop on first error
- `mode continue` - Log errors, keep going
- `mode interactive` - Pause and prompt

### CLI Debug Flag
- `--debug` - Show detailed output (default)
- `--quiet` - Show minimal output

**They work together:**

```bash
# Debug mode + Continue mode (default + default)
./build/Debug/UniControl examples/test.unictl
# Shows: Detailed output + Error summary at end

# Quiet mode + Continue mode
./build/Debug/UniControl --quiet examples/test.unictl
# Shows: Only log commands + Final status

# Debug mode + Interactive mode
mode interactive  # in script
./build/Debug/UniControl examples/test.unictl
# Shows: Detailed output + Interactive prompts
```

---

## Performance Impact

### Debug Mode
- **Overhead**: Minimal (~5% slower)
- **Reason**: Printing text to terminal
- **Impact**: Negligible for most scripts

### Quiet Mode
- **Overhead**: None
- **Performance**: Same as debug mode (vision/AX operations dominate)
- **Benefit**: Cleaner output for production

**Note**: The verbose flag only affects **what is printed**, not what UniControl does internally. Both modes run the same operations.

---

## Tips & Tricks

### 1. Redirect Debug Output

Save debug output to a file while seeing progress:

```bash
./build/Debug/UniControl examples/test.unictl 2>&1 | tee debug.log
```

### 2. Filter Debug Output

Show only errors in debug mode:

```bash
./build/Debug/UniControl examples/test.unictl 2>&1 | grep "❌"
```

### 3. Quiet Mode for Scripting

Use quiet mode when calling from other scripts:

```bash
#!/bin/bash
if ./build/Debug/UniControl --quiet automation.unictl; then
    echo "Automation succeeded"
else
    echo "Automation failed"
fi
```

### 4. Debug Specific Stages

Combine with execution modes in your script:

```unictl
# test.unictl
mode continue  # Don't stop on errors

log Starting Stage 1
find Button1
click

log Starting Stage 2
find Button2
click
```

Then run with debug to see which stage fails:
```bash
./build/Debug/UniControl examples/test.unictl
# You'll see which "Starting Stage X" log appears before the error
```

---

## Troubleshooting

### Debug Output Not Showing

**Problem**: Running with default but not seeing debug output

**Solution**: Debug is on by default. If not seeing output:
1. Check if script is actually running: `echo $?` after running
2. Try explicit flag: `./build/Debug/UniControl --debug script.unictl`
3. Check if output is being redirected

### Too Much Output

**Problem**: Debug output is overwhelming

**Solution**: Use quiet mode or filter:
```bash
# Quiet mode
./build/Debug/UniControl --quiet script.unictl

# Or filter debug output
./build/Debug/UniControl script.unictl 2>&1 | grep -E "(log|Error|✅)"
```

### Want More Debug Info

**Problem**: Even debug mode isn't detailed enough

**Solution**: The code has additional debug functions you can call:
1. Use `printElementDebug()` in Swift code for deep element inspection
2. Add more `log` commands to your `.unictl` scripts
3. Check examples/ExcelDebugExample.swift for advanced debugging patterns

---

## Summary

| Mode | Flag | Output Level | Use Case |
|------|------|--------------|----------|
| **Debug** | `--debug`, `-d` (default) | Detailed | Development, troubleshooting |
| **Quiet** | `--quiet`, `-q` | Minimal | Production, clean logs |

**Default behavior**: Debug mode is ON - you get helpful output without asking for it!

**When in doubt**: Use the default (debug mode). It's designed to be helpful without being overwhelming.
