//
//  UniControlServer.swift
//  UniControl
//
//  HTTP and WebSocket server for remote DSL execution
//

import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOCore
import NIOPosix

// MARK: - Request Context

struct UniControlRequestContext: RequestContext, WebSocketRequestContext {
    var coreContext: CoreRequestContextStorage
    var webSocket: WebSocketHandlerReference<UniControlRequestContext>

    init(source: ApplicationRequestContextSource) {
        self.coreContext = .init(source: source)
        self.webSocket = .init()
    }
}

// MARK: - Execution Event Types

/// Information about a script execution
public struct ScriptExecution: Identifiable, Sendable {
    public let id: UUID
    public let script: String
    public let mode: String?
    public let startTime: Date
    public var endTime: Date?
    public var response: ExecuteResponse?
    public var logs: [LogMessage]

    public init(id: UUID = UUID(), script: String, mode: String? = nil, startTime: Date = Date()) {
        self.id = id
        self.script = script
        self.mode = mode
        self.startTime = startTime
        self.endTime = nil
        self.response = nil
        self.logs = []
    }

    public var isComplete: Bool {
        return response != nil
    }

    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}

// MARK: - Output Capture Factory

/// Factory type for creating output captures
public typealias OutputCaptureFactory = @Sendable (UUID) -> OutputCapture

// MARK: - Server Delegate

/// Protocol for receiving server events
public protocol UniControlServerDelegate: AnyObject, Sendable {
    /// Called when a script execution starts
    func serverDidStartExecution(_ server: UniControlServer, executionId: UUID, script: String, mode: String?)

    /// Called when a script execution completes
    func serverDidCompleteExecution(_ server: UniControlServer, executionId: UUID, response: ExecuteResponse)

    /// Called when the server starts
    func serverDidStart(_ server: UniControlServer, port: Int)

    /// Called when the server stops
    func serverDidStop(_ server: UniControlServer)
}

// Default empty implementations
public extension UniControlServerDelegate {
    func serverDidStartExecution(_ server: UniControlServer, executionId: UUID, script: String, mode: String?) {}
    func serverDidCompleteExecution(_ server: UniControlServer, executionId: UUID, response: ExecuteResponse) {}
    func serverDidStart(_ server: UniControlServer, port: Int) {}
    func serverDidStop(_ server: UniControlServer) {}
}

// MARK: - UniControl Server

/// HTTP/WebSocket server for UniControl
public final class UniControlServer: @unchecked Sendable {
    public let port: Int
    public let hostname: String

    /// Delegate for receiving server events
    public weak var delegate: UniControlServerDelegate?

    /// Factory for creating output captures (allows injecting custom captures)
    public var outputCaptureFactory: OutputCaptureFactory?

    /// Whether the server is currently running
    public private(set) var isRunning: Bool = false

    /// Task running the server
    private var serverTask: Task<Void, Error>?

    /// Default execution mode
    public var defaultExecutionMode: ExecutionMode = .continue

    /// Verbose logging
    public var verboseLogging: Bool = true

    /// MCP HTTP transport for Model Context Protocol support
    private let mcpTransport = MCPHTTPTransport()

    public init(port: Int, hostname: String = "127.0.0.1") {
        self.port = port
        self.hostname = hostname
    }

    /// Start the server asynchronously
    public func startAsync() {
        guard !isRunning else { return }

        serverTask = Task {
            try await self.start()
        }
    }

    /// Stop the server
    public func stop() {
        serverTask?.cancel()
        serverTask = nil
        isRunning = false
        delegate?.serverDidStop(self)
    }

    /// Start the server (blocking)
    public func start() async throws {
        // Create router
        let router = Router(context: UniControlRequestContext.self)

        // Health check endpoint
        router.get("/health") { _, _ -> Response in
            let response = HealthResponse()
            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(data: data))
            )
        }

        // Execute DSL endpoint
        router.post("/execute") { request, _ -> Response in
            return try await self.handleExecute(request)
        }

        // Add WebSocket upgrade handler using router
        router.ws("/ws") { inbound, outbound, _ in
            try await self.handleWebSocket(inbound: inbound, outbound: outbound)
        }

        // MCP (Model Context Protocol) endpoint
        router.post("/mcp") { request, _ -> Response in
            return try await handleMCPRequest(request: request, transport: self.mcpTransport)
        }

        // MCP session close endpoint
        router.delete("/mcp/session") { request, _ -> Response in
            return handleMCPSessionClose(request: request, transport: self.mcpTransport)
        }

        // Create application
        let app = Application(
            router: router,
            configuration: .init(address: .hostname(self.hostname, port: self.port))
        )

        isRunning = true
        delegate?.serverDidStart(self, port: port)

        print("UniControl server starting on http://\(hostname):\(port)")
        print("Endpoints:")
        print("  GET    /health      - Health check")
        print("  POST   /execute     - Execute DSL script")
        print("  WS     /ws          - WebSocket for streaming")
        print("  POST   /mcp         - MCP JSON-RPC endpoint")
        print("  DELETE /mcp/session - Close MCP session")
        print("")
        print("Press Ctrl+C to stop the server")

        do {
            try await app.run()
        } catch {
            isRunning = false
            delegate?.serverDidStop(self)
            throw error
        }

        isRunning = false
        delegate?.serverDidStop(self)
    }

    // MARK: - HTTP Handlers

    /// Handle POST /execute request
    private func handleExecute(_ request: Request) async throws -> Response {
        // Parse request body
        let body = request.body
        var bodyData = Data()
        for try await buffer in body {
            bodyData.append(contentsOf: buffer.readableBytesView)
        }

        guard !bodyData.isEmpty else {
            return errorResponse(status: .badRequest, message: "Missing request body")
        }

        let executeRequest: ExecuteRequest
        do {
            executeRequest = try JSONDecoder().decode(ExecuteRequest.self, from: bodyData)
        } catch {
            return errorResponse(status: .badRequest, message: "Invalid JSON: \(error.localizedDescription)")
        }

        // Execute the script
        let response = await executeScript(executeRequest)

        // Return JSON response
        let encoder = JSONEncoder()
        let responseData = try encoder.encode(response)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: responseData))
        )
    }

    /// Execute a DSL script and return the response
    private func executeScript(_ request: ExecuteRequest) async -> ExecuteResponse {
        let executionId = UUID()

        // Use factory to create capture if available, otherwise use default
        let capture: OutputCapture
        if let factory = outputCaptureFactory {
            capture = factory(executionId)
        } else {
            capture = ServerOutputCapture()
        }

        // Notify delegate of execution start
        delegate?.serverDidStartExecution(self, executionId: executionId, script: request.script, mode: request.mode)

        let commands = DSLParser.parse(request.script)
        let executor = DSLExecutor()
        executor.context.outputCapture = capture

        // Set execution mode if specified
        if let mode = request.mode {
            switch mode.lowercased() {
            case "strict":
                executor.context.mode = .strict
            case "interactive":
                executor.context.mode = .interactive
            default:
                executor.context.mode = defaultExecutionMode
            }
        } else {
            executor.context.mode = defaultExecutionMode
        }

        let startTime = Date()
        let success = executor.execute(commands, verbose: verboseLogging)
        let executionTime = Date().timeIntervalSince(startTime)

        // Get results from the capture
        let serverCapture = capture as? ServerOutputCapture
        let results = serverCapture?.results ?? []
        let successCount = serverCapture?.successCount ?? (success ? commands.count : 0)
        let failureCount = serverCapture?.failureCount ?? (success ? 0 : 1)

        let response = ExecuteResponse(
            success: success,
            commandsExecuted: successCount,
            commandsFailed: failureCount,
            results: results,
            executionTime: executionTime
        )

        // Notify delegate of execution completion
        delegate?.serverDidCompleteExecution(self, executionId: executionId, response: response)

        return response
    }

    /// Create an error response
    private func errorResponse(status: HTTPResponse.Status, message: String) -> Response {
        let error = ["error": message]
        let encoder = JSONEncoder()
        let data = try! encoder.encode(error)
        return Response(
            status: status,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: data))
        )
    }

    // MARK: - WebSocket Handler

    /// Handle WebSocket connection
    /// Maintains a persistent executor for context preservation across commands
    private func handleWebSocket(
        inbound: WebSocketInboundStream,
        outbound: WebSocketOutboundWriter
    ) async throws {
        let encoder = JSONEncoder()

        // Create a persistent executor for this connection - context is preserved across commands
        let executor = DSLExecutor()

        // Send welcome message
        let welcome = LogMessage(level: .info, message: "Connected to UniControl server (interactive session)")
        if let data = try? encoder.encode(welcome),
           let text = String(data: data, encoding: .utf8) {
            try await outbound.write(.text(text))
        }

        // Process incoming messages
        for try await frame in inbound {
            // Get text data from frame
            guard let text = frame.data.getString(at: 0, length: frame.data.readableBytes) else {
                continue
            }

            // Parse incoming command
            guard let data = text.data(using: .utf8) else { continue }

            // Try to decode as execute command
            if let executeCmd = try? JSONDecoder().decode(WSExecuteCommand.self, from: data),
               executeCmd.type == "execute" {
                let executionId = UUID()

                // Create output capture with WebSocket streaming (fresh for each command batch)
                let capture: OutputCapture
                if let factory = outputCaptureFactory {
                    capture = factory(executionId)
                } else {
                    capture = ServerOutputCapture()
                }

                // Notify delegate of execution start
                delegate?.serverDidStartExecution(self, executionId: executionId, script: executeCmd.script, mode: executeCmd.mode)

                // Set up real-time streaming if using ServerOutputCapture
                if let serverCapture = capture as? ServerOutputCapture {
                    // Set up real-time log streaming
                    serverCapture.onLog = { logMessage in
                        Task {
                            if let logData = try? encoder.encode(logMessage),
                               let logText = String(data: logData, encoding: .utf8) {
                                try? await outbound.write(.text(logText))
                            }
                        }
                    }

                    // Set up real-time result streaming
                    serverCapture.onResult = { result in
                        Task {
                            let wsResult = WSResultMessage(result: result)
                            if let resultData = try? encoder.encode(wsResult),
                               let resultText = String(data: resultData, encoding: .utf8) {
                                try? await outbound.write(.text(resultText))
                            }
                        }
                    }
                }

                // Update output capture on the persistent executor
                executor.context.outputCapture = capture

                // Parse and execute commands
                let commands = DSLParser.parse(executeCmd.script)

                // Set execution mode if specified
                if let mode = executeCmd.mode {
                    switch mode.lowercased() {
                    case "strict":
                        executor.context.mode = .strict
                    case "interactive":
                        executor.context.mode = .interactive
                    default:
                        executor.context.mode = defaultExecutionMode
                    }
                } else {
                    executor.context.mode = defaultExecutionMode
                }

                let startTime = Date()
                let success = executor.execute(commands, verbose: verboseLogging)
                let executionTime = Date().timeIntervalSince(startTime)

                // Get results from the capture
                let serverCapture = capture as? ServerOutputCapture
                let results = serverCapture?.results ?? []
                let successCount = serverCapture?.successCount ?? (success ? commands.count : 0)
                let failureCount = serverCapture?.failureCount ?? (success ? 0 : 1)

                // Send completion message
                let response = ExecuteResponse(
                    success: success,
                    commandsExecuted: successCount,
                    commandsFailed: failureCount,
                    results: results,
                    executionTime: executionTime
                )

                // Notify delegate of execution completion
                delegate?.serverDidCompleteExecution(self, executionId: executionId, response: response)

                let complete = WSCompleteMessage(response: response)
                if let completeData = try? encoder.encode(complete),
                   let completeText = String(data: completeData, encoding: .utf8) {
                    try await outbound.write(.text(completeText))
                }
            } else if let resetCmd = try? JSONDecoder().decode(WSResetCommand.self, from: data),
                      resetCmd.type == "reset" {
                // Reset the executor context
                executor.context.reset()
                let msg = LogMessage(level: .info, message: "Session context reset")
                if let msgData = try? encoder.encode(msg),
                   let msgText = String(data: msgData, encoding: .utf8) {
                    try await outbound.write(.text(msgText))
                }
            }
        }
    }
}
