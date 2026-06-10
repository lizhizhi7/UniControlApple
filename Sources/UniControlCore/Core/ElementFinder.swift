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

// MARK: - Menu Navigation

/// Find menu bar in a window
public func findMenuBar(in window: AXUIElement) -> AXUIElement? {
    // Get the application from the window
    guard let app = getApplicationFromWindow(window) else {
        return nil
    }

    // Get menu bar from application
    if let menuBar = getAttribute(app, attribute: kAXMenuBarAttribute as CFString) {
        return (menuBar as! AXUIElement)
    }
    return nil
}

/// Get application element from window
private func getApplicationFromWindow(_ window: AXUIElement) -> AXUIElement? {
    // Try to get parent application
    var parent: AnyObject?
    let result = AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &parent)
    if result == .success {
        let parentElement = (parent as! AXUIElement)
        // Check if this is the application
        if let role = getAttribute(parentElement, attribute: kAXRoleAttribute as CFString) as? String,
           role == kAXApplicationRole as String {
            return parentElement
        }
    }

    // Alternative: Create application element from window's process
    var pid: pid_t = 0
    if AXUIElementGetPid(window, &pid) == .success {
        return AXUIElementCreateApplication(pid)
    }

    return nil
}

/// Navigate menu hierarchy and find menu item
/// Path format: "File/Save As" or "Edit/Find/Replace"
public func findMenuItemByPath(in window: AXUIElement, path: String) -> AXUIElement? {
    let components = path.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespaces) }
    guard !components.isEmpty else { return nil }

    guard let menuBar = findMenuBar(in: window) else {
        print("❌ Could not find menu bar")
        return nil
    }

    // Start from menu bar
    var currentElement: AXUIElement = menuBar

    for (index, component) in components.enumerated() {
        // Find child matching this component
        guard let children = getAttribute(currentElement, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] else {
            print("❌ No children at level \(index): \(component)")
            return nil
        }

        var found: AXUIElement?
        for child in children {
            let title = getAttribute(child, attribute: kAXTitleAttribute as CFString) as? String
            if title == component || title?.contains(component) == true {
                found = child
                break
            }
        }

        guard let nextElement = found else {
            print("❌ Could not find menu item: \(component)")
            return nil
        }

        currentElement = nextElement

        // If not the last component, we need to get the menu (submenu)
        if index < components.count - 1 {
            // Get children attribute or menu attribute to navigate deeper
            if let menuObj = getAttribute(currentElement, attribute: "AXMenu" as CFString) {
                let menu = (menuObj as! AXUIElement)
                currentElement = menu
            } else if let children = getAttribute(currentElement, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement],
                      let firstChild = children.first {
                currentElement = firstChild
            }
        }
    }

    return currentElement
}

/// Select a menu item by clicking it
public func selectMenuItemByPath(in window: AXUIElement, path: String) -> Bool {
    guard let menuItem = findMenuItemByPath(in: window, path: path) else {
        return false
    }

    // Click the menu item
    let result = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
    return result == .success || result.rawValue == -25206
}

/// Open a top-level menu by name
public func openMenu(in window: AXUIElement, name: String) -> AXUIElement? {
    guard let menuBar = findMenuBar(in: window) else {
        return nil
    }

    guard let children = getAttribute(menuBar, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] else {
        return nil
    }

    for child in children {
        let title = getAttribute(child, attribute: kAXTitleAttribute as CFString) as? String
        if title == name || title?.contains(name) == true {
            // Open the menu
            let _ = AXUIElementPerformAction(child, kAXPressAction as CFString)
            return child
        }
    }

    return nil
}

// MARK: - Element Info Builder

/// Build rich ElementInfo from an AXUIElement
/// - Parameter element: The accessibility element
/// - Returns: ElementInfo struct with all available attributes
public func buildElementInfo(_ element: AXUIElement) -> ElementInfo {
    // Get basic attributes
    let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String
    let roleDescription = getAttribute(element, attribute: kAXRoleDescriptionAttribute as CFString) as? String
    let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
    let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String

    // Get value - handle different types
    var valueStr: String? = nil
    if let value = getAttribute(element, attribute: kAXValueAttribute as CFString) {
        if let str = value as? String {
            valueStr = str
        } else if let num = value as? NSNumber {
            valueStr = num.stringValue
        } else {
            valueStr = "\(value)"
        }
    }

    // Get state attributes
    let enabled = (getAttribute(element, attribute: kAXEnabledAttribute as CFString) as? Bool) ?? false
    let focused = (getAttribute(element, attribute: kAXFocusedAttribute as CFString) as? Bool) ?? false
    let selected = (getAttribute(element, attribute: kAXSelectedAttribute as CFString) as? Bool) ?? false
    let expanded = getAttribute(element, attribute: kAXExpandedAttribute as CFString) as? Bool

    // Get position
    var position: CGPointInfo? = nil
    if let posValue = getAttribute(element, attribute: kAXPositionAttribute as CFString) {
        var point = CGPoint.zero
        if AXValueGetValue(posValue as! AXValue, .cgPoint, &point) {
            position = CGPointInfo(from: point)
        }
    }

    // Get size
    var size: CGSizeInfo? = nil
    if let sizeValue = getAttribute(element, attribute: kAXSizeAttribute as CFString) {
        var sizeVal = CGSize.zero
        if AXValueGetValue(sizeValue as! AXValue, .cgSize, &sizeVal) {
            size = CGSizeInfo(from: sizeVal)
        }
    }

    // Get available actions
    var actions: [String] = []
    var actionsRef: CFArray?
    if AXUIElementCopyActionNames(element, &actionsRef) == .success, let actionNames = actionsRef as? [String] {
        actions = actionNames
    }

    // Get children count
    var childrenCount = 0
    if let children = getAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] {
        childrenCount = children.count
    }

    return ElementInfo(
        role: role,
        roleDescription: roleDescription,
        title: title,
        description: description,
        value: valueStr,
        enabled: enabled,
        focused: focused,
        selected: selected,
        expanded: expanded,
        position: position,
        size: size,
        actions: actions,
        childrenCount: childrenCount
    )
}

/// Render the element tree under `root` as indented text for discovery/debugging.
/// Each line shows role, title/description, value, and disabled/actions hints.
/// Output is capped at `maxLines` to keep results digestible.
public func dumpElementTree(_ root: AXUIElement, maxDepth: Int, maxLines: Int = 400) -> String {
    var lines: [String] = []
    var truncated = false

    func describe(_ element: AXUIElement) -> String {
        let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String ?? "AXUnknown"
        var text = role

        if let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String, !title.isEmpty {
            text += " \"\(title)\""
        } else if let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String, !description.isEmpty {
            text += " \"\(description)\""
        }

        if let value = getAttribute(element, attribute: kAXValueAttribute as CFString) {
            let valueStr = (value as? String) ?? (value as? NSNumber)?.stringValue
            if let valueStr = valueStr, !valueStr.isEmpty {
                let shortValue = valueStr.count > 40 ? String(valueStr.prefix(37)) + "..." : valueStr
                text += " value=\"\(shortValue)\""
            }
        }

        if let enabled = getAttribute(element, attribute: kAXEnabledAttribute as CFString) as? Bool, !enabled {
            text += " [disabled]"
        }

        return text
    }

    func walk(_ element: AXUIElement, depth: Int) {
        if lines.count >= maxLines {
            truncated = true
            return
        }

        let indent = String(repeating: "  ", count: depth)
        lines.append(indent + describe(element))

        guard depth < maxDepth else {
            if let children = getAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement],
               !children.isEmpty {
                lines.append(indent + "  ... (\(children.count) children below depth limit)")
            }
            return
        }

        if let children = getAttribute(element, attribute: kAXChildrenAttribute as CFString) as? [AXUIElement] {
            for child in children {
                walk(child, depth: depth + 1)
                if truncated { return }
            }
        }
    }

    walk(root, depth: 0)

    if truncated {
        lines.append("... (truncated at \(maxLines) lines; use a smaller depth or find with a selector)")
    }

    return lines.joined(separator: "\n")
}
