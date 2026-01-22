//
//  AppState.swift
//  UniControlApp
//
//  Main application state container
//

import Foundation
import UniControlCore

@MainActor
@Observable
class AppState {
    /// Application settings (persisted)
    var settings: AppSettings {
        didSet {
            settings.save()
            applySettings()
        }
    }

    /// Server manager
    let serverManager: ServerManager

    /// Execution history
    private(set) var executionHistory: [ScriptExecutionRecord] = []

    /// Currently selected execution (for detail view)
    var selectedExecutionId: UUID?

    /// Show accessibility permission alert
    var showAccessibilityAlert: Bool = false

    /// Selected tab
    var selectedTab: Tab = .history

    enum Tab: String, CaseIterable {
        case history = "History"
        case settings = "Settings"
    }

    init() {
        self.settings = AppSettings.load()
        self.serverManager = ServerManager()

        // Configure server manager
        applySettings()
        setupServerCallbacks()
    }

    // MARK: - Settings Application

    private func applySettings() {
        serverManager.verboseLogging = settings.logLevel == .debug
        serverManager.defaultExecutionMode = settings.executionMode.toExecutionMode()
    }

    // MARK: - Server Callbacks

    private func setupServerCallbacks() {
        serverManager.onExecutionStarted = { [weak self] executionId, script, mode in
            self?.handleExecutionStarted(id: executionId, script: script, mode: mode)
        }

        serverManager.onExecutionCompleted = { [weak self] executionId, response in
            self?.handleExecutionCompleted(id: executionId, response: response)
        }
    }

    private func handleExecutionStarted(id: UUID, script: String, mode: String?) {
        let execution = ScriptExecutionRecord(
            id: id,
            script: script,
            mode: mode,
            startTime: Date()
        )

        // Add to history (at the beginning)
        executionHistory.insert(execution, at: 0)

        // Trim history if needed
        if executionHistory.count > settings.maxHistoryItems {
            executionHistory = Array(executionHistory.prefix(settings.maxHistoryItems))
        }
    }

    private func handleExecutionCompleted(id: UUID, response: ExecuteResponse) {
        guard let index = executionHistory.firstIndex(where: { $0.id == id }) else {
            return
        }

        // Update the execution record
        executionHistory[index].endTime = Date()
        executionHistory[index].success = response.success
        executionHistory[index].commandsExecuted = response.commandsExecuted
        executionHistory[index].commandsFailed = response.commandsFailed

        // Convert command results
        executionHistory[index].results = response.results.map { result in
            CommandResult(
                index: result.index,
                command: result.command,
                status: result.status == "success" ? .success : .failure,
                error: result.error,
                value: result.value
            )
        }
    }

    // MARK: - Computed Properties

    var selectedExecution: ScriptExecutionRecord? {
        guard let id = selectedExecutionId else { return nil }
        return executionHistory.first { $0.id == id }
    }

    // MARK: - Actions

    func clearHistory() {
        executionHistory.removeAll()
        selectedExecutionId = nil
    }

    func removeExecution(_ id: UUID) {
        executionHistory.removeAll { $0.id == id }
        if selectedExecutionId == id {
            selectedExecutionId = nil
        }
    }
}
