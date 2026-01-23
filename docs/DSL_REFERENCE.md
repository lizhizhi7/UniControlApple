# UniControl DSL Reference

UniControl provides a domain-specific language (DSL) for automating macOS applications using the Accessibility APIs. Scripts can be written in text files (`.unictl` extension) or constructed programmatically in Swift.

For information on how to run scripts (CLI, interactive mode, server mode), see [Running Modes](RUNNING_MODES.md).

## Script Syntax

### Basic Script Structure

```
# Comments start with # or //
// This is also a comment

# Launch an application
launch Microsoft Excel

# Wait for the application to be ready
wait 2

# Find and interact with UI elements
find Developer role: AXButton
click

log Done!
```

## Command Reference

### Application Control

#### `launch <app-name>`

Launches an application by name and waits for its main window to become available.

```
launch Excel
launch Microsoft Word
launch System Settings
```

- Searches `/Applications`, `/System/Applications`, and `~/Applications`
- Uses substring matching (e.g., "Excel" matches "Microsoft Excel.app")
- Waits up to ~10 seconds for the application window

### Element Finding

#### `find <selector>`

Finds UI elements in the current window and selects the first match.

**By Title:**
```
find Developer
find Save As...
find 7                    # Works for numeric titles (Calculator buttons)
```

**By Role:**
```
find role: AXButton
find type: AXTextField    # "type:" is an alias for "role:"
```

**By Title and Role:**
```
find Developer role: AXButton
find OK type: AXButton
```

**By Regex Pattern:**
```
find pattern: ^Submit.*
find pattern: [Ss]ave
```

**By State:**
```
find role: AXButton state: enabled
find role: AXTextField state: focused
find role: AXButton state: disabled
```

**By Index** (after finding multiple elements):
```
find role: AXButton       # Finds all buttons, selects first
find index: 3             # Select the 4th button (0-indexed)
```

### Click Actions

#### `click`

Performs a single click on the currently selected element.

```
find Submit role: AXButton
click
```

#### `doubleclick`

Performs a double-click on the currently selected element.

```
find Document.txt
doubleclick
```

#### `rightclick`

Performs a right-click (context menu) on the currently selected element.

```
find icon.png
rightclick
```

### Text Input

#### `type <text>`

Types text into the currently selected element (typically a text field).

```
find Search role: AXTextField
click
type Hello World
```

Note: For multi-word text, simply include spaces - no quotes needed in the DSL.

### Navigation & Focus

#### `focus`

Sets focus to the currently selected element.

```
find Name Box role: AXTextField
focus
```

#### `scroll <direction>`

Scrolls the currently selected element in the specified direction.

```
find Content Area
scroll down
scroll up
scroll left
scroll right
```

#### `presskey <combo>`

Simulates pressing a key or key combination.

```
presskey return
presskey escape
presskey tab
presskey cmd+s
presskey cmd+shift+n
presskey ctrl+alt+delete
```

**Supported modifiers:** `cmd`, `ctrl`, `alt`/`option`, `shift`

### Menu Actions

#### `selectmenuitem <path>`

Selects a menu item by its path (menu names separated by `>`).

```
selectmenuitem File > Save
selectmenuitem Edit > Find > Find and Replace
selectmenuitem View > Zoom > Fit to Window
```

#### `openmenu <name>`

Opens a menu bar item by name.

```
openmenu File
openmenu Edit
```

### Control Actions

#### `increment` / `decrement`

Increases or decreases the value of a stepper or slider control.

```
find Quantity
increment
increment
decrement
```

#### `check` / `uncheck`

Checks or unchecks a checkbox element.

```
find Enable notifications role: AXCheckBox
check

find Show hidden files
uncheck
```

#### `expand` / `collapse`

Expands or collapses a disclosure triangle or outline row.

```
find Advanced Settings
expand

find Details
collapse
```

### Flow Control

#### `wait <seconds>`

Pauses execution for the specified number of seconds.

```
wait 2
wait 0.5
```

#### `mode <mode-name>`

Sets the execution mode for error handling.

```
mode strict       # Stop immediately on any error
mode continue     # Log errors and continue (default)
mode interactive  # Prompt user on each command and error
```

### Logging

#### `log <message>`

Prints a message to the console.

```
log Starting automation
log Step 1 complete
log Finished processing all files
```

### State Retrieval

State retrieval commands query system, application, window, and element information. They return structured data that is especially useful in server mode (JSON responses).

#### `getsystem`

Returns system information including OS version, hostname, architecture, and current user.

```
getsystem
```

Output:
```
System: Version 15.2 (Build 24C101) (arm64)
Host: MacBook-Pro.local, User: john
```

JSON response includes: `osVersion`, `osBuild`, `hostname`, `architecture`, `username`, `homeDirectory`

#### `getwindows` / `getwindow`

Returns information about visible windows.

```
getwindows              # Get all visible windows
getwindows all          # Same as above
getwindows active       # Get only the active/focused window
getwindow               # Shorthand for getwindows active
```

Output:
```
Found 3 window(s):
  [0] "Document1.xlsx" - Microsoft Excel
  [1] "Untitled" - TextEdit
  [2] "Finder"  - Finder
```

JSON response includes: `title`, `role`, `subrole`, `position`, `size`, `isMain`, `isMinimized`, `isFullScreen`, `appName`, `appPID`

#### `getapps` / `getapp`

Returns information about running applications.

```
getapps                 # Get all running applications
getapps all             # Same as above
getapps frontmost       # Get only the frontmost application
getapp                  # Shorthand for getapps frontmost
```

Output:
```
Running applications (5):
  Microsoft Excel [active] (PID: 1234)
  Finder (PID: 456)
  Safari [hidden] (PID: 789)
  ...
```

JSON response includes: `name`, `bundleIdentifier`, `pid`, `isActive`, `isHidden`, `launchDate`

#### `getelement`

Returns detailed information about the currently selected element (after using `find`).

```
find Submit role: AXButton
getelement
```

Output:
```
Element: AXButton - "Submit"
  enabled: true, focused: false, actions: AXPress, AXShowMenu
  position: (450, 320), size: 100x30
```

JSON response includes: `role`, `roleDescription`, `title`, `description`, `value`, `enabled`, `focused`, `selected`, `expanded`, `position`, `size`, `actions`, `childrenCount`

### Enhanced Find Results

When using `find` commands, the result now includes rich element information (same as `getelement`). In server mode, the JSON response contains a structured `elementInfo` or `elementInfos` field with all element attributes.

```
find Submit role: AXButton
# Returns ElementInfo with position, size, states, available actions, etc.
```

## Element Selectors

### `byTitle(String)`

Matches elements by their title, description, help text, or value attributes.

```
find Save
find Document1.xlsx
```

### `byRole(String)`

Matches elements by their accessibility role.

Common roles:
- `AXButton` - Buttons
- `AXTextField` - Text input fields
- `AXStaticText` - Labels
- `AXCheckBox` - Checkboxes
- `AXRadioButton` - Radio buttons
- `AXPopUpButton` - Dropdown menus
- `AXSlider` - Sliders
- `AXTable` - Tables
- `AXRow` - Table rows
- `AXCell` - Table cells
- `AXScrollArea` - Scrollable regions
- `AXToolbar` - Toolbars
- `AXMenuBar` - Menu bar
- `AXMenuItem` - Menu items

### `byTitleAndRole(title, role)`

Matches elements by both title and role for more precise selection.

```
find Save role: AXButton        # "Save" button specifically
find Save role: AXMenuItem      # "Save" menu item specifically
```

### `byRegex(pattern)`

Matches elements whose title, description, or value matches a regular expression.

```
find pattern: ^File.*
find pattern: [0-9]+
```

### `byState(role, state)`

Matches elements by role and accessibility state.

Supported states:
- `enabled` - Element is enabled (AXEnabled = true)
- `disabled` - Element is disabled (AXEnabled = false)
- `focused` - Element has keyboard focus

```
find role: AXButton state: enabled
```

### `byIndex(Int)`

Selects a specific element from the last multi-element search result.

```
find role: AXButton       # foundElements now contains all buttons
find index: 2             # Select the 3rd button (0-indexed)
click
```

## Execution Modes

UniControl supports three execution modes that control error handling behavior:

### `strict` Mode

Stops execution immediately when any error occurs.

```
mode strict
find NonexistentElement    # Script stops here if not found
click                      # Never reached
```

### `continue` Mode (Default)

Logs errors and continues executing subsequent commands. Shows a summary at the end.

```
mode continue
find MissingElement        # Logs error, continues
click                      # Fails (no element selected)
log This still runs        # Executes
```

Output includes an error summary:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Execution Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total commands: 5
✅ Succeeded: 3
❌ Failed: 2
...
```

### `interactive` Mode

Prompts the user before each command and on errors.

```
mode interactive
find Element               # Prompts: [c]ontinue, [s]kip, [i]nspect, [q]uit
click                      # User can inspect element tree before clicking
```

Interactive options:
- `c` - Continue (execute this command)
- `s` - Skip (skip this command)
- `i` - Inspect (show element hierarchy)
- `q` - Quit (stop execution)

## Vision Fallback Strategy

When accessibility APIs cannot find an element, UniControl automatically falls back to vision-based detection using OCR.

### How It Works

1. **Accessibility Search First**: UniControl attempts to find elements using macOS Accessibility APIs
2. **Automatic Fallback**: If not found, captures a screenshot of the current window
3. **OCR Detection**: Uses macOS Vision framework to detect text in the screenshot
4. **Fuzzy Matching**: Matches the search text against detected text with configurable threshold
5. **Coordinate-Based Actions**: Click actions use the detected text's screen coordinates

### When Fallback Occurs

Fallback is triggered when:
- Element cannot be found by any accessibility attribute (title, description, help, value)
- The application doesn't properly expose accessibility information
- Custom UI controls don't implement standard accessibility protocols

### Supported Actions via Vision

- `click` - Clicks at the center of detected text
- `doubleclick` - Double-clicks at detected text location
- `rightclick` - Right-clicks at detected text location
- `type` - Clicks to focus, then types text

### Console Output

When vision fallback is used, you'll see:
```
🔍 Trying vision fallback (OCR)...
✅ Found via vision: "Submit" (confidence: 94%)
🎯 Using vision coordinates: (450, 320)
📊 Screenshot similarity: 45%
✅ Action verified (UI changed)
```

### Requirements

- macOS 12.3 or later (for Vision text recognition)
- Screen recording permission may be required for screenshots

## Error Handling and Suggestions

When an element cannot be found, UniControl provides helpful suggestions:

```
❌ Error: Could not find element with title: Develper role: AXButton

💡 Suggestions:
  - Did you mean "Developer"? (found AXButton with similar title)
  - Available buttons: "File", "Edit", "View", "Developer", "Help"
```

The suggestion engine:
- Detects typos using fuzzy string matching
- Lists available elements with the requested role
- Shows similar elements in the window hierarchy

## Example Scripts

### Basic Calculator Automation

```
# calculator.unictl
launch Calculator
wait 1

# Perform calculation: 7 + 5
find 7
click
find +
click
find 5
click
find =
click

log Calculation complete
```

### Excel Workflow

```
# excel-workflow.unictl
launch Excel
wait 3

# Navigate to Developer tab
find Developer role: AXButton
click
wait 1

# Insert a checkbox
find Check Box
click

log Checkbox inserted
```

### Form Filling with Error Tolerance

```
# fill-form.unictl
mode continue

launch MyApp
wait 2

# Fill form fields (continues even if some are missing)
find First Name role: AXTextField
type John

find Last Name role: AXTextField
type Doe

find Email role: AXTextField
type john.doe@example.com

# Submit
find Submit role: AXButton
click

log Form submitted
```

### Interactive Debugging

```
# debug-session.unictl
mode interactive

launch App
wait 2

# Each step will prompt for user confirmation
find Settings
click

find Advanced
expand

log Check element tree before proceeding
find Custom Option
click
```

### State Inspection Script

```
# inspect-state.unictl
# Query system and application state

getsystem
log ---

getapps
log ---

launch Calculator
wait 1

getwindow
log ---

find 7
getelement

log State inspection complete
```

## Programmatic Usage (Swift)

Scripts can also be constructed programmatically:

```swift
import UniControl

let commands: [Command] = [
    .launch(appName: "Excel"),
    .perform(action: .wait(2.0)),
    .find(selector: .byTitleAndRole(title: "Developer", role: "AXButton")),
    .perform(action: .click),
    .log(message: "Clicked Developer tab")
]

let executor = DSLExecutor()
let success = executor.execute(commands, verbose: true)
```

### Accessing Execution Context

```swift
let executor = DSLExecutor()
executor.execute(commands)

// Access context after execution
if let window = executor.context.currentWindow {
    print("Current window available")
}

if let element = executor.context.currentElement {
    print("Element is selected")
}

// Access stored variables
if let value = executor.context.variables["myVar"] as? String {
    print("Variable value: \(value)")
}
```

### State Retrieval Commands

```swift
let commands: [Command] = [
    .getSystem,                           // Get system info
    .launch(appName: "Calculator"),
    .perform(action: .wait(1.0)),
    .getWindows(activeOnly: true),        // Get active window
    .find(selector: .byTitle("7")),
    .getElement,                          // Get element details
    .getApps(frontmostOnly: false)        // Get all running apps
]

let executor = DSLExecutor()
executor.execute(commands)
```

## See Also

- [Running Modes](RUNNING_MODES.md) - CLI, interactive, and server modes
- [Extension System Guide](EXTENSION_SYSTEM.md) - Creating custom DSL extensions
- [Excel Extension](extensions/EXCEL_EXTENSION.md) - Excel-specific commands
