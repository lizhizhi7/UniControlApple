//
//  MCPToolRegistry.swift
//  UniControl
//
//  MCP tool definitions generated from CommandRegistry
//

import Foundation

/// Registry of all available MCP tools for UniControl
/// Tools are generated from CommandDescriptors in CommandRegistry
public struct MCPToolRegistry {

    /// Ensure built-in commands are registered before accessing tools
    private static let _initialized: Bool = {
        BuiltInCommands.registerAll()
        return true
    }()

    /// All available tools (generated from CommandRegistry)
    public static var tools: [MCPTool] {
        _ = _initialized
        return CommandRegistry.shared.mcpTools
    }

    // MARK: - Tool Lookup

    /// Find a tool by name
    public static func tool(named name: String) -> MCPTool? {
        _ = _initialized
        return tools.first { $0.name == name }
    }

    /// Check if a tool exists
    public static func hasTool(named name: String) -> Bool {
        _ = _initialized
        return CommandRegistry.shared.hasMCPTool(name)
    }

    /// Get the command descriptor for a tool
    public static func descriptor(forTool name: String) -> CommandDescriptor? {
        _ = _initialized
        return CommandRegistry.shared.descriptor(forMCPName: name)
    }
}
