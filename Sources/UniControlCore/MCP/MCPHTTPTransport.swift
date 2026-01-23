//
//  MCPHTTPTransport.swift
//  UniControl
//
//  HTTP transport for MCP - handles POST /mcp and GET /mcp/sse endpoints
//

import Foundation
import Hummingbird
import HTTPTypes
import NIOCore

/// HTTP transport for MCP communication over network
/// Manages MCP sessions keyed by session ID
public class MCPHTTPTransport {
    /// Session storage - maps session ID to handler
    private var sessions: [String: MCPHandler] = [:]

    /// Lock for thread-safe session access
    private let sessionsLock = NSLock()

    public init() {}

    // MARK: - Session Management

    /// Get or create a session handler
    /// - Parameter sessionId: Session identifier (from header or generated)
    /// - Returns: MCPHandler for this session
    public func getHandler(sessionId: String?) -> (handler: MCPHandler, sessionId: String) {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }

        let id = sessionId ?? UUID().uuidString

        if let existing = sessions[id] {
            return (existing, id)
        }

        let handler = MCPHandler()
        sessions[id] = handler
        return (handler, id)
    }

    /// Remove a session
    /// - Parameter sessionId: Session identifier to remove
    public func removeSession(sessionId: String) {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        sessions.removeValue(forKey: sessionId)
    }

    /// Get count of active sessions
    public var sessionCount: Int {
        sessionsLock.lock()
        defer { sessionsLock.unlock() }
        return sessions.count
    }

    // MARK: - Request Handling

    /// Handle an MCP HTTP request
    /// - Parameters:
    ///   - body: Request body data
    ///   - sessionId: Optional session ID from header
    /// - Returns: Tuple of (response data, session ID)
    public func handleRequest(body: Data, sessionId: String?) -> (data: Data?, sessionId: String) {
        let (handler, sid) = getHandler(sessionId: sessionId)

        let responseData = handler.handleMessage(body)

        return (responseData, sid)
    }
}

// MARK: - Hummingbird Integration Helpers

/// MCP HTTP response wrapper
public struct MCPHTTPResponse {
    public let status: HTTPResponse.Status
    public let body: ByteBuffer?
    public let sessionId: String?

    public init(status: HTTPResponse.Status, body: ByteBuffer? = nil, sessionId: String? = nil) {
        self.status = status
        self.body = body
        self.sessionId = sessionId
    }

    /// Convert to Hummingbird Response
    public func toResponse() -> Response {
        var headers: HTTPFields = [.contentType: "application/json"]

        if let sessionId = sessionId {
            headers[HTTPField.Name("X-MCP-Session-Id")!] = sessionId
        }

        if let body = body {
            return Response(status: status, headers: headers, body: .init(byteBuffer: body))
        } else {
            return Response(status: status, headers: headers)
        }
    }
}

/// Route handler for POST /mcp endpoint
/// - Parameters:
///   - request: Hummingbird request
///   - transport: MCP HTTP transport instance
/// - Returns: Hummingbird response
public func handleMCPRequest(
    request: Request,
    transport: MCPHTTPTransport
) async throws -> Response {
    // Read request body
    var bodyData = Data()
    for try await buffer in request.body {
        bodyData.append(contentsOf: buffer.readableBytesView)
    }

    guard !bodyData.isEmpty else {
        return MCPHTTPResponse(status: .badRequest, body: ByteBuffer(string: "{\"error\":\"Empty request body\"}")).toResponse()
    }

    // Get session ID from header if present
    let sessionId = request.headers[HTTPField.Name("X-MCP-Session-Id")!]

    // Handle the request
    let (responseData, sid) = transport.handleRequest(body: bodyData, sessionId: sessionId)

    if let data = responseData {
        return MCPHTTPResponse(
            status: .ok,
            body: ByteBuffer(data: data),
            sessionId: sid
        ).toResponse()
    } else {
        // Notification - no response body but return session ID
        return MCPHTTPResponse(status: .accepted, sessionId: sid).toResponse()
    }
}

/// Route handler for DELETE /mcp/session endpoint (close session)
/// - Parameters:
///   - request: Hummingbird request
///   - transport: MCP HTTP transport instance
/// - Returns: Hummingbird response
public func handleMCPSessionClose(
    request: Request,
    transport: MCPHTTPTransport
) -> Response {
    // Get session ID from header
    guard let sessionId = request.headers[HTTPField.Name("X-MCP-Session-Id")!] else {
        return MCPHTTPResponse(
            status: .badRequest,
            body: ByteBuffer(string: "{\"error\":\"Missing X-MCP-Session-Id header\"}")
        ).toResponse()
    }

    transport.removeSession(sessionId: sessionId)

    return MCPHTTPResponse(
        status: .ok,
        body: ByteBuffer(string: "{\"message\":\"Session closed\"}")
    ).toResponse()
}

// MARK: - Convenience Extensions

extension ByteBuffer {
    init(string: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        self = buffer
    }

    init(data: Data) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        self = buffer
    }
}
