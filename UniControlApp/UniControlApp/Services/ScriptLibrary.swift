//
//  ScriptLibrary.swift
//  UniControlApp
//
//  Observable class managing saved scripts
//

import Foundation

@MainActor
@Observable
class ScriptLibrary {
    /// All saved scripts
    private(set) var scripts: [SavedScript] = []

    /// Currently selected script for editing
    var selectedScriptId: UUID?

    /// Unsaved content in the editor (for tracking changes)
    var unsavedContent: String = ""

    /// Search query for filtering scripts
    var searchQuery: String = ""

    /// Sort order for scripts
    var sortOrder: SortOrder = .lastExecuted

    /// Current version being executed (for tracking)
    var currentExecutingVersionId: UUID?

    /// Pending execution tracking
    private var pendingExecutions: [UUID: PendingExecution] = [:]

    /// Info about a pending execution
    private struct PendingExecution {
        let scriptId: UUID
        let versionId: UUID?
        let startTime: Date
        let isRemote: Bool
        let scriptContent: String
    }

    enum SortOrder: String, CaseIterable {
        case lastExecuted = "Last Executed"
        case created = "Created"
        case name = "Name"
    }

    init() {
        loadScripts()
    }

    // MARK: - Computed Properties

    var selectedScript: SavedScript? {
        guard let id = selectedScriptId else { return nil }
        return scripts.first { $0.id == id }
    }

    /// Check if current content differs from saved content
    var hasUnsavedChanges: Bool {
        guard let script = selectedScript else { return false }
        return unsavedContent != script.content
    }

    /// Filtered and sorted scripts
    var filteredScripts: [SavedScript] {
        var result = scripts

        // Apply search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { script in
                script.name.lowercased().contains(query) ||
                script.content.lowercased().contains(query)
            }
        }

        // Apply sort
        switch sortOrder {
        case .lastExecuted:
            result.sort { s1, s2 in
                let t1 = s1.lastExecutedAt ?? s1.createdAt
                let t2 = s2.lastExecutedAt ?? s2.createdAt
                return t1 > t2
            }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return result
    }

    // MARK: - Script Management

    /// Load scripts from disk
    func loadScripts() {
        scripts = PersistenceManager.shared.loadScripts()
    }

    /// Save all scripts to disk
    private func saveScripts() {
        PersistenceManager.shared.saveScripts(scripts)
    }

    /// Create a new script
    @discardableResult
    func createScript(name: String, content: String = "") -> SavedScript {
        let script = SavedScript(name: name, content: content)
        scripts.insert(script, at: 0)
        saveScripts()
        return script
    }

    /// Update a script's content
    func updateScript(id: UUID, content: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].content = content
        scripts[index].modifiedAt = Date()
        saveScripts()
    }

    /// Rename a script
    func renameScript(id: UUID, name: String) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[index].name = name
        scripts[index].modifiedAt = Date()
        saveScripts()
    }

    /// Delete a script
    func deleteScript(id: UUID) {
        scripts.removeAll { $0.id == id }
        if selectedScriptId == id {
            selectedScriptId = nil
            unsavedContent = ""
        }
        PersistenceManager.shared.deleteScript(id: id)
    }

    // MARK: - Script Matching

    /// Find a script that matches the given content (exact match or version match)
    func findScript(byContent content: String) -> SavedScript? {
        // First check for exact content match
        if let script = scripts.first(where: { $0.content == content }) {
            return script
        }
        // Then check versions
        return scripts.first { script in
            script.versions.contains { $0.content == content }
        }
    }

    /// Find a script that best matches the content (using similarity if no exact match)
    func findBestMatchingScript(for content: String) -> SavedScript? {
        // First try exact match
        if let exact = findScript(byContent: content) {
            return exact
        }

        // If content is very short, don't try fuzzy matching
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.count < 10 {
            return nil
        }

        // Find script with highest content similarity (simple line-based matching)
        let contentLines = Set(trimmedContent.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) })
        var bestMatch: (script: SavedScript, score: Double)?

        for script in scripts {
            let scriptLines = Set(script.content.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) })
            let intersection = contentLines.intersection(scriptLines)
            let union = contentLines.union(scriptLines)

            guard !union.isEmpty else { continue }
            let score = Double(intersection.count) / Double(union.count)

            // Require at least 70% similarity
            if score > 0.7 {
                if bestMatch == nil || score > bestMatch!.score {
                    bestMatch = (script, score)
                }
            }
        }

        return bestMatch?.script
    }

    // MARK: - Version Management

    /// Save a version of the script with an optional note
    func saveVersion(for scriptId: UUID, content: String, note: String?, isRemote: Bool = false) {
        guard let index = scripts.firstIndex(where: { $0.id == scriptId }) else { return }
        scripts[index].content = content
        scripts[index].saveVersion(note: note, isRemote: isRemote)
        saveScripts()
    }

    /// Restore a version
    func restoreVersion(_ versionId: UUID, for scriptId: UUID) {
        guard let index = scripts.firstIndex(where: { $0.id == scriptId }) else { return }
        scripts[index].restoreVersion(versionId)
        if selectedScriptId == scriptId {
            unsavedContent = scripts[index].content
        }
        saveScripts()
    }

    /// Auto-save version after successful execution
    func autoSaveVersionAfterExecution(for scriptId: UUID, content: String, isRemote: Bool = false) {
        let note = isRemote ? "Auto-save after remote execution" : "Auto-save after successful execution"
        saveVersion(for: scriptId, content: content, note: note, isRemote: isRemote)
    }

    /// Get the current version ID for a script (if content matches a version)
    func currentVersionId(for scriptId: UUID, content: String) -> UUID? {
        guard let script = scripts.first(where: { $0.id == scriptId }) else { return nil }
        return script.versionId(for: content)
    }

    // MARK: - Selection

    /// Select a script for editing
    func selectScript(_ id: UUID?) {
        selectedScriptId = id
        if let id = id, let script = scripts.first(where: { $0.id == id }) {
            unsavedContent = script.content
        } else {
            unsavedContent = ""
        }
    }

    /// Save current unsaved changes
    func saveCurrentChanges() {
        guard let id = selectedScriptId else { return }
        updateScript(id: id, content: unsavedContent)
    }

    // MARK: - Execution Tracking

    /// Called when an execution starts
    func handleExecutionStarted(executionId: UUID, script: String) {
        // First, check if this matches the currently selected script (local execution)
        if let scriptId = selectedScriptId, unsavedContent == script {
            let versionId = currentVersionId(for: scriptId, content: script)
            pendingExecutions[executionId] = PendingExecution(
                scriptId: scriptId,
                versionId: versionId,
                startTime: Date(),
                isRemote: false,
                scriptContent: script
            )
            return
        }

        // Otherwise, try to find a matching script (remote execution)
        if let matchedScript = findBestMatchingScript(for: script) {
            let versionId = matchedScript.versionId(for: script)
            pendingExecutions[executionId] = PendingExecution(
                scriptId: matchedScript.id,
                versionId: versionId,
                startTime: Date(),
                isRemote: true,
                scriptContent: script
            )
        }
        // If no match found, execution won't be tracked in the library
    }

    /// Called when an execution completes
    func handleExecutionCompleted(executionId: UUID, success: Bool, commandsExecuted: Int, commandsFailed: Int) {
        guard let pending = pendingExecutions.removeValue(forKey: executionId) else { return }
        guard let index = scripts.firstIndex(where: { $0.id == pending.scriptId }) else { return }

        let duration = Date().timeIntervalSince(pending.startTime)

        // Record the execution in the script
        scripts[index].recordExecution(
            versionId: pending.versionId,
            sessionId: executionId,
            success: success,
            commandsExecuted: commandsExecuted,
            commandsFailed: commandsFailed,
            duration: duration,
            isRemote: pending.isRemote
        )

        saveScripts()

        // Auto-save version after execution
        if pending.isRemote {
            // For remote executions: always save a new version if content is different
            if !scripts[index].hasVersion(with: pending.scriptContent) {
                autoSaveVersionAfterExecution(for: pending.scriptId, content: pending.scriptContent, isRemote: true)
            }
        } else {
            // For local executions: only save on success if content has changed
            if success && hasUnsavedChanges {
                autoSaveVersionAfterExecution(for: pending.scriptId, content: unsavedContent, isRemote: false)
            }
        }
    }

    /// Clear execution history for a script
    func clearExecutionHistory(for scriptId: UUID) {
        guard let index = scripts.firstIndex(where: { $0.id == scriptId }) else { return }
        scripts[index].executionHistory.removeAll()
        saveScripts()
    }
}
