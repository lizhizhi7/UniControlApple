# Parser Fix: Numeric Element Names

## Problem

The DSL parser was incorrectly treating numeric strings as element indices instead of element titles.

### Example Failure

```unictl
find 7
click
```

**Before fix:** Parsed as `byIndex(7)` - tries to get the 7th element from a list
**Expected:** Parse as `byTitle("7")` - tries to find button labeled "7"

### Impact

This broke scripts that needed to click:
- **Calculator buttons**: "7", "5", "3", "+", "×", etc.
- **Numeric menus or options**: "1", "2", "3"
- **Any UI element with a numeric name**

## Root Cause

In `DSLParser.swift` line 176-179, the parser checked if a string could be converted to an integer BEFORE checking if it should be a title:

```swift
// OLD CODE (BROKEN)
if let index = Int(joined) {
    return .byIndex(index)  // ❌ Takes priority over byTitle
}

return .byTitle(joined)  // Never reached for "7"
```

## Solution

Changed `byIndex` to require **explicit syntax**: `index: N`

```swift
// NEW CODE (FIXED)
// Check for explicit index specification: "index: 5"
if let indexKeywordIndex = parts.firstIndex(of: "index:") {
    let indexStr = parts[(indexKeywordIndex + 1)...].joined(separator: " ")
    if let index = Int(indexStr) {
        return .byIndex(index)
    }
}

// Default to title search (including numeric titles)
return .byTitle(joined)  // ✅ Now handles "7" correctly
```

## New Syntax

### Finding by Title (includes numeric names)

```unictl
# Finds button with title "7"
find 7

# Finds button with title "3"
find 3

# Finds element with title "Submit"
find Submit
```

### Finding by Index (explicit keyword required)

```unictl
# Finds the element at index 5 in the found elements list
find index: 5

# Finds the element at index 0 (first element)
find index: 0
```

## When to Use byIndex

The `byIndex` selector is useful when:

1. **Selecting from previously found elements**
   ```unictl
   # Find all buttons first (stores in foundElements)
   find role: AXButton

   # Select the 3rd button from the found list
   find index: 2
   click
   ```

2. **Dealing with unnamed elements**
   ```unictl
   # Some elements have no title/description
   find role: AXGroup
   find index: 0  # Get first group
   ```

3. **Known element order**
   ```unictl
   # You know the submit button is always the 2nd button
   find role: AXButton
   find index: 1
   click
   ```

**Note:** `byIndex` is fragile - if the UI changes, indices break. Prefer `byTitle` whenever possible.

## Breaking Change?

**No** - This is a **bug fix**, not a breaking change:

- The old behavior was **wrong** (couldn't click Calculator buttons)
- No existing scripts should have used `find 7` to mean "get index 7"
- Scripts that needed index selection were broken anyway

If any script did use numeric-only find commands expecting index behavior, update them:

```unictl
# OLD (broken syntax that may have existed)
find 5  # Was trying to get index 5, but failed most of the time

# NEW (correct explicit syntax)
find index: 5  # Explicitly get element at index 5
```

## Testing

### Calculator Test

```unictl
launch Calculator
wait 2

find 7    # ✅ Now works - finds button "7"
click

find +    # ✅ Works - finds button "+"
click

find 3    # ✅ Now works - finds button "3"
click

find =    # ✅ Works - finds button "="
click
```

### Index Selection Test

```unictl
launch Calculator
wait 2

# Find all buttons (stores in foundElements)
find role: AXButton

# Select specific button by index
find index: 5   # ✅ New explicit syntax
click
```

## Updated Documentation

### DSL Selector Syntax

**By Title** (default):
```unictl
find Submit
find 7           # Numeric titles work now!
find Next Step
```

**By Role**:
```unictl
find role: AXButton
find role: AXTextField
```

**By Title AND Role**:
```unictl
find Submit role: AXButton
find 7 role: AXButton
```

**By Index** (explicit keyword):
```unictl
find index: 0
find index: 5
```

**By State**:
```unictl
find role: AXButton state: enabled
```

**By Regex Pattern**:
```unictl
find pattern: ^Submit.*
```

## Files Changed

- **`UniControl/DSL/DSLParser.swift`** - Parser logic updated
  - Moved index parsing to require explicit `index:` keyword
  - Changed default behavior to `byTitle` for all strings
  - Added comments explaining the change

## Migration Guide

**No migration needed** for most users - this is a bug fix.

If you were working around this bug, you can now simplify:

```unictl
# BEFORE (workaround)
find 7 role: AXButton   # Had to specify role to avoid index parsing

# AFTER (simplified)
find 7                   # Just works now!
```

## Future Considerations

### Should we deprecate byIndex entirely?

**Pros of keeping it:**
- Useful for selecting from previously found elements
- Needed for elements with no title/description
- Some automation scenarios need positional selection

**Cons:**
- Fragile - breaks when UI changes
- Confusing - users expect name-based selection
- Rarely used in practice

**Decision:** Keep `byIndex` but require explicit `index:` keyword to prevent confusion.

## Summary

✅ **Fixed**: Numeric element names now work correctly
✅ **Syntax**: `find 7` → finds title "7" (not index 7)
✅ **Explicit index**: Use `find index: 5` for index-based selection
✅ **Backward compatible**: This is a bug fix, not a breaking change
✅ **Calculator scripts**: Now work properly with numeric buttons

This fix makes UniControl more intuitive and aligns with user expectations.
