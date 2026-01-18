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
