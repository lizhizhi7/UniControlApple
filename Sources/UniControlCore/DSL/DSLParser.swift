//
//  DSLParser.swift
//  UniControl
//
//  Parser for text-based DSL scripts
//

import Foundation

/// Simple DSL parser for text-based commands
public class DSLParser {
    public static func parse(_ script: String) -> [Command] {
        var commands: [Command] = []
        let lines = script.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }

            // Parse command
            if let command = parseCommand(trimmed) {
                commands.append(command)
            }
        }

        return commands
    }

    private static func parseCommand(_ line: String) -> Command? {
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let verb = parts.first?.lowercased() else { return nil }

        switch verb {
        case "launch":
            if parts.count >= 2 {
                let appName = parts[1...].joined(separator: " ")
                return .launch(appName: appName)
            }

        case "find":
            if parts.count >= 2 {
                let selector = parseSelector(Array(parts[1...]))
                return .find(selector: selector)
            }

        case "click":
            return .perform(action: .click)

        case "doubleclick":
            return .perform(action: .doubleClick)

        case "rightclick":
            return .perform(action: .rightClick)

        case "type":
            if parts.count >= 2 {
                let text = parts[1...].joined(separator: " ")
                return .perform(action: .type(text))
            }

        case "wait":
            if parts.count >= 2, let seconds = Double(parts[1]) {
                return .perform(action: .wait(seconds))
            }

        case "scroll":
            if parts.count >= 2 {
                let direction = parts[1]
                return .perform(action: .scroll(direction: direction))
            }

        case "presskey":
            if parts.count >= 2 {
                let combo = parts[1...].joined(separator: " ")
                return .perform(action: .pressKey(combo: combo))
            }

        case "selectmenuitem":
            if parts.count >= 2 {
                let path = parts[1...].joined(separator: " ")
                return .perform(action: .selectMenuItem(path: path))
            }

        case "openmenu":
            if parts.count >= 2 {
                let name = parts[1...].joined(separator: " ")
                return .perform(action: .openMenu(name: name))
            }

        case "increment":
            return .perform(action: .increment)

        case "decrement":
            return .perform(action: .decrement)

        case "focus":
            return .perform(action: .focus)

        case "check":
            return .perform(action: .check)

        case "uncheck":
            return .perform(action: .uncheck)

        case "expand":
            return .perform(action: .expand)

        case "collapse":
            return .perform(action: .collapse)

        case "mode":
            if parts.count >= 2 {
                let modeName = parts[1].lowercased()
                switch modeName {
                case "strict":
                    return .mode(.strict)
                case "continue":
                    return .mode(.continue)
                case "interactive":
                    return .mode(.interactive)
                default:
                    print("⚠️  Unknown mode: \(modeName), using continue mode")
                    return .mode(.continue)
                }
            }

        case "log":
            if parts.count >= 2 {
                let message = parts[1...].joined(separator: " ")
                return .log(message: message)
            }

        // State retrieval commands
        case "getsystem":
            return .getSystem

        case "getwindows":
            return .getWindows

        case "getelement":
            return .getElement

        case "getapps":
            return .getApps

        default:
            // Check if an extension can handle this verb
            if ExtensionRegistry.shared.canHandle(verb: verb) {
                if let extCmd = ExtensionRegistry.shared.parse(line, verb: verb, parts: parts) {
                    return .custom(extCmd)
                }
            }
        }

        return nil
    }

    private static func parseSelector(_ parts: [String]) -> ElementSelector {
        if parts.isEmpty { return .all }

        let joined = parts.joined(separator: " ")

        // Check for state specification: "role: AXButton state: enabled"
        if let stateIndex = parts.firstIndex(of: "state:") {
            if let roleIndex = parts.firstIndex(of: "role:") ?? parts.firstIndex(of: "type:") {
                let role = parts[(roleIndex + 1)..<stateIndex].joined(separator: " ")
                let state = parts[(stateIndex + 1)...].joined(separator: " ")
                return .byState(role: role, state: state)
            }
        }

        // Check for regex pattern: "pattern: ^Submit.*"
        if let patternIndex = parts.firstIndex(of: "pattern:") {
            let pattern = parts[(patternIndex + 1)...].joined(separator: " ")
            return .byRegex(pattern: pattern)
        }

        // Check for explicit index specification: "index: 5"
        if let indexKeywordIndex = parts.firstIndex(of: "index:") {
            let indexStr = parts[(indexKeywordIndex + 1)...].joined(separator: " ")
            if let index = Int(indexStr) {
                return .byIndex(index)
            }
        }

        // Check for role specification
        if let roleIndex = parts.firstIndex(of: "role:") ?? parts.firstIndex(of: "type:") {
            let role = parts[(roleIndex + 1)...].joined(separator: " ")

            if roleIndex > 0 {
                let title = parts[0..<roleIndex].joined(separator: " ")
                return .byTitleAndRole(title: title, role: role)
            } else {
                return .byRole(role)
            }
        }

        // Default to title search (including numeric titles like "7", "5", etc.)
        // This allows finding Calculator buttons and other numeric elements
        return .byTitle(joined)
    }
}
