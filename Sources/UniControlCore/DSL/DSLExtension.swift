//
//  DSLExtension.swift
//  UniControl
//
//  Protocol definition for DSL extensions
//

import Foundation

/// Represents a command from an extension
public struct ExtensionCommand {
    public let extensionId: String
    public let verb: String
    public let arguments: [String]
    public let metadata: [String: Any]

    public init(extensionId: String, verb: String, arguments: [String], metadata: [String: Any] = [:]) {
        self.extensionId = extensionId
        self.verb = verb
        self.arguments = arguments
        self.metadata = metadata
    }
}

/// Protocol for DSL extensions
/// Extensions register themselves with the ExtensionRegistry and handle specific verbs
public protocol DSLExtension {
    /// Unique identifier for this extension (e.g., "excel", "finder")
    static var identifier: String { get }

    /// List of command verbs this extension handles (e.g., ["clickcell", "range", "typeincell"])
    static var supportedCommands: [String] { get }

    /// Command descriptors for this extension's commands
    /// Used for MCP tool generation and autocomplete
    static var commandDescriptors: [CommandDescriptor] { get }

    /// Parse a DSL line into an ExtensionCommand
    /// - Parameters:
    ///   - line: The full DSL line
    ///   - verb: The command verb (first word, lowercased)
    ///   - parts: All whitespace-separated parts of the line
    /// - Returns: An ExtensionCommand if parsing succeeds, nil otherwise
    static func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand?

    /// Execute an extension command
    /// - Parameters:
    ///   - command: The ExtensionCommand to execute
    ///   - context: The current execution context
    ///   - verbose: Whether to print verbose output
    /// - Returns: CommandResult indicating success or failure
    func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult

    /// Required initializer for creating extension instances
    init()
}

// MARK: - Default Implementation

extension DSLExtension {
    /// Default implementation generates basic descriptors from supportedCommands
    /// Extensions should override this to provide full metadata
    public static var commandDescriptors: [CommandDescriptor] {
        supportedCommands.map { verb in
            CommandDescriptor(
                verb: verb,
                mcpName: "\(identifier)_\(verb)",
                syntax: verb,
                description: "\(identifier.capitalized) extension command: \(verb)",
                category: .extension_,
                extensionId: identifier
            )
        }
    }
}
