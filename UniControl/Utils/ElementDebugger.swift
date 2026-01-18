//
//  ElementDebugger.swift
//  UniControl
//
//  Debugging utilities for UI elements
//

import Foundation
import ApplicationServices

/// Print detailed information about an element including all available actions
public func debugElement(_ element: AXUIElement, label: String = "Element") {
    print("\n=== \(label) Debug Info ===")

    // Basic attributes
    let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String ?? "<no role>"
    let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String ?? "<no title>"
    let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String ?? "<no description>"
    let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String ?? "<no value>"
    let roleDescription = getAttribute(element, attribute: kAXRoleDescriptionAttribute as CFString) as? String ?? "<no role description>"

    print("Role: \(role)")
    print("Role Description: \(roleDescription)")
    print("Title: \(title)")
    print("Description: \(description)")
    print("Value: \(value)")

    // Get supported actions
    var actionsRef: CFArray?
    let result = AXUIElementCopyActionNames(element, &actionsRef)

    if result == .success, let actions = actionsRef as? [String] {
        print("\nSupported Actions (\(actions.count)):")
        for action in actions {
            print("  - \(action)")
        }
    } else {
        print("\nSupported Actions: None or error (\(result.rawValue))")
    }

    // Check if element is enabled
    let enabled = getAttribute(element, attribute: kAXEnabledAttribute as CFString) as? Bool ?? false
    print("\nEnabled: \(enabled)")

    // Get position and size
    if let positionValue = getAttribute(element, attribute: kAXPositionAttribute as CFString) {
        var point = CGPoint.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
        print("Position: \(point)")
    }

    if let sizeValue = getAttribute(element, attribute: kAXSizeAttribute as CFString) {
        var size = CGSize.zero
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        print("Size: \(size)")
    }

    print("========================\n")
}

/// Try multiple methods to click an element
public func clickElementSmart(_ element: AXUIElement, debug: Bool = false) -> Bool {
    if debug {
        debugElement(element, label: "Attempting to click")
    }

    // Method 1: Standard press action
    var result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    if result == .success {
        print("✅ Clicked using AXPress")
        return true
    }
    print("⚠️  AXPress failed with code: \(result.rawValue)")

    // Method 2: Try AXShowMenu action (some elements use this)
    result = AXUIElementPerformAction(element, kAXShowMenuAction as CFString)
    if result == .success {
        print("✅ Clicked using AXShowMenu")
        return true
    }

    // Method 3: Try AXPick action (for list items, thumbnails)
    result = AXUIElementPerformAction(element, kAXPickAction as CFString)
    if result == .success {
        print("✅ Clicked using AXPick")
        return true
    }

    // Method 4: Try simulating mouse click at element position
    if let positionValue = getAttribute(element, attribute: kAXPositionAttribute as CFString),
       let sizeValue = getAttribute(element, attribute: kAXSizeAttribute as CFString) {

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        // Click at center of element
        let clickPoint = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)

        if simulateMouseClick(at: clickPoint) {
            print("✅ Clicked using mouse simulation at \(clickPoint)")
            return true
        }
    }

    print("❌ All click methods failed")
    return false
}

/// Simulate a mouse click at a specific screen position
public func simulateMouseClick(at point: CGPoint) -> Bool {
    // Create mouse down event
    guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) else {
        return false
    }

    // Create mouse up event
    guard let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
        return false
    }

    // Post events
    mouseDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05) // Small delay between down and up
    mouseUp.post(tap: .cghidEventTap)

    return true
}

/// Find element and print all available actions
public func exploreElementActions(in window: AXUIElement, titleContains: String) {
    print("\n🔍 Searching for elements containing: '\(titleContains)'")

    let allElements = findElements(in: window)
    var found = 0

    for element in allElements {
        let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
        let desc = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
        let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String

        if title?.contains(titleContains) == true ||
           desc?.contains(titleContains) == true ||
           value?.contains(titleContains) == true {
            found += 1
            debugElement(element, label: "Match #\(found)")
        }
    }

    if found == 0 {
        print("❌ No elements found containing '\(titleContains)'")

        // Show similar elements
        print("\nShowing first 10 elements with titles:")
        for element in allElements.prefix(10) {
            if let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String, !title.isEmpty {
                let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String ?? "unknown"
                print("  - '\(title)' (\(role))")
            }
        }
    } else {
        print("\n✅ Found \(found) matching element(s)")
    }
}
