//
//  ExcelDebugExample.swift
//  UniControl
//
//  Debug helper for Excel automation
//

import Foundation
import ApplicationServices

/// Example to explore Excel template elements
public func exampleExcelDebug() {
    if !checkAccessibilityPermission() {
        print("Accessibility permission required.")
        _ = requestAccessibilityPermission()
        exit(1)
    }

    print("=== Excel Element Explorer ===\n")

    launchAppAndGetFocusedWindow(appName: "Excel") { window in
        guard let win = window else {
            print("Could not get window")
            exit(1)
        }

        print("✅ Excel launched\n")

        // Wait for templates to load
        Thread.sleep(forTimeInterval: 3)

        // Find all elements that might be the "Blank Workbook" template
        print("🔍 Searching for 'Blank' elements...\n")

        let allElements = findElements(in: win)
        var foundElements: [(element: AXUIElement, info: String)] = []

        for element in allElements {
            let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
            let desc = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
            let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String
            let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String

            // Check if any attribute contains "Blank"
            if title?.contains("Blank") == true ||
               desc?.contains("Blank") == true ||
               value?.contains("Blank") == true {

                let info = "Title: '\(title ?? "none")' | Desc: '\(desc ?? "none")' | Role: \(role ?? "none")"
                foundElements.append((element, info))
            }
        }

        if foundElements.isEmpty {
            print("❌ No elements found containing 'Blank'\n")

            // Show what IS available
            print("📋 Showing first 20 elements with titles or descriptions:\n")
            var count = 0
            for element in allElements {
                if count >= 20 { break }

                let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
                let desc = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
                let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String

                if (title != nil && !title!.isEmpty) || (desc != nil && !desc!.isEmpty) {
                    print("\(count + 1). Role: \(role ?? "unknown")")
                    if let t = title, !t.isEmpty { print("   Title: \(t)") }
                    if let d = desc, !d.isEmpty { print("   Description: \(d)") }
                    print("")
                    count += 1
                }
            }
        } else {
            print("✅ Found \(foundElements.count) elements containing 'Blank'\n")

            for (index, (element, info)) in foundElements.enumerated() {
                print("--- Element \(index + 1) ---")
                print(info)

                // Print detailed debug info
                printElementDebug(element)

                // Try to get available actions
                var actionsRef: CFArray?
                let result = AXUIElementCopyActionNames(element, &actionsRef)

                if result == .success, let actions = actionsRef as? [String] {
                    print("  🎯 Suggested action: \(actions.first ?? "none")")

                    // Try clicking with the first available action
                    if let firstAction = actions.first {
                        print("\n  Trying to click using: \(firstAction)")
                        let clickResult = AXUIElementPerformAction(element, firstAction as CFString)
                        print("  Result: \(clickResult == .success ? "✅ Success" : "❌ Failed (\(clickResult.rawValue))")")
                    }
                }

                print("\n")
            }

            // Ask user which one to try
            if foundElements.count > 1 {
                print("Multiple elements found. You can modify the search to be more specific.")
            }
        }

        exit(0)
    }

    RunLoop.current.run()
}

/// Find and click the Blank Workbook template with retry
public func exampleExcelBlankWorkbook() {
    if !checkAccessibilityPermission() {
        print("Accessibility permission required.")
        _ = requestAccessibilityPermission()
        exit(1)
    }

    print("=== Excel Blank Workbook Test ===\n")

    launchAppAndGetFocusedWindow(appName: "Excel") { window in
        guard let win = window else {
            print("Could not get window")
            exit(1)
        }

        print("✅ Excel launched")
        Thread.sleep(forTimeInterval: 3)

        // Try to find and click Blank Workbook
        print("🔍 Searching for Blank Workbook template...")

        if let blankWorkbook = findElement(in: win, title: "Blank") {
            print("✅ Found Blank Workbook element")
            printElementDebug(blankWorkbook)

            print("\n🖱️  Attempting to click...")

            // Try multiple click methods
            if clickElementWithRetry(blankWorkbook, debug: true) {
                print("\n✅ Successfully clicked Blank Workbook!")
                Thread.sleep(forTimeInterval: 2)
                print("Excel should now have created a blank workbook")
            } else {
                print("\n❌ Could not click Blank Workbook")
                print("\nTry looking for different text patterns:")
                print("  - 'Workbook'")
                print("  - 'New'")
                print("  - Or check the exact template name in Excel")
            }
        } else {
            print("❌ Could not find element containing 'Blank'")
            print("\nTrying alternative search terms...")

            // Try other search terms
            for searchTerm in ["Workbook", "New", "Template"] {
                if let element = findElement(in: win, title: searchTerm) {
                    print("✅ Found element with '\(searchTerm)'")
                    printElementDebug(element)
                    break
                }
            }
        }

        exit(0)
    }

    RunLoop.current.run()
}
