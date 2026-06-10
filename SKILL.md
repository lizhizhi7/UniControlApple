# UniControl DSL - macOS Automation Skill

This document describes how to use the UniControl DSL to automate macOS applications via the Accessibility API.

## Quick Reference

```
launch <app-name>                    # Launch app and get its window
usewindow [title]                    # Attach to an open window (frontmost if no title)
find <title> [role: <AXRole>]        # Find UI element
waitfor <selector> [timeout: <sec>]  # Wait until element appears (preferred over wait)
dumptree [depth]                     # Discover what elements exist
click                                # Click current element
type <text>                          # Type into current element
assert exists <selector>             # Verify an action worked
```

## Commands

### Application Control

| Command | Syntax | Description |
|---------|--------|-------------|
| `launch` | `launch <app-name>` | Launch application by name (partial match OK) |
| `usewindow` | `usewindow [title-substring]` | Attach to an already-open window; frontmost when no title given |

```
launch Safari
launch Microsoft Excel
usewindow                       # control whatever window is frontmost
usewindow Untitled              # control the window titled like "Untitled"
```

### Element Finding

| Command | Syntax | Description |
|---------|--------|-------------|
| `find` | `find <title>` | Find element by title/label |
| `find` | `find role: <AXRole>` | Find element by accessibility role |
| `find` | `find <title> role: <AXRole>` | Find by both title and role |
| `find` | `find index: <n>` | Select nth element from previous search |
| `find` | `find pattern: <regex>` | Find by regex pattern |
| `find` | `find role: <AXRole> state: <state>` | Find by role and state |
| `waitfor` | `waitfor <selector> [timeout: <sec>]` | Poll until element appears (default timeout 5s); selects it like `find` |
| `dumptree` | `dumptree [depth]` | Print the UI element tree (role, title, value) for discovery |
| `screenshot` | `screenshot [path]` | Capture the current window to PNG; reports the window's screen frame for coordinate math (needs Screen Recording permission) |

`find` ranks matches: exact > prefix > contains, with title > description > value. When several elements match, all are kept and reported — use `find index: n` to pick a different one.

```
find Save
find role: AXButton
find Submit role: AXButton
find index: 2
find pattern: ^Submit.*
find role: AXTextField state: enabled
waitfor Save role: AXButton timeout: 10
dumptree 3
```

**Common AX Roles:**
- `AXButton` - Buttons
- `AXTextField` - Text input fields
- `AXStaticText` - Labels
- `AXCheckBox` - Checkboxes
- `AXRadioButton` - Radio buttons
- `AXPopUpButton` - Dropdowns
- `AXMenuItem` - Menu items
- `AXTable` - Tables
- `AXRow` - Table rows
- `AXCell` - Table cells
- `AXScrollArea` - Scrollable areas
- `AXTabGroup` - Tab containers
- `AXToolbar` - Toolbars

**States:** `enabled`, `disabled`, `focused`

### Actions

| Command | Syntax | Description |
|---------|--------|-------------|
| `click` | `click` | Click current element |
| `doubleclick` | `doubleclick` | Double-click current element |
| `rightclick` | `rightclick` | Right-click current element |
| `clickat` | `clickat <x> <y> [right\|double]` | Click at absolute screen coordinates (fallback when elements aren't in the AX tree; get coordinates from `screenshot` or `getelement`) |
| `type` | `type <text>` | Type text into current element |
| `setvalue` | `setvalue <value>` | Set element's value directly (no keyboard simulation) |
| `focus` | `focus` | Focus current element |
| `check` | `check` | Check a checkbox |
| `uncheck` | `uncheck` | Uncheck a checkbox |
| `expand` | `expand` | Expand a disclosure |
| `collapse` | `collapse` | Collapse a disclosure |
| `increment` | `increment` | Increment stepper/slider |
| `decrement` | `decrement` | Decrement stepper/slider |

```
click
type Hello World
check
expand
```

### Scrolling

| Command | Syntax | Description |
|---------|--------|-------------|
| `scroll` | `scroll <direction>` | Scroll up/down/left/right |

```
scroll down
scroll up
```

### Keyboard

| Command | Syntax | Description |
|---------|--------|-------------|
| `presskey` | `presskey <combo>` | Press key combination |

```
presskey cmd+s
presskey cmd+shift+n
presskey escape
presskey return
```

### Menu Interaction

| Command | Syntax | Description |
|---------|--------|-------------|
| `selectmenuitem` | `selectmenuitem <path>` | Select menu item by path |
| `openmenu` | `openmenu <name>` | Open a menu |

```
selectmenuitem File > Save As
selectmenuitem Edit > Find > Find...
openmenu File
```

### Timing

| Command | Syntax | Description |
|---------|--------|-------------|
| `wait` | `wait <seconds>` | Pause for duration |

```
wait 1
wait 0.5
wait 2.5
```

### Verification

| Command | Syntax | Description |
|---------|--------|-------------|
| `assert` | `assert exists <selector>` | Fail unless a matching element exists |
| `assert` | `assert missing <selector>` | Fail if a matching element exists |
| `assert` | `assert enabled` / `assert disabled` | Check current element's enabled state |
| `assert` | `assert value <text>` | Check current element's value equals text |

```
assert exists Saved role: AXStaticText
assert missing Error
assert value 12
```

### Session

| Command | Syntax | Description |
|---------|--------|-------------|
| `reset` | `reset` | Clear window/element context |

### Execution Mode

| Command | Syntax | Description |
|---------|--------|-------------|
| `mode` | `mode strict` | Stop on first error |
| `mode` | `mode continue` | Log errors, continue (default) |
| `mode` | `mode interactive` | Prompt on errors |

### Logging

| Command | Syntax | Description |
|---------|--------|-------------|
| `log` | `log <message>` | Print message to output |

```
log Starting automation
log Step completed
```

### Comments

```
# This is a comment
// This is also a comment
```

## Example Scripts

### Open Safari and Navigate

```
# Open Safari and go to a URL
launch Safari
wait 1
find role: AXTextField
click
type https://example.com
presskey return
wait 2
```

### Fill a Form

```
launch Safari
wait 2

# Fill form fields
find Name role: AXTextField
click
type John Doe

find Email role: AXTextField
click
type john@example.com

find Submit role: AXButton
click
```

### System Settings Navigation

```
launch System Settings
wait 1

find General
click
wait 0.5

find About
click
```

### Excel Automation

```
launch Microsoft Excel
wait 3

# Click on cell A1
find role: AXCell
click
type Hello World

# Navigate with keyboard
presskey tab
type 123

presskey return
type Formula here
```

### Calculator

```
launch Calculator
waitfor 7 role: AXButton timeout: 10
click
waitfor Add role: AXButton
click
waitfor 5 role: AXButton
click
waitfor Equals role: AXButton
click
```

Note: Calculator's operator buttons are titled `Add`/`Equals` in the accessibility tree, not `+`/`=`. When a find fails, run `dumptree` to see the real titles.

## Best Practices

1. **Prefer `waitfor` over fixed waits** - It proceeds as soon as the element exists and only fails after the timeout
   ```
   launch App
   waitfor Save role: AXButton timeout: 10    # better than: wait 2
   ```

2. **Discover before guessing** - Use `dumptree` to see what elements actually exist instead of trying titles blindly
   ```
   usewindow
   dumptree 3
   ```

3. **Be specific with selectors** - Use role when multiple elements have same title
   ```
   find Save role: AXButton    # Better than just "find Save"
   ```

4. **Verify outcomes with `assert`** - Confirm an action worked before moving on
   ```
   click
   assert exists Document Saved
   ```

5. **Attach instead of relaunching** - If the app is already open, `usewindow` avoids launch delays
   ```
   usewindow My Spreadsheet
   ```

6. **Use strict mode for unattended runs** - Stop at the first failure rather than cascading
   ```
   mode strict
   ```

7. **Log progress** - Helps with debugging
   ```
   log Starting step 1
   find Button
   click
   log Step 1 complete
   ```

Note: scripts with unknown commands or malformed arguments are rejected before execution with line numbers and "did you mean" suggestions — fix the reported lines and rerun.

## Error Handling

When an element is not found, UniControl provides suggestions:
- Similar elements by title (fuzzy matching)
- Available elements with the same role
- Vision fallback (OCR) for non-accessible elements

If `find` fails, check:
1. Is the element visible on screen?
2. Is the title/role correct? (Use accessibility inspector)
3. Did you wait long enough for the app to load?
4. Does the app support accessibility?

## Vision Fallback

When Accessibility API cannot find an element, UniControl automatically tries OCR-based detection. This works for:
- Custom-rendered UI elements
- Non-accessible controls
- Text in images

The vision fallback clicks at the detected text's screen coordinates.
