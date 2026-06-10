//
//  AppLauncher.swift
//  UniControl
//
//  Application launching and window management
//

import Foundation
import Cocoa
import ApplicationServices

/// Launch an application by name
public func launchApp(appName name: String) {
    let fileManager = FileManager.default
    let appDirectories = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications"
    ]

    var atPath: String = ""
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

/// Get the focused window of the frontmost application
public func getFrontmostAppFocusedWindow() -> AXUIElement? {
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

/// Move a window to a specific position
public func moveWindow(_ window: AXUIElement, to point: CGPoint) {
    var mutablePoint = point
    let positionValue = AXValueCreate(.cgPoint, &mutablePoint)!
    let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)

    if result == .success {
        print("Window moved to \(point)")
    } else {
        print("Failed to move window: \(result.rawValue)")
    }
}

/// Launch an app and get its focused window asynchronously
public func launchAppAndGetFocusedWindow(appName: String, completion: @escaping (AXUIElement?) -> Void) {
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

/// Find a window whose title contains the given substring (case-insensitive),
/// searching the windows of all regular running applications.
public func findWindow(titleContains query: String) -> AXUIElement? {
    let lowered = query.lowercased()

    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = getAttribute(appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] else {
            continue
        }
        for window in windows {
            if let title = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String,
               title.lowercased().contains(lowered) {
                return window
            }
        }
    }
    return nil
}
