//
//  ExtensionRegistry.swift
//  UniControl
//
//  Global registry for managing DSL extensions
//

import Foundation

/// Metadata about a registered extension, suitable for UI display
public struct ExtensionInfo: Codable, Sendable {
    public let identifier: String
    public let displayName: String
    public let version: String
    public let author: String
    public let description: String
    public let targetApplication: String?
    public let systemImageName: String
    public let commandCount: Int
    public let commands: [ExtensionCommandInfo]
    public let configDescriptors: [ExtensionConfigInfo]
    public var isEnabled: Bool
}

/// Info about a single extension command, for UI display
public struct ExtensionCommandInfo: Codable, Sendable {
    public let verb: String
    public let syntax: String
    public let description: String
}

/// Info about a single config descriptor, for UI display
public struct ExtensionConfigInfo: Codable, Sendable {
    public let key: String
    public let displayName: String
    public let type: String
    public let defaultValue: String
    public let description: String
}

/// Singleton registry for DSL extensions
/// Manages registration, lookup, and instantiation of extension handlers
public class ExtensionRegistry {
    public static let shared = ExtensionRegistry()

    /// Mapping from verb to extension type
    private var verbToExtension: [String: DSLExtension.Type] = [:]

    /// Cached extension instances (lazy instantiation)
    private var extensionInstances: [String: DSLExtension] = [:]

    /// All registered extension types, keyed by identifier
    private var registeredTypes: [String: DSLExtension.Type] = [:]

    /// Set of disabled extension identifiers
    private var disabledExtensions: Set<String> = []

    /// Extension configuration values: [extensionId: [key: value]]
    private var extensionConfigs: [String: [String: String]] = [:]

    private init() {}

    /// Register an extension type
    /// - Parameter extensionType: The DSLExtension conforming type to register
    public func register<T: DSLExtension>(_ extensionType: T.Type) {
        registeredTypes[extensionType.identifier] = extensionType

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

    /// Check if a verb can be handled by any enabled registered extension
    /// - Parameter verb: The command verb (lowercased)
    /// - Returns: true if an enabled extension can handle this verb
    public func canHandle(verb: String) -> Bool {
        let lowerVerb = verb.lowercased()
        guard let extensionType = verbToExtension[lowerVerb] else { return false }
        return !disabledExtensions.contains(extensionType.identifier)
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

        let extensionId = extensionType.identifier

        // Check if extension is disabled
        if disabledExtensions.contains(extensionId) {
            return .failure(error: "Extension '\(extensionType.displayName)' is disabled")
        }

        // Get or create extension instance
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

    // MARK: - Enable/Disable

    /// Set whether an extension is enabled or disabled
    public func setEnabled(_ enabled: Bool, for extensionId: String) {
        if enabled {
            disabledExtensions.remove(extensionId)
            // Call onActivate if we have an instance
            if let instance = extensionInstances[extensionId] {
                instance.onActivate()
            }
        } else {
            disabledExtensions.insert(extensionId)
            // Call onDeactivate if we have an instance
            if let instance = extensionInstances[extensionId] {
                instance.onDeactivate()
            }
        }
    }

    /// Check whether an extension is enabled
    public func isEnabled(_ extensionId: String) -> Bool {
        return !disabledExtensions.contains(extensionId)
    }

    // MARK: - Extension Info

    /// Get metadata about all registered extensions
    public func registeredExtensions() -> [ExtensionInfo] {
        return registeredTypes.values.map { extType in
            let commands = extType.commandDescriptors.map { desc in
                ExtensionCommandInfo(
                    verb: desc.verb,
                    syntax: desc.syntax,
                    description: desc.description
                )
            }
            let configs = extType.configDescriptors.map { desc in
                ExtensionConfigInfo(
                    key: desc.key,
                    displayName: desc.displayName,
                    type: desc.type.rawValue,
                    defaultValue: desc.defaultValue,
                    description: desc.description
                )
            }
            return ExtensionInfo(
                identifier: extType.identifier,
                displayName: extType.displayName,
                version: extType.version,
                author: extType.author,
                description: extType.extensionDescription,
                targetApplication: extType.targetApplication,
                systemImageName: extType.systemImageName,
                commandCount: extType.supportedCommands.count,
                commands: commands,
                configDescriptors: configs,
                isEnabled: isEnabled(extType.identifier)
            )
        }.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Extension Configuration

    /// Get a config value for an extension
    public func getConfig(extensionId: String, key: String) -> String? {
        if let value = extensionConfigs[extensionId]?[key] {
            return value
        }
        // Return default value from descriptor
        return registeredTypes[extensionId]?.configDescriptors.first { $0.key == key }?.defaultValue
    }

    /// Set a config value for an extension
    public func setConfig(extensionId: String, key: String, value: String) {
        if extensionConfigs[extensionId] == nil {
            extensionConfigs[extensionId] = [:]
        }
        extensionConfigs[extensionId]?[key] = value
    }

    // MARK: - Execution Hooks

    /// Get all enabled extension instances for calling hooks
    public func enabledInstances() -> [DSLExtension] {
        var instances: [DSLExtension] = []
        for (id, extType) in registeredTypes {
            guard !disabledExtensions.contains(id) else { continue }
            if let cached = extensionInstances[id] {
                instances.append(cached)
            } else {
                let instance = extType.init()
                extensionInstances[id] = instance
                instances.append(instance)
            }
        }
        return instances
    }
}
