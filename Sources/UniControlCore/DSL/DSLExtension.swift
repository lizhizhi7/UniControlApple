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

/// Describes a configurable setting for an extension
public struct ExtensionConfigDescriptor: Sendable {
    public let key: String
    public let displayName: String
    public let type: ParameterType
    public let defaultValue: String
    public let description: String

    public init(key: String, displayName: String, type: ParameterType, defaultValue: String, description: String) {
        self.key = key
        self.displayName = displayName
        self.type = type
        self.defaultValue = defaultValue
        self.description = description
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

    // MARK: - Metadata

    /// Human-readable display name (e.g., "Microsoft Excel")
    static var displayName: String { get }

    /// Extension version (e.g., "1.0.0")
    static var version: String { get }

    /// Extension author
    static var author: String { get }

    /// Longer description of what this extension provides
    static var extensionDescription: String { get }

    /// Target application name, or nil for generic extensions
    static var targetApplication: String? { get }

    /// SF Symbol name for the extension's icon
    static var systemImageName: String { get }

    // MARK: - Lifecycle Hooks

    /// Called when extension is enabled
    func onActivate()

    /// Called when extension is disabled
    func onDeactivate()

    // MARK: - Execution Hooks

    /// Called before any command executes (not just this extension's commands)
    func willExecuteCommand(_ command: Command, context: ExecutionContext)

    /// Called after any command executes (not just this extension's commands)
    func didExecuteCommand(_ command: Command, result: CommandResult, context: ExecutionContext)

    // MARK: - Configuration

    /// Configurable settings for this extension
    static var configDescriptors: [ExtensionConfigDescriptor] { get }

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

// MARK: - Default Implementations

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

    public static var displayName: String { identifier.capitalized }
    public static var version: String { "1.0.0" }
    public static var author: String { "Unknown" }
    public static var extensionDescription: String { "Extension: \(identifier)" }
    public static var targetApplication: String? { nil }
    public static var systemImageName: String { "puzzlepiece.extension" }
    public static var configDescriptors: [ExtensionConfigDescriptor] { [] }

    public func onActivate() {}
    public func onDeactivate() {}
    public func willExecuteCommand(_ command: Command, context: ExecutionContext) {}
    public func didExecuteCommand(_ command: Command, result: CommandResult, context: ExecutionContext) {}
}
