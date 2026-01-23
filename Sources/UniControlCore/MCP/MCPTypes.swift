//
//  MCPTypes.swift
//  UniControl
//
//  JSON-RPC 2.0 and Model Context Protocol (MCP) types
//

import Foundation

// MARK: - JSON-RPC 2.0 Types

/// JSON-RPC 2.0 request
public struct JSONRPCRequest: Codable {
    public let jsonrpc: String
    public let id: JSONRPCId?
    public let method: String
    public let params: JSONValue?

    public init(id: JSONRPCId?, method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 response
public struct JSONRPCResponse: Codable {
    public let jsonrpc: String
    public let id: JSONRPCId?
    public let result: JSONValue?
    public let error: JSONRPCError?

    public init(id: JSONRPCId?, result: JSONValue) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: JSONRPCId?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

/// JSON-RPC 2.0 notification (no id, no response expected)
public struct JSONRPCNotification: Codable {
    public let jsonrpc: String
    public let method: String
    public let params: JSONValue?

    public init(method: String, params: JSONValue? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 error object
public struct JSONRPCError: Codable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard JSON-RPC error codes
    public static let parseError = JSONRPCError(code: -32700, message: "Parse error")
    public static let invalidRequest = JSONRPCError(code: -32600, message: "Invalid Request")
    public static let methodNotFound = JSONRPCError(code: -32601, message: "Method not found")
    public static let invalidParams = JSONRPCError(code: -32602, message: "Invalid params")
    public static let internalError = JSONRPCError(code: -32603, message: "Internal error")

    public static func methodNotFound(_ method: String) -> JSONRPCError {
        JSONRPCError(code: -32601, message: "Method not found: \(method)")
    }

    public static func invalidParams(_ message: String) -> JSONRPCError {
        JSONRPCError(code: -32602, message: message)
    }

    public static func internalError(_ message: String) -> JSONRPCError {
        JSONRPCError(code: -32603, message: message)
    }
}

/// JSON-RPC ID can be string, number, or null
public enum JSONRPCId: Codable, Equatable, Hashable {
    case string(String)
    case number(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCId.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or integer")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}

/// Generic JSON value for dynamic content
public enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    // Convenience accessors
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        if case .int(let value) = self { return Double(value) }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self {
            return dict[key]
        }
        return nil
    }

    public subscript(index: Int) -> JSONValue? {
        if case .array(let arr) = self, index >= 0 && index < arr.count {
            return arr[index]
        }
        return nil
    }
}

// MARK: - MCP Protocol Types

/// MCP protocol version
public let MCP_PROTOCOL_VERSION = "2024-11-05"

/// MCP server info
public struct MCPServerInfo: Codable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// MCP client info
public struct MCPClientInfo: Codable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// MCP server capabilities
public struct MCPServerCapabilities: Codable {
    public let tools: MCPToolsCapability?
    public let prompts: MCPPromptsCapability?
    public let resources: MCPResourcesCapability?
    public let logging: MCPLoggingCapability?

    public init(
        tools: MCPToolsCapability? = nil,
        prompts: MCPPromptsCapability? = nil,
        resources: MCPResourcesCapability? = nil,
        logging: MCPLoggingCapability? = nil
    ) {
        self.tools = tools
        self.prompts = prompts
        self.resources = resources
        self.logging = logging
    }

    public static let toolsOnly = MCPServerCapabilities(tools: MCPToolsCapability())
}

public struct MCPToolsCapability: Codable {
    public let listChanged: Bool?

    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct MCPPromptsCapability: Codable {
    public let listChanged: Bool?

    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct MCPResourcesCapability: Codable {
    public let subscribe: Bool?
    public let listChanged: Bool?

    public init(subscribe: Bool? = nil, listChanged: Bool? = nil) {
        self.subscribe = subscribe
        self.listChanged = listChanged
    }
}

public struct MCPLoggingCapability: Codable {
    public init() {}
}

/// MCP client capabilities
public struct MCPClientCapabilities: Codable {
    public let roots: MCPRootsCapability?
    public let sampling: MCPSamplingCapability?

    public init(roots: MCPRootsCapability? = nil, sampling: MCPSamplingCapability? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
}

public struct MCPRootsCapability: Codable {
    public let listChanged: Bool?

    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct MCPSamplingCapability: Codable {
    public init() {}
}

/// MCP initialize request params
public struct MCPInitializeParams: Codable {
    public let protocolVersion: String
    public let capabilities: MCPClientCapabilities
    public let clientInfo: MCPClientInfo

    public init(protocolVersion: String, capabilities: MCPClientCapabilities, clientInfo: MCPClientInfo) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
    }
}

/// MCP initialize result
public struct MCPInitializeResult: Codable {
    public let protocolVersion: String
    public let capabilities: MCPServerCapabilities
    public let serverInfo: MCPServerInfo
    public let instructions: String?

    public init(
        protocolVersion: String,
        capabilities: MCPServerCapabilities,
        serverInfo: MCPServerInfo,
        instructions: String? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
        self.instructions = instructions
    }
}

/// MCP tool definition
public struct MCPTool: Codable {
    public let name: String
    public let description: String?
    public let inputSchema: JSONValue

    public init(name: String, description: String?, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// MCP tools/list result
public struct MCPToolsListResult: Codable {
    public let tools: [MCPTool]

    public init(tools: [MCPTool]) {
        self.tools = tools
    }
}

/// MCP tools/call params
public struct MCPToolCallParams: Codable {
    public let name: String
    public let arguments: [String: JSONValue]?

    public init(name: String, arguments: [String: JSONValue]?) {
        self.name = name
        self.arguments = arguments
    }
}

/// MCP content types
public enum MCPContentType: String, Codable {
    case text = "text"
    case image = "image"
    case resource = "resource"
}

/// MCP text content
public struct MCPTextContent: Codable {
    public let type: String
    public let text: String

    public init(text: String) {
        self.type = "text"
        self.text = text
    }
}

/// MCP image content
public struct MCPImageContent: Codable {
    public let type: String
    public let data: String  // base64 encoded
    public let mimeType: String

    public init(data: String, mimeType: String) {
        self.type = "image"
        self.data = data
        self.mimeType = mimeType
    }
}

/// MCP tool call result
public struct MCPToolCallResult: Codable {
    public let content: [MCPContent]
    public let isError: Bool?

    public init(content: [MCPContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }

    public static func text(_ text: String) -> MCPToolCallResult {
        MCPToolCallResult(content: [.text(MCPTextContent(text: text))])
    }

    public static func error(_ message: String) -> MCPToolCallResult {
        MCPToolCallResult(content: [.text(MCPTextContent(text: message))], isError: true)
    }
}

/// MCP content (union type)
public enum MCPContent: Codable {
    case text(MCPTextContent)
    case image(MCPImageContent)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let content = try MCPTextContent(from: decoder)
            self = .text(content)
        case "image":
            let content = try MCPImageContent(from: decoder)
            self = .image(content)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .image(let content):
            try content.encode(to: encoder)
        }
    }
}

// MARK: - Helper Extensions

extension JSONValue {
    /// Create JSONValue from any Encodable type
    public static func from<T: Encodable>(_ value: T) -> JSONValue? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let json = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return nil
        }
        return json
    }

    /// Convert to JSON string
    public func toJSONString(pretty: Bool = false) -> String? {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = .prettyPrinted
        }
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

extension MCPToolCallResult {
    /// Create result with JSON data
    public static func json<T: Encodable>(_ value: T) -> MCPToolCallResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(value),
           let jsonString = String(data: data, encoding: .utf8) {
            return .text(jsonString)
        }
        return .error("Failed to encode result as JSON")
    }
}
