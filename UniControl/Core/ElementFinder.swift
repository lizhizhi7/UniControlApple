//
//  ElementFinder.swift
//  UniControl
//
//  UI element discovery and search functions
//

import Foundation
import ApplicationServices

/// Get an accessibility attribute value
public func getAttribute(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    if result == .success {
        return value
    }
    return nil
}

/// Find all buttons under an AXUIElement (legacy function)
public func findAllButtons(in element: AXUIElement) -> [AXUIElement] {
    var buttons = [AXUIElement]()

    // Check role of current element
    if let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String,
       role == kAXButtonRole as String {
        buttons.append(element)
    }

    // Get children and recurse
    if let children = getAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] {
        for child in children {
            buttons.append(contentsOf: findAllButtons(in: child))
        }
    }

    return buttons
}

/// Generic recursive function to find all elements of a specific role
public func findElements(in element: AXUIElement, role: String? = nil, maxDepth: Int = 50, currentDepth: Int = 0) -> [AXUIElement] {
    guard currentDepth < maxDepth else { return [] }

    var elements = [AXUIElement]()

    // Check if current element matches the role (if specified)
    if let targetRole = role {
        if let elementRole = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String,
           elementRole == targetRole {
            elements.append(element)
        }
    } else {
        // If no role specified, collect all elements
        elements.append(element)
    }

    // Get children and recurse
    if let children = getAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] {
        for child in children {
            elements.append(contentsOf: findElements(in: child, role: role, maxDepth: maxDepth, currentDepth: currentDepth + 1))
        }
    }

    return elements
}

/// Find element by title/description
public func findElement(in rootElement: AXUIElement, title: String, role: String? = nil) -> AXUIElement? {
    let elements = findElements(in: rootElement, role: role)

    for element in elements {
        // Try multiple attributes to match the title
        let titleAttr = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
        let descAttr = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
        let helpAttr = getAttribute(element, attribute: kAXHelpAttribute as CFString) as? String
        let valueAttr = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String

        if titleAttr?.contains(title) == true ||
           descAttr?.contains(title) == true ||
           helpAttr?.contains(title) == true ||
           valueAttr?.contains(title) == true {
            return element
        }
    }

    return nil
}
