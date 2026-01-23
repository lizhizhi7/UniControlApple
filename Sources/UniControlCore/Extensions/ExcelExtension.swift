//
//  ExcelExtension.swift
//  UniControl
//
//  Excel-specific DSL extension for cell navigation and manipulation
//

import Foundation
import ApplicationServices
import Carbon
import AppKit

/// Excel-specific DSL extension
/// Provides commands for cell navigation and manipulation in Microsoft Excel
public class ExcelExtension: DSLExtension {
    public static let identifier = "excel"

    public static let supportedCommands = [
        "range",        // Navigate to a cell or select a range: range A1 or range A1:B5
        "typeincell",   // Type into a specific cell: typeincell A1 "Hello"
        "getcell"       // Read cell value: getcell A1 as varname
    ]

    public required init() {}

    public static func parse(_ line: String, verb: String, parts: [String]) -> ExtensionCommand? {
        switch verb {
        case "range":
            // range A1 or range A1:B5
            guard parts.count >= 2 else { return nil }
            let cellRef = parts[1]
            return ExtensionCommand(
                extensionId: identifier,
                verb: verb,
                arguments: [cellRef]
            )

        case "typeincell":
            // typeincell A1 "Hello" or typeincell A1 Hello World
            guard parts.count >= 3 else { return nil }
            let cellRef = parts[1]
            // Join remaining parts as the text to type
            // Handle quoted strings
            let textParts = Array(parts[2...])
            let text = extractQuotedString(from: textParts) ?? textParts.joined(separator: " ")
            return ExtensionCommand(
                extensionId: identifier,
                verb: verb,
                arguments: [cellRef, text]
            )

        case "getcell":
            // getcell A1 or getcell A1 as varname
            guard parts.count >= 2 else { return nil }
            let cellRef = parts[1]
            var varName: String? = nil

            // Check for "as varname" syntax
            if parts.count >= 4 && parts[2].lowercased() == "as" {
                varName = parts[3]
            }

            var args = [cellRef]
            if let name = varName {
                args.append(name)
            }
            return ExtensionCommand(
                extensionId: identifier,
                verb: verb,
                arguments: args
            )

        default:
            return nil
        }
    }

    public func execute(_ command: ExtensionCommand, context: ExecutionContext, verbose: Bool) -> CommandResult {
        guard let window = context.currentWindow else {
            return .failure(error: "No active window. Launch Excel first.")
        }

        switch command.verb {
        case "range":
            return executeRange(command.arguments, window: window, context: context, verbose: verbose)

        case "typeincell":
            return executeTypeInCell(command.arguments, window: window, context: context, verbose: verbose)

        case "getcell":
            return executeGetCell(command.arguments, window: window, context: context, verbose: verbose)

        default:
            return .failure(error: "Unknown Excel command: \(command.verb)")
        }
    }

    // MARK: - Command Implementations

    /// Navigate to a cell or range using the Name Box
    private func executeRange(_ args: [String], window: AXUIElement, context: ExecutionContext, verbose: Bool) -> CommandResult {
        guard !args.isEmpty else {
            return .failure(error: "range requires a cell reference (e.g., range A1)")
        }

        let cellRef = args[0].uppercased()

        if verbose {
            print("📊 Navigating to \(cellRef)")
        }

        // Strategy: Use keyboard shortcut Cmd+G (Go To) or click on Name Box
        // First try to find and click the Name Box (shows cell address like "A1")
        if let nameBox = findNameBox(in: window) {
            // Click the Name Box to focus it
            if clickElementWithRetry(nameBox, debug: verbose) {
                Thread.sleep(forTimeInterval: 0.2)

                // Clear existing content and type the cell reference
                if pressKeyCombo("cmd+a") {
                    Thread.sleep(forTimeInterval: 0.1)
                    if typeWithKeyboard(cellRef) {
                        Thread.sleep(forTimeInterval: 0.1)
                        // Press Enter to navigate
                        if pressKeyCombo("return") {
                            Thread.sleep(forTimeInterval: 0.3)
                            if verbose {
                                print("✅ Navigated to \(cellRef)")
                            }
                            return .success(value: cellRef)
                        }
                    }
                }
            }
        }

        // Fallback: Use Ctrl+G (Go To dialog) on macOS Excel
        if verbose {
            print("📊 Trying Ctrl+G Go To dialog...")
        }

        if pressKeyCombo("ctrl+g") {
            Thread.sleep(forTimeInterval: 0.5)

            // Type the cell reference in the Go To dialog
            if typeWithKeyboard(cellRef) {
                Thread.sleep(forTimeInterval: 0.1)
                if pressKeyCombo("return") {
                    Thread.sleep(forTimeInterval: 0.3)
                    if verbose {
                        print("✅ Navigated to \(cellRef)")
                    }
                    return .success(value: cellRef)
                }
            }
        }

        return .failure(error: "Could not navigate to \(cellRef)")
    }

    /// Type text into a specific cell
    private func executeTypeInCell(_ args: [String], window: AXUIElement, context: ExecutionContext, verbose: Bool) -> CommandResult {
        guard args.count >= 2 else {
            return .failure(error: "typeincell requires cell reference and text (e.g., typeincell A1 \"Hello\")")
        }

        let cellRef = args[0].uppercased()
        let text = args[1]

        if verbose {
            print("📊 Typing \"\(text)\" into \(cellRef)")
        }

        // First navigate to the cell
        let rangeResult = executeRange([cellRef], window: window, context: context, verbose: false)
        guard rangeResult.isSuccess else {
            return .failure(error: "Could not navigate to \(cellRef)")
        }

        // Small delay after navigation
        Thread.sleep(forTimeInterval: 0.2)

        // Type the text
        if typeWithKeyboard(text) {
            Thread.sleep(forTimeInterval: 0.1)
            // Press Enter to confirm
            if pressKeyCombo("return") {
                if verbose {
                    print("✅ Typed \"\(text)\" into \(cellRef)")
                }
                return .success(value: text)
            }
        }

        return .failure(error: "Could not type into \(cellRef)")
    }

    /// Read the value of a cell
    private func executeGetCell(_ args: [String], window: AXUIElement, context: ExecutionContext, verbose: Bool) -> CommandResult {
        guard !args.isEmpty else {
            return .failure(error: "getcell requires a cell reference (e.g., getcell A1)")
        }

        let cellRef = args[0].uppercased()
        let varName = args.count > 1 ? args[1] : nil

        if verbose {
            print("📊 Reading value from \(cellRef)")
        }

        // Navigate to the cell first
        let rangeResult = executeRange([cellRef], window: window, context: context, verbose: false)
        guard rangeResult.isSuccess else {
            return .failure(error: "Could not navigate to \(cellRef)")
        }

        Thread.sleep(forTimeInterval: 0.2)

        // Try to read the value from the formula bar or the cell itself
        // Look for the formula bar (AXTextField with specific identifier)
        if let formulaBar = findFormulaBar(in: window) {
            if let value = getAttribute(formulaBar, attribute: kAXValueAttribute as CFString) as? String {
                if verbose {
                    print("✅ Cell \(cellRef) = \"\(value)\"")
                }

                // Store in context variable if name provided
                if let name = varName {
                    context.variables[name] = value
                    if verbose {
                        print("📝 Stored in variable: $\(name)")
                    }
                }

                return .success(value: value)
            }
        }

        // Fallback: Copy the cell value using Cmd+C and read from pasteboard
        if pressKeyCombo("cmd+c") {
            Thread.sleep(forTimeInterval: 0.2)
            if let value = NSPasteboard.general.string(forType: .string) {
                if verbose {
                    print("✅ Cell \(cellRef) = \"\(value)\"")
                }

                if let name = varName {
                    context.variables[name] = value
                    if verbose {
                        print("📝 Stored in variable: $\(name)")
                    }
                }

                return .success(value: value)
            }
        }

        return .failure(error: "Could not read value from \(cellRef)")
    }

    // MARK: - Helper Methods

    /// Find the Name Box (cell address field) in Excel
    private func findNameBox(in window: AXUIElement) -> AXUIElement? {
        // The Name Box is typically an AXTextField that shows the current cell address
        // It's usually in the toolbar area
        let textFields = findElements(in: window, role: "AXTextField")

        for field in textFields {
            // Check if it looks like a cell address (e.g., "A1", "B2:C10")
            if let value = getAttribute(field, attribute: kAXValueAttribute as CFString) as? String {
                // Cell references are typically 1-4 characters like A1, AA1, A1:B10
                if isCellReference(value) {
                    return field
                }
            }

            // Also check by description/identifier
            if let desc = getAttribute(field, attribute: kAXDescriptionAttribute as CFString) as? String {
                if desc.lowercased().contains("name box") || desc.lowercased().contains("cell") {
                    return field
                }
            }
        }

        return nil
    }

    /// Find the Formula Bar in Excel
    private func findFormulaBar(in window: AXUIElement) -> AXUIElement? {
        let textFields = findElements(in: window, role: "AXTextField")

        for field in textFields {
            if let desc = getAttribute(field, attribute: kAXDescriptionAttribute as CFString) as? String {
                if desc.lowercased().contains("formula") {
                    return field
                }
            }

            // The formula bar is usually a larger text field
            if let role = getAttribute(field, attribute: kAXRoleAttribute as CFString) as? String,
               role == "AXTextField" {
                // Check if it has formula bar identifier
                if let identifier = getAttribute(field, attribute: kAXIdentifierAttribute as CFString) as? String {
                    if identifier.lowercased().contains("formula") {
                        return field
                    }
                }
            }
        }

        return nil
    }

    /// Check if a string looks like a cell reference
    private func isCellReference(_ str: String) -> Bool {
        // Basic pattern: one or more letters followed by one or more digits
        // Optionally with a colon for ranges
        let pattern = "^[A-Za-z]+[0-9]+(:[A-Za-z]+[0-9]+)?$"
        return str.range(of: pattern, options: .regularExpression) != nil
    }

    /// Extract a quoted string from parts
    private static func extractQuotedString(from parts: [String]) -> String? {
        let joined = parts.joined(separator: " ")

        // Check for double-quoted string
        if joined.hasPrefix("\"") {
            if let endIndex = joined.dropFirst().firstIndex(of: "\"") {
                let start = joined.index(after: joined.startIndex)
                return String(joined[start..<endIndex])
            }
        }

        // Check for single-quoted string
        if joined.hasPrefix("'") {
            if let endIndex = joined.dropFirst().firstIndex(of: "'") {
                let start = joined.index(after: joined.startIndex)
                return String(joined[start..<endIndex])
            }
        }

        return nil
    }

    /// Type text using keyboard simulation
    private func typeWithKeyboard(_ text: String) -> Bool {
        // Use CGEvent to type each character
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            guard let keyCode = keyCodeForCharacter(char) else {
                continue
            }

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode.code, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode.code, keyDown: false)

            if keyCode.shift {
                keyDown?.flags = .maskShift
                keyUp?.flags = .maskShift
            }

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            Thread.sleep(forTimeInterval: 0.02)
        }

        return true
    }

    /// Get key code for a character
    private func keyCodeForCharacter(_ char: Character) -> (code: CGKeyCode, shift: Bool)? {
        let keyMap: [Character: (CGKeyCode, Bool)] = [
            "a": (0x00, false), "A": (0x00, true),
            "b": (0x0B, false), "B": (0x0B, true),
            "c": (0x08, false), "C": (0x08, true),
            "d": (0x02, false), "D": (0x02, true),
            "e": (0x0E, false), "E": (0x0E, true),
            "f": (0x03, false), "F": (0x03, true),
            "g": (0x05, false), "G": (0x05, true),
            "h": (0x04, false), "H": (0x04, true),
            "i": (0x22, false), "I": (0x22, true),
            "j": (0x26, false), "J": (0x26, true),
            "k": (0x28, false), "K": (0x28, true),
            "l": (0x25, false), "L": (0x25, true),
            "m": (0x2E, false), "M": (0x2E, true),
            "n": (0x2D, false), "N": (0x2D, true),
            "o": (0x1F, false), "O": (0x1F, true),
            "p": (0x23, false), "P": (0x23, true),
            "q": (0x0C, false), "Q": (0x0C, true),
            "r": (0x0F, false), "R": (0x0F, true),
            "s": (0x01, false), "S": (0x01, true),
            "t": (0x11, false), "T": (0x11, true),
            "u": (0x20, false), "U": (0x20, true),
            "v": (0x09, false), "V": (0x09, true),
            "w": (0x0D, false), "W": (0x0D, true),
            "x": (0x07, false), "X": (0x07, true),
            "y": (0x10, false), "Y": (0x10, true),
            "z": (0x06, false), "Z": (0x06, true),
            "0": (0x1D, false), ")": (0x1D, true),
            "1": (0x12, false), "!": (0x12, true),
            "2": (0x13, false), "@": (0x13, true),
            "3": (0x14, false), "#": (0x14, true),
            "4": (0x15, false), "$": (0x15, true),
            "5": (0x17, false), "%": (0x17, true),
            "6": (0x16, false), "^": (0x16, true),
            "7": (0x1A, false), "&": (0x1A, true),
            "8": (0x1C, false), "*": (0x1C, true),
            "9": (0x19, false), "(": (0x19, true),
            " ": (0x31, false),
            "-": (0x1B, false), "_": (0x1B, true),
            "=": (0x18, false), "+": (0x18, true),
            "[": (0x21, false), "{": (0x21, true),
            "]": (0x1E, false), "}": (0x1E, true),
            "\\": (0x2A, false), "|": (0x2A, true),
            ";": (0x29, false), ":": (0x29, true),
            "'": (0x27, false), "\"": (0x27, true),
            ",": (0x2B, false), "<": (0x2B, true),
            ".": (0x2F, false), ">": (0x2F, true),
            "/": (0x2C, false), "?": (0x2C, true),
            "`": (0x32, false), "~": (0x32, true),
        ]

        return keyMap[char]
    }
}
