//
//  SystemState.swift
//  UniControl
//
//  System state retrieval functions
//

import Foundation
import ApplicationServices
import AppKit

// MARK: - System Information

/// Get current system information
public func getSystemInfo() -> SystemInfo {
    let processInfo = ProcessInfo.processInfo

    // Get OS version
    let osVersion = processInfo.operatingSystemVersionString

    // Get OS build number using sysctl
    var size = 0
    sysctlbyname("kern.osversion", nil, &size, nil, 0)
    var osBuild = ""
    if size > 0 {
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
        osBuild = String(cString: buffer)
    }

    // Get hostname
    let hostname = processInfo.hostName

    // Get architecture using sysctl
    var archSize = 0
    sysctlbyname("hw.machine", nil, &archSize, nil, 0)
    var architecture = ""
    if archSize > 0 {
        var archBuffer = [CChar](repeating: 0, count: archSize)
        sysctlbyname("hw.machine", &archBuffer, &archSize, nil, 0)
        architecture = String(cString: archBuffer)
    }

    // Get username and home directory
    let username = NSUserName()
    let homeDirectory = NSHomeDirectory()

    return SystemInfo(
        osVersion: osVersion,
        osBuild: osBuild,
        hostname: hostname,
        architecture: architecture,
        username: username,
        homeDirectory: homeDirectory
    )
}

// MARK: - Running Applications

/// Get running applications
/// - Parameter frontmostOnly: If true, returns only the frontmost application
/// - Returns: Array of AppInfo structs
public func getRunningApps(frontmostOnly: Bool = false) -> [AppInfo] {
    let workspace = NSWorkspace.shared
    var apps: [AppInfo] = []

    if frontmostOnly {
        // Get only the frontmost application
        if let frontApp = workspace.frontmostApplication {
            let info = AppInfo(
                name: frontApp.localizedName ?? "Unknown",
                bundleIdentifier: frontApp.bundleIdentifier,
                pid: frontApp.processIdentifier,
                isActive: frontApp.isActive,
                isHidden: frontApp.isHidden,
                launchDate: frontApp.launchDate
            )
            apps.append(info)
        }
    } else {
        // Get all running applications
        for app in workspace.runningApplications {
            // Filter to regular applications only (not background processes)
            if app.activationPolicy == .regular {
                let info = AppInfo(
                    name: app.localizedName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier,
                    pid: app.processIdentifier,
                    isActive: app.isActive,
                    isHidden: app.isHidden,
                    launchDate: app.launchDate
                )
                apps.append(info)
            }
        }
    }

    return apps
}

// MARK: - Windows Information

/// Get information about visible windows
/// - Parameter activeOnly: If true, returns only the active/focused window
/// - Returns: Array of WindowInfo structs
public func getWindowsInfo(activeOnly: Bool = false) -> [WindowInfo] {
    var windows: [WindowInfo] = []
    let workspace = NSWorkspace.shared

    if activeOnly {
        // Get only the active window from the frontmost app
        if let frontApp = workspace.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

            // Try to get focused window first
            if let focusedWindow = getAttribute(appElement, attribute: kAXFocusedWindowAttribute as CFString) {
                let windowElement = focusedWindow as! AXUIElement
                if let info = buildWindowInfo(windowElement, appName: frontApp.localizedName, pid: frontApp.processIdentifier) {
                    windows.append(info)
                }
            } else if let windowList = getAttribute(appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement],
                      let firstWindow = windowList.first {
                // Fall back to first window
                if let info = buildWindowInfo(firstWindow, appName: frontApp.localizedName, pid: frontApp.processIdentifier) {
                    windows.append(info)
                }
            }
        }
    } else {
        // Get all windows from all running applications
        for app in workspace.runningApplications {
            if app.activationPolicy == .regular {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)

                if let windowList = getAttribute(appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] {
                    for window in windowList {
                        if let info = buildWindowInfo(window, appName: app.localizedName, pid: app.processIdentifier) {
                            windows.append(info)
                        }
                    }
                }
            }
        }
    }

    return windows
}

/// Build WindowInfo from an AXUIElement
private func buildWindowInfo(_ window: AXUIElement, appName: String?, pid: pid_t) -> WindowInfo? {
    let title = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String
    let role = getAttribute(window, attribute: kAXRoleAttribute as CFString) as? String
    let subrole = getAttribute(window, attribute: kAXSubroleAttribute as CFString) as? String

    // Get position
    var position: CGPointInfo? = nil
    if let posValue = getAttribute(window, attribute: kAXPositionAttribute as CFString) {
        var point = CGPoint.zero
        if AXValueGetValue(posValue as! AXValue, .cgPoint, &point) {
            position = CGPointInfo(from: point)
        }
    }

    // Get size
    var size: CGSizeInfo? = nil
    if let sizeValue = getAttribute(window, attribute: kAXSizeAttribute as CFString) {
        var sizeVal = CGSize.zero
        if AXValueGetValue(sizeValue as! AXValue, .cgSize, &sizeVal) {
            size = CGSizeInfo(from: sizeVal)
        }
    }

    // Get window states
    let isMain = (getAttribute(window, attribute: kAXMainAttribute as CFString) as? Bool) ?? false
    let isMinimized = (getAttribute(window, attribute: kAXMinimizedAttribute as CFString) as? Bool) ?? false
    let isFullScreen = (getAttribute(window, attribute: "AXFullScreen" as CFString) as? Bool) ?? false

    return WindowInfo(
        title: title,
        role: role,
        subrole: subrole,
        position: position,
        size: size,
        isMain: isMain,
        isMinimized: isMinimized,
        isFullScreen: isFullScreen,
        appName: appName,
        appPID: pid
    )
}
