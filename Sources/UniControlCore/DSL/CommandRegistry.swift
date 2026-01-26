//
//  CommandRegistry.swift
//  UniControl
//
//  Central registry for all command descriptors.
//  Provides lookup by DSL verb and MCP name, and generates MCP tools.
//

import Foundation

/// Central registry for command descriptors
/// Manages built-in and extension commands, provides lookup and MCP tool generation
public final class CommandRegistry: @unchecked Sendable {
    public static let shared = CommandRegistry()

    /// All registered descriptors by verb (including aliases)
    private var descriptorsByVerb: [String: CommandDescriptor] = [:]

    /// All registered descriptors by MCP name
    private var descriptorsByMCPName: [String: CommandDescriptor] = [:]

    /// Ordered list of all unique descriptors
    private var _allDescriptors: [CommandDescriptor] = []

    /// Thread-safe lock
    private let lock = NSLock()

    private init() {}

    // MARK: - Registration

    /// Register a command descriptor
    /// - Parameter descriptor: The descriptor to register
    public func register(_ descriptor: CommandDescriptor) {
        lock.lock()
        defer { lock.unlock() }

        // Register by main verb
        let lowerVerb = descriptor.verb.lowercased()
        if descriptorsByVerb[lowerVerb] != nil {
            // Allow overwriting - extension commands may override built-ins
        }
        descriptorsByVerb[lowerVerb] = descriptor

        // Register by aliases
        for alias in descriptor.aliases {
            let lowerAlias = alias.lowercased()
            descriptorsByVerb[lowerAlias] = descriptor
        }

        // Register by MCP name
        let lowerMCP = descriptor.mcpName.lowercased()
        descriptorsByMCPName[lowerMCP] = descriptor

        // Add to all descriptors if not already present
        if !_allDescriptors.contains(where: { $0.verb == descriptor.verb && $0.extensionId == descriptor.extensionId }) {
            _allDescriptors.append(descriptor)
        }
    }

    /// Register multiple descriptors at once
    /// - Parameter descriptors: Array of descriptors to register
    public func registerAll(_ descriptors: [CommandDescriptor]) {
        for descriptor in descriptors {
            register(descriptor)
        }
    }

    // MARK: - Lookup

    /// Get descriptor for a DSL verb (case-insensitive)
    /// - Parameter verb: The DSL verb to look up
    /// - Returns: The descriptor if found
    public func descriptor(forVerb verb: String) -> CommandDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return descriptorsByVerb[verb.lowercased()]
    }

    /// Get descriptor for an MCP tool name (case-insensitive)
    /// - Parameter mcpName: The MCP tool name to look up
    /// - Returns: The descriptor if found
    public func descriptor(forMCPName mcpName: String) -> CommandDescriptor? {
        lock.lock()
        defer { lock.unlock() }
        return descriptorsByMCPName[mcpName.lowercased()]
    }

    /// Check if a verb is registered
    /// - Parameter verb: The DSL verb to check
    /// - Returns: true if the verb is registered
    public func hasVerb(_ verb: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return descriptorsByVerb[verb.lowercased()] != nil
    }

    /// Check if an MCP tool name is registered
    /// - Parameter mcpName: The MCP name to check
    /// - Returns: true if the MCP name is registered
    public func hasMCPTool(_ mcpName: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return descriptorsByMCPName[mcpName.lowercased()] != nil
    }

    // MARK: - Accessors

    /// All registered descriptors (excluding aliases)
    public var allDescriptors: [CommandDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return _allDescriptors
    }

    /// All registered verbs (including aliases)
    public var allVerbs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(descriptorsByVerb.keys).sorted()
    }

    /// All registered MCP tool names
    public var allMCPNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(descriptorsByMCPName.keys).sorted()
    }

    /// Descriptors grouped by category
    public var descriptorsByCategory: [CommandCategory: [CommandDescriptor]] {
        lock.lock()
        defer { lock.unlock() }

        var result: [CommandCategory: [CommandDescriptor]] = [:]
        for descriptor in _allDescriptors {
            result[descriptor.category, default: []].append(descriptor)
        }
        return result
    }

    /// Built-in descriptors only (extensionId is nil)
    public var builtInDescriptors: [CommandDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return _allDescriptors.filter { $0.extensionId == nil }
    }

    /// Extension descriptors only (extensionId is not nil)
    public var extensionDescriptors: [CommandDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return _allDescriptors.filter { $0.extensionId != nil }
    }

    /// Get extension descriptors for a specific extension
    /// - Parameter extensionId: The extension identifier
    /// - Returns: Array of descriptors for that extension
    public func descriptors(forExtension extensionId: String) -> [CommandDescriptor] {
        lock.lock()
        defer { lock.unlock() }
        return _allDescriptors.filter { $0.extensionId == extensionId }
    }

    // MARK: - MCP Generation

    /// Generate MCP tools from all registered descriptors
    public var mcpTools: [MCPTool] {
        lock.lock()
        defer { lock.unlock() }
        return _allDescriptors.map { $0.toMCPTool() }
    }

    /// Generate MCP tools for built-in commands only
    public var builtInMCPTools: [MCPTool] {
        lock.lock()
        defer { lock.unlock() }
        return _allDescriptors.filter { $0.extensionId == nil }.map { $0.toMCPTool() }
    }

    // MARK: - Reset

    /// Clear all registered descriptors (mainly for testing)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        descriptorsByVerb.removeAll()
        descriptorsByMCPName.removeAll()
        _allDescriptors.removeAll()
    }
}
