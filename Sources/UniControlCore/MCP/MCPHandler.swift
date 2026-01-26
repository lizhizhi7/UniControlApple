//
//  MCPHandler.swift
//  UniControl
//
//  Core MCP message handler - routes JSON-RPC requests to appropriate handlers
//

import Foundation

/// Handler for MCP protocol messages
public class MCPHandler {
    /// Persistent executor for this session (maintains context across tool calls)
    private let executor: DSLExecutor

    /// Whether the session has been initialized
    private var initialized: Bool = false

    /// Client info from initialize
    private var clientInfo: MCPClientInfo?

    /// JSON encoder for responses
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    /// JSON decoder for requests
    private let decoder = JSONDecoder()

    public init() {
        self.executor = DSLExecutor()
    }

    // MARK: - Message Handling

    /// Handle an incoming JSON-RPC message and return a response (if any)
    /// - Parameter data: Raw JSON data
    /// - Returns: Response data, or nil for notifications
    public func handleMessage(_ data: Data) -> Data? {
        // Try to parse as JSON-RPC request
        guard let request = try? decoder.decode(JSONRPCRequest.self, from: data) else {
            // Parse error
            let response = JSONRPCResponse(id: nil, error: .parseError)
            return try? encoder.encode(response)
        }

        // Check for valid JSON-RPC version
        guard request.jsonrpc == "2.0" else {
            let response = JSONRPCResponse(id: request.id, error: .invalidRequest)
            return try? encoder.encode(response)
        }

        // Handle notification (no id means no response expected)
        if request.id == nil {
            handleNotification(request)
            return nil
        }

        // Handle request and return response
        let response = handleRequest(request)
        return try? encoder.encode(response)
    }

    /// Handle a JSON-RPC request (expects response)
    private func handleRequest(_ request: JSONRPCRequest) -> JSONRPCResponse {
        switch request.method {
        case "initialize":
            return handleInitialize(request)
        case "tools/list":
            return handleToolsList(request)
        case "tools/call":
            return handleToolsCall(request)
        case "ping":
            return handlePing(request)
        default:
            return JSONRPCResponse(id: request.id, error: .methodNotFound(request.method))
        }
    }

    /// Handle a JSON-RPC notification (no response)
    private func handleNotification(_ request: JSONRPCRequest) {
        switch request.method {
        case "initialized":
            // Client acknowledges initialization - session is now fully ready
            break
        case "notifications/cancelled":
            // Request cancellation - we don't support async operations yet
            break
        default:
            // Unknown notification - ignore
            break
        }
    }

    // MARK: - MCP Method Handlers

    /// Handle initialize request
    private func handleInitialize(_ request: JSONRPCRequest) -> JSONRPCResponse {
        // Parse params
        if let params = request.params?.objectValue {
            if let clientInfoValue = params["clientInfo"],
               let clientInfoData = try? encoder.encode(clientInfoValue),
               let info = try? decoder.decode(MCPClientInfo.self, from: clientInfoData) {
                self.clientInfo = info
            }
        }

        initialized = true

        let result = MCPInitializeResult(
            protocolVersion: MCP_PROTOCOL_VERSION,
            capabilities: .toolsOnly,
            serverInfo: MCPServerInfo(name: "UniControl", version: "1.0.0"),
            instructions: "UniControl provides macOS UI automation via the Accessibility API. Use launch_app to start an application, find_element to locate UI elements, and action tools (click, type_text, etc.) to interact with them. The session maintains context - found elements persist for subsequent actions."
        )

        guard let resultValue = JSONValue.from(result) else {
            return JSONRPCResponse(id: request.id, error: .internalError("Failed to encode result"))
        }

        return JSONRPCResponse(id: request.id, result: resultValue)
    }

    /// Handle ping request
    private func handlePing(_ request: JSONRPCRequest) -> JSONRPCResponse {
        return JSONRPCResponse(id: request.id, result: .object([:]))
    }

    /// Handle tools/list request
    private func handleToolsList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let result = MCPToolsListResult(tools: MCPToolRegistry.tools)

        guard let resultValue = JSONValue.from(result) else {
            return JSONRPCResponse(id: request.id, error: .internalError("Failed to encode tools list"))
        }

        return JSONRPCResponse(id: request.id, result: resultValue)
    }

    /// Handle tools/call request
    private func handleToolsCall(_ request: JSONRPCRequest) -> JSONRPCResponse {
        // Parse tool call params
        guard let params = request.params?.objectValue,
              let toolName = params["name"]?.stringValue else {
            return JSONRPCResponse(id: request.id, error: .invalidParams("Missing tool name"))
        }

        let arguments = params["arguments"]?.objectValue ?? [:]

        // Execute the tool
        let result = executeTool(name: toolName, arguments: arguments)

        guard let resultValue = JSONValue.from(result) else {
            return JSONRPCResponse(id: request.id, error: .internalError("Failed to encode tool result"))
        }

        return JSONRPCResponse(id: request.id, result: resultValue)
    }

    // MARK: - Tool Execution

    /// Execute a tool and return the result
    private func executeTool(name: String, arguments: [String: JSONValue]) -> MCPToolCallResult {
        switch name {
        // Application control
        case "launch_app":
            return executeLaunchApp(arguments)

        // Element finding
        case "find_element":
            return executeFindElement(arguments)

        // Actions
        case "click":
            return executeSimpleAction(.click)
        case "double_click":
            return executeSimpleAction(.doubleClick)
        case "right_click":
            return executeSimpleAction(.rightClick)
        case "type_text":
            return executeTypeText(arguments)
        case "press_key":
            return executePressKey(arguments)
        case "scroll":
            return executeScroll(arguments)
        case "wait":
            return executeWait(arguments)

        // Checkbox/toggle
        case "check":
            return executeSimpleAction(.check)
        case "uncheck":
            return executeSimpleAction(.uncheck)

        // Expand/collapse
        case "expand":
            return executeSimpleAction(.expand)
        case "collapse":
            return executeSimpleAction(.collapse)

        // Focus
        case "focus":
            return executeSimpleAction(.focus)

        // Menu
        case "select_menu_item":
            return executeSelectMenuItem(arguments)
        case "open_menu":
            return executeOpenMenu(arguments)

        // Increment/decrement
        case "increment":
            return executeSimpleAction(.increment)
        case "decrement":
            return executeSimpleAction(.decrement)

        // State queries
        case "get_system_info":
            return executeGetSystemInfo()
        case "get_windows":
            return executeGetWindows(arguments)
        case "get_apps":
            return executeGetApps(arguments)
        case "get_element":
            return executeGetElement()

        // Composite
        case "execute_script":
            return executeScript(arguments)

        // Session management
        case "reset_session":
            return executeResetSession()

        default:
            return .error("Unknown tool: \(name)")
        }
    }

    // MARK: - Tool Implementations

    private func executeLaunchApp(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let appName = args["app_name"]?.stringValue else {
            return .error("Missing required parameter: app_name")
        }

        let command = Command.launch(appName: appName)
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Launched \(appName) successfully. Window is now ready for interaction.")
        case .failure(let error):
            return .error("Failed to launch \(appName): \(error)")
        }
    }

    private func executeFindElement(_ args: [String: JSONValue]) -> MCPToolCallResult {
        let selector: ElementSelector

        // Determine selector type based on provided arguments
        if let pattern = args["pattern"]?.stringValue {
            selector = .byRegex(pattern: pattern)
        } else if let state = args["state"]?.stringValue, let role = args["role"]?.stringValue {
            selector = .byState(role: role, state: state)
        } else if let index = args["index"]?.intValue {
            selector = .byIndex(index)
        } else if let title = args["title"]?.stringValue, let role = args["role"]?.stringValue {
            selector = .byTitleAndRole(title: title, role: role)
        } else if let title = args["title"]?.stringValue {
            selector = .byTitle(title)
        } else if let role = args["role"]?.stringValue {
            selector = .byRole(role)
        } else {
            // No specific selector - find all elements (for exploration)
            selector = .all
        }

        let command = Command.find(selector: selector)
        let result = executeCommand(command)

        switch result {
        case .success(let value):
            // Format element info for response
            if let elementInfo = value as? ElementInfo {
                return .json(elementInfo)
            } else if let elementInfos = value as? [ElementInfo] {
                return .json(elementInfos)
            } else {
                return .text("Element found and selected")
            }
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeSimpleAction(_ action: Action) -> MCPToolCallResult {
        let command = Command.perform(action: action)
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Action completed successfully")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeTypeText(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let text = args["text"]?.stringValue else {
            return .error("Missing required parameter: text")
        }

        let command = Command.perform(action: .type(text))
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Typed text successfully")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executePressKey(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let combo = args["combo"]?.stringValue else {
            return .error("Missing required parameter: combo")
        }

        let command = Command.perform(action: .pressKey(combo: combo))
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Key combination pressed successfully")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeScroll(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let direction = args["direction"]?.stringValue else {
            return .error("Missing required parameter: direction")
        }

        let command = Command.perform(action: .scroll(direction: direction))
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Scrolled \(direction) successfully")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeWait(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let seconds = args["seconds"]?.doubleValue else {
            return .error("Missing required parameter: seconds")
        }

        let command = Command.perform(action: .wait(seconds))
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Waited \(seconds) seconds")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeSelectMenuItem(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let path = args["path"]?.stringValue else {
            return .error("Missing required parameter: path")
        }

        let command = Command.perform(action: .selectMenuItem(path: path))
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Menu item selected: \(path)")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeOpenMenu(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let name = args["name"]?.stringValue else {
            return .error("Missing required parameter: name")
        }

        let command = Command.perform(action: .openMenu(name: name))
        let result = executeCommand(command)

        switch result {
        case .success:
            return .text("Menu opened: \(name)")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeGetSystemInfo() -> MCPToolCallResult {
        let command = Command.getSystem
        let result = executeCommand(command)

        switch result {
        case .success(let value):
            if let info = value as? SystemInfo {
                return .json(info)
            }
            return .text("System info retrieved")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeGetWindows(_ args: [String: JSONValue]) -> MCPToolCallResult {
        let command = Command.getWindows
        let result = executeCommand(command)

        switch result {
        case .success(let value):
            if let windows = value as? [WindowInfo] {
                return .json(windows)
            }
            return .text("Windows info retrieved")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeGetApps(_ args: [String: JSONValue]) -> MCPToolCallResult {
        let command = Command.getApps
        let result = executeCommand(command)

        switch result {
        case .success(let value):
            if let apps = value as? [AppInfo] {
                return .json(apps)
            }
            return .text("Apps info retrieved")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeGetElement() -> MCPToolCallResult {
        let command = Command.getElement
        let result = executeCommand(command)

        switch result {
        case .success(let value):
            if let info = value as? ElementInfo {
                return .json(info)
            }
            return .text("Element info retrieved")
        case .failure(let error):
            return .error(error)
        }
    }

    private func executeScript(_ args: [String: JSONValue]) -> MCPToolCallResult {
        guard let script = args["script"]?.stringValue else {
            return .error("Missing required parameter: script")
        }

        let mode = args["mode"]?.stringValue

        // Set execution mode
        if let mode = mode {
            switch mode.lowercased() {
            case "strict":
                executor.context.mode = .strict
            default:
                executor.context.mode = .continue
            }
        }

        // Parse and execute script
        let commands = DSLParser.parse(script)

        if commands.isEmpty {
            return .error("No valid commands found in script")
        }

        // Create a capture for results
        let capture = ServerOutputCapture()
        executor.context.outputCapture = capture

        let success = executor.execute(commands, verbose: false)

        // Build result summary
        let successCount = capture.successCount
        let failureCount = capture.failureCount

        var resultText = "Executed \(commands.count) commands: \(successCount) succeeded, \(failureCount) failed"

        if !capture.results.isEmpty {
            resultText += "\n\nResults:\n"
            for result in capture.results {
                let status = result.status == "success" ? "✓" : "✗"
                resultText += "  \(status) [\(result.index + 1)] \(result.command)"
                if let error = result.error {
                    resultText += " - \(error)"
                }
                resultText += "\n"
            }
        }

        if success {
            return .text(resultText)
        } else {
            return MCPToolCallResult(
                content: [.text(MCPTextContent(text: resultText))],
                isError: true
            )
        }
    }

    private func executeResetSession() -> MCPToolCallResult {
        executor.context.reset()
        return .text("Session context reset. Current window and element cleared.")
    }

    // MARK: - Command Execution Helper

    /// Execute a single DSL command using the persistent executor
    private func executeCommand(_ command: Command) -> CommandResult {
        // Create a temporary capture
        let capture = ServerOutputCapture()
        executor.context.outputCapture = capture

        // Execute single command (array with one element)
        let success = executor.execute([command], verbose: false)

        // Get result from capture
        if let result = capture.results.first {
            if result.status == "success" {
                // Try to extract typed value from the result
                if let elementInfo = result.elementInfo {
                    return .success(value: elementInfo)
                } else if let elementInfos = result.elementInfos {
                    return .success(value: elementInfos)
                } else if let systemInfo = result.systemInfo {
                    return .success(value: systemInfo)
                } else if let windowInfo = result.windowInfo {
                    return .success(value: windowInfo)
                } else if let appInfo = result.appInfo {
                    return .success(value: appInfo)
                }
                return .success(value: result.value)
            } else {
                return .failure(error: result.error ?? "Unknown error")
            }
        }

        // Fallback based on executor return value
        if success {
            return .success(value: nil)
        } else {
            return .failure(error: "Command failed")
        }
    }
}
