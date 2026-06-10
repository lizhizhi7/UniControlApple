//
//  DSLParser.swift
//  UniControl
//
//  Parser for text-based DSL scripts
//

import Foundation

/// A parse error tied to a script line
public struct ParseError: Sendable, CustomStringConvertible {
    public let line: Int        // 1-based line number
    public let text: String     // the offending line
    public let message: String

    public init(line: Int, text: String, message: String) {
        self.line = line
        self.text = text
        self.message = message
    }

    public var description: String {
        "line \(line): \(message)  →  \"\(text)\""
    }
}

/// Error payload for a single unparseable command
public struct ParseFailure: Error, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}

/// Result of parsing a script: commands plus any errors found
public struct ParseOutcome {
    public let commands: [Command]
    public let errors: [ParseError]

    public var hasErrors: Bool { !errors.isEmpty }
}

/// Simple DSL parser for text-based commands
public class DSLParser {

    /// Parse a script leniently, dropping invalid lines (legacy behavior).
    /// Prefer `parseWithDiagnostics` so callers can report errors.
    public static func parse(_ script: String) -> [Command] {
        return parseWithDiagnostics(script).commands
    }

    /// Parse a script and report every invalid line with its line number.
    public static func parseWithDiagnostics(_ script: String) -> ParseOutcome {
        var commands: [Command] = []
        var errors: [ParseError] = []
        let lines = script.components(separatedBy: .newlines)

        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }

            switch parseCommand(trimmed) {
            case .success(let command):
                commands.append(command)
            case .failure(let failure):
                errors.append(ParseError(line: lineIndex + 1, text: trimmed, message: failure.message))
            }
        }

        return ParseOutcome(commands: commands, errors: errors)
    }

    private static func parseCommand(_ line: String) -> Result<Command, ParseFailure> {
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let verb = parts.first?.lowercased() else {
            return .failure(ParseFailure("Empty command"))
        }

        switch verb {
        case "launch":
            guard parts.count >= 2 else { return .failure(ParseFailure("'launch' requires an app name (launch <app-name>)")) }
            return .success(.launch(appName: parts[1...].joined(separator: " ")))

        case "find":
            guard parts.count >= 2 else { return .failure(ParseFailure("'find' requires a selector (find <title> [role: <role>])")) }
            return .success(.find(selector: parseSelector(Array(parts[1...]))))

        case "waitfor":
            guard parts.count >= 2 else {
                return .failure(ParseFailure("'waitfor' requires a selector (waitfor <title> [role: <role>] [timeout: <seconds>])"))
            }
            var selectorParts = Array(parts[1...])
            var timeout: TimeInterval = 5.0
            if let timeoutIndex = selectorParts.firstIndex(of: "timeout:") {
                guard timeoutIndex + 1 < selectorParts.count, let value = Double(selectorParts[timeoutIndex + 1]) else {
                    return .failure(ParseFailure("'timeout:' must be followed by a number of seconds"))
                }
                timeout = value
                selectorParts.removeSubrange(timeoutIndex...)
            }
            guard !selectorParts.isEmpty else {
                return .failure(ParseFailure("'waitfor' requires a selector before 'timeout:'"))
            }
            return .success(.waitFor(selector: parseSelector(selectorParts), timeout: timeout))

        case "assert":
            guard parts.count >= 2 else {
                return .failure(ParseFailure("'assert' requires a condition: exists <selector>, missing <selector>, enabled, disabled, or value <text>"))
            }
            return parseAssertion(Array(parts[1...])).map { .assert($0) }

        case "usewindow":
            let title = parts.count >= 2 ? parts[1...].joined(separator: " ") : nil
            return .success(.useWindow(titleContains: title))

        case "dumptree":
            if parts.count >= 2 {
                guard let depth = Int(parts[1]), depth > 0 else {
                    return .failure(ParseFailure("'dumptree' depth must be a positive integer (dumptree [depth])"))
                }
                return .success(.dumpTree(maxDepth: depth))
            }
            return .success(.dumpTree(maxDepth: 4))

        case "reset":
            return .success(.reset)

        case "click":
            return .success(.perform(action: .click))

        case "doubleclick":
            return .success(.perform(action: .doubleClick))

        case "rightclick":
            return .success(.perform(action: .rightClick))

        case "type":
            guard parts.count >= 2 else { return .failure(ParseFailure("'type' requires text (type <text>)")) }
            return .success(.perform(action: .type(parts[1...].joined(separator: " "))))

        case "setvalue":
            guard parts.count >= 2 else { return .failure(ParseFailure("'setvalue' requires a value (setvalue <value>)")) }
            return .success(.perform(action: .setValue(parts[1...].joined(separator: " "))))

        case "wait":
            guard parts.count >= 2 else { return .failure(ParseFailure("'wait' requires a duration in seconds (wait <seconds>)")) }
            guard let seconds = Double(parts[1]) else {
                return .failure(ParseFailure("'wait' duration must be a number, got '\(parts[1])'"))
            }
            return .success(.perform(action: .wait(seconds)))

        case "scroll":
            guard parts.count >= 2 else { return .failure(ParseFailure("'scroll' requires a direction (scroll <up|down|left|right>)")) }
            let direction = parts[1].lowercased()
            guard ["up", "down", "left", "right"].contains(direction) else {
                return .failure(ParseFailure("'scroll' direction must be up, down, left, or right, got '\(parts[1])'"))
            }
            return .success(.perform(action: .scroll(direction: direction)))

        case "presskey":
            guard parts.count >= 2 else { return .failure(ParseFailure("'presskey' requires a key combo (presskey <combo>, e.g. presskey cmd+c)")) }
            return .success(.perform(action: .pressKey(combo: parts[1...].joined(separator: " "))))

        case "selectmenuitem":
            guard parts.count >= 2 else { return .failure(ParseFailure("'selectmenuitem' requires a menu path (selectmenuitem File > Save)")) }
            return .success(.perform(action: .selectMenuItem(path: parts[1...].joined(separator: " "))))

        case "openmenu":
            guard parts.count >= 2 else { return .failure(ParseFailure("'openmenu' requires a menu name (openmenu <name>)")) }
            return .success(.perform(action: .openMenu(name: parts[1...].joined(separator: " "))))

        case "increment":
            return .success(.perform(action: .increment))

        case "decrement":
            return .success(.perform(action: .decrement))

        case "focus":
            return .success(.perform(action: .focus))

        case "check":
            return .success(.perform(action: .check))

        case "uncheck":
            return .success(.perform(action: .uncheck))

        case "expand":
            return .success(.perform(action: .expand))

        case "collapse":
            return .success(.perform(action: .collapse))

        case "mode":
            guard parts.count >= 2 else { return .failure(ParseFailure("'mode' requires a mode name (mode <strict|continue|interactive>)")) }
            switch parts[1].lowercased() {
            case "strict":
                return .success(.mode(.strict))
            case "continue":
                return .success(.mode(.continue))
            case "interactive":
                return .success(.mode(.interactive))
            default:
                return .failure(ParseFailure("Unknown mode '\(parts[1])'. Valid modes: strict, continue, interactive"))
            }

        case "log":
            guard parts.count >= 2 else { return .failure(ParseFailure("'log' requires a message (log <message>)")) }
            return .success(.log(message: parts[1...].joined(separator: " ")))

        // State retrieval commands
        case "getsystem":
            return .success(.getSystem)

        case "getwindows", "getwindow":
            return .success(.getWindows)

        case "getelement":
            return .success(.getElement)

        case "getapps", "getapp":
            return .success(.getApps)

        default:
            // Check if an extension can handle this verb
            if ExtensionRegistry.shared.canHandle(verb: verb) {
                if let extCmd = ExtensionRegistry.shared.parse(line, verb: verb, parts: parts) {
                    return .success(.custom(extCmd))
                }
                return .failure(ParseFailure("Extension command '\(verb)' could not parse arguments"))
            }
            var message = "Unknown command '\(verb)'"
            if let suggestion = closestVerb(to: verb) {
                message += ". Did you mean '\(suggestion)'?"
            }
            return .failure(ParseFailure(message))
        }
    }

    /// Parse the condition part of an `assert` command (also used by the MCP `assert` tool)
    public static func parseAssertion(_ parts: [String]) -> Result<Assertion, ParseFailure> {
        guard let kind = parts.first?.lowercased() else {
            return .failure(ParseFailure("'assert' requires a condition"))
        }

        switch kind {
        case "exists":
            guard parts.count >= 2 else { return .failure(ParseFailure("'assert exists' requires a selector")) }
            return .success(.exists(parseSelector(Array(parts[1...]))))

        case "missing":
            guard parts.count >= 2 else { return .failure(ParseFailure("'assert missing' requires a selector")) }
            return .success(.notExists(parseSelector(Array(parts[1...]))))

        case "enabled":
            return .success(.enabled(true))

        case "disabled":
            return .success(.enabled(false))

        case "value":
            guard parts.count >= 2 else { return .failure(ParseFailure("'assert value' requires the expected value text")) }
            return .success(.value(parts[1...].joined(separator: " ")))

        default:
            return .failure(ParseFailure("Unknown assert condition '\(kind)'. Valid: exists <selector>, missing <selector>, enabled, disabled, value <text>"))
        }
    }

    /// Find the closest known verb for "did you mean" suggestions
    private static func closestVerb(to verb: String) -> String? {
        var candidates = Set(BuiltInCommands.all.flatMap { [$0.verb] + $0.aliases })
        candidates.formUnion(CommandRegistry.shared.allVerbs)

        var best: (verb: String, distance: Int)? = nil
        for candidate in candidates {
            let distance = levenshteinDistance(verb, candidate)
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }

        // Only suggest close matches (e.g. "lauch" → "launch", not "x" → "log")
        if let best = best, best.distance <= 2, best.distance < verb.count {
            return best.verb
        }
        return nil
    }

    public static func parseSelector(_ parts: [String]) -> ElementSelector {
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
