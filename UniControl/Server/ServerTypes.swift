//
//  ServerTypes.swift
//  UniControl
//
//  Request/Response types for HTTP API and WebSocket messages
//

import Foundation

// MARK: - HTTP Request/Response Types

/// Request body for POST /execute endpoint
public struct ExecuteRequest: Codable {
    /// DSL script content to execute
    public let script: String
    /// Execution mode: "strict", "continue" (default), or "interactive"
    public let mode: String?

    public init(script: String, mode: String? = nil) {
        self.script = script
        self.mode = mode
    }
}

/// Response body for POST /execute endpoint
public struct ExecuteResponse: Codable {
    /// Whether all commands succeeded
    public let success: Bool
    /// Number of commands that succeeded
    public let commandsExecuted: Int
    /// Number of commands that failed
    public let commandsFailed: Int
    /// Detailed results for each command
    public let results: [CommandExecutionResult]
    /// Total execution time in seconds
    public let executionTime: Double

    public init(success: Bool, commandsExecuted: Int, commandsFailed: Int, results: [CommandExecutionResult], executionTime: Double) {
        self.success = success
        self.commandsExecuted = commandsExecuted
        self.commandsFailed = commandsFailed
        self.results = results
        self.executionTime = executionTime
    }
}

/// Result of executing a single command
public struct CommandExecutionResult: Codable {
    /// Zero-based index of the command
    public let index: Int
    /// String representation of the command
    public let command: String
    /// "success" or "failure"
    public let status: String
    /// Error message if failed
    public let error: String?
    /// Stringified result value if any
    public let value: String?

    public init(index: Int, command: String, status: String, error: String? = nil, value: String? = nil) {
        self.index = index
        self.command = command
        self.status = status
        self.error = error
        self.value = value
    }
}

/// Health check response
public struct HealthResponse: Codable {
    public let status: String
    public let version: String

    public init(status: String = "ok", version: String = "1.0.0") {
        self.status = status
        self.version = version
    }
}

// MARK: - WebSocket Message Types

/// Log level for server output
public enum LogLevel: String, Codable {
    case info
    case success
    case error
    case warning
    case debug
}

/// Log message sent via WebSocket
public struct LogMessage: Codable {
    public let type: String
    public let level: String
    public let message: String
    public let timestamp: Date

    public init(level: LogLevel, message: String, timestamp: Date = Date()) {
        self.type = "log"
        self.level = level.rawValue
        self.message = message
        self.timestamp = timestamp
    }
}

/// Interactive prompt sent via WebSocket
public struct InteractivePrompt: Codable {
    public let type: String
    public let promptId: String
    public let message: String
    public let options: [String]

    public init(promptId: String, message: String, options: [String]) {
        self.type = "prompt"
        self.promptId = promptId
        self.message = message
        self.options = options
    }
}

/// Client response to interactive prompt
public struct InteractiveResponse: Codable {
    public let type: String
    public let promptId: String
    public let selection: String

    public init(promptId: String, selection: String) {
        self.type = "response"
        self.promptId = promptId
        self.selection = selection
    }
}

/// WebSocket execute command from client
public struct WSExecuteCommand: Codable {
    public let type: String
    public let script: String
    public let mode: String?
}

/// WebSocket reset command from client
public struct WSResetCommand: Codable {
    public let type: String
}

/// WebSocket complete message
public struct WSCompleteMessage: Codable {
    public let type: String
    public let success: Bool
    public let commandsExecuted: Int
    public let commandsFailed: Int
    public let executionTime: Double

    public init(response: ExecuteResponse) {
        self.type = "complete"
        self.success = response.success
        self.commandsExecuted = response.commandsExecuted
        self.commandsFailed = response.commandsFailed
        self.executionTime = response.executionTime
    }
}

/// WebSocket result message for individual command
public struct WSResultMessage: Codable {
    public let type: String
    public let index: Int
    public let command: String
    public let status: String
    public let error: String?

    public init(result: CommandExecutionResult) {
        self.type = "result"
        self.index = result.index
        self.command = result.command
        self.status = result.status
        self.error = result.error
    }
}
