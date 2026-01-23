//
//  ServerManager.swift
//  UniControlApp
//
//  Manages the UniControl server lifecycle
//

import Foundation
import UniControlCore

@MainActor
@Observable
class ServerManager: @unchecked Sendable {
    enum Status: Equatable {
        case stopped
        case starting
        case running(port: Int)
        case error(String)

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }

        var displayText: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .running(let port): return "Running on port \(port)"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        var icon: String {
            switch self {
            case .stopped: return "stop.circle"
            case .starting: return "arrow.clockwise.circle"
            case .running: return "play.circle.fill"
            case .error: return "exclamationmark.triangle"
            }
        }

        var color: String {
            switch self {
            case .stopped: return "gray"
            case .starting: return "orange"
            case .running: return "green"
            case .error: return "red"
            }
        }
    }

    private(set) var status: Status = .stopped
    private var server: UniControlServer?
    private var serverTask: Task<Void, Never>?
    private var delegateAdapter: ServerDelegateAdapter?

    /// Callback when execution starts
    var onExecutionStarted: ((UUID, String, String?) -> Void)?

    /// Callback when execution completes
    var onExecutionCompleted: ((UUID, ExecuteResponse) -> Void)?

    /// Configuration
    var verboseLogging: Bool = false
    var defaultExecutionMode: ExecutionMode = .continue

    func start(port: Int) {
        guard !status.isRunning else { return }

        status = .starting
        server = UniControlServer(port: port)
        server?.verboseLogging = verboseLogging
        server?.defaultExecutionMode = defaultExecutionMode

        // Create and store delegate adapter (must be retained since delegate is weak)
        delegateAdapter = ServerDelegateAdapter(manager: self)
        server?.delegate = delegateAdapter

        serverTask = Task { [weak self] in
            guard let self = self, let server = self.server else { return }

            do {
                try await server.start()
                // Server stopped normally
                await MainActor.run {
                    self.status = .stopped
                }
            } catch {
                await MainActor.run {
                    if !Task.isCancelled {
                        self.status = .error(error.localizedDescription)
                    } else {
                        self.status = .stopped
                    }
                }
            }
        }

        // Update status after a brief delay (server starting)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if case .starting = self.status {
                self.status = .running(port: port)
            }
        }
    }

    func stop() {
        serverTask?.cancel()
        serverTask = nil
        server?.stop()
        server = nil
        delegateAdapter = nil
        status = .stopped
    }

    func restart(port: Int) {
        stop()
        // Brief delay before restarting
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.start(port: port)
        }
    }

    /// Update status (called from delegate adapter)
    func updateStatus(_ newStatus: Status) {
        self.status = newStatus
    }

    /// Get the current port if server is running
    var currentPort: Int? {
        if case .running(let port) = status {
            return port
        }
        return nil
    }

    /// Execute a script by making an HTTP request to the local server
    func execute(script: String, mode: String?) async throws -> ExecuteResponse {
        guard let port = currentPort else {
            throw ServerError.notRunning
        }

        let url = URL(string: "http://localhost:\(port)/execute")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ExecuteRequest(script: script, mode: mode)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServerError.executionFailed("Server returned error")
        }

        return try JSONDecoder().decode(ExecuteResponse.self, from: data)
    }

    enum ServerError: LocalizedError {
        case notRunning
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notRunning:
                return "Server is not running"
            case .executionFailed(let message):
                return "Execution failed: \(message)"
            }
        }
    }
}

// MARK: - Server Delegate Adapter

/// Adapter to bridge server delegate to ServerManager
final class ServerDelegateAdapter: UniControlServerDelegate, @unchecked Sendable {
    private weak var manager: ServerManager?

    init(manager: ServerManager) {
        self.manager = manager
    }

    nonisolated func serverDidStartExecution(_ server: UniControlServer, executionId: UUID, script: String, mode: String?) {
        Task { @MainActor in
            manager?.onExecutionStarted?(executionId, script, mode)
        }
    }

    nonisolated func serverDidCompleteExecution(_ server: UniControlServer, executionId: UUID, response: ExecuteResponse) {
        Task { @MainActor in
            manager?.onExecutionCompleted?(executionId, response)
        }
    }

    nonisolated func serverDidStart(_ server: UniControlServer, port: Int) {
        Task { @MainActor in
            manager?.updateStatus(.running(port: port))
        }
    }

    nonisolated func serverDidStop(_ server: UniControlServer) {
        Task { @MainActor in
            manager?.updateStatus(.stopped)
        }
    }
}
