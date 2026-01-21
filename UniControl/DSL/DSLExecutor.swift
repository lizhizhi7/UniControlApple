//
//  DSLExecutor.swift
//  UniControl
//
//  Executes DSL commands with context management
//

import Foundation
import ApplicationServices

public class DSLExecutor {
    public let context = ExecutionContext()

    public init() {}

    public func execute(_ commands: [Command], verbose: Bool = true) -> Bool {
        var success = true

        for (index, command) in commands.enumerated() {
            if verbose {
                print("[\(index + 1)/\(commands.count)] Executing: \(command)")
            }

            let result = executeCommand(command)

            if case .failure(let error) = result {
                print("❌ Error: \(error)")
                success = false
                break
            } else if verbose {
                print("✓ Success")
            }
        }

        return success
    }

    private func executeCommand(_ command: Command) -> CommandResult {
        switch command {
        case .launch(let appName):
            return executeLaunch(appName)

        case .find(let selector):
            return executeFind(selector)

        case .perform(let action):
            return executeAction(action)

        case .log(let message):
            print("📝 \(message)")
            return .success(value: nil)

        case .assert(_):
            return .success(value: nil)

        case .mode(let executionMode):
            context.mode = executionMode
            print("🔧 Switched to \(executionMode) mode")
            return .success(value: nil)
        }
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
                return .success(value: element)
            }
            return .failure(error: "Could not find element with title: \(title)")

        case .byRole(let role):
            let elements = findElements(in: window, role: role)
            if let first = elements.first {
                context.currentElement = first
                context.foundElements = elements
                return .success(value: elements)
            }
            return .failure(error: "Could not find elements with role: \(role)")

        case .byTitleAndRole(let title, let role):
            if let element = findElement(in: window, title: title, role: role) {
                context.currentElement = element
                return .success(value: element)
            }
            return .failure(error: "Could not find element with title: \(title) and role: \(role)")

        case .byIndex(let index):
            if index >= 0 && index < context.foundElements.count {
                context.currentElement = context.foundElements[index]
                return .success(value: context.foundElements[index])
            }
            return .failure(error: "Index \(index) out of bounds")

        case .all:
            let elements = findElements(in: window)
            context.foundElements = elements
            return .success(value: elements)

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
                return .success(value: matchingElements)
            }
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
                return .success(value: matchingElements)
            }
            return .failure(error: "Could not find elements matching pattern: \(pattern)")
        }
    }

    private func executeAction(_ action: Action) -> CommandResult {
        switch action {
        case .click:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            // Use retry logic directly (includes all methods and -25206 handling)
            if clickElementWithRetry(element, debug: true) {
                return .success(value: nil)
            }
            return .failure(error: "Click failed - tried all methods")

        case .doubleClick:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if doubleClickElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Double-click failed")

        case .rightClick:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if rightClickElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Right-click failed")

        case .type(let text):
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            return typeText(text, into: element)

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
}
