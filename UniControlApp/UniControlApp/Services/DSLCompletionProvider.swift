//
//  DSLCompletionProvider.swift
//  UniControlApp
//
//  Provides autocomplete suggestions for DSL commands
//  Completions are generated from CommandRegistry
//

import Foundation
import UniControlCore

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

    /// Ensure built-in commands are registered before accessing completions
    private static let _initialized: Bool = {
        BuiltInCommands.registerAll()
        return true
    }()

    /// All available DSL command completions (generated from CommandRegistry)
    static var commands: [Completion] {
        _ = _initialized
        return CommandRegistry.shared.allDescriptors.flatMap { descriptor -> [Completion] in
            // Create completion for main verb
            var completions = [
                Completion(
                    command: descriptor.verb,
                    syntax: descriptor.syntax,
                    description: descriptor.description
                )
            ]

            // Add completions for aliases
            for alias in descriptor.aliases {
                completions.append(Completion(
                    command: alias,
                    syntax: descriptor.syntax,
                    description: descriptor.description
                ))
            }

            return completions
        }.sorted { $0.command < $1.command }
    }

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
