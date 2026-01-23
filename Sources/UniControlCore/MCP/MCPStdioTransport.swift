//
//  MCPStdioTransport.swift
//  UniControl
//
//  Stdio transport for MCP - reads/writes newline-delimited JSON on stdin/stdout
//

import Foundation

/// Stdio transport for MCP communication with Claude Desktop and other clients
public class MCPStdioTransport {
    private let handler: MCPHandler

    /// File handle for reading from stdin
    private let stdinHandle: FileHandle

    /// File handle for writing to stdout
    private let stdoutHandle: FileHandle

    /// Whether the transport is running
    private var isRunning: Bool = false

    public init() {
        self.handler = MCPHandler()
        self.stdinHandle = FileHandle.standardInput
        self.stdoutHandle = FileHandle.standardOutput
    }

    /// Start the transport - reads from stdin and writes responses to stdout
    /// This method blocks until stdin is closed or an error occurs
    public func run() {
        isRunning = true

        // Read lines from stdin
        while isRunning {
            guard let line = readLine() else {
                // EOF - stdin closed
                break
            }

            // Skip empty lines
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            // Parse and handle the message
            guard let data = trimmed.data(using: .utf8) else {
                continue
            }

            if let responseData = handler.handleMessage(data) {
                // Write response followed by newline
                if let responseString = String(data: responseData, encoding: .utf8) {
                    writeOutput(responseString)
                }
            }
        }
    }

    /// Run asynchronously using async/await
    public func runAsync() async {
        isRunning = true

        // Use a background task to read from stdin
        while isRunning {
            // Read data from stdin asynchronously
            let data = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let data = self.stdinHandle.availableData
                    continuation.resume(returning: data)
                }
            }

            // EOF - stdin closed
            if data.isEmpty {
                break
            }

            // Process lines
            guard let input = String(data: data, encoding: .utf8) else {
                continue
            }

            // Split into lines and process each
            let lines = input.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    continue
                }

                guard let messageData = trimmed.data(using: .utf8) else {
                    continue
                }

                if let responseData = handler.handleMessage(messageData) {
                    if let responseString = String(data: responseData, encoding: .utf8) {
                        writeOutput(responseString)
                    }
                }
            }
        }
    }

    /// Stop the transport
    public func stop() {
        isRunning = false
    }

    /// Write a line to stdout
    private func writeOutput(_ message: String) {
        // Ensure message ends with newline
        let output = message.hasSuffix("\n") ? message : message + "\n"

        if let data = output.data(using: .utf8) {
            stdoutHandle.write(data)
        }
    }
}

// MARK: - Convenience Functions

/// Run UniControl as an MCP server using stdio transport
/// This is the main entry point for `UniControl --mcp`
public func runMCPStdioServer() {
    let transport = MCPStdioTransport()
    transport.run()
}

/// Run UniControl as an MCP server using stdio transport (async version)
public func runMCPStdioServerAsync() async {
    let transport = MCPStdioTransport()
    await transport.runAsync()
}
