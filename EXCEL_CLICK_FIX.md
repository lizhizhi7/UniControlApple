# Fixing Excel "Blank Workbook" Click Issue

## Problem (RESOLVED ✅)

When trying to click "Blank Workbook" template in Excel, you get error:
```
Failed to click element: -25205
❌ Error: Click failed
```

Error code `-25205` = `kAXErrorCannotComplete` - the element doesn't support the standard press action.

**Update**: Initial fix caused **double-clicking** (two workbooks created). This has been **FIXED** in the latest version.

## Solution

I've added **automatic retry with alternative click methods**. The system now tries multiple approaches:

1. ✅ **AXPress** (standard click)
2. ✅ **AXPick** (for templates, list items, thumbnails)
3. ✅ **AXShowMenu** (for menu items)
4. ✅ **AXConfirm** (for confirmation dialogs)

### What Changed

**File**: `UniControl/Core/ElementInteraction.swift`

**New function**: `clickElementWithRetry()` - automatically tries all click methods

**Updated**: `DSLExecutor` now uses retry logic automatically when standard click fails

## How to Use

### Option 1: Your Code Already Fixed (Automatic)

The DSL executor now automatically retries with alternative methods:

```swift
let commands: [Command] = [
    .launch(appName: "Excel"),
    .perform(action: .wait(3.0)),
    .find(selector: .byTitle("Blank Workbook")),
    .perform(action: .click),  // Will automatically try all methods!
]
```

Just rebuild and it should work!

### Option 2: Use Debug Mode to See What's Happening

Edit `UniControl/main.swift` to use the debug example:

```swift
exampleExcelDebug()  // This will show you what elements exist
```

Or:

```swift
exampleExcelBlankWorkbook()  // This will try to click with debug output
```

## Testing Your Fix

### Step 1: Rebuild

```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

### Step 2: Run Your Updated Code

Your `exampleDSLComplex` should now work automatically.

### Step 3: If Still Failing - Use Debug Mode

```swift
// In main.swift, change to:
exampleExcelDebug()
```

This will show you:
- All elements containing "Blank"
- What actions each element supports
- Try clicking with the correct action

## Common Solutions

### Solution A: Element Found, Wrong Action

If element is found but click fails, it needs a different action:

```swift
// Instead of just finding and clicking:
find Blank Workbook
click

// The system now automatically tries:
// 1. AXPress (standard)
// 2. AXPick (for templates) ← This usually works for Excel templates!
// 3. AXShowMenu
// 4. AXConfirm
```

### Solution B: Element Not Found

If the element isn't found at all:

1. **Check the exact title**:
```bash
# Run debug mode to see actual titles
exampleExcelDebug()
```

2. **Try partial match**:
```swift
find Blank    # Instead of "Blank Workbook"
```

3. **Try different attributes**:
```swift
find Workbook
# or
find New
```

### Solution C: Different Excel Version

Templates might have different names in different Excel versions.

**Debug script to find the right name**:

```swift
// In exampleDSLComplex, before your template click:
.log(message: "Searching for templates..."),
.find(selector: .byRole("AXButton")),  // Find all buttons
// Then manually check output for template names
```

## Updated Files

✅ `UniControl/Core/ElementInteraction.swift` - Added `clickElementWithRetry()`
✅ `UniControl/DSL/DSLExecutor.swift` - Auto-retry on click failure
✅ `UniControl/Utils/ElementDebugger.swift` - Advanced debugging tools
✅ `UniControl/Examples/ExcelDebugExample.swift` - Debug helpers

## Quick Fix Script

If you want to test immediately:

```swift
// In UniControl/main.swift:
exampleExcelBlankWorkbook()  // This will debug and try to click
```

Then rebuild:

```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
./UniControl
```

## Expected Output (Success)

```
=== DSL Example: Complex Workflow ===

[1/9] Executing: log(message: "Starting Excel automation workflow")
📝 Starting Excel automation workflow
✓ Success

[2/9] Executing: launch(appName: "Excel")
✓ Success

[3/9] Executing: perform(action: UniControl.Action.wait(3.0))
✓ Success

[4/9] Executing: log(message: "Clicking Blank Workbook")
📝 Clicking Blank Workbook
✓ Success

[5/9] Executing: find(selector: UniControl.ElementSelector.byTitle("Blank"))
✓ Success

[6/9] Executing: perform(action: UniControl.Action.click)
Failed to click element: -25205
⚠️  AXPress failed: -25205
✅ Clicked using AXPick          ← SUCCESS!
✓ Success

✅ Workflow executed successfully!
```

## Still Not Working?

### Debug Checklist

1. ✅ Excel is launching?
2. ✅ Wait time is long enough? (try `wait 5` instead of `wait 3`)
3. ✅ Template screen is showing?
4. ✅ Element name is correct?

### Get Element Details

Run this to see exact element info:

```swift
// main.swift:
exampleExcelDebug()
```

This shows:
- All elements containing your search term
- Available actions for each
- Suggests which action to use

### Manual Override

If you find the correct action from debug mode, you can use it directly:

```swift
// After finding the element:
if let element = findElement(in: window, title: "Blank") {
    // Try the specific action that works:
    AXUIElementPerformAction(element, "AXPick" as CFString)
}
```

## Summary

✅ **Fixed**: Added automatic retry with 4 different click methods
✅ **No code changes needed**: Your existing DSL commands work automatically
✅ **Debug tools added**: Use `exampleExcelDebug()` to explore
✅ **AXPick action**: Usually works for Excel template thumbnails

Just **rebuild and run** - it should work now! 🎉

If still having issues, run `exampleExcelDebug()` and share the output.

## Double-Click Fix (2026-01-18) ✅

### Issue
The initial implementation caused clicks to be executed **twice**, resulting in two Excel workbooks being created.

### Root Cause
In `UniControl/DSL/DSLExecutor.swift`, the click action handler was calling both:
1. `clickElement()` - tried AXPress (failed with -25205, but might trigger action)
2. `clickElementWithRetry()` - tried all methods including AXPick (succeeded)

This resulted in the element being clicked twice.

### Fix
**File**: `UniControl/DSL/DSLExecutor.swift` (lines 126-134)

**Before**:
```swift
case .click:
    guard let element = context.currentElement else {
        return .failure(error: "No element selected. Use 'find' first.")
    }
    // Try standard click first, then retry with alternative methods
    if clickElement(element) {
        return .success(value: nil)
    }
    // If standard click fails, try alternative methods
    if clickElementWithRetry(element, debug: true) {
        return .success(value: nil)
    }
    return .failure(error: "Click failed - tried all methods")
```

**After**:
```swift
case .click:
    guard let element = context.currentElement else {
        return .failure(error: "No element selected. Use 'find' first.")
    }
    // Use retry logic directly (includes all methods and -25206 handling)
    if clickElementWithRetry(element, debug: true) {
        return .success(value: nil)
    }
    return .failure(error: "Click failed - tried all methods")
```

### Expected Output After Fix
```
[6/15] Executing: perform(action: UniControl.Action.click)
⚠️  AXPress failed: -25205
✅ Clicked using AXPick (element invalidated after click - this is normal)
✓ Success
```

**Result**: Only **one** Excel workbook is created. ✅
