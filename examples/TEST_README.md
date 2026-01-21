# UniControl Test Scripts

This directory contains test scripts for verifying the functionality of UniControl's DSL implementation across all three stages.

## Building UniControl

Before running tests, build the project:

```bash
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

The executable will be at: `build/Debug/UniControl`

## Running Tests

### Individual Stage Tests

**Stage 1: Extended Actions**
```bash
./build/Debug/UniControl examples/test-extended-actions.unictl
```
Tests: doubleclick, scroll, pressKey, increment/decrement, focus, check/uncheck, expand/collapse

**Stage 1: Menu Navigation**
```bash
./build/Debug/UniControl examples/test-menu-navigation.unictl
```
Tests: openMenu, selectMenuItem with menu paths (File/Save As)

**Stage 1: Basic Actions** (from original)
```bash
./build/Debug/UniControl examples/test-basic-actions.unictl
```
Tests: Basic click operations with Calculator

**Stage 2: Execution Modes**
```bash
./build/Debug/UniControl examples/test-execution-modes.unictl
```
Tests: strict, continue, and interactive modes with error handling

**Stage 2: Suggestion Engine**
```bash
./build/Debug/UniControl examples/test-suggestion-engine.unictl
```
Tests: Fuzzy matching, similarity scores, element suggestions on failure

### Comprehensive Test

Run all stages together:
```bash
./build/Debug/UniControl examples/test-comprehensive.unictl
```

This executes tests for:
- Stage 1: Extended DSL operations (15 actions)
- Stage 2: Error handling and suggestion engine
- Stage 3: Vision fallback (automatic when AX fails)

## Test Descriptions

### test-basic-actions.unictl
- **Purpose**: Test fundamental actions with Calculator
- **Tests**: Click, focus, keyboard shortcuts
- **Expected**: Calculator performs basic math operations
- **Duration**: ~10 seconds

### test-menu-navigation.unictl
- **Purpose**: Test menu hierarchy navigation
- **Tests**: openMenu, selectMenuItem with TextEdit
- **Expected**: Menus open, commands execute
- **Duration**: ~15 seconds
- **Note**: Tests File menu, Format menu, keyboard shortcuts

### test-extended-actions.unictl
- **Purpose**: Test all Stage 1 new actions
- **Tests**:
  - doubleClick
  - pressKey (keyboard shortcuts)
  - focus
  - type (in TextEdit)
- **Expected**: All actions execute without errors
- **Duration**: ~20 seconds

### test-execution-modes.unictl
- **Purpose**: Test Stage 2 execution modes
- **Tests**:
  - Continue mode: Logs errors, continues execution
  - Strict mode: Stops on first error
- **Expected**:
  - Continue mode shows error summary at end
  - Strict mode stops mid-execution
- **Duration**: ~15 seconds
- **Interactive**: No (tests continue and strict only)

### test-suggestion-engine.unictl
- **Purpose**: Test Stage 2 fuzzy matching and suggestions
- **Tests**:
  - Exact matches (should work)
  - Typos (e.g., "Cientific" → suggests "Scientific")
  - Partial matches
  - Non-existent elements (shows available alternatives)
- **Expected**: Helpful suggestions with similarity scores
- **Duration**: ~15 seconds
- **Output**: Check console for suggestion lists

### test-comprehensive.unictl
- **Purpose**: Integration test for all three stages
- **Tests**:
  - Stage 1: Extended actions with Calculator and TextEdit
  - Stage 2: Error handling, logging, suggestions
  - Stage 3: Vision fallback (automatic when needed)
- **Expected**: Complete test suite with error summary
- **Duration**: ~45 seconds

## Interactive Mode Test

To test interactive mode manually:

```bash
./build/Debug/UniControl examples/test-basic-actions.unictl
```

Then change the first line to:
```
mode interactive
```

This will pause before each command and prompt:
- `[c]` Continue - Execute command
- `[s]` Skip - Skip command
- `[i]` Inspect - Show element tree
- `[q]` Quit - Stop execution

## Expected Outputs

### Successful Execution
```
[1/10] Executing: launch("Calculator")
✓ Success
[2/10] Executing: wait(2.0)
✓ Success
...
```

### Continue Mode with Errors
```
[5/10] Executing: find(byTitle("NonExistent"))
❌ Error: Could not find element with title: NonExistent

📋 Available elements (showing 3):
  [0] "Clear" (45% match)
  [1] "Delete" (38% match)
  [2] "Equals" (22% match)

💡 Suggestion: Did you mean "Clear"?
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Execution Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total commands: 10
✅ Succeeded: 8
❌ Failed: 2

Failed commands:
  [5] find NonExistent
      Error: Could not find element...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Vision Fallback Activation
```
[3/10] Executing: find(byTitle("Submit"))
🔍 Trying vision fallback (OCR)...
✅ Found via vision: "Submit" (confidence: 87%)

[4/10] Executing: click
🎯 Using vision coordinates: (342, 156)
📊 Screenshot similarity: 78%
✅ Action verified (UI changed)
```

## Troubleshooting

### Permission Errors

**Accessibility Permissions**:
1. System Settings → Privacy & Security → Accessibility
2. Add Terminal (or your terminal app)
3. Restart terminal

**Screen Recording Permissions** (for Stage 3):
1. System Settings → Privacy & Security → Screen Recording
2. Add Terminal
3. Required for vision fallback (ScreenCaptureKit)

### Application Issues

**Calculator not found**:
- Calculator should be at `/System/Applications/Calculator.app`
- Try: `launch /System/Applications/Calculator`

**TextEdit not found**:
- Try: `launch /System/Applications/TextEdit`

### Build Issues

**Build failed**:
```bash
# Clean build
xcodebuild clean
xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build
```

## Test Results Checklist

After running tests, verify:

- [ ] Stage 1: All 15 new actions execute without crashes
- [ ] Stage 1: Menu navigation works (File/Save As paths)
- [ ] Stage 2: Continue mode logs errors and shows summary
- [ ] Stage 2: Strict mode stops on first error
- [ ] Stage 2: Suggestion engine shows similar elements
- [ ] Stage 3: Vision fallback activates when AX fails (if macOS 12.3+)
- [ ] Stage 3: Coordinate-based clicks work
- [ ] No compilation errors or warnings

## Creating New Tests

Template for new test scripts:

```
# Test Description
# Purpose: What this test validates

mode continue  # or strict, or interactive

log === Test Name ===

launch AppName
wait 2

# Test steps
find ElementName
click
wait 0.5

# Add assertions
log Expected result achieved

log === Test Complete ===
```

## Performance Notes

- **AX API Path**: ~150ms per operation
- **Vision Fallback**: ~1-3 seconds overhead (OCR processing)
- **Execution Modes**: No performance impact
- **Suggestion Engine**: ~50-100ms for similarity calculation

## Next Steps

1. Run all test scripts and verify outputs
2. Check error summaries for any failures
3. Test vision fallback with non-AX-accessible elements
4. Create app-specific tests (Excel, PowerPoint, etc.)
5. Document any edge cases or limitations discovered
