//
//  ScriptExecutionRecord.swift
//  UniControlApp
//
//  Model for tracking script execution history
//

import Foundation
import UniControlCore

/// Local record of a script execution for history display
struct ScriptExecutionRecord: Identifiable {
    let id: UUID
    let script: String
    let mode: String?
    let startTime: Date
    var endTime: Date?
    var success: Bool?
    var commandsExecuted: Int = 0
    var commandsFailed: Int = 0
    var logs: [LogEntry] = []
    var results: [CommandResult] = []

    init(id: UUID = UUID(), script: String, mode: String? = nil, startTime: Date = Date()) {
        self.id = id
        self.script = script
        self.mode = mode
        self.startTime = startTime
    }

    var isComplete: Bool {
        return success != nil
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var scriptPreview: String {
        let lines = script.split(separator: "\n", omittingEmptySubsequences: true)
        let preview = lines.prefix(1).joined(separator: " ")
        if preview.count > 50 {
            return String(preview.prefix(47)) + "..."
        }
        return preview
    }

    var statusIcon: String {
        guard let success = success else {
            return "circle.dotted"  // In progress
        }
        if commandsFailed == 0 {
            return "checkmark.circle.fill"
        } else if success {
            return "exclamationmark.triangle.fill"  // Partial success
        } else {
            return "xmark.circle.fill"
        }
    }

    var statusColor: String {
        guard let success = success else {
            return "blue"  // In progress
        }
        if commandsFailed == 0 {
            return "green"
        } else if success {
            return "orange"  // Partial success
        } else {
            return "red"
        }
    }
}

/// Log entry for display
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevelDisplay
    let message: String

    enum LogLevelDisplay: String {
        case info
        case success
        case error
        case warning
        case debug

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .error: return "xmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .debug: return "magnifyingglass"
            }
        }

        var color: String {
            switch self {
            case .info: return "primary"
            case .success: return "green"
            case .error: return "red"
            case .warning: return "orange"
            case .debug: return "gray"
            }
        }
    }
}

/// Command result for display
struct CommandResult: Identifiable {
    let id = UUID()
    let index: Int
    let command: String
    let status: ResultStatus
    let error: String?
    let value: String?

    enum ResultStatus {
        case success
        case failure

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .success: return "green"
            case .failure: return "red"
            }
        }
    }
}
