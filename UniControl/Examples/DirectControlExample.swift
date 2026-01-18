//
//  DirectControlExample.swift
//  UniControl
//
//  Example demonstrating direct control flow
//

import Foundation
import ApplicationServices

/// Legacy example for backward compatibility
public func exampleOld() {
    // Get Permission
    if checkAccessibilityPermission() {
        print("App has Accessibility permission")
    } else {
        print("App does NOT have Accessibility permission")
        // Optionally prompt user:
        _ = requestAccessibilityPermission()
    }

    // Run App
    launchAppAndGetFocusedWindow(appName: "Excel") { focusedWindow in
        guard let window = focusedWindow else {
            print("Could not get focused window")
            return
        }
        print("Got focused window: \(window)")
        // Operate App
        // Move window to top-left corner (0,0)
        let newPosition = CGPoint(x: 0, y: 0)
        moveWindow(window, to: newPosition)
        // Get A11y Buttons
        let buttons = findAllButtons(in: window)
        print("Found \(buttons.count) buttons:")

        for (index, button) in buttons.enumerated() {
            // Get button title or description
            let title = getAttribute(button, attribute: kAXTitleAttribute as CFString) as? String ?? "<no title>"
            print("\(index + 1): \(title)")
            print("\(index + 1): \(button)")
        }

        // Exit
        exit(0)
    }
    // Keep the command line tool running until the async call completes
    RunLoop.current.run()
}

/// Example: "open Excel; find Developer ribbon button; click Checkbox"
public func exampleControlFlow() {
    // Check accessibility permission
    if !checkAccessibilityPermission() {
        print("Accessibility permission required. Requesting...")
        _ = requestAccessibilityPermission()
        print("Please grant accessibility permission in System Settings and run again.")
        exit(1)
    }

    print("=== Starting Control Flow Example ===")
    print("Task: Open Excel, find Developer button, click Checkbox")
    print()

    // Step 1: Open Excel
    print("Step 1: Launching Excel...")
    launchAppAndGetFocusedWindow(appName: "Excel") { focusedWindow in
        guard let window = focusedWindow else {
            print("ERROR: Could not get focused window")
            exit(1)
        }

        print("✓ Excel launched and window obtained")
        print()

        // Step 2: Find Developer ribbon button
        print("Step 2: Searching for 'Developer' button in ribbon...")

        // First, let's try to find the Developer button
        if let developerButton = findElement(in: window, title: "Developer", role: kAXButtonRole as String) {
            print("✓ Found Developer button")
            printElementInfo(developerButton)
            print()

            // Step 3: Click the Developer button
            print("Step 3: Clicking Developer button...")
            if clickElement(developerButton) {
                print("✓ Developer button clicked")
                print()

                // Wait a bit for the ribbon to update
                Thread.sleep(forTimeInterval: 1.0)

                // Step 4: Find and click Checkbox
                print("Step 4: Searching for 'Check Box' control...")
                if let checkboxControl = findElement(in: window, title: "Check Box") {
                    print("✓ Found Check Box control")
                    printElementInfo(checkboxControl)
                    print()

                    print("Step 5: Clicking Check Box...")
                    if clickElement(checkboxControl) {
                        print("✓ Check Box clicked successfully!")
                        print()
                        print("=== Control Flow Completed Successfully ===")
                    } else {
                        print("✗ Failed to click Check Box")
                    }
                } else {
                    print("✗ Could not find Check Box control")
                    print("Searching for all buttons to help debug...")
                    let allButtons = findElements(in: window, role: kAXButtonRole as String)
                    print("Found \(allButtons.count) buttons total. First 20:")
                    for (i, btn) in allButtons.prefix(20).enumerated() {
                        let title = getAttribute(btn, attribute: kAXTitleAttribute as CFString) as? String ?? "<no title>"
                        let desc = getAttribute(btn, attribute: kAXDescriptionAttribute as CFString) as? String ?? ""
                        print("  \(i+1). \(title) [\(desc)]")
                    }
                }
            } else {
                print("✗ Failed to click Developer button")
            }
        } else {
            print("✗ Could not find Developer button")
            print("Searching for all buttons to help debug...")
            let allButtons = findElements(in: window, role: kAXButtonRole as String)
            print("Found \(allButtons.count) buttons total. First 20:")
            for (i, btn) in allButtons.prefix(20).enumerated() {
                let title = getAttribute(btn, attribute: kAXTitleAttribute as CFString) as? String ?? "<no title>"
                let desc = getAttribute(btn, attribute: kAXDescriptionAttribute as CFString) as? String ?? ""
                print("  \(i+1). \(title) [\(desc)]")
            }
        }

        // Exit after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            exit(0)
        }
    }

    // Keep running
    RunLoop.current.run()
}
