//
//  BuiltInCommands.swift
//  UniControl
//
//  Definitions for all built-in DSL commands.
//  Single source of truth for command metadata, MCP tools, and autocomplete.
//

import Foundation

/// All built-in DSL commands
public enum BuiltInCommands {

    // MARK: - Application Control

    public static let launch = CommandDescriptor(
        verb: "launch",
        mcpName: "launch_app",
        syntax: "launch <app-name>",
        description: "Launch an application by name",
        detailedDescription: "Launch a macOS application by name and wait for it to be ready. Sets the launched app's window as the current context for subsequent commands.",
        category: .appControl,
        parameters: [
            ParameterDescriptor(
                name: "app_name",
                type: .string,
                description: "Name of the application to launch (e.g., 'Calculator', 'Safari', 'Microsoft Excel')"
            )
        ]
    )

    // MARK: - Element Finding

    public static let find = CommandDescriptor(
        verb: "find",
        mcpName: "find_element",
        syntax: "find <selector> [role: <role>]",
        description: "Find a UI element",
        detailedDescription: "Find UI element(s) in the current window. The found element becomes the current element for subsequent actions (click, type, etc.). Returns element info including role, title, enabled state, and available actions.",
        category: .elementFinding,
        parameters: [
            ParameterDescriptor(
                name: "title",
                type: .string,
                description: "Text/title to search for in the element",
                isRequired: false
            ),
            ParameterDescriptor(
                name: "role",
                type: .string,
                description: "Accessibility role to filter by (e.g., 'AXButton', 'AXTextField', 'AXCheckBox', 'AXStaticText', 'AXMenuItem')",
                isRequired: false
            ),
            ParameterDescriptor(
                name: "index",
                type: .integer,
                description: "Select the nth element (0-based) from multiple matches",
                isRequired: false
            ),
            ParameterDescriptor(
                name: "pattern",
                type: .string,
                description: "Regex pattern to match against element text",
                isRequired: false
            ),
            ParameterDescriptor(
                name: "state",
                type: .string,
                description: "Filter by element state: 'enabled', 'disabled', or 'focused'",
                isRequired: false,
                enumValues: ["enabled", "disabled", "focused"]
            )
        ],
        requiresWindow: true
    )

    public static let waitFor = CommandDescriptor(
        verb: "waitfor",
        mcpName: "wait_for",
        syntax: "waitfor <selector> [timeout: <seconds>]",
        description: "Wait until an element appears",
        detailedDescription: "Poll the current window until an element matching the selector appears, or the timeout (default 5s) elapses. On success the element becomes the current element, like find_element. Prefer this over fixed waits — it is faster and more reliable.",
        category: .elementFinding,
        parameters: [
            ParameterDescriptor(
                name: "title",
                type: .string,
                description: "Text/title to search for in the element",
                isRequired: false
            ),
            ParameterDescriptor(
                name: "role",
                type: .string,
                description: "Accessibility role to filter by (e.g., 'AXButton', 'AXTextField')",
                isRequired: false
            ),
            ParameterDescriptor(
                name: "timeout",
                type: .number,
                description: "Maximum seconds to wait (default 5)",
                isRequired: false
            )
        ],
        requiresWindow: true
    )

    public static let useWindow = CommandDescriptor(
        verb: "usewindow",
        mcpName: "use_window",
        syntax: "usewindow [title-substring]",
        description: "Attach to an existing window",
        detailedDescription: "Set the working window without launching anything. With no argument, attaches to the frontmost window. With a title substring, attaches to the first window (any app) whose title contains it (case-insensitive). Use get_windows to list candidates.",
        category: .appControl,
        parameters: [
            ParameterDescriptor(
                name: "title",
                type: .string,
                description: "Substring of the window title to attach to. Omit to use the frontmost window.",
                isRequired: false
            )
        ]
    )

    public static let dumpTree = CommandDescriptor(
        verb: "dumptree",
        mcpName: "dump_tree",
        syntax: "dumptree [depth]",
        description: "Dump the UI element tree",
        detailedDescription: "Render the UI element tree of the current window (or current element, if one is selected) as indented text showing role, title, value, and disabled state. Use this to discover what elements exist before using find_element. Output is capped to stay digestible.",
        category: .stateQueries,
        parameters: [
            ParameterDescriptor(
                name: "depth",
                type: .integer,
                description: "Maximum tree depth to descend (default 4)",
                isRequired: false
            )
        ],
        requiresWindow: true
    )

    public static let screenshot = CommandDescriptor(
        verb: "screenshot",
        mcpName: "screenshot",
        syntax: "screenshot [file-path]",
        description: "Capture the current window",
        detailedDescription: "Capture a screenshot of the current window. Returns the image so you can SEE the window state — use it to verify actions, read custom-rendered UI that the accessibility tree cannot describe, or decide where to click_at. The response includes the window's screen frame so positions in the image can be converted to screen coordinates: screenX = frameX + imageX * frameWidth / imageWidth (same for Y). Requires Screen Recording permission (separate from Accessibility).",
        category: .stateQueries,
        parameters: [
            ParameterDescriptor(
                name: "path",
                type: .string,
                description: "Optional file path to save the PNG to (defaults to a temp file)",
                isRequired: false
            )
        ],
        requiresWindow: true
    )

    // MARK: - Basic Actions

    public static let click = CommandDescriptor.simple(
        verb: "click",
        mcpName: "click",
        description: "Click the current element",
        detailedDescription: "Click the currently selected element. Use find_element first to select an element.",
        category: .basicActions,
        requiresElement: true
    )

    public static let doubleClick = CommandDescriptor.simple(
        verb: "doubleclick",
        mcpName: "double_click",
        description: "Double-click the current element",
        detailedDescription: "Double-click the currently selected element. Use find_element first to select an element.",
        category: .basicActions,
        requiresElement: true
    )

    public static let rightClick = CommandDescriptor.simple(
        verb: "rightclick",
        mcpName: "right_click",
        description: "Right-click the current element",
        detailedDescription: "Right-click (context click) the currently selected element. Use find_element first to select an element.",
        category: .basicActions,
        requiresElement: true
    )

    public static let clickAt = CommandDescriptor(
        verb: "clickat",
        mcpName: "click_at",
        syntax: "clickat <x> <y> [right|double]",
        description: "Click at screen coordinates",
        detailedDescription: "Click at absolute screen coordinates (in points, origin top-left of the main display). Use this as a fallback when an element is not reachable through find_element — derive the coordinates from a screenshot (which reports the window's screen frame) or from element positions returned by find_element/get_element. Take a fresh screenshot first if the UI may have changed.",
        category: .basicActions,
        parameters: [
            ParameterDescriptor(
                name: "x",
                type: .number,
                description: "X screen coordinate in points"
            ),
            ParameterDescriptor(
                name: "y",
                type: .number,
                description: "Y screen coordinate in points"
            ),
            ParameterDescriptor(
                name: "type",
                type: .string,
                description: "Click kind (default: left)",
                isRequired: false,
                enumValues: ["left", "right", "double"]
            )
        ]
    )

    public static let type = CommandDescriptor(
        verb: "type",
        mcpName: "type_text",
        syntax: "type <text>",
        description: "Type text into the current element",
        detailedDescription: "Type text. If an element is selected, types into that element. Otherwise, types to whatever is currently focused using keyboard simulation.",
        category: .basicActions,
        parameters: [
            ParameterDescriptor(
                name: "text",
                type: .string,
                description: "The text to type"
            )
        ]
    )

    public static let setValue = CommandDescriptor(
        verb: "setvalue",
        mcpName: "set_value",
        syntax: "setvalue <value>",
        description: "Set the current element's value",
        detailedDescription: "Set the value attribute of the currently selected element directly (no keyboard simulation). Works on text fields, sliders, and other value-bearing elements. Use find_element first.",
        category: .basicActions,
        parameters: [
            ParameterDescriptor(
                name: "value",
                type: .string,
                description: "The value to set"
            )
        ],
        requiresElement: true
    )

    public static let assertCondition = CommandDescriptor(
        verb: "assert",
        mcpName: "assert",
        syntax: "assert <exists|missing|enabled|disabled|value> [args]",
        description: "Verify a condition",
        detailedDescription: "Verify a condition and fail the command if it does not hold. Conditions: 'exists <selector>' (an element matching the selector exists), 'missing <selector>' (no match exists), 'enabled' / 'disabled' (current element state), 'value <text>' (current element's value equals text). Use after actions to confirm they had the intended effect.",
        category: .stateQueries,
        parameters: [
            ParameterDescriptor(
                name: "condition",
                type: .string,
                description: "Condition expression, e.g. 'exists Save role: AXButton', 'missing Error', 'enabled', 'value 42'"
            )
        ],
        requiresWindow: true
    )

    public static let wait = CommandDescriptor(
        verb: "wait",
        mcpName: "wait",
        syntax: "wait <seconds>",
        description: "Wait for specified duration",
        detailedDescription: "Wait for a specified number of seconds. Useful for waiting for UI to update or animations to complete.",
        category: .basicActions,
        parameters: [
            ParameterDescriptor(
                name: "seconds",
                type: .number,
                description: "Number of seconds to wait (supports decimals, e.g., 0.5)"
            )
        ]
    )

    public static let scroll = CommandDescriptor(
        verb: "scroll",
        mcpName: "scroll",
        syntax: "scroll <up|down|left|right>",
        description: "Scroll in a direction",
        detailedDescription: "Scroll in the currently selected element or window.",
        category: .basicActions,
        parameters: [
            ParameterDescriptor(
                name: "direction",
                type: .string,
                description: "Direction to scroll",
                enumValues: ["up", "down", "left", "right"]
            )
        ]
    )

    public static let pressKey = CommandDescriptor(
        verb: "presskey",
        mcpName: "press_key",
        syntax: "presskey <combo>",
        description: "Press a key combination",
        detailedDescription: "Press a keyboard shortcut or key combination. Modifiers: cmd, ctrl, alt/option, shift. Examples: 'cmd+c', 'cmd+shift+s', 'return', 'escape', 'tab'.",
        category: .basicActions,
        parameters: [
            ParameterDescriptor(
                name: "combo",
                type: .string,
                description: "Key combination to press (e.g., 'cmd+c', 'cmd+shift+s', 'return', 'escape')"
            )
        ]
    )

    // MARK: - Checkbox/Toggle

    public static let check = CommandDescriptor.simple(
        verb: "check",
        mcpName: "check",
        description: "Check a checkbox",
        detailedDescription: "Check (enable) a checkbox element. Use find_element first to select a checkbox.",
        category: .checkboxToggle,
        requiresElement: true
    )

    public static let uncheck = CommandDescriptor.simple(
        verb: "uncheck",
        mcpName: "uncheck",
        description: "Uncheck a checkbox",
        detailedDescription: "Uncheck (disable) a checkbox element. Use find_element first to select a checkbox.",
        category: .checkboxToggle,
        requiresElement: true
    )

    // MARK: - Expand/Collapse

    public static let expand = CommandDescriptor.simple(
        verb: "expand",
        mcpName: "expand",
        description: "Expand a disclosure",
        detailedDescription: "Expand a collapsible element (disclosure triangle, tree node, etc.). Use find_element first to select the element.",
        category: .expandCollapse,
        requiresElement: true
    )

    public static let collapse = CommandDescriptor.simple(
        verb: "collapse",
        mcpName: "collapse",
        description: "Collapse a disclosure",
        detailedDescription: "Collapse an expanded element (disclosure triangle, tree node, etc.). Use find_element first to select the element.",
        category: .expandCollapse,
        requiresElement: true
    )

    // MARK: - Focus

    public static let focus = CommandDescriptor.simple(
        verb: "focus",
        mcpName: "focus",
        description: "Focus the current element",
        detailedDescription: "Set keyboard focus to the currently selected element. Use find_element first to select the element.",
        category: .focus,
        requiresElement: true
    )

    // MARK: - Menu

    public static let selectMenuItem = CommandDescriptor(
        verb: "selectmenuitem",
        mcpName: "select_menu_item",
        syntax: "selectmenuitem <path>",
        description: "Select a menu item by path",
        detailedDescription: "Select a menu item by path. Use '>' to separate menu levels (e.g., 'File > Save As...').",
        category: .menu,
        parameters: [
            ParameterDescriptor(
                name: "path",
                type: .string,
                description: "Menu path with '>' separators (e.g., 'File > New', 'Edit > Find > Find...')"
            )
        ],
        requiresWindow: true
    )

    public static let openMenu = CommandDescriptor(
        verb: "openmenu",
        mcpName: "open_menu",
        syntax: "openmenu <name>",
        description: "Open a menu",
        detailedDescription: "Open a top-level menu by name without selecting an item.",
        category: .menu,
        parameters: [
            ParameterDescriptor(
                name: "name",
                type: .string,
                description: "Name of the menu to open (e.g., 'File', 'Edit', 'View')"
            )
        ],
        requiresWindow: true
    )

    // MARK: - Increment/Decrement

    public static let increment = CommandDescriptor.simple(
        verb: "increment",
        mcpName: "increment",
        description: "Increment a stepper/slider",
        detailedDescription: "Increment the value of the currently selected element (for steppers, sliders, etc.). Use find_element first to select the element.",
        category: .incrementDecrement,
        requiresElement: true
    )

    public static let decrement = CommandDescriptor.simple(
        verb: "decrement",
        mcpName: "decrement",
        description: "Decrement a stepper/slider",
        detailedDescription: "Decrement the value of the currently selected element (for steppers, sliders, etc.). Use find_element first to select the element.",
        category: .incrementDecrement,
        requiresElement: true
    )

    // MARK: - State Queries

    public static let getSystem = CommandDescriptor.simple(
        verb: "getsystem",
        mcpName: "get_system_info",
        description: "Get system info",
        detailedDescription: "Get system information including macOS version, hostname, architecture, and username.",
        category: .stateQueries
    )

    public static let getWindows = CommandDescriptor(
        verb: "getwindows",
        mcpName: "get_windows",
        syntax: "getwindows [active|all]",
        description: "Get window info",
        detailedDescription: "Get information about all visible windows. Each window includes markers: isFrontmost (system's active window) and isWorking (UniControl's current target window set by launch_app).",
        category: .stateQueries,
        aliases: ["getwindow"]
    )

    public static let getApps = CommandDescriptor(
        verb: "getapps",
        mcpName: "get_apps",
        syntax: "getapps [frontmost|all]",
        description: "Get running apps info",
        detailedDescription: "Get information about all running applications. Each app includes markers: isActive (system's frontmost app) and isWorking (UniControl's current target app).",
        category: .stateQueries,
        aliases: ["getapp"]
    )

    public static let getElement = CommandDescriptor.simple(
        verb: "getelement",
        mcpName: "get_element",
        description: "Get current element info",
        detailedDescription: "Get detailed information about the currently selected element including its role, title, enabled state, position, size, and available actions.",
        category: .stateQueries,
        requiresElement: true
    )

    // MARK: - Composite

    public static let executeScript = CommandDescriptor(
        verb: "script",
        mcpName: "execute_script",
        syntax: "script <inline-script>",
        description: "Execute a DSL script",
        detailedDescription: """
            Execute a multi-command UniControl DSL script. This is useful for running complex automation workflows in a single call.

            DSL Commands:
            - launch <app-name>: Launch an application
            - usewindow [title]: Attach to an existing window (frontmost if no title)
            - find <title> [role: <role>]: Find UI element
            - waitfor <selector> [timeout: <sec>]: Wait until an element appears (prefer over fixed waits)
            - click: Click current element
            - doubleclick: Double-click current element
            - rightclick: Right-click current element
            - type <text>: Type text (into element or keyboard simulation)
            - setvalue <value>: Set current element's value directly
            - wait <seconds>: Wait for duration
            - presskey <combo>: Press key combination (e.g., cmd+c)
            - scroll <direction>: Scroll (up/down/left/right)
            - check / uncheck: Toggle checkbox
            - expand / collapse: Toggle expandable element
            - focus: Focus element
            - selectmenuitem <path>: Select menu item (e.g., File > Save)
            - openmenu <name>: Open a menu
            - increment / decrement: Change stepper/slider value
            - assert <exists|missing|enabled|disabled|value> [args]: Verify a condition
            - getsystem: Get system info
            - getwindows: Get all windows (with frontmost/working markers)
            - getapps: Get all apps (with frontmost/working markers)
            - getelement: Get current element info
            - dumptree [depth]: Dump UI element tree for discovery
            - screenshot [path]: Capture current window to PNG
            - clickat <x> <y> [right|double]: Click at screen coordinates
            - reset: Clear session context
            - log <message>: Log a message

            Example script:
            ```
            launch Calculator
            waitfor 7 role: AXButton timeout: 10
            click
            waitfor Add role: AXButton
            click
            waitfor 3 role: AXButton
            click
            waitfor Equals role: AXButton
            click
            assert exists Equals role: AXButton

            Tip: button titles come from the accessibility tree (Calculator's plus
            button is titled "Add", not "+"). Use dump_tree to discover titles.
            ```
            """,
        category: .composite,
        parameters: [
            ParameterDescriptor(
                name: "script",
                type: .string,
                description: "UniControl DSL script to execute (one command per line)"
            ),
            ParameterDescriptor(
                name: "mode",
                type: .string,
                description: "Execution mode: 'strict' stops on first error, 'continue' logs errors and continues. Default: continue",
                isRequired: false,
                enumValues: ["strict", "continue"]
            )
        ]
    )

    // MARK: - Session Management

    public static let resetSession = CommandDescriptor.simple(
        verb: "reset",
        mcpName: "reset_session",
        description: "Reset session context",
        detailedDescription: "Reset the session context, clearing the current window, element, and any stored state. Use this to start fresh.",
        category: .session
    )

    // MARK: - Logging

    public static let log = CommandDescriptor(
        verb: "log",
        mcpName: "log",
        syntax: "log <message>",
        description: "Print a message to console",
        category: .logging,
        parameters: [
            ParameterDescriptor(
                name: "message",
                type: .string,
                description: "Message to log"
            )
        ]
    )

    // MARK: - Execution Mode

    public static let mode = CommandDescriptor(
        verb: "mode",
        mcpName: "mode",
        syntax: "mode <strict|continue|interactive>",
        description: "Set execution mode",
        detailedDescription: "Set the execution mode for error handling: strict (stop on error), continue (log and continue), interactive (prompt on error).",
        category: .mode,
        parameters: [
            ParameterDescriptor(
                name: "mode",
                type: .string,
                description: "Execution mode",
                enumValues: ["strict", "continue", "interactive"]
            )
        ]
    )

    // MARK: - All Commands

    /// All built-in command descriptors
    public static let all: [CommandDescriptor] = [
        // Application Control
        launch,
        useWindow,
        // Element Finding
        find,
        waitFor,
        // Basic Actions
        click,
        doubleClick,
        rightClick,
        clickAt,
        type,
        setValue,
        wait,
        scroll,
        pressKey,
        // Checkbox/Toggle
        check,
        uncheck,
        // Expand/Collapse
        expand,
        collapse,
        // Focus
        focus,
        // Menu
        selectMenuItem,
        openMenu,
        // Increment/Decrement
        increment,
        decrement,
        // State Queries
        getSystem,
        getWindows,
        getApps,
        getElement,
        dumpTree,
        screenshot,
        assertCondition,
        // Composite
        executeScript,
        // Session Management
        resetSession,
        // Logging
        log,
        // Execution Mode
        mode
    ]

    /// Register all built-in commands with the registry
    public static func registerAll() {
        CommandRegistry.shared.registerAll(all)
    }
}
