//
//  OutputCapture.swift
//  UniControl
//
//  Protocol for capturing executor output in server mode
//

import Foundation

// MARK: - Output Capture Protocol

/// Protocol for capturing DSL executor output
/// Implementations can log to console, store for HTTP response, or stream via WebSocket
public protocol OutputCapture: AnyObject {
    /// Log a message with specified level
    func log(_ message: String, level: LogLevel)

    /// Record the result of a command execution
    func recordResult(_ index: Int, command: String, result: CommandResult)
}

// MARK: - Server Output Capture

/// Server-mode implementation that captures output for HTTP response and optional WebSocket streaming
public class ServerOutputCapture: OutputCapture {
    /// Collected log messages
    public private(set) var logs: [LogMessage] = []

    /// Collected command results
    public private(set) var results: [CommandExecutionResult] = []

    /// Optional callback for real-time WebSocket streaming
    public var onLog: ((LogMessage) -> Void)?
    public var onResult: ((CommandExecutionResult) -> Void)?

    /// Thread-safe lock for concurrent access
    private let lock = NSLock()

    public init() {}

    public func log(_ message: String, level: LogLevel) {
        let logMessage = LogMessage(level: level, message: message)

        lock.lock()
        logs.append(logMessage)
        lock.unlock()

        // Stream via WebSocket if callback is set
        onLog?(logMessage)
    }

    public func recordResult(_ index: Int, command: String, result: CommandResult) {
        let executionResult: CommandExecutionResult

        switch result {
        case .success(let value):
            var valueStr: String? = nil
            var elementInfo: ElementInfo? = nil
            var elementInfos: [ElementInfo]? = nil
            var systemInfo: SystemInfo? = nil
            var windowInfo: [WindowInfo]? = nil
            var appInfo: [AppInfo]? = nil

            // Detect structured types and populate appropriate fields
            if let info = value as? ElementInfo {
                elementInfo = info
            } else if let infos = value as? [ElementInfo] {
                elementInfos = infos
            } else if let info = value as? SystemInfo {
                systemInfo = info
            } else if let infos = value as? [WindowInfo] {
                windowInfo = infos
            } else if let infos = value as? [AppInfo] {
                appInfo = infos
            } else if let val = value {
                valueStr = "\(val)"
            }

            executionResult = CommandExecutionResult(
                index: index,
                command: command,
                status: "success",
                error: nil,
                value: valueStr,
                elementInfo: elementInfo,
                elementInfos: elementInfos,
                systemInfo: systemInfo,
                windowInfo: windowInfo,
                appInfo: appInfo
            )
        case .failure(let error):
            executionResult = CommandExecutionResult(
                index: index,
                command: command,
                status: "failure",
                error: error,
                value: nil
            )
        }

        lock.lock()
        results.append(executionResult)
        lock.unlock()

        // Stream via WebSocket if callback is set
        onResult?(executionResult)
    }

    /// Get the number of successful commands
    public var successCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return results.filter { $0.status == "success" }.count
    }

    /// Get the number of failed commands
    public var failureCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return results.filter { $0.status == "failure" }.count
    }

    /// Reset captured data
    public func reset() {
        lock.lock()
        logs.removeAll()
        results.removeAll()
        lock.unlock()
    }
}

// MARK: - Console Output Capture (for CLI compatibility)

/// Console implementation that prints to stdout while also capturing for potential use
public class ConsoleOutputCapture: OutputCapture {
    public init() {}

    public func log(_ message: String, level: LogLevel) {
        let prefix: String
        switch level {
        case .info:
            prefix = ""
        case .success:
            prefix = "✓ "
        case .error:
            prefix = "❌ "
        case .warning:
            prefix = "⚠️ "
        case .debug:
            prefix = "🔍 "
        }
        print("\(prefix)\(message)")
    }

    public func recordResult(_ index: Int, command: String, result: CommandResult) {
        // Console mode doesn't need to record results - they're printed inline
    }
}
