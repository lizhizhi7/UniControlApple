//
//  ElementInteraction.swift
//  UniControl
//
//  UI element interaction functions
//

import Foundation
import ApplicationServices

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
