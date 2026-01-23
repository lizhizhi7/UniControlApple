//
//  MCPToolRegistry.swift
//  UniControl
//
//  MCP tool definitions with JSON Schema for macOS UI automation
//

import Foundation

/// Registry of all available MCP tools for UniControl
public struct MCPToolRegistry {

    /// All available tools
    public static let tools: [MCPTool] = [
        // Application control
        launchAppTool,
        // Element finding
        findElementTool,
        // Actions
        clickTool,
        doubleClickTool,
        rightClickTool,
        typeTextTool,
        pressKeyTool,
        scrollTool,
        waitTool,
        // Checkbox/toggle
        checkTool,
        uncheckTool,
        // Expand/collapse
        expandTool,
        collapseTool,
        // Focus
        focusTool,
        // Menu
        selectMenuItemTool,
        openMenuTool,
        // Increment/decrement
        incrementTool,
        decrementTool,
        // State queries
        getSystemInfoTool,
        getWindowsTool,
        getAppsTool,
        getElementTool,
        // Composite tool
        executeScriptTool,
        // Session management
        resetSessionTool,
    ]

    // MARK: - Application Control Tools

    static let launchAppTool = MCPTool(
        name: "launch_app",
        description: "Launch a macOS application by name and wait for it to be ready. Sets the launched app's window as the current context for subsequent commands.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "app_name": .object([
                    "type": .string("string"),
                    "description": .string("Name of the application to launch (e.g., 'Calculator', 'Safari', 'Microsoft Excel')")
                ])
            ]),
            "required": .array([.string("app_name")])
        ])
    )

    // MARK: - Element Finding Tools

    static let findElementTool = MCPTool(
        name: "find_element",
        description: "Find UI element(s) in the current window. The found element becomes the current element for subsequent actions (click, type, etc.). Returns element info including role, title, enabled state, and available actions.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Text/title to search for in the element")
                ]),
                "role": .object([
                    "type": .string("string"),
                    "description": .string("Accessibility role to filter by (e.g., 'AXButton', 'AXTextField', 'AXCheckBox', 'AXStaticText', 'AXMenuItem')")
                ]),
                "index": .object([
                    "type": .string("integer"),
                    "description": .string("Select the nth element (0-based) from multiple matches")
                ]),
                "pattern": .object([
                    "type": .string("string"),
                    "description": .string("Regex pattern to match against element text")
                ]),
                "state": .object([
                    "type": .string("string"),
                    "description": .string("Filter by element state: 'enabled', 'disabled', or 'focused'")
                ])
            ])
        ])
    )

    // MARK: - Action Tools

    static let clickTool = MCPTool(
        name: "click",
        description: "Click the currently selected element. Use find_element first to select an element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let doubleClickTool = MCPTool(
        name: "double_click",
        description: "Double-click the currently selected element. Use find_element first to select an element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let rightClickTool = MCPTool(
        name: "right_click",
        description: "Right-click (context click) the currently selected element. Use find_element first to select an element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let typeTextTool = MCPTool(
        name: "type_text",
        description: "Type text. If an element is selected, types into that element. Otherwise, types to whatever is currently focused using keyboard simulation.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "text": .object([
                    "type": .string("string"),
                    "description": .string("The text to type")
                ])
            ]),
            "required": .array([.string("text")])
        ])
    )

    static let pressKeyTool = MCPTool(
        name: "press_key",
        description: "Press a keyboard shortcut or key combination. Modifiers: cmd, ctrl, alt/option, shift. Examples: 'cmd+c', 'cmd+shift+s', 'return', 'escape', 'tab'.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "combo": .object([
                    "type": .string("string"),
                    "description": .string("Key combination to press (e.g., 'cmd+c', 'cmd+shift+s', 'return', 'escape')")
                ])
            ]),
            "required": .array([.string("combo")])
        ])
    )

    static let scrollTool = MCPTool(
        name: "scroll",
        description: "Scroll in the currently selected element or window.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "direction": .object([
                    "type": .string("string"),
                    "enum": .array([.string("up"), .string("down"), .string("left"), .string("right")]),
                    "description": .string("Direction to scroll")
                ])
            ]),
            "required": .array([.string("direction")])
        ])
    )

    static let waitTool = MCPTool(
        name: "wait",
        description: "Wait for a specified number of seconds. Useful for waiting for UI to update or animations to complete.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "seconds": .object([
                    "type": .string("number"),
                    "description": .string("Number of seconds to wait (supports decimals, e.g., 0.5)")
                ])
            ]),
            "required": .array([.string("seconds")])
        ])
    )

    // MARK: - Checkbox/Toggle Tools

    static let checkTool = MCPTool(
        name: "check",
        description: "Check (enable) a checkbox element. Use find_element first to select a checkbox.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let uncheckTool = MCPTool(
        name: "uncheck",
        description: "Uncheck (disable) a checkbox element. Use find_element first to select a checkbox.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    // MARK: - Expand/Collapse Tools

    static let expandTool = MCPTool(
        name: "expand",
        description: "Expand a collapsible element (disclosure triangle, tree node, etc.). Use find_element first to select the element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let collapseTool = MCPTool(
        name: "collapse",
        description: "Collapse an expanded element (disclosure triangle, tree node, etc.). Use find_element first to select the element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    // MARK: - Focus Tool

    static let focusTool = MCPTool(
        name: "focus",
        description: "Set keyboard focus to the currently selected element. Use find_element first to select the element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    // MARK: - Menu Tools

    static let selectMenuItemTool = MCPTool(
        name: "select_menu_item",
        description: "Select a menu item by path. Use '>' to separate menu levels (e.g., 'File > Save As...').",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Menu path with '>' separators (e.g., 'File > New', 'Edit > Find > Find...')")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    )

    static let openMenuTool = MCPTool(
        name: "open_menu",
        description: "Open a top-level menu by name without selecting an item.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Name of the menu to open (e.g., 'File', 'Edit', 'View')")
                ])
            ]),
            "required": .array([.string("name")])
        ])
    )

    // MARK: - Increment/Decrement Tools

    static let incrementTool = MCPTool(
        name: "increment",
        description: "Increment the value of the currently selected element (for steppers, sliders, etc.). Use find_element first to select the element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let decrementTool = MCPTool(
        name: "decrement",
        description: "Decrement the value of the currently selected element (for steppers, sliders, etc.). Use find_element first to select the element.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    // MARK: - State Query Tools

    static let getSystemInfoTool = MCPTool(
        name: "get_system_info",
        description: "Get system information including macOS version, hostname, architecture, and username.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let getWindowsTool = MCPTool(
        name: "get_windows",
        description: "Get information about all visible windows. Each window includes markers: isFrontmost (system's active window) and isWorking (UniControl's current target window set by launch_app).",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let getAppsTool = MCPTool(
        name: "get_apps",
        description: "Get information about all running applications. Each app includes markers: isActive (system's frontmost app) and isWorking (UniControl's current target app).",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    static let getElementTool = MCPTool(
        name: "get_element",
        description: "Get detailed information about the currently selected element including its role, title, enabled state, position, size, and available actions.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    // MARK: - Composite Tool

    static let executeScriptTool = MCPTool(
        name: "execute_script",
        description: """
            Execute a multi-command UniControl DSL script. This is useful for running complex automation workflows in a single call.

            DSL Commands:
            - launch <app-name>: Launch an application
            - find <title> [role: <role>]: Find UI element
            - click: Click current element
            - doubleclick: Double-click current element
            - rightclick: Right-click current element
            - type <text>: Type text (into element or keyboard simulation)
            - wait <seconds>: Wait for duration
            - presskey <combo>: Press key combination (e.g., cmd+c)
            - scroll <direction>: Scroll (up/down/left/right)
            - check / uncheck: Toggle checkbox
            - expand / collapse: Toggle expandable element
            - focus: Focus element
            - selectmenuitem <path>: Select menu item (e.g., File > Save)
            - openmenu <name>: Open a menu
            - increment / decrement: Change stepper/slider value
            - getsystem: Get system info
            - getwindows: Get all windows (with frontmost/working markers)
            - getapps: Get all apps (with frontmost/working markers)
            - getelement: Get current element info
            - log <message>: Log a message

            Example script:
            ```
            launch Calculator
            wait 1
            find 7
            click
            find +
            click
            find 3
            click
            find =
            click
            ```
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "script": .object([
                    "type": .string("string"),
                    "description": .string("UniControl DSL script to execute (one command per line)")
                ]),
                "mode": .object([
                    "type": .string("string"),
                    "enum": .array([.string("strict"), .string("continue")]),
                    "description": .string("Execution mode: 'strict' stops on first error, 'continue' logs errors and continues. Default: continue")
                ])
            ]),
            "required": .array([.string("script")])
        ])
    )

    // MARK: - Session Management

    static let resetSessionTool = MCPTool(
        name: "reset_session",
        description: "Reset the session context, clearing the current window, element, and any stored state. Use this to start fresh.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    )

    // MARK: - Tool Lookup

    /// Find a tool by name
    public static func tool(named name: String) -> MCPTool? {
        tools.first { $0.name == name }
    }

    /// Check if a tool exists
    public static func hasTools(named name: String) -> Bool {
        tools.contains { $0.name == name }
    }
}
