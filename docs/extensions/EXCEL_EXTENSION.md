# Excel Extension

The Excel extension provides specialized commands for automating Microsoft Excel on macOS.

## Overview

This extension adds commands for:
- Navigating to cells and ranges
- Typing text into specific cells
- Reading cell values

## Prerequisites

- Microsoft Excel for Mac installed
- UniControl accessibility permissions granted
- Excel must be launched and have a workbook open

## Command Reference

### `range <cell-reference>`

Navigates to a cell or selects a range in the current workbook.

**Syntax:**
```
range A1
range B5
range A1:C10
range Sheet2!A1
```

**Examples:**
```
# Navigate to cell A1
range A1

# Navigate to cell in column Z
range Z100

# Select a range
range A1:D10
```

**How it works:**
1. Locates the Name Box (cell address field) in Excel's toolbar
2. Clicks the Name Box to focus it
3. Clears existing content and types the cell reference
4. Presses Enter to navigate

**Fallback strategy:**
If the Name Box cannot be found, uses Ctrl+G to open the "Go To" dialog.

### `typeincell <cell-reference> <text>`

Types text into a specific cell.

**Syntax:**
```
typeincell A1 Hello World
typeincell B2 "Quoted text"
typeincell C3 123.45
```

**Examples:**
```
# Type a simple value
typeincell A1 Hello

# Type multi-word text
typeincell B2 This is a longer sentence

# Type with quotes (quotes are stripped)
typeincell C3 "Product Name"

# Type a number
typeincell D4 42
```

**How it works:**
1. Executes `range` to navigate to the specified cell
2. Types the text using keyboard simulation
3. Presses Enter to confirm the cell entry

### `getcell <cell-reference> [as <variable-name>]`

Reads the value of a cell, optionally storing it in a variable.

**Syntax:**
```
getcell A1
getcell B2 as myValue
```

**Examples:**
```
# Read and display cell value
getcell A1

# Read and store in a variable
getcell B2 as total
log The total is stored in $total

# Read multiple cells
getcell A1 as firstName
getcell A2 as lastName
```

**How it works:**
1. Executes `range` to navigate to the specified cell
2. Attempts to read the value from Excel's Formula Bar
3. If Formula Bar is not accessible, uses Cmd+C to copy the cell value
4. Stores the value in the specified variable (if provided)

**Output:**
```
📊 Reading value from A1
✅ Cell A1 = "Hello World"
📝 Stored in variable: $myValue
```

## Implementation Notes

### Name Box Detection

The extension identifies the Name Box by:
1. Finding all `AXTextField` elements in the window
2. Checking if the field's value looks like a cell reference (e.g., "A1", "B2:C10")
3. Checking the field's description for "name box" or "cell"

### Formula Bar Detection

The Formula Bar is located by:
1. Finding all `AXTextField` elements
2. Checking descriptions for "formula"
3. Checking identifiers for "formula"

### Keyboard Input

Text is typed using CGEvent keyboard simulation, which:
- Supports all alphanumeric characters
- Handles shift-modified characters (uppercase, symbols)
- Includes small delays between keystrokes for reliability

### Clipboard Fallback

When reading cell values, if the Formula Bar is inaccessible:
1. The cell value is copied using Cmd+C
2. The value is read from the system pasteboard
3. This approach works reliably but modifies the clipboard

## Example Workflows

### Create a Simple Spreadsheet

```
# create-spreadsheet.unictl
launch Excel
wait 3

# Add headers
typeincell A1 Name
typeincell B1 Age
typeincell C1 City

# Add data
typeincell A2 John
typeincell B2 30
typeincell C2 New York

typeincell A3 Jane
typeincell B3 25
typeincell C3 Los Angeles

log Spreadsheet created
```

### Read and Process Data

```
# process-data.unictl
launch Excel
wait 3

# Read values from existing spreadsheet
getcell A1 as name
getcell B1 as value

log Processing data for: $name

# Navigate to result cell
range C1
type Processed
```

### Batch Data Entry

```
# batch-entry.unictl
mode continue

launch Excel
wait 3

# Enter multiple values (continues even if some fail)
typeincell A1 Item 1
typeincell A2 Item 2
typeincell A3 Item 3
typeincell A4 Item 4
typeincell A5 Item 5

# Add values column
typeincell B1 100
typeincell B2 200
typeincell B3 300
typeincell B4 400
typeincell B5 500

log Batch entry complete
```

### Working with Formulas

```
# formulas.unictl
launch Excel
wait 3

# Enter values
typeincell A1 10
typeincell A2 20
typeincell A3 30

# Enter a SUM formula
range A4
type =SUM(A1:A3)
presskey return

# Read the result
wait 0.5
getcell A4 as total
log The sum is: $total
```

## Troubleshooting

### "No active window" Error

**Problem:** Command fails with "No active window. Launch Excel first."

**Solution:** Ensure the script includes a `launch Excel` command and sufficient `wait` time:
```
launch Excel
wait 3    # Give Excel time to fully load
range A1
```

### "Could not navigate to cell" Error

**Problem:** The `range` command fails to navigate.

**Possible causes:**
1. Excel window is not focused
2. A dialog box is open
3. Excel is in edit mode (cell is being edited)

**Solutions:**
```
# Ensure focus is on Excel
launch Excel
wait 2

# Press Escape to exit any edit mode
presskey escape
wait 0.5

# Then navigate
range A1
```

### "Could not find Name Box" Error

**Problem:** The extension cannot locate the Name Box element.

**Possible causes:**
1. Excel's toolbar is collapsed or customized
2. Full-screen mode is active
3. Another window or sheet is active

**Solutions:**
- Ensure Excel is in normal window mode (not full-screen)
- Check that the standard toolbar is visible
- Try the Ctrl+G fallback manually to verify it works

### Cell Values Not Reading Correctly

**Problem:** `getcell` returns unexpected values or empty strings.

**Possible causes:**
1. Cell contains a formula (showing result vs. formula)
2. Cell has special formatting
3. Clipboard permission not granted

**Solutions:**
- The Formula Bar shows the actual formula if that's what you need
- Grant clipboard access in System Settings > Privacy & Security
- Ensure no other application is modifying the clipboard

### Keyboard Input Missing Characters

**Problem:** Typed text is incomplete or has wrong characters.

**Possible causes:**
1. Keyboard layout is not US English
2. Modifier keys are stuck
3. Another application is intercepting keystrokes

**Solutions:**
- Ensure US keyboard layout is active during automation
- Add small delays between operations:
```
range A1
wait 0.3
type Hello
wait 0.2
presskey return
```

## Limitations

1. **Single Workbook**: Commands operate on the active workbook only
2. **Keyboard Layout**: Assumes US English keyboard layout
3. **No Formula Parsing**: Cannot evaluate or modify formulas programmatically
4. **Clipboard Usage**: `getcell` may modify the system clipboard
5. **Timing Sensitive**: Excel operations may require additional waits on slower systems

## See Also

- [DSL Reference](../DSL_REFERENCE.md) - Built-in DSL commands
- [Extension System](../EXTENSION_SYSTEM.md) - Creating custom extensions
