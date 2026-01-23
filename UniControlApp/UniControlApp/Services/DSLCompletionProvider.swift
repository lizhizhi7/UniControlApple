//
//  DSLCompletionProvider.swift
//  UniControlApp
//
//  Provides autocomplete suggestions for DSL commands
//

import Foundation

/// Provides autocomplete suggestions for DSL commands
struct DSLCompletionProvider {
    /// A completion suggestion with command and syntax hint
    struct Completion: Identifiable {
        let id = UUID()
        let command: String
        let syntax: String
        let description: String

        var displayText: String {
            command
        }

        var detailText: String {
            syntax
        }
    }

    /// All available DSL command completions
    static let commands: [Completion] = [
        // App control
        Completion(command: "launch", syntax: "launch <app-name>", description: "Launch an application by name"),

        // Element finding
        Completion(command: "find", syntax: "find <selector> [role: <role>]", description: "Find a UI element"),

        // Basic actions
        Completion(command: "click", syntax: "click", description: "Click the current element"),
        Completion(command: "doubleclick", syntax: "doubleclick", description: "Double-click the current element"),
        Completion(command: "rightclick", syntax: "rightclick", description: "Right-click the current element"),
        Completion(command: "type", syntax: "type <text>", description: "Type text into the current element"),
        Completion(command: "wait", syntax: "wait <seconds>", description: "Wait for specified duration"),

        // Scrolling
        Completion(command: "scroll", syntax: "scroll <up|down|left|right>", description: "Scroll in a direction"),

        // Keyboard
        Completion(command: "presskey", syntax: "presskey <combo>", description: "Press a key combination"),

        // Element state
        Completion(command: "focus", syntax: "focus", description: "Focus the current element"),
        Completion(command: "check", syntax: "check", description: "Check a checkbox"),
        Completion(command: "uncheck", syntax: "uncheck", description: "Uncheck a checkbox"),
        Completion(command: "expand", syntax: "expand", description: "Expand a disclosure"),
        Completion(command: "collapse", syntax: "collapse", description: "Collapse a disclosure"),
        Completion(command: "increment", syntax: "increment", description: "Increment a stepper/slider"),
        Completion(command: "decrement", syntax: "decrement", description: "Decrement a stepper/slider"),

        // Menu interaction
        Completion(command: "selectmenuitem", syntax: "selectmenuitem <path>", description: "Select a menu item by path"),
        Completion(command: "openmenu", syntax: "openmenu <name>", description: "Open a menu"),

        // Execution mode
        Completion(command: "mode", syntax: "mode <strict|continue|interactive>", description: "Set execution mode"),

        // Logging
        Completion(command: "log", syntax: "log <message>", description: "Print a message to console"),

        // State retrieval
        Completion(command: "getsystem", syntax: "getsystem", description: "Get system info"),
        Completion(command: "getwindow", syntax: "getwindow", description: "Get active window info"),
        Completion(command: "getwindows", syntax: "getwindows [active|all]", description: "Get window info"),
        Completion(command: "getapp", syntax: "getapp", description: "Get frontmost app info"),
        Completion(command: "getapps", syntax: "getapps [frontmost|all]", description: "Get running apps info"),
        Completion(command: "getelement", syntax: "getelement", description: "Get current element info"),
    ]

    /// Get completions matching the given prefix
    static func completions(for prefix: String) -> [Completion] {
        let lowercasedPrefix = prefix.lowercased()
        if lowercasedPrefix.isEmpty {
            return commands
        }
        return commands.filter { $0.command.lowercased().hasPrefix(lowercasedPrefix) }
    }

    /// Get completions for the current word in the text at cursor position
    static func completions(for text: String, cursorPosition: Int) -> (completions: [Completion], wordRange: Range<String.Index>?) {
        let index = text.index(text.startIndex, offsetBy: min(cursorPosition, text.count))

        // Find the start of the current word
        var wordStart = index
        while wordStart > text.startIndex {
            let prevIndex = text.index(before: wordStart)
            let char = text[prevIndex]
            if char.isWhitespace || char.isNewline {
                break
            }
            wordStart = prevIndex
        }

        // Find the end of the current word (cursor position)
        let wordEnd = index

        // Extract the current word
        let word = String(text[wordStart..<wordEnd])

        // Check if we're at the start of a line (command position)
        let lineStart = text[..<wordStart].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let textBeforeWord = text[lineStart..<wordStart].trimmingCharacters(in: .whitespaces)

        // Only provide completions if we're at the start of a command (no other words before)
        if textBeforeWord.isEmpty {
            let range = wordStart..<wordEnd
            return (completions(for: word), range)
        }

        return ([], nil)
    }
}
