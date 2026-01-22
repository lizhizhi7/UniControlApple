//
//  DSLTypes.swift
//  UniControl
//
//  DSL type definitions for automation workflows
//

import Foundation
import ApplicationServices
import CoreGraphics

/// Represents a UI element selector
public enum ElementSelector {
    case byTitle(String)
    case byRole(String)
    case byTitleAndRole(title: String, role: String)
    case byIndex(Int)
    case all
    case byState(role: String, state: String)
    case byRegex(pattern: String)
}

/// Represents an action to perform on an element
public enum Action {
    case click
    case doubleClick
    case rightClick
    case type(String)
    case setValue(String)
    case wait(TimeInterval)
    case scroll(direction: String)
    case pressKey(combo: String)
    case selectMenuItem(path: String)
    case openMenu(name: String)
    case increment
    case decrement
    case focus
    case check
    case uncheck
    case expand
    case collapse
}

/// Represents a command in the DSL
public enum Command {
    case launch(appName: String)
    case find(selector: ElementSelector)
    case perform(action: Action)
    case assert(condition: String)
    case log(message: String)
    case mode(ExecutionMode)
    case custom(ExtensionCommand)
}

/// Execution mode for error handling
public enum ExecutionMode {
    case strict      // Stop immediately on error
    case `continue`  // Log errors and continue, show summary
    case interactive // Pause and prompt user on errors
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

/// Vision-detected element (from OCR fallback)
public struct VisionElement {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float
    public let windowOrigin: CGPoint

    public init(text: String, boundingBox: CGRect, confidence: Float, windowOrigin: CGPoint) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.windowOrigin = windowOrigin
    }

    /// Get screen coordinates of the center of this element
    public var screenCenter: CGPoint {
        return CGPoint(
            x: windowOrigin.x + boundingBox.origin.x + boundingBox.width / 2,
            y: windowOrigin.y + boundingBox.origin.y + boundingBox.height / 2
        )
    }
}

/// Context for executing commands
public class ExecutionContext {
    public var currentWindow: AXUIElement?
    public var currentElement: AXUIElement?
    public var foundElements: [AXUIElement] = []
    public var variables: [String: Any] = [:]
    public var mode: ExecutionMode = .continue  // Default to continue mode
    public var errorLog: [(commandIndex: Int, command: String, error: String)] = []
    public var visionElement: VisionElement?  // Vision fallback element
    public var lastScreenshot: CGImage?  // Store last captured screenshot

    public init() {}

    public func reset() {
        currentWindow = nil
        currentElement = nil
        foundElements = []
        variables = [:]
        mode = .continue
        errorLog = []
        visionElement = nil
        lastScreenshot = nil
    }
}
