# UniControl DSL - macOS Automation Skill

This document describes how to use the UniControl DSL to automate macOS applications via the Accessibility API.

## Quick Reference

```
launch <app-name>                    # Launch app and get its window
find <title> [role: <AXRole>]        # Find UI element
click                                # Click current element
type <text>                          # Type into current element
wait <seconds>                       # Pause execution
```

## Commands

### Application Control

| Command | Syntax | Description |
|---------|--------|-------------|
| `launch` | `launch <app-name>` | Launch application by name (partial match OK) |

```
launch Safari
launch Microsoft Excel
launch System Settings
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

```
find Save
find role: AXButton
find Submit role: AXButton
find index: 2
find pattern: ^Submit.*
find role: AXTextField state: enabled
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
| `type` | `type <text>` | Type text into current element |
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
wait 1

find 7
click
find +
click
find 5
click
find =
click
```

## Best Practices

1. **Always wait after launch** - Apps need time to fully load
   ```
   launch App
   wait 2
   ```

2. **Be specific with selectors** - Use role when multiple elements have same title
   ```
   find Save role: AXButton    # Better than just "find Save"
   ```

3. **Wait after UI changes** - Give UI time to update after clicks
   ```
   click
   wait 0.5
   find Next Element
   ```

4. **Use continue mode for robustness** - Script continues even if some steps fail
   ```
   mode continue
   ```

5. **Log progress** - Helps with debugging
   ```
   log Starting step 1
   find Button
   click
   log Step 1 complete
   ```

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
