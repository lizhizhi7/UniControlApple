//
//  DSLExecutor.swift
//  UniControl
//
//  Executes DSL commands with context management
//

import Foundation
import ApplicationServices
import Vision
import CoreGraphics

public class DSLExecutor {
    public let context = ExecutionContext()

    public init() {}

    // MARK: - Output Helpers

    /// Output a message - routes to outputCapture if in server mode, otherwise prints
    private func output(_ message: String, level: LogLevel = .info) {
        if let capture = context.outputCapture {
            capture.log(message, level: level)
        } else {
            let prefix: String
            switch level {
            case .info:
                prefix = ""
            case .success:
                prefix = "✓ "
            case .error:
                prefix = "❌ "
            case .warning:
                prefix = "⚠️ "
            case .debug:
                prefix = "🔍 "
            }
            print("\(prefix)\(message)")
        }
    }

    /// Record a command result for server mode
    private func recordResult(_ index: Int, command: String, result: CommandResult) {
        context.outputCapture?.recordResult(index, command: command, result: result)
    }

    public func execute(_ commands: [Command], verbose: Bool = true) -> Bool {
        var successCount = 0
        var failureCount = 0

        for (index, command) in commands.enumerated() {
            // Interactive mode: prompt before each command
            if context.mode == .interactive {
                if !promptForCommand(command, index: index, total: commands.count) {
                    output("Skipped command", level: .info)
                    continue
                }
            }

            if verbose {
                output("[\(index + 1)/\(commands.count)] Executing: \(command)", level: .info)
            }

            let result = executeCommand(command, index: index)

            // Record result for server mode
            recordResult(index, command: "\(command)", result: result)

            if case .failure(let error) = result {
                failureCount += 1

                // Log error for continue mode
                if context.mode == .continue {
                    context.errorLog.append((commandIndex: index, command: "\(command)", error: error))
                    output("Error: \(error)", level: .error)
                    // Continue to next command
                } else if context.mode == .strict {
                    // Stop immediately
                    output("Error: \(error)", level: .error)
                    output("Stopped execution (strict mode)", level: .error)
                    printErrorSummary(successCount: successCount, failureCount: failureCount + 1, total: commands.count)
                    return false
                } else if context.mode == .interactive {
                    // Interactive mode: prompt on error
                    output("Error: \(error)", level: .error)
                    if !promptOnError(error: error, command: command) {
                        output("User chose to quit", level: .error)
                        printErrorSummary(successCount: successCount, failureCount: failureCount + 1, total: commands.count)
                        return false
                    }
                }
            } else {
                successCount += 1
                if verbose {
                    output("Success", level: .success)
                }
            }
        }

        // Print summary for continue mode
        if context.mode == .continue && !context.errorLog.isEmpty {
            printErrorSummary(successCount: successCount, failureCount: failureCount, total: commands.count)
        }

        return failureCount == 0
    }

    private func executeCommand(_ command: Command, index: Int = 0) -> CommandResult {
        // Call willExecuteCommand hooks on all enabled extensions
        let enabledExtensions = ExtensionRegistry.shared.enabledInstances()
        for ext in enabledExtensions {
            ext.willExecuteCommand(command, context: context)
        }

        let result = executeCommandCore(command, index: index)

        // Call didExecuteCommand hooks on all enabled extensions
        for ext in enabledExtensions {
            ext.didExecuteCommand(command, result: result, context: context)
        }

        return result
    }

    private func executeCommandCore(_ command: Command, index: Int = 0) -> CommandResult {
        switch command {
        case .launch(let appName):
            return executeLaunch(appName)

        case .find(let selector):
            return executeFind(selector)

        case .perform(let action):
            return executeAction(action)

        case .log(let message):
            output(message, level: .info)
            return .success(value: nil)

        case .assert(_):
            return .success(value: nil)

        case .mode(let executionMode):
            context.mode = executionMode
            output("Switched to \(executionMode) mode", level: .info)
            return .success(value: nil)

        case .custom(let extensionCommand):
            return executeCustomCommand(extensionCommand)

        case .getSystem:
            return executeGetSystem()

        case .getWindows:
            return executeGetWindows()

        case .getElement:
            return executeGetElement()

        case .getApps:
            return executeGetApps()
        }
    }

    private func executeCustomCommand(_ command: ExtensionCommand) -> CommandResult {
        return ExtensionRegistry.shared.execute(command, context: context, verbose: true)
    }

    private func executeLaunch(_ appName: String) -> CommandResult {
        var completed = false
        var result: CommandResult = .failure(error: "Timeout")

        launchAppAndGetFocusedWindow(appName: appName) { window in
            if let win = window {
                self.context.currentWindow = win
                result = .success(value: win)
            } else {
                result = .failure(error: "Could not get window for \(appName)")
            }
            completed = true
        }

        // Wait for completion
        let startTime = Date()
        while !completed && Date().timeIntervalSince(startTime) < 15 {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }

        return result
    }

    private func executeFind(_ selector: ElementSelector) -> CommandResult {
        guard let window = context.currentWindow else {
            return .failure(error: "No active window. Launch an app first.")
        }

        switch selector {
        case .byTitle(let title):
            if let element = findElement(in: window, title: title) {
                context.currentElement = element
                let elementInfo = buildElementInfo(element)
                return .success(value: elementInfo)
            }

            // Try vision fallback if available (macOS 12.3+)
            if #available(macOS 12.3, *) {
                let visionResult = tryVisionFallback(searchText: title, verbose: true)
                if visionResult.isSuccess {
                    return visionResult
                }
            }

            // Clear current element since search failed
            context.currentElement = nil

            // Use suggestion engine
            let suggestions = generateNotFoundMessage(window: window, searchTerm: title)
            return .failure(error: "Could not find element with title: \(title)\n\n\(suggestions)")

        case .byRole(let role):
            let elements = findElements(in: window, role: role)
            if let first = elements.first {
                context.currentElement = first
                context.foundElements = elements
                let elementInfos = elements.map { buildElementInfo($0) }
                return .success(value: elementInfos)
            }
            // Clear current element since search failed
            context.currentElement = nil
            return .failure(error: "Could not find elements with role: \(role)")

        case .byTitleAndRole(let title, let role):
            if let element = findElement(in: window, title: title, role: role) {
                context.currentElement = element
                let elementInfo = buildElementInfo(element)
                return .success(value: elementInfo)
            }

            // Try vision fallback if available (macOS 12.3+)
            if #available(macOS 12.3, *) {
                let visionResult = tryVisionFallback(searchText: title, verbose: true)
                if visionResult.isSuccess {
                    return visionResult
                }
            }

            // Clear current element since search failed
            context.currentElement = nil

            // Use suggestion engine
            let suggestions = generateNotFoundMessage(window: window, searchTerm: title, role: role)
            return .failure(error: "Could not find element with title: \(title) and role: \(role)\n\n\(suggestions)")

        case .byIndex(let index):
            if index >= 0 && index < context.foundElements.count {
                context.currentElement = context.foundElements[index]
                let elementInfo = buildElementInfo(context.foundElements[index])
                return .success(value: elementInfo)
            }
            // Clear current element since index is invalid
            context.currentElement = nil
            return .failure(error: "Index \(index) out of bounds (found elements: \(context.foundElements.count))")

        case .all:
            let elements = findElements(in: window)
            context.foundElements = elements
            let elementInfos = elements.map { buildElementInfo($0) }
            return .success(value: elementInfos)

        case .byState(let role, let state):
            // Find all elements with specified role
            let elements = findElements(in: window, role: role)

            // Filter by state attribute
            var matchingElements: [AXUIElement] = []
            for element in elements {
                // Check various state-related attributes
                let enabled = getAttribute(element, attribute: kAXEnabledAttribute as CFString) as? Bool
                let focused = getAttribute(element, attribute: kAXFocusedAttribute as CFString) as? Bool

                let stateLower = state.lowercased()
                if stateLower == "enabled" && enabled == true {
                    matchingElements.append(element)
                } else if stateLower == "disabled" && enabled == false {
                    matchingElements.append(element)
                } else if stateLower == "focused" && focused == true {
                    matchingElements.append(element)
                }
            }

            if let first = matchingElements.first {
                context.currentElement = first
                context.foundElements = matchingElements
                let elementInfos = matchingElements.map { buildElementInfo($0) }
                return .success(value: elementInfos)
            }
            // Clear current element since search failed
            context.currentElement = nil
            return .failure(error: "Could not find elements with role: \(role) and state: \(state)")

        case .byRegex(let pattern):
            // Find all elements and filter by regex pattern
            let allElements = findElements(in: window)

            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return .failure(error: "Invalid regex pattern: \(pattern)")
            }

            var matchingElements: [AXUIElement] = []
            for element in allElements {
                // Try matching against multiple text attributes
                let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
                let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
                let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String

                let textsToCheck = [title, description, value].compactMap { $0 }

                for text in textsToCheck {
                    let range = NSRange(text.startIndex..., in: text)
                    if regex.firstMatch(in: text, options: [], range: range) != nil {
                        matchingElements.append(element)
                        break
                    }
                }
            }

            if let first = matchingElements.first {
                context.currentElement = first
                context.foundElements = matchingElements
                let elementInfos = matchingElements.map { buildElementInfo($0) }
                return .success(value: elementInfos)
            }
            // Clear current element since search failed
            context.currentElement = nil
            return .failure(error: "Could not find elements matching pattern: \(pattern)")
        }
    }

    private func executeAction(_ action: Action) -> CommandResult {
        switch action {
        case .click:
            // Check if we have a vision element (fallback mode)
            if context.visionElement != nil && context.currentElement == nil {
                if #available(macOS 12.3, *) {
                    return executeActionWithVision(action, verbose: true)
                }
            }

            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            // Use retry logic directly (includes all methods and -25206 handling)
            if clickElementWithRetry(element, debug: true) {
                return .success(value: nil)
            }
            return .failure(error: "Click failed - tried all methods")

        case .doubleClick:
            // Check if we have a vision element (fallback mode)
            if context.visionElement != nil && context.currentElement == nil {
                if #available(macOS 12.3, *) {
                    return executeActionWithVision(action, verbose: true)
                }
            }

            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if doubleClickElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Double-click failed")

        case .rightClick:
            // Check if we have a vision element (fallback mode)
            if context.visionElement != nil && context.currentElement == nil {
                if #available(macOS 12.3, *) {
                    return executeActionWithVision(action, verbose: true)
                }
            }

            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if rightClickElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Right-click failed")

        case .type(let text):
            // Check if we have a vision element (fallback mode)
            if context.visionElement != nil && context.currentElement == nil {
                if #available(macOS 12.3, *) {
                    return executeActionWithVision(action, verbose: true)
                }
            }

            // If no element selected, type to whatever is currently focused
            if context.currentElement == nil {
                if typeAtCoordinate(text: text) {
                    return .success(value: nil)
                }
                return .failure(error: "Failed to type text (no element selected)")
            }
            return typeText(text, into: context.currentElement!)

        case .setValue(let value):
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            return setValue(value, for: element)

        case .wait(let seconds):
            Thread.sleep(forTimeInterval: seconds)
            return .success(value: nil)

        case .scroll(let direction):
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if scrollElement(element, direction: direction) {
                return .success(value: nil)
            }
            return .failure(error: "Scroll failed: \(direction)")

        case .pressKey(let combo):
            if pressKeyCombo(combo) {
                return .success(value: nil)
            }
            return .failure(error: "Key press failed: \(combo)")

        case .selectMenuItem(let path):
            guard let window = context.currentWindow else {
                return .failure(error: "No window available")
            }
            if selectMenuItemByPath(in: window, path: path) {
                return .success(value: nil)
            }
            return .failure(error: "Menu selection failed: \(path)")

        case .openMenu(let name):
            guard let window = context.currentWindow else {
                return .failure(error: "No window available")
            }
            if let _ = openMenu(in: window, name: name) {
                return .success(value: nil)
            }
            return .failure(error: "Menu open failed: \(name)")

        case .increment:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if incrementElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Increment failed")

        case .decrement:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if decrementElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Decrement failed")

        case .focus:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if focusElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Focus failed")

        case .check:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if checkElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Check failed")

        case .uncheck:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if uncheckElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Uncheck failed")

        case .expand:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if expandElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Expand failed")

        case .collapse:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if collapseElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Collapse failed")
        }
    }

    private func typeText(_ text: String, into element: AXUIElement) -> CommandResult {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        if result == .success {
            return .success(value: nil)
        }
        return .failure(error: "Failed to type text: \(result.rawValue)")
    }

    private func setValue(_ value: String, for element: AXUIElement) -> CommandResult {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)
        if result == .success {
            return .success(value: nil)
        }
        return .failure(error: "Failed to set value: \(result.rawValue)")
    }

    // MARK: - Interactive Mode Helpers

    /// Prompt user before executing command (interactive mode)
    private func promptForCommand(_ command: Command, index: Int, total: Int) -> Bool {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("[\(index + 1)/\(total)] Next: \(command)")
        print("\nCurrent context:")
        if let window = context.currentWindow {
            let title = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String ?? "Unknown"
            print("  Window: \"\(title)\"")
        } else {
            print("  Window: (none)")
        }
        if context.currentElement != nil {
            print("  Element: (selected)")
        } else {
            print("  Element: (none)")
        }
        print("\nOptions:")
        print("  [c] Continue - Execute this command")
        print("  [s] Skip     - Skip this command")
        print("  [i] Inspect  - Show element details")
        print("  [q] Quit     - Stop execution")
        print("\nYour choice: ", terminator: "")

        guard let input = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return false
        }

        switch input {
        case "c", "continue", "":
            return true
        case "s", "skip":
            return false
        case "i", "inspect":
            showInspectionMode()
            return promptForCommand(command, index: index, total: total) // Re-prompt after inspection
        case "q", "quit":
            return false
        default:
            print("Invalid choice. Please enter c, s, i, or q.")
            return promptForCommand(command, index: index, total: total)
        }
    }

    /// Prompt user on error (interactive mode)
    private func promptOnError(error: String, command: Command) -> Bool {
        print("\nError occurred. Options:")
        print("  [c] Continue - Continue to next command")
        print("  [r] Retry    - Retry this command")
        print("  [q] Quit     - Stop execution")
        print("\nYour choice: ", terminator: "")

        guard let input = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return false
        }

        switch input {
        case "c", "continue":
            return true
        case "r", "retry":
            // Note: Retry not yet implemented, treat as continue
            print("⚠️  Retry not yet implemented, continuing...")
            return true
        case "q", "quit":
            return false
        default:
            print("Invalid choice. Please enter c, r, or q.")
            return promptOnError(error: error, command: command)
        }
    }

    /// Show inspection mode (element tree)
    private func showInspectionMode() {
        print("\n🔍 Inspection Mode\n")

        guard let window = context.currentWindow else {
            print("No window available to inspect.")
            return
        }

        let windowTitle = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String ?? "Unknown"
        print("Window: \"\(windowTitle)\"")

        // Show top-level children
        if let children = getAttribute(window, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] {
            print("\nWindow hierarchy (top 2 levels):")
            print("└─ \(windowTitle) (AXWindow)")

            for (index, child) in children.prefix(5).enumerated() {
                let role = getAttribute(child, attribute: kAXRoleAttribute as CFString) as? String ?? "Unknown"
                let title = getAttribute(child, attribute: kAXTitleAttribute as CFString) as? String
                let enabled = getAttribute(child, attribute: kAXEnabledAttribute as CFString) as? Bool ?? false

                let prefix = (index == children.count - 1) ? "└─" : "├─"
                let titleStr = title.map { " \"\($0)\"" } ?? ""
                let enabledStr = enabled ? " ✓ enabled" : " ✗ disabled"

                print("   \(prefix) \(role)\(titleStr)\(enabledStr)")
            }

            if children.count > 5 {
                print("   ... and \(children.count - 5) more")
            }
        }

        if let element = context.currentElement {
            print("\nCurrent element:")
            printElementInfo(element)
        } else {
            print("\nCurrent element: (none)")
        }

        print("\n[Press Enter to return]")
        _ = readLine()
    }

    /// Print error summary (continue mode)
    private func printErrorSummary(successCount: Int, failureCount: Int, total: Int) {
        output("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", level: .info)
        output("Execution Summary", level: .info)
        output("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", level: .info)
        output("Total commands: \(total)", level: .info)
        output("Succeeded: \(successCount)", level: .success)
        output("Failed: \(failureCount)", level: .error)

        if !context.errorLog.isEmpty {
            output("Failed commands:", level: .error)
            for error in context.errorLog {
                output("  [\(error.commandIndex + 1)] \(error.command)", level: .error)
                output("      Error: \(error.error)", level: .error)
            }
        }
        output("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", level: .info)
    }

    // MARK: - Vision Fallback Methods

    /// Try vision fallback for finding an element by text
    /// - Parameters:
    ///   - searchText: The text to search for
    ///   - verbose: Whether to print debug output
    /// - Returns: CommandResult with success if found, failure otherwise
    @available(macOS 12.3, *)
    private func tryVisionFallback(searchText: String, verbose: Bool) -> CommandResult {
        guard let window = context.currentWindow else {
            return .failure(error: "No active window for vision fallback")
        }

        if verbose {
            output("Trying vision fallback (OCR)...", level: .debug)
        }

        // Capture screenshot
        guard let screenshot = captureWindowSync(window) else {
            if verbose {
                output("Failed to capture screenshot", level: .error)
            }
            return .failure(error: "Screenshot capture failed")
        }

        // Store screenshot for later verification
        context.lastScreenshot = screenshot

        // Run OCR to find text
        let matches = findText(searchText, in: screenshot, fuzzy: true, threshold: 0.6)

        if matches.isEmpty {
            if verbose {
                output("Vision fallback found no matches", level: .error)
            }
            return .failure(error: "Element not found via vision fallback")
        }

        // Use the best match (first in sorted results)
        let bestMatch = matches[0]
        let windowOrigin = getWindowOrigin(window)

        // Create VisionElement
        let visionElement = VisionElement(
            text: bestMatch.text,
            boundingBox: bestMatch.boundingBox,
            confidence: bestMatch.confidence,
            windowOrigin: windowOrigin
        )

        context.visionElement = visionElement
        context.currentElement = nil  // Clear AX element since we're using vision

        if verbose {
            output("Found via vision: \"\(bestMatch.text)\" (confidence: \(Int(bestMatch.confidence * 100))%)", level: .success)
        }

        return .success(value: visionElement)
    }

    /// Execute action using vision element (coordinate-based)
    /// - Parameters:
    ///   - action: The action to perform
    ///   - verbose: Whether to print debug output
    /// - Returns: CommandResult with success/failure
    @available(macOS 12.3, *)
    private func executeActionWithVision(_ action: Action, verbose: Bool) -> CommandResult {
        guard let visionElement = context.visionElement else {
            return .failure(error: "No vision element available")
        }

        // Get click coordinates
        let clickPoint = visionElement.screenCenter

        if verbose {
            output("Using vision coordinates: (\(Int(clickPoint.x)), \(Int(clickPoint.y)))", level: .debug)
        }

        // Capture before screenshot for verification
        let beforeScreenshot = context.lastScreenshot

        // Perform action based on type
        var success = false
        switch action {
        case .click:
            success = clickAtCoordinate(point: clickPoint)

        case .doubleClick:
            success = doubleClickAtCoordinate(point: clickPoint)

        case .rightClick:
            success = rightClickAtCoordinate(point: clickPoint)

        case .type(let text):
            // First click to focus, then type
            if clickAtCoordinate(point: clickPoint) {
                Thread.sleep(forTimeInterval: 0.2)
                success = typeAtCoordinate(text: text)
            }

        default:
            return .failure(error: "Action \(action) not supported with vision fallback")
        }

        if !success {
            return .failure(error: "Failed to execute action via coordinates")
        }

        // Verify by capturing after screenshot
        Thread.sleep(forTimeInterval: 0.5)  // Wait for UI update
        if let window = context.currentWindow,
           let afterScreenshot = captureWindowSync(window) {

            // Compare screenshots to verify action had effect
            if let beforeImage = beforeScreenshot {
                let similarity = compareImages(beforeImage, afterScreenshot)

                if verbose {
                    output("Screenshot similarity: \(Int(similarity * 100))%", level: .debug)
                }

                // If images are very different, action likely succeeded
                if similarity < 0.95 {
                    if verbose {
                        output("Action verified (UI changed)", level: .success)
                    }
                    return .success(value: nil)
                } else {
                    if verbose {
                        output("Warning: UI may not have changed", level: .warning)
                    }
                    // Still return success since action was performed
                    return .success(value: nil)
                }
            }
        }

        // Couldn't verify but action was performed
        return .success(value: nil)
    }

    // MARK: - State Retrieval Commands

    /// Execute getsystem command - get system information
    private func executeGetSystem() -> CommandResult {
        let info = getSystemInfo()
        output("System: \(info.osVersion) (\(info.architecture))", level: .info)
        output("Host: \(info.hostname), User: \(info.username)", level: .info)
        return .success(value: info)
    }

    /// Execute getwindows command - get all windows with frontmost/working markers
    private func executeGetWindows() -> CommandResult {
        // Get the working window's PID for comparison
        var workingWindowPID: pid_t = 0
        if let workingWindow = context.currentWindow {
            AXUIElementGetPid(workingWindow, &workingWindowPID)
        }
        let workingWindowTitle = context.currentWindow.flatMap {
            getAttribute($0, attribute: kAXTitleAttribute as CFString) as? String
        }

        // Get all windows with markers
        let windows = getWindowsInfoWithMarkers(workingWindowPID: workingWindowPID, workingWindowTitle: workingWindowTitle)

        if windows.isEmpty {
            return .failure(error: "No windows found")
        }

        output("Found \(windows.count) window(s):", level: .info)
        for (index, win) in windows.enumerated() {
            var markers: [String] = []
            if win.isFrontmost { markers.append("frontmost") }
            if win.isWorking { markers.append("working") }
            let markerStr = markers.isEmpty ? "" : " [\(markers.joined(separator: ", "))]"
            output("  [\(index)] \"\(win.title ?? "Untitled")\" - \(win.appName ?? "Unknown")\(markerStr)", level: .info)
        }

        return .success(value: windows)
    }

    /// Execute getelement command - get current element info
    private func executeGetElement() -> CommandResult {
        guard let element = context.currentElement else {
            return .failure(error: "No element selected. Use 'find' first.")
        }

        let info = buildElementInfo(element)
        output("Element: \(info.role ?? "unknown") - \"\(info.title ?? info.description ?? "")\"", level: .info)
        output("  enabled: \(info.enabled), focused: \(info.focused), actions: \(info.actions.joined(separator: ", "))", level: .info)
        if let pos = info.position, let size = info.size {
            output("  position: (\(Int(pos.x)), \(Int(pos.y))), size: \(Int(size.width))x\(Int(size.height))", level: .info)
        }

        return .success(value: info)
    }

    /// Execute getapps command - get all running applications with frontmost/working markers
    private func executeGetApps() -> CommandResult {
        // Get the working window's PID to identify the working app
        var workingAppPID: pid_t = 0
        if let workingWindow = context.currentWindow {
            AXUIElementGetPid(workingWindow, &workingAppPID)
        }

        // Get all apps with markers
        let apps = getRunningAppsWithMarkers(workingAppPID: workingAppPID)

        if apps.isEmpty {
            return .failure(error: "No applications found")
        }

        output("Running applications (\(apps.count)):", level: .info)
        for app in apps {
            var markers: [String] = []
            if app.isActive { markers.append("frontmost") }
            if app.isWorking { markers.append("working") }
            if app.isHidden { markers.append("hidden") }
            let markerStr = markers.isEmpty ? "" : " [\(markers.joined(separator: ", "))]"
            output("  \(app.name)\(markerStr) (PID: \(app.pid))", level: .info)
        }

        return .success(value: apps)
    }
}
