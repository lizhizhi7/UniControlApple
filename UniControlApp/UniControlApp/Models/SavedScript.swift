//
//  SavedScript.swift
//  UniControlApp
//
//  Model for saved scripts with version history
//

import Foundation

/// Simplified command result for storage (avoids bloating storage with full structured data)
struct StoredCommandResult: Identifiable, Codable {
    let id: UUID
    let index: Int
    let command: String
    let status: String  // "success" or "failure"
    let error: String?
    let value: String?

    init(id: UUID = UUID(), index: Int, command: String, status: String, error: String? = nil, value: String? = nil) {
        self.id = id
        self.index = index
        self.command = command
        self.status = status
        self.error = error
        self.value = value
    }

    var isSuccess: Bool {
        status == "success"
    }
}

/// A saved script with version history
struct SavedScript: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    let createdAt: Date
    var modifiedAt: Date
    var lastExecutedAt: Date?
    var versions: [ScriptVersion]
    var executionHistory: [VersionExecution]

    init(id: UUID = UUID(), name: String, content: String = "", createdAt: Date = Date(), modifiedAt: Date = Date(), lastExecutedAt: Date? = nil, versions: [ScriptVersion] = [], executionHistory: [VersionExecution] = []) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastExecutedAt = lastExecutedAt
        self.versions = versions
        self.executionHistory = executionHistory
    }

    /// Execution record tied to a specific version
    struct VersionExecution: Identifiable, Codable {
        let id: UUID
        let versionId: UUID?  // nil if executed from unsaved content
        let sessionId: UUID
        let executedAt: Date
        var success: Bool?
        var commandsExecuted: Int
        var commandsFailed: Int
        var duration: TimeInterval?
        var isRemote: Bool  // true if executed via remote HTTP request
        var commandResults: [StoredCommandResult]  // Detailed results for each command

        init(id: UUID = UUID(), versionId: UUID? = nil, sessionId: UUID = UUID(), executedAt: Date = Date(), success: Bool? = nil, commandsExecuted: Int = 0, commandsFailed: Int = 0, duration: TimeInterval? = nil, isRemote: Bool = false, commandResults: [StoredCommandResult] = []) {
            self.id = id
            self.versionId = versionId
            self.sessionId = sessionId
            self.executedAt = executedAt
            self.success = success
            self.commandsExecuted = commandsExecuted
            self.commandsFailed = commandsFailed
            self.duration = duration
            self.isRemote = isRemote
            self.commandResults = commandResults
        }

        // Custom decoding to handle missing fields (backward compatibility)
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            versionId = try container.decodeIfPresent(UUID.self, forKey: .versionId)
            sessionId = try container.decode(UUID.self, forKey: .sessionId)
            executedAt = try container.decode(Date.self, forKey: .executedAt)
            success = try container.decodeIfPresent(Bool.self, forKey: .success)
            commandsExecuted = try container.decode(Int.self, forKey: .commandsExecuted)
            commandsFailed = try container.decode(Int.self, forKey: .commandsFailed)
            duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
            isRemote = try container.decodeIfPresent(Bool.self, forKey: .isRemote) ?? false
            commandResults = try container.decodeIfPresent([StoredCommandResult].self, forKey: .commandResults) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case id, versionId, sessionId, executedAt, success, commandsExecuted, commandsFailed, duration, isRemote, commandResults
        }

        var statusIcon: String {
            guard let success = success else {
                return "circle.dotted"
            }
            if commandsFailed == 0 {
                return "checkmark.circle.fill"
            } else if success {
                return "exclamationmark.triangle.fill"
            } else {
                return "xmark.circle.fill"
            }
        }

        var statusColor: String {
            guard let success = success else {
                return "blue"
            }
            if commandsFailed == 0 {
                return "green"
            } else if success {
                return "orange"
            } else {
                return "red"
            }
        }
    }

    /// A single version snapshot of a script
    struct ScriptVersion: Identifiable, Codable {
        let id: UUID
        let content: String
        let savedAt: Date
        var note: String?
        var lastExecutionId: UUID?  // Reference to last execution for this version
        var isRemote: Bool  // true if version was created from remote execution

        init(id: UUID = UUID(), content: String, savedAt: Date = Date(), note: String? = nil, lastExecutionId: UUID? = nil, isRemote: Bool = false) {
            self.id = id
            self.content = content
            self.savedAt = savedAt
            self.note = note
            self.lastExecutionId = lastExecutionId
            self.isRemote = isRemote
        }

        // Custom decoding to handle missing isRemote field (backward compatibility)
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            content = try container.decode(String.self, forKey: .content)
            savedAt = try container.decode(Date.self, forKey: .savedAt)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            lastExecutionId = try container.decodeIfPresent(UUID.self, forKey: .lastExecutionId)
            isRemote = try container.decodeIfPresent(Bool.self, forKey: .isRemote) ?? false
        }

        private enum CodingKeys: String, CodingKey {
            case id, content, savedAt, note, lastExecutionId, isRemote
        }
    }

    /// Create a new version snapshot
    mutating func saveVersion(note: String? = nil, isRemote: Bool = false) {
        let version = ScriptVersion(content: content, note: note, isRemote: isRemote)
        versions.append(version)
        modifiedAt = Date()
    }

    /// Restore content from a version
    mutating func restoreVersion(_ versionId: UUID) {
        guard let version = versions.first(where: { $0.id == versionId }) else { return }
        content = version.content
        modifiedAt = Date()
    }

    /// Record an execution
    mutating func recordExecution(versionId: UUID?, sessionId: UUID, success: Bool?, commandsExecuted: Int, commandsFailed: Int, duration: TimeInterval?, isRemote: Bool = false, commandResults: [StoredCommandResult] = []) {
        let execution = VersionExecution(
            versionId: versionId,
            sessionId: sessionId,
            executedAt: Date(),
            success: success,
            commandsExecuted: commandsExecuted,
            commandsFailed: commandsFailed,
            duration: duration,
            isRemote: isRemote,
            commandResults: commandResults
        )
        executionHistory.insert(execution, at: 0)
        lastExecutedAt = execution.executedAt

        // Update version's last execution reference
        if let vId = versionId, let index = versions.firstIndex(where: { $0.id == vId }) {
            versions[index].lastExecutionId = execution.id
        }

        // Trim history to last 50 executions
        if executionHistory.count > 50 {
            executionHistory = Array(executionHistory.prefix(50))
        }
    }

    /// Check if content matches any existing version
    func hasVersion(with content: String) -> Bool {
        versions.contains { $0.content == content } || self.content == content
    }

    /// Find version ID for given content
    func versionId(for content: String) -> UUID? {
        if self.content == content {
            return versions.last?.id
        }
        return versions.first { $0.content == content }?.id
    }

    /// Get last execution for this script
    var lastExecution: VersionExecution? {
        executionHistory.first
    }

    /// Get executions for a specific version
    func executions(for versionId: UUID) -> [VersionExecution] {
        executionHistory.filter { $0.versionId == versionId }
    }

    /// Preview of the script content
    var contentPreview: String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        let preview = lines.prefix(2).joined(separator: " ")
        if preview.count > 60 {
            return String(preview.prefix(57)) + "..."
        }
        return preview.isEmpty ? "(empty)" : preview
    }

    /// Number of lines in the script
    var lineCount: Int {
        content.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}
