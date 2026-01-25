//
//  ExtensionRegistry.swift
//  UniControl
//
//  Global registry for managing DSL extensions
//

import Foundation

/// Singleton registry for DSL extensions
/// Manages registration, lookup, and instantiation of extension handlers
public class ExtensionRegistry {
    public static let shared = ExtensionRegistry()

    /// Mapping from verb to extension type
    private var verbToExtension: [String: DSLExtension.Type] = [:]

    /// Cached extension instances (lazy instantiation)
    private var extensionInstances: [String: DSLExtension] = [:]

    private init() {}

    /// Register an extension type
    /// - Parameter extensionType: The DSLExtension conforming type to register
    public func register<T: DSLExtension>(_ extensionType: T.Type) {
        for verb in extensionType.supportedCommands {
            let lowerVerb = verb.lowercased()
            if verbToExtension[lowerVerb] != nil {
                print("⚠️  Warning: Verb '\(verb)' already registered, overwriting")
            }
            verbToExtension[lowerVerb] = extensionType
        }

        // Register command descriptors with CommandRegistry
        for descriptor in extensionType.commandDescriptors {
            CommandRegistry.shared.register(descriptor)
        }
    }

    /// Check if a verb can be handled by any registered extension
    /// - Parameter verb: The command verb (lowercased)
    /// - Returns: true if an extension can handle this verb
    public func canHandle(verb: String) -> Bool {
        return verbToExtension[verb.lowercased()] != nil
    }

    /// Parse a DSL line using the appropriate extension
    /// - Parameters:
    ///   - line: The full DSL line
    ///   - verb: The command verb (lowercased)
    ///   - parts: All whitespace-separated parts of the line
    /// - Returns: An ExtensionCommand if parsing succeeds, nil otherwise
    public func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand? {
        let lowerVerb = verb.lowercased()
        guard let extensionType = verbToExtension[lowerVerb] else {
            return nil
        }
        return extensionType.parse(line, verb: lowerVerb, parts: parts)
    }

    /// Execute an extension command
    /// - Parameters:
    ///   - command: The ExtensionCommand to execute
    ///   - context: The current execution context
    ///   - verbose: Whether to print verbose output
    /// - Returns: CommandResult indicating success or failure
    public func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult {
        guard let extensionType = verbToExtension[command.verb.lowercased()] else {
            return .failure(error: "No extension registered for verb: \(command.verb)")
        }

        // Get or create extension instance
        let extensionId = extensionType.identifier
        let instance: DSLExtension
        if let cached = extensionInstances[extensionId] {
            instance = cached
        } else {
            instance = extensionType.init()
            extensionInstances[extensionId] = instance
        }

        return instance.execute(command, context: context, verbose: verbose)
    }

    /// Get all registered verbs (for help/documentation)
    public func registeredVerbs() -> [String] {
        return Array(verbToExtension.keys).sorted()
    }

    /// Get the extension identifier for a verb
    public func extensionId(for verb: String) -> String? {
        return verbToExtension[verb.lowercased()]?.identifier
    }
}
