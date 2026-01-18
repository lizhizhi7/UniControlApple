//
//  DSLTypes.swift
//  UniControl
//
//  DSL type definitions for automation workflows
//

import Foundation
import ApplicationServices

/// Represents a UI element selector
public enum ElementSelector {
    case byTitle(String)
    case byRole(String)
    case byTitleAndRole(title: String, role: String)
    case byIndex(Int)
    case all
}

/// Represents an action to perform on an element
public enum Action {
    case click
    case type(String)
    case setValue(String)
    case wait(TimeInterval)
}

/// Represents a command in the DSL
public enum Command {
    case launch(appName: String)
    case find(selector: ElementSelector)
    case perform(action: Action)
    case assert(condition: String)
    case log(message: String)
}

/// Result of executing a command
public enum CommandResult {
    case success(value: Any?)
    case failure(error: String)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Context for executing commands
public class ExecutionContext {
    public var currentWindow: AXUIElement?
    public var currentElement: AXUIElement?
    public var foundElements: [AXUIElement] = []
    public var variables: [String: Any] = [:]

    public init() {}

    public func reset() {
        currentWindow = nil
        currentElement = nil
        foundElements = []
        variables = [:]
    }
}
