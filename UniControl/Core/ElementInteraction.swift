//
//  ElementInteraction.swift
//  UniControl
//
//  UI element interaction functions
//

import Foundation
import ApplicationServices
import CoreGraphics

/// Click on an element
public func clickElement(_ element: AXUIElement) -> Bool {
    let result = AXUIElementPerformAction(element, kAXPressAction as CFString)

    if result == .success {
        print("Successfully clicked element")
        return true
    } else {
        print("Failed to click element: \(result.rawValue)")
        return false
    }
}

/// Click on an element using alternative methods if standard click fails
public func clickElementWithRetry(_ element: AXUIElement, debug: Bool = false) -> Bool {
    // Some elements (like Excel templates) work but return error codes because
    // they become invalid after being clicked (dialog closes, etc.)
    // Error -25206 (kAXErrorInvalidUIElement) after clicking often means success!

    // Method 1: Standard press
    var result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    if result == .success {
        if debug { print("✅ Clicked using AXPress") }
        return true
    }
    // -25206 (kAXErrorInvalidUIElement) often means it worked but element is now gone
    if result.rawValue == -25206 {
        if debug { print("✅ Clicked using AXPress (element invalidated after click - this is normal)") }
        return true
    }
    if debug { print("⚠️  AXPress failed: \(result.rawValue)") }

    // Method 2: Pick action (for list items, thumbnails, template selections)
    result = AXUIElementPerformAction(element, kAXPickAction as CFString)
    if result == .success {
        if debug { print("✅ Clicked using AXPick") }
        return true
    }
    if result.rawValue == -25206 {
        if debug { print("✅ Clicked using AXPick (element invalidated after click - this is normal)") }
        return true
    }
    if debug { print("⚠️  AXPick failed: \(result.rawValue)") }

    // Method 3: ShowMenu action
    result = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)
    if result == .success {
        if debug { print("✅ Clicked using AXShowMenu") }
        return true
    }
    if result.rawValue == -25206 {
        if debug { print("✅ Clicked using AXShowMenu (element invalidated after click - this is normal)") }
        return true
    }
    if debug { print("⚠️  AXShowMenu failed: \(result.rawValue)") }

    // Method 4: Confirm action
    result = AXUIElementPerformAction(element, kAXConfirmAction as CFString)
    if result == .success {
        if debug { print("✅ Clicked using AXConfirm") }
        return true
    }
    if result.rawValue == -25206 {
        if debug { print("✅ Clicked using AXConfirm (element invalidated after click - this is normal)") }
        return true
    }

    if debug { print("❌ All click methods failed") }
    return false
}

/// Print element information for debugging
public func printElementInfo(_ element: AXUIElement) {
    let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String ?? "<no role>"
    let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String ?? "<no title>"
    let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String ?? "<no description>"
    let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String ?? "<no value>"

    print("Element Info:")
    print("  Role: \(role)")
    print("  Title: \(title)")
    print("  Description: \(description)")
    print("  Value: \(value)")
}

/// Print detailed element information including available actions
public func printElementDebug(_ element: AXUIElement) {
    printElementInfo(element)

    // Get supported actions
    var actionsRef: CFArray?
    let result = AXUIElementCopyActionNames(element, &actionsRef)

    if result == .success, let actionsArray = actionsRef as? [String] {
        print("  Available Actions: \(actionsArray.joined(separator: ", "))")
    } else {
        print("  Available Actions: None or error")
    }

    // Check enabled state
    let enabled = getAttribute(element, attribute: kAXEnabledAttribute as CFString) as? Bool ?? false
    print("  Enabled: \(enabled)")
}

// MARK: - New Action Implementations

/// Double-click on an element
public func doubleClickElement(_ element: AXUIElement) -> Bool {
    // Try clicking twice with small delay
    if clickElementWithRetry(element, debug: false) {
        Thread.sleep(forTimeInterval: 0.1)
        return clickElementWithRetry(element, debug: false)
    }
    return false
}

/// Right-click on an element
public func rightClickElement(_ element: AXUIElement) -> Bool {
    // Try AXShowMenuAction first (most common way to get context menu)
    var result = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)
    if result == .success || result.rawValue == -25206 {
        return true
    }

    // Fallback: Use CGEvent to simulate right-click at element center
    // Get element position and size
    guard let posValue = getAttribute(element, attribute: kAXPositionAttribute as CFString),
          let sizeValue = getAttribute(element, attribute: kAXSizeAttribute as CFString) else {
        return false
    }

    var position = CGPoint.zero
    var size = CGSize.zero

    if AXValueGetValue(posValue as! AXValue, .cgPoint, &position) == true,
       AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) == true {
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let clickPoint = CGPoint(x: centerX, y: centerY)

        return rightClickAtPoint(clickPoint)
    }

    return false
}

/// Scroll an element in a specific direction
public func scrollElement(_ element: AXUIElement, direction: String) -> Bool {
    // Try using AXScroll action if available
    // Note: AX doesn't have directional scroll actions, but some elements support scrolling

    // For now, use keyboard shortcuts as fallback
    let keyMap: [String: CGKeyCode] = [
        "up": 126,    // Up arrow
        "down": 125,  // Down arrow
        "left": 123,  // Left arrow
        "right": 124  // Right arrow
    ]

    guard let keyCode = keyMap[direction.lowercased()] else {
        print("Unknown scroll direction: \(direction)")
        return false
    }

    // Focus the element first
    let _ = focusElement(element)
    Thread.sleep(forTimeInterval: 0.1)

    // Send arrow key
    return sendKeyPress(keyCode: keyCode, modifiers: [])
}

/// Send keyboard combination
public func pressKeyCombo(_ combo: String) -> Bool {
    // Parse combo like "Cmd+C", "Cmd+Shift+V", "Return", etc.
    let parts = combo.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }

    var modifiers: CGEventFlags = []
    var keyCode: CGKeyCode = 0
    var foundKey = false

    for part in parts {
        let lower = part.lowercased()
        switch lower {
        case "cmd", "command":
            modifiers.insert(.maskCommand)
        case "shift":
            modifiers.insert(.maskShift)
        case "opt", "option", "alt":
            modifiers.insert(.maskAlternate)
        case "ctrl", "control":
            modifiers.insert(.maskControl)
        default:
            // This is the actual key
            if let code = keyCodeForString(lower) {
                keyCode = code
                foundKey = true
            }
        }
    }

    guard foundKey else {
        print("❌ No valid key found in combo: \(combo)")
        return false
    }

    return sendKeyPress(keyCode: keyCode, modifiers: modifiers)
}

/// Send a key press with modifiers
public func sendKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) -> Bool {
    guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
        return false
    }

    keyDownEvent.flags = modifiers
    keyDownEvent.post(tap: .cghidEventTap)

    Thread.sleep(forTimeInterval: 0.05)

    guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
        return false
    }

    keyUpEvent.flags = modifiers
    keyUpEvent.post(tap: .cghidEventTap)

    return true
}

/// Map string to key code
private func keyCodeForString(_ key: String) -> CGKeyCode? {
    let keyMap: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
        "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53, "esc": 53,
        "up": 126, "down": 125, "left": 123, "right": 124,
        "home": 115, "end": 119, "pageup": 116, "pagedown": 121
    ]

    return keyMap[key.lowercased()]
}

/// Right-click at a specific screen point
private func rightClickAtPoint(_ point: CGPoint) -> Bool {
    guard let rightDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right) else {
        return false
    }

    rightDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)

    guard let rightUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right) else {
        return false
    }

    rightUp.post(tap: .cghidEventTap)
    return true
}

/// Increment element value (for spinners, sliders)
public func incrementElement(_ element: AXUIElement) -> Bool {
    let result = AXUIElementPerformAction(element, kAXIncrementAction as CFString)
    return result == .success || result.rawValue == -25206
}

/// Decrement element value
public func decrementElement(_ element: AXUIElement) -> Bool {
    let result = AXUIElementPerformAction(element, kAXDecrementAction as CFString)
    return result == .success || result.rawValue == -25206
}

/// Focus an element
public func focusElement(_ element: AXUIElement) -> Bool {
    let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    return result == .success
}

/// Check a checkbox
public func checkElement(_ element: AXUIElement) -> Bool {
    // Check current value
    if let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? Int {
        if value == 1 {
            // Already checked
            return true
        }
    }

    // Toggle by clicking
    return clickElementWithRetry(element, debug: false)
}

/// Uncheck a checkbox
public func uncheckElement(_ element: AXUIElement) -> Bool {
    // Check current value
    if let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? Int {
        if value == 0 {
            // Already unchecked
            return true
        }
    }

    // Toggle by clicking
    return clickElementWithRetry(element, debug: false)
}

/// Expand a disclosure triangle or tree item
public func expandElement(_ element: AXUIElement) -> Bool {
    // Check if already expanded
    if let expanded = getAttribute(element, attribute: kAXExpandedAttribute as CFString) as? Bool {
        if expanded {
            return true  // Already expanded
        }
    }

    // Try to expand
    let result = AXUIElementSetAttributeValue(element, kAXExpandedAttribute as CFString, kCFBooleanTrue)
    if result == .success {
        return true
    }

    // Fallback: click the element
    return clickElementWithRetry(element, debug: false)
}

/// Collapse a disclosure triangle or tree item
public func collapseElement(_ element: AXUIElement) -> Bool {
    // Check if already collapsed
    if let expanded = getAttribute(element, attribute: kAXExpandedAttribute as CFString) as? Bool {
        if !expanded {
            return true  // Already collapsed
        }
    }

    // Try to collapse
    let result = AXUIElementSetAttributeValue(element, kAXExpandedAttribute as CFString, kCFBooleanFalse)
    if result == .success {
        return true
    }

    // Fallback: click the element
    return clickElementWithRetry(element, debug: false)
}

// Define kAXExpandedAttribute if not available
private let kAXExpandedAttribute = "AXExpanded" as CFString
