//
//  CommandDescriptor.swift
//  UniControl
//
//  Core types for the unified command registry system.
//  Defines command metadata used to generate MCP tools, autocomplete, and help.
//

import Foundation

// MARK: - Parameter Types

/// Parameter data type for command arguments
public enum ParameterType: String, Sendable, Codable {
    case string = "string"
    case integer = "integer"
    case number = "number"
    case boolean = "boolean"
}

/// Describes a single parameter for a command
public struct ParameterDescriptor: Sendable {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let isRequired: Bool
    public let enumValues: [String]?

    public init(
        name: String,
        type: ParameterType,
        description: String,
        isRequired: Bool = true,
        enumValues: [String]? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.isRequired = isRequired
        self.enumValues = enumValues
    }
}

// MARK: - Command Categories

/// Categories for organizing commands
public enum CommandCategory: String, Sendable, CaseIterable {
    case appControl = "Application Control"
    case elementFinding = "Element Finding"
    case basicActions = "Basic Actions"
    case checkboxToggle = "Checkbox/Toggle"
    case expandCollapse = "Expand/Collapse"
    case focus = "Focus"
    case menu = "Menu"
    case incrementDecrement = "Increment/Decrement"
    case stateQueries = "State Queries"
    case composite = "Composite"
    case session = "Session Management"
    case logging = "Logging"
    case mode = "Execution Mode"
    case extension_ = "Extension"
}

// MARK: - Command Descriptor

/// Describes a DSL command with all metadata needed for MCP tools and autocomplete
public struct CommandDescriptor: Sendable {
    /// DSL verb (e.g., "launch", "click", "find")
    public let verb: String

    /// MCP tool name (e.g., "launch_app", "click", "find_element")
    public let mcpName: String

    /// Syntax hint for autocomplete (e.g., "launch <app-name>")
    public let syntax: String

    /// Short description for autocomplete
    public let description: String

    /// Detailed description for MCP tool
    public let detailedDescription: String?

    /// Command category for organization
    public let category: CommandCategory

    /// Parameters for the command
    public let parameters: [ParameterDescriptor]

    /// Whether this command requires a window context
    public let requiresWindow: Bool

    /// Whether this command requires an element context
    public let requiresElement: Bool

    /// Alternative verbs that map to this command (e.g., ["getwindow"] for "getwindows")
    public let aliases: [String]

    /// Extension identifier (nil for built-in commands)
    public let extensionId: String?

    public init(
        verb: String,
        mcpName: String,
        syntax: String,
        description: String,
        detailedDescription: String? = nil,
        category: CommandCategory,
        parameters: [ParameterDescriptor] = [],
        requiresWindow: Bool = false,
        requiresElement: Bool = false,
        aliases: [String] = [],
        extensionId: String? = nil
    ) {
        self.verb = verb
        self.mcpName = mcpName
        self.syntax = syntax
        self.description = description
        self.detailedDescription = detailedDescription
        self.category = category
        self.parameters = parameters
        self.requiresWindow = requiresWindow
        self.requiresElement = requiresElement
        self.aliases = aliases
        self.extensionId = extensionId
    }

    /// Generate an MCP tool definition from this descriptor
    public func toMCPTool() -> MCPTool {
        // Build properties object
        var properties: [String: JSONValue] = [:]

        for param in parameters {
            var paramSchema: [String: JSONValue] = [
                "type": .string(param.type.rawValue),
                "description": .string(param.description)
            ]

            if let enumVals = param.enumValues {
                paramSchema["enum"] = .array(enumVals.map { .string($0) })
            }

            properties[param.name] = .object(paramSchema)
        }

        // Build required array
        let requiredParams = parameters.filter { $0.isRequired }.map { JSONValue.string($0.name) }

        // Build input schema
        var schemaFields: [String: JSONValue] = [
            "type": .string("object"),
            "properties": .object(properties)
        ]

        if !requiredParams.isEmpty {
            schemaFields["required"] = .array(requiredParams)
        }

        return MCPTool(
            name: mcpName,
            description: detailedDescription ?? description,
            inputSchema: .object(schemaFields)
        )
    }
}

// MARK: - Convenience Initializers

extension CommandDescriptor {
    /// Create a simple command with no parameters
    public static func simple(
        verb: String,
        mcpName: String,
        description: String,
        detailedDescription: String? = nil,
        category: CommandCategory,
        requiresWindow: Bool = false,
        requiresElement: Bool = false,
        aliases: [String] = []
    ) -> CommandDescriptor {
        CommandDescriptor(
            verb: verb,
            mcpName: mcpName,
            syntax: verb,
            description: description,
            detailedDescription: detailedDescription,
            category: category,
            parameters: [],
            requiresWindow: requiresWindow,
            requiresElement: requiresElement,
            aliases: aliases
        )
    }
}
