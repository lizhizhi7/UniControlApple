//
//  ScreenCapture.swift
//  UniControl
//
//  Window screenshot capture for vision-based fallback
//

import Foundation
import ApplicationServices
import CoreGraphics
import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Capture a screenshot of a specific window
/// - Parameter window: The AXUIElement window to capture
/// - Returns: CGImage of the window, or nil if capture fails
@available(macOS 12.3, *)
public func captureWindow(_ window: AXUIElement) async -> CGImage? {
    // Get window ID from AXUIElement
    guard let windowID = getWindowID(from: window) else {
        print("❌ Screenshot failed: Could not get window ID from AXUIElement")
        return nil
    }

    do {
        // Get available content (windows and apps)
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        // Find the window with matching ID
        guard let scWindow = availableContent.windows.first(where: { $0.windowID == CGWindowID(windowID) }) else {
            print("❌ Screenshot failed: Window ID \(windowID) not found in shareable content")
            print("   Available windows: \(availableContent.windows.count)")
            print("   💡 Window may be minimized, hidden, or requires Screen Recording permission")
            return nil
        }

        // Create content filter for this specific window
        let contentFilter = SCContentFilter(desktopIndependentWindow: scWindow)

        // Configure capture (full resolution)
        let config = SCStreamConfiguration()
        config.width = Int(scWindow.frame.width)
        config.height = Int(scWindow.frame.height)
        config.scalesToFit = false

        // Capture screenshot
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: contentFilter,
            configuration: config
        )

        return image
    } catch let error as NSError {
        print("❌ Screenshot failed: \(error.localizedDescription)")
        print("   Error domain: \(error.domain)")
        print("   Error code: \(error.code)")
        if error.domain == "com.apple.screencapturekit" && error.code == -3801 {
            print("   💡 This error usually means Screen Recording permission is required")
            print("   📋 Grant permission: System Settings → Privacy & Security → Screen Recording")
        }
        return nil
    } catch {
        print("❌ Screenshot failed: \(error.localizedDescription)")
        return nil
    }
}

/// Synchronous wrapper for captureWindow (for compatibility)
/// - Parameter window: The AXUIElement window to capture
/// - Returns: CGImage of the window, or nil if capture fails
@available(macOS 12.3, *)
public func captureWindowSync(_ window: AXUIElement) -> CGImage? {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var capturedImage: CGImage?

    Task {
        capturedImage = await captureWindow(window)
        semaphore.signal()
    }

    semaphore.wait()
    return capturedImage
}

/// Get the bounds (position and size) of a window
/// - Parameter window: The AXUIElement window
/// - Returns: CGRect with window bounds, or nil if attributes unavailable
public func captureWindowBounds(_ window: AXUIElement) -> CGRect? {
    // Get position
    guard let positionValue = getAttribute(window, attribute: kAXPositionAttribute as CFString) else {
        return nil
    }

    var position = CGPoint.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else {
        return nil
    }

    // Get size
    guard let sizeValue = getAttribute(window, attribute: kAXSizeAttribute as CFString) else {
        return nil
    }

    var size = CGSize.zero
    guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
        return nil
    }

    return CGRect(origin: position, size: size)
}

/// Get the window ID from an AXUIElement
/// - Parameter window: The AXUIElement window
/// - Returns: Window ID as Int32, or nil if unavailable
private func getWindowID(from window: AXUIElement) -> Int32? {
    // Try to get window ID attribute directly
    if let windowIDValue = getAttribute(window, attribute: "AXWindowID" as CFString) as? Int32 {
        return windowIDValue
    }

    // Fallback: Get PID and find matching window
    var pid: pid_t = 0
    guard AXUIElementGetPid(window, &pid) == .success else {
        return nil
    }

    // Get window bounds for matching
    guard let targetBounds = captureWindowBounds(window) else {
        return nil
    }

    // Get all windows for this PID
    let windowListOption = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
    guard let windowList = CGWindowListCopyWindowInfo(windowListOption, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }

    // Find matching window by PID and bounds
    for windowInfo in windowList {
        guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
              windowPID == pid else {
            continue
        }

        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
            continue
        }

        let windowBounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Check if bounds match (with small tolerance for rounding)
        if abs(windowBounds.origin.x - targetBounds.origin.x) < 2.0 &&
           abs(windowBounds.origin.y - targetBounds.origin.y) < 2.0 &&
           abs(windowBounds.size.width - targetBounds.size.width) < 2.0 &&
           abs(windowBounds.size.height - targetBounds.size.height) < 2.0 {

            if let windowID = windowInfo[kCGWindowNumber as String] as? Int32 {
                return windowID
            }
        }
    }

    return nil
}

/// Save a screenshot to disk as PNG
/// - Parameters:
///   - image: The CGImage to save
///   - path: The file path where the image should be saved
/// - Returns: true if save succeeded, false otherwise
@available(macOS 12.3, *)
public func saveScreenshot(_ image: CGImage, path: String) -> Bool {
    let url = URL(fileURLWithPath: path)

    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        return false
    }

    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

/// Capture and save a window screenshot in one operation
/// - Parameters:
///   - window: The AXUIElement window to capture
///   - path: The file path where the image should be saved
/// - Returns: true if capture and save succeeded, false otherwise
@available(macOS 12.3, *)
public func captureAndSaveWindow(_ window: AXUIElement, path: String) -> Bool {
    guard let image = captureWindowSync(window) else {
        return false
    }

    return saveScreenshot(image, path: path)
}

/// Get the screen coordinates of a window's origin
/// - Parameter window: The AXUIElement window
/// - Returns: CGPoint representing the window's origin, or .zero if unavailable
public func getWindowOrigin(_ window: AXUIElement) -> CGPoint {
    guard let positionValue = getAttribute(window, attribute: kAXPositionAttribute as CFString) else {
        return .zero
    }

    var position = CGPoint.zero
    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else {
        return .zero
    }

    return position
}

/// Downscale an image so its longest edge is at most `maxDimension` pixels.
/// Returns the original image if it is already small enough or scaling fails.
public func downscaleImage(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let longest = max(width, height)
    guard longest > maxDimension else { return image }

    let scale = maxDimension / longest
    let newWidth = Int(width * scale)
    let newHeight = Int(height * scale)

    guard let context = CGContext(
        data: nil,
        width: newWidth,
        height: newHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return image
    }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    return context.makeImage() ?? image
}

/// Encode an image as PNG data
public func pngData(from image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        return nil
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}
