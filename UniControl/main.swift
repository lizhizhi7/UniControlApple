//
//  main.swift
//  UniControl
//
//  Created by Oliver Li on 2025/7/15.
//

import Foundation
import Cocoa
import ApplicationServices

func launchApp(appName name: String) {
    let fileManager = FileManager.default
    let appDirectories = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications"
    ]
    
    var atPath: String = "";
    for dir in appDirectories {
        if !atPath.isEmpty {
            break
        }
        print("Scanning directory: \(dir)")
        if let apps = try? fileManager.contentsOfDirectory(atPath: dir) {
            for app in apps where app.hasSuffix(".app") && app.contains(name) {
                atPath = "\(dir)/\(app)"
                print("Found app: \(app) at \(atPath)")
            }
        } else {
            print("Could not access directory: \(dir)")
        }
    }
    
    if !atPath.isEmpty {
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: atPath)
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        workspace.openApplication(at: appURL, configuration: configuration) { app, error in
            if let error = error {
                print("Failed to open app: \(error.localizedDescription)")
            } else {
                print("App launched successfully: \(String(describing: app))")
            }
        }
    }
}

func getFrontmostAppFocusedWindow() -> AXUIElement? {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
        print("No frontmost app")
        return nil
    }
    
    let pid = frontmostApp.processIdentifier
    let appElement = AXUIElementCreateApplication(pid)
    
    var focusedWindow: AnyObject?
    let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
    
    if result == .success, let window = focusedWindow {
        return unsafeBitCast(window, to: AXUIElement.self)
    } else {
        print("Failed to get focused window: \(result.rawValue)")
        return nil
    }
}

func moveWindow(_ window: AXUIElement, to point: CGPoint) {
    var mutablePoint = point
    let positionValue = AXValueCreate(.cgPoint, &mutablePoint)!
    let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    
    if result == .success {
        print("Window moved to \(point)")
    } else {
        print("Failed to move window: \(result.rawValue)")
    }
}

// Helper function to get attribute value as CFType
func getAttribute(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    if result == .success {
        return value
    }
    return nil
}

// Recursive function to find all buttons under an AXUIElement
func findAllButtons(in element: AXUIElement) -> [AXUIElement] {
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


func launchAppAndGetFocusedWindow(appName: String, completion: @escaping (AXUIElement?) -> Void) {
    launchApp(appName: appName)

    // Wait for the app to appear in runningApplications
    DispatchQueue.global().async {
        let workspace = NSWorkspace.shared
        var app: NSRunningApplication?
        for _ in 0..<20 { // try for up to ~10 seconds
            if let runningApp = workspace.runningApplications.first(where: { $0.localizedName?.contains(appName) == true }) {
                app = runningApp
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        guard let runningApp = app else {
            print("App did not launch")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)
        
        // Retry function to get focused window
        func getFocusedWindowWithRetry(retries: Int = 10, delay: TimeInterval = 0.5, completion: @escaping (AXUIElement?) -> Void) {
            var attempts = 0
            
            func attempt() {
                var focusedWindow: AnyObject?
                let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
                
                if result == .success, let window = focusedWindow {
                    completion(unsafeBitCast(window, to: AXUIElement.self))
                } else if attempts < retries {
                    attempts += 1
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                } else {
                    print("Failed to get focused window after \(attempts) attempts, error: \(result.rawValue)")
                    completion(nil)
                }
            }
            
            attempt()
        }
        
        getFocusedWindowWithRetry(completion: completion)
    }
}

func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func requestAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func example() {
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

example()
