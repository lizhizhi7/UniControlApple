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
        }
    }

    private func executeAction(_ action: Action) -> CommandResult {
        switch action {
        case .click:
            guard let element = context.currentElement else {
                return .failure(error: "No element selected. Use 'find' first.")
            }
            if clickElement(element) {
                return .success(value: nil)
            }
            return .failure(error: "Click failed")

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
