//
//  Permissions.swift
//  UniControl
//
//  Accessibility permission handling
//

import Foundation
import ApplicationServices

/// Check if the app has accessibility permissions
public func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

/// Request accessibility permissions from the user
public func requestAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
