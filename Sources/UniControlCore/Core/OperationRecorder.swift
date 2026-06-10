//
//  OperationRecorder.swift
//  UniControl
//
//  Records user interactions (clicks, keystrokes) as a .unictl script.
//  Clicks are hit-tested against the accessibility tree so they replay as
//  robust `find` + `click` commands; elements without text fall back to
//  coordinate clicks.
//

import Foundation
import ApplicationServices
import CoreGraphics
import AppKit

// MARK: - Key Classification (pure, testable)

/// How a recorded key event should be represented in the script
public enum RecordedKey: Equatable {
    case text(String)       // printable text — accumulate into a `type` line
    case combo(String)      // shortcut / special key — a `presskey` line
    case ignore
}

private let specialKeyNames: [Int64: String] = [
    36: "return",
    48: "tab",
    53: "escape",
    51: "delete",
    117: "forwarddelete",
    123: "left",
    124: "right",
    125: "down",
    126: "up",
    115: "home",
    119: "end",
    116: "pageup",
    121: "pagedown",
]

/// Classify a key event for recording.
/// - Parameters:
///   - keyCode: the virtual key code
///   - cmd/ctrl/alt/shift: modifier state
///   - typed: the unicode string the event would type (already shift-adjusted)
public func classifyKey(keyCode: Int64, cmd: Bool, ctrl: Bool, alt: Bool, shift: Bool, typed: String) -> RecordedKey {
    // Bare modifier keys produce no useful event here
    let specialName = specialKeyNames[keyCode]

    if cmd || ctrl {
        var parts: [String] = []
        if cmd { parts.append("cmd") }
        if ctrl { parts.append("ctrl") }
        if alt { parts.append("alt") }
        if shift { parts.append("shift") }
        let keyName = specialName ?? typed.lowercased()
        guard !keyName.isEmpty else { return .ignore }
        parts.append(keyName)
        return .combo(parts.joined(separator: "+"))
    }

    if let specialName = specialName {
        return .combo(specialName)
    }

    // Plain printable text (shift handled by the typed string itself)
    guard !typed.isEmpty, typed.allSatisfy({ !$0.isASCII || ($0.asciiValue ?? 0) >= 32 }) else {
        return .ignore
    }
    return .text(typed)
}

// MARK: - Recorder

public final class OperationRecorder {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) public var lines: [String] = []
    private var textBuffer = ""
    private var lastWindowTitle: String?
    private let echo: Bool
    public private(set) var keyboardCaptured = false

    public init(echo: Bool = true) {
        self.echo = echo
    }

    /// Start the event tap. Returns false if no tap could be created
    /// (missing Accessibility permission). Keyboard capture additionally
    /// needs Input Monitoring on recent macOS; if unavailable, recording
    /// continues with clicks only and `keyboardCaptured` stays false.
    public func start() -> Bool {
        let mouseMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)
        let fullMask = mouseMask | (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<OperationRecorder>.fromOpaque(userInfo).takeUnretainedValue()
            recorder.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        if let fullTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: fullMask,
            callback: callback,
            userInfo: userInfo
        ) {
            tap = fullTap
            keyboardCaptured = true
        } else if let mouseTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mouseMask,
            callback: callback,
            userInfo: userInfo
        ) {
            tap = mouseTap
            keyboardCaptured = false
        } else {
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap!, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap!, enable: true)
        return true
    }

    public func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        flushText()
    }

    /// The recorded script text
    public func script() -> String {
        var header = [
            "# Recorded by UniControl --record",
            "# Review before replaying: `type` sets a field's whole value (it does not append),",
            "# and find lines use the element titles seen during recording.",
            "",
        ]
        header.append(contentsOf: lines)
        return header.joined(separator: "\n") + "\n"
    }

    public func save(to path: String) -> Bool {
        (try? script().write(toFile: path, atomically: true, encoding: .utf8)) != nil
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            handleClick(at: event.location, right: false)
        case .rightMouseDown:
            handleClick(at: event.location, right: true)
        case .keyDown:
            handleKey(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        default:
            break
        }
    }

    private func handleClick(at point: CGPoint, right: Bool) {
        flushText()

        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &elementRef)

        guard error == .success, let element = elementRef else {
            emit("clickat \(Int(point.x)) \(Int(point.y))\(right ? " right" : "")")
            return
        }

        // Track window changes so the replay attaches to the right window
        var windowRef: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowRef) == .success {
            let window = unsafeBitCast(windowRef as CFTypeRef, to: AXUIElement.self)
            let windowTitle = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String
            if let windowTitle = windowTitle, !windowTitle.isEmpty, windowTitle != lastWindowTitle {
                emit("usewindow \(windowTitle)")
                lastWindowTitle = windowTitle
            }
        }

        let role = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String
        let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
        let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
        let label = [title, description].compactMap { $0 }.first { !$0.isEmpty }

        if let label = label, let role = role {
            emit("find \(label) role: \(role)")
            emit(right ? "rightclick" : "click")
        } else {
            emit("clickat \(Int(point.x)) \(Int(point.y))\(right ? " right" : "")")
        }
    }

    private func handleKey(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        let typed = String(utf16CodeUnits: chars, count: length)

        switch classifyKey(
            keyCode: keyCode,
            cmd: flags.contains(.maskCommand),
            ctrl: flags.contains(.maskControl),
            alt: flags.contains(.maskAlternate),
            shift: flags.contains(.maskShift),
            typed: typed
        ) {
        case .text(let text):
            textBuffer += text
        case .combo(let combo):
            flushText()
            emit("presskey \(combo)")
        case .ignore:
            break
        }
    }

    private func flushText() {
        guard !textBuffer.isEmpty else { return }
        emit("type \(textBuffer)")
        textBuffer = ""
    }

    private func emit(_ line: String) {
        lines.append(line)
        if echo {
            print("  + \(line)")
        }
    }
}
