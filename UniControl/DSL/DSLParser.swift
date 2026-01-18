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

        case "type":
            if parts.count >= 2 {
                let text = parts[1...].joined(separator: " ")
                return .perform(action: .type(text))
            }

        case "wait":
            if parts.count >= 2, let seconds = Double(parts[1]) {
                return .perform(action: .wait(seconds))
            }

        case "log":
            if parts.count >= 2 {
                let message = parts[1...].joined(separator: " ")
                return .log(message: message)
            }

        default:
            break
        }

        return nil
    }

    private static func parseSelector(_ parts: [String]) -> ElementSelector {
        if parts.isEmpty { return .all }

        let joined = parts.joined(separator: " ")

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

        // Check for index
        if let index = Int(joined) {
            return .byIndex(index)
        }

        // Default to title search
        return .byTitle(joined)
    }
}
