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

    /// Script library for managing saved scripts
    let scriptLibrary: ScriptLibrary

    /// Show accessibility permission alert
    var showAccessibilityAlert: Bool = false

    /// Selected tab
    var selectedTab: Tab = .scripts

    enum Tab: String, CaseIterable {
        case scripts = "Scripts"
        case settings = "Settings"
    }

    init() {
        self.settings = AppSettings.load()
        self.serverManager = ServerManager()
        self.scriptLibrary = ScriptLibrary()

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
        // Track in script library if we have a selected script
        scriptLibrary.handleExecutionStarted(executionId: id, script: script)
    }

    private func handleExecutionCompleted(id: UUID, response: ExecuteResponse) {
        // Convert CommandExecutionResult to StoredCommandResult (simplified for storage)
        let storedResults = response.results.map { result in
            StoredCommandResult(
                index: result.index,
                command: result.command,
                status: result.status,
                error: result.error,
                value: result.value
            )
        }

        // Update script library with execution results
        scriptLibrary.handleExecutionCompleted(
            executionId: id,
            success: response.success,
            commandsExecuted: response.commandsExecuted,
            commandsFailed: response.commandsFailed,
            commandResults: storedResults
        )
    }
}
