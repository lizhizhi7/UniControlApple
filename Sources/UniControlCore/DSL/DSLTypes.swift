//
//  DSLTypes.swift
//  UniControl
//
//  DSL type definitions for automation workflows
//

import Foundation
import ApplicationServices
import CoreGraphics

// MARK: - State Information Structs

/// Codable wrapper for CGPoint
public struct CGPointInfo: Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(from point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
}

/// Codable wrapper for CGSize
public struct CGSizeInfo: Codable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public init(from size: CGSize) {
        self.width = Double(size.width)
        self.height = Double(size.height)
    }
}

/// Rich element information returned by find and getelement commands
public struct ElementInfo: Codable, Sendable {
    public let role: String?
    public let roleDescription: String?
    public let title: String?
    public let description: String?
    public let value: String?
    public let enabled: Bool
    public let focused: Bool
    public let selected: Bool
    public let expanded: Bool?
    public let position: CGPointInfo?
    public let size: CGSizeInfo?
    public let actions: [String]
    public let childrenCount: Int

    public init(
        role: String?,
        roleDescription: String?,
        title: String?,
        description: String?,
        value: String?,
        enabled: Bool,
        focused: Bool,
        selected: Bool,
        expanded: Bool?,
        position: CGPointInfo?,
        size: CGSizeInfo?,
        actions: [String],
        childrenCount: Int
    ) {
        self.role = role
        self.roleDescription = roleDescription
        self.title = title
        self.description = description
        self.value = value
        self.enabled = enabled
        self.focused = focused
        self.selected = selected
        self.expanded = expanded
        self.position = position
        self.size = size
        self.actions = actions
        self.childrenCount = childrenCount
    }
}

/// System information (OS, machine, user)
public struct SystemInfo: Codable, Sendable {
    public let osVersion: String
    public let osBuild: String
    public let hostname: String
    public let architecture: String
    public let username: String
    public let homeDirectory: String

    public init(
        osVersion: String,
        osBuild: String,
        hostname: String,
        architecture: String,
        username: String,
        homeDirectory: String
    ) {
        self.osVersion = osVersion
        self.osBuild = osBuild
        self.hostname = hostname
        self.architecture = architecture
        self.username = username
        self.homeDirectory = homeDirectory
    }
}

/// Window information
public struct WindowInfo: Codable, Sendable {
    public let title: String?
    public let role: String?
    public let subrole: String?
    public let position: CGPointInfo?
    public let size: CGSizeInfo?
    public let isMain: Bool
    public let isMinimized: Bool
    public let isFullScreen: Bool
    public let isFrontmost: Bool      // System's frontmost window
    public let isWorking: Bool        // UniControl's current working window
    public let appName: String?
    public let appPID: Int32

    public init(
        title: String?,
        role: String?,
        subrole: String?,
        position: CGPointInfo?,
        size: CGSizeInfo?,
        isMain: Bool,
        isMinimized: Bool,
        isFullScreen: Bool,
        isFrontmost: Bool = false,
        isWorking: Bool = false,
        appName: String?,
        appPID: Int32
    ) {
        self.title = title
        self.role = role
        self.subrole = subrole
        self.position = position
        self.size = size
        self.isMain = isMain
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.isFrontmost = isFrontmost
        self.isWorking = isWorking
        self.appName = appName
        self.appPID = appPID
    }
}

/// Application information
public struct AppInfo: Codable, Sendable {
    public let name: String
    public let bundleIdentifier: String?
    public let pid: Int32
    public let isActive: Bool           // System's frontmost/active app
    public let isWorking: Bool          // UniControl's current working app
    public let isHidden: Bool
    public let launchDate: Date?

    public init(
        name: String,
        bundleIdentifier: String?,
        pid: Int32,
        isActive: Bool,
        isWorking: Bool = false,
        isHidden: Bool,
        launchDate: Date?
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.isActive = isActive
        self.isWorking = isWorking
        self.isHidden = isHidden
        self.launchDate = launchDate
    }
}

// MARK: - Selectors and Actions

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

extension ElementSelector: CustomStringConvertible {
    public var description: String {
        switch self {
        case .byTitle(let title): return "title \"\(title)\""
        case .byRole(let role): return "role \(role)"
        case .byTitleAndRole(let title, let role): return "title \"\(title)\" role \(role)"
        case .byIndex(let index): return "index \(index)"
        case .all: return "all elements"
        case .byState(let role, let state): return "role \(role) state \(state)"
        case .byRegex(let pattern): return "pattern \(pattern)"
        }
    }
}

/// Kind of click for coordinate-based clicking
public enum ClickKind: String {
    case left
    case right
    case double
}

/// Represents an action to perform on an element
public enum Action {
    case click
    case doubleClick
    case rightClick
    case clickAt(x: Double, y: Double, kind: ClickKind)
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

/// A verifiable condition for the `assert` command
public enum Assertion {
    case exists(ElementSelector)        // an element matching the selector exists
    case notExists(ElementSelector)     // no element matching the selector exists
    case enabled(Bool)                  // current element is enabled (true) / disabled (false)
    case value(String)                  // current element's value equals the given string
}

extension Assertion: CustomStringConvertible {
    public var description: String {
        switch self {
        case .exists(let selector): return "exists \(selector)"
        case .notExists(let selector): return "missing \(selector)"
        case .enabled(let expected): return expected ? "enabled" : "disabled"
        case .value(let expected): return "value \"\(expected)\""
        }
    }
}

/// Represents a command in the DSL
public enum Command {
    case launch(appName: String)
    case find(selector: ElementSelector)
    case perform(action: Action)
    case assert(Assertion)
    case waitFor(selector: ElementSelector, timeout: TimeInterval)
    case useWindow(titleContains: String?, saveAs: String? = nil)
    case dumpTree(maxDepth: Int)
    case screenshot(path: String?)
    case setVariable(name: String, value: String)
    case readValue(variableName: String)
    case conditional(condition: Assertion, thenCommands: [Command], elseCommands: [Command])
    case repeatBlock(count: Int, commands: [Command])
    case reset
    case log(message: String)
    case mode(ExecutionMode)
    case custom(ExtensionCommand)
    // State retrieval commands
    case getSystem
    case getWindows
    case getElement
    case getApps
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

/// Substitute `$name` / `${name}` references with variable values.
/// Unknown variables are left untouched so literal `$` text keeps working.
public func interpolateVariables(_ input: String, variables: [String: Any]) -> String {
    guard input.contains("$"), !variables.isEmpty else { return input }

    var result = ""
    var index = input.startIndex

    func isNameChar(_ c: Character, first: Bool) -> Bool {
        c.isLetter || c == "_" || (!first && c.isNumber)
    }

    while index < input.endIndex {
        let char = input[index]
        guard char == "$" else {
            result.append(char)
            index = input.index(after: index)
            continue
        }

        let afterDollar = input.index(after: index)

        // ${name}
        if afterDollar < input.endIndex, input[afterDollar] == "{" {
            if let close = input[afterDollar...].firstIndex(of: "}") {
                let name = String(input[input.index(after: afterDollar)..<close])
                if let value = variables[name] {
                    result.append("\(value)")
                    index = input.index(after: close)
                    continue
                }
            }
            result.append(char)
            index = afterDollar
            continue
        }

        // $name
        var nameEnd = afterDollar
        while nameEnd < input.endIndex, isNameChar(input[nameEnd], first: nameEnd == afterDollar) {
            nameEnd = input.index(after: nameEnd)
        }
        if nameEnd > afterDollar {
            let name = String(input[afterDollar..<nameEnd])
            if let value = variables[name] {
                result.append("\(value)")
                index = nameEnd
                continue
            }
        }

        result.append(char)
        index = afterDollar
    }

    return result
}

/// Context for executing commands
public class ExecutionContext {
    public var currentWindow: AXUIElement?
    public var currentElement: AXUIElement?
    public var foundElements: [AXUIElement] = []
    public var namedWindows: [String: AXUIElement] = [:]
    public var variables: [String: Any] = [:]
    public var mode: ExecutionMode = .continue  // Default to continue mode
    public var errorLog: [(commandIndex: Int, command: String, error: String)] = []
    public var visionElement: VisionElement?  // Vision fallback element
    public var lastScreenshot: CGImage?  // Store last captured screenshot
    public var outputCapture: OutputCapture?  // Server mode output capture

    public init() {}

    public func reset() {
        currentWindow = nil
        currentElement = nil
        foundElements = []
        namedWindows = [:]
        variables = [:]
        mode = .continue
        errorLog = []
        visionElement = nil
        lastScreenshot = nil
    }
}
