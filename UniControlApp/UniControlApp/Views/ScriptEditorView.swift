//
//  ScriptEditorView.swift
//  UniControlApp
//
//  Unified script editor with library, editor, and execution history
//

import SwiftUI

struct ScriptEditorView: View {
    @Bindable var appState: AppState
    @State private var showNewScriptSheet = false
    @State private var showRenameSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showVersionHistory = false
    @State private var newScriptName = ""
    @State private var historyExpanded = true
    @State private var selectedExecutionId: UUID?

    private var scriptLibrary: ScriptLibrary {
        appState.scriptLibrary
    }

    var body: some View {
        HSplitView {
            // Left: Script library with search and status
            scriptLibraryPanel
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 300, maxHeight: .infinity)

            // Right: Editor + Execution history
            rightPanel
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showNewScriptSheet) {
            NewScriptSheet(name: $newScriptName) {
                if !newScriptName.isEmpty {
                    let script = scriptLibrary.createScript(name: newScriptName)
                    scriptLibrary.selectScript(script.id)
                    newScriptName = ""
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameScriptSheet(
                name: $newScriptName,
                originalName: scriptLibrary.selectedScript?.name ?? ""
            ) {
                if let id = scriptLibrary.selectedScriptId, !newScriptName.isEmpty {
                    scriptLibrary.renameScript(id: id, name: newScriptName)
                    newScriptName = ""
                }
            }
        }
        .alert("Delete Script?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = scriptLibrary.selectedScriptId {
                    scriptLibrary.deleteScript(id: id)
                }
            }
        } message: {
            Text("This will permanently delete \"\(scriptLibrary.selectedScript?.name ?? "this script")\" and all its versions and execution history.")
        }
        .sheet(isPresented: $showVersionHistory) {
            if let script = scriptLibrary.selectedScript {
                VersionHistorySheet(script: script) { versionId in
                    scriptLibrary.restoreVersion(versionId, for: script.id)
                }
            }
        }
    }

    // MARK: - Script Library Panel

    private var scriptLibraryPanel: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 8) {
                HStack {
                    Text("Scripts")
                        .font(.headline)

                    Spacer()

                    Button(action: { showNewScriptSheet = true }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("New Script")
                }

                // Sort and search
                HStack(spacing: 6) {
                    // Sort button (cycles through sort types)
                    Button(action: cycleSortOrder) {
                        Image(systemName: sortOrderIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Sort: \(appState.scriptLibrary.sortOrder.rawValue)\nClick to change")

                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Search", text: Binding(
                            get: { appState.scriptLibrary.searchQuery },
                            set: { appState.scriptLibrary.searchQuery = $0 }
                        ))
                            .textFieldStyle(.plain)
                            .font(.caption)
                    }
                    .padding(6)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                }
            }
            .padding(10)

            Divider()

            // Script list
            if scriptLibrary.filteredScripts.isEmpty {
                ContentUnavailableView {
                    Label(scriptLibrary.searchQuery.isEmpty ? "No Scripts" : "No Results", systemImage: "doc.text")
                } description: {
                    Text(scriptLibrary.searchQuery.isEmpty ? "Create a new script to get started" : "Try a different search")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(scriptLibrary.filteredScripts, selection: Binding(
                    get: { scriptLibrary.selectedScriptId },
                    set: { scriptLibrary.selectScript($0) }
                )) { script in
                    ScriptListRow(script: script, isSelected: script.id == scriptLibrary.selectedScriptId)
                        .tag(script.id)
                        .contextMenu {
                            Button("Rename...") {
                                newScriptName = script.name
                                scriptLibrary.selectScript(script.id)
                                showRenameSheet = true
                            }
                            if let sessionId = script.lastExecution?.sessionId {
                                Button("Copy Last Session ID") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(sessionId.uuidString, forType: .string)
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                scriptLibrary.selectScript(script.id)
                                showDeleteConfirmation = true
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Right Panel (Editor + History)

    private var rightPanel: some View {
        VStack(spacing: 0) {
            if scriptLibrary.selectedScript != nil {
                // Editor (majority of space)
                VStack(spacing: 0) {
                    editorToolbar
                    Divider()
                    DSLTextEditor(
                        text: Binding(
                            get: { scriptLibrary.unsavedContent },
                            set: { scriptLibrary.unsavedContent = $0 }
                        ),
                        onRun: runScript
                    )
                }

                // Collapsible execution history
                executionHistoryPanel
            } else {
                ContentUnavailableView {
                    Label("Select a Script", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Select a script from the library or create a new one")
                }
            }
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // Script name with unsaved indicator
            HStack(spacing: 4) {
                Text(scriptLibrary.selectedScript?.name ?? "")
                    .font(.headline)

                if scriptLibrary.hasUnsavedChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")
                }
            }

            Spacer()

            // Version history button
            if let script = scriptLibrary.selectedScript, !script.versions.isEmpty {
                Button(action: { showVersionHistory = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("\(script.versions.count)")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Version History")
            }

            // Save button
            Button(action: saveScript) {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .disabled(!scriptLibrary.hasUnsavedChanges)
            .help("Save (Cmd+S)")
            .keyboardShortcut("s", modifiers: .command)

            // Save version button
            Button(action: saveVersion) {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(.borderless)
            .help("Save Version")

            Divider()
                .frame(height: 16)

            // Run button
            Button(action: runScript) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("Run")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!appState.serverManager.status.isRunning)
            .help("Run Script (Cmd+Enter)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Execution History Panel

    private var executionHistoryPanel: some View {
        VStack(spacing: 0) {
            if let executionId = selectedExecutionId,
               let script = scriptLibrary.selectedScript,
               let execution = script.executionHistory.first(where: { $0.id == executionId }) {
                // Detail view
                ExecutionDetailView(
                    execution: execution,
                    versionName: versionName(for: execution.versionId, in: script),
                    onBack: { withAnimation { selectedExecutionId = nil } }
                )
            } else {
                // List view
                executionHistoryListView
            }
        }
    }

    private var executionHistoryListView: some View {
        VStack(spacing: 0) {
            // Header (clickable to expand/collapse)
            Button(action: { withAnimation { historyExpanded.toggle() } }) {
                HStack {
                    Image(systemName: historyExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Execution History")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let script = scriptLibrary.selectedScript {
                        Text("(\(script.executionHistory.count))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if historyExpanded, let id = scriptLibrary.selectedScriptId,
                       let script = scriptLibrary.selectedScript,
                       !script.executionHistory.isEmpty {
                        Button(action: { scriptLibrary.clearExecutionHistory(for: id) }) {
                            Image(systemName: "trash")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .help("Clear History")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
            }
            .buttonStyle(.plain)

            if historyExpanded {
                Divider()

                if let script = scriptLibrary.selectedScript {
                    if script.executionHistory.isEmpty {
                        Text("No executions yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(script.executionHistory) { execution in
                                    ExecutionHistoryRow(
                                        execution: execution,
                                        versionName: versionName(for: execution.versionId, in: script),
                                        onSelect: {
                                            withAnimation { selectedExecutionId = execution.id }
                                        }
                                    )
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
            }
        }
    }

    private func versionName(for versionId: UUID?, in script: SavedScript) -> String? {
        guard let vId = versionId else { return nil }
        if let index = script.versions.firstIndex(where: { $0.id == vId }) {
            return "v\(index + 1)"
        }
        return nil
    }

    // MARK: - Actions

    private var sortOrderIcon: String {
        switch appState.scriptLibrary.sortOrder {
        case .lastExecuted: return "clock"
        case .created: return "calendar"
        case .name: return "textformat.abc"
        }
    }

    private func cycleSortOrder() {
        let allCases = ScriptLibrary.SortOrder.allCases
        let currentIndex = allCases.firstIndex(of: appState.scriptLibrary.sortOrder) ?? 0
        let nextIndex = (currentIndex + 1) % allCases.count
        appState.scriptLibrary.sortOrder = allCases[nextIndex]
    }

    private func saveScript() {
        scriptLibrary.saveCurrentChanges()
    }

    private func saveVersion() {
        guard let id = scriptLibrary.selectedScriptId else { return }
        scriptLibrary.saveVersion(for: id, content: scriptLibrary.unsavedContent, note: "Manual save")
    }

    private func runScript() {
        guard appState.serverManager.status.isRunning else { return }

        let script = scriptLibrary.unsavedContent
        guard !script.isEmpty else { return }

        Task {
            do {
                _ = try await appState.serverManager.execute(script: script, mode: nil)
            } catch {
                print("Execution failed: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct ScriptListRow: View {
    let script: SavedScript
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name with status indicator
            HStack(spacing: 6) {
                if let execution = script.lastExecution {
                    Image(systemName: execution.statusIcon)
                        .foregroundStyle(statusColor(execution.statusColor))
                        .font(.caption)
                }

                Text(script.name)
                    .font(.system(.caption, design: .default))
                    .fontWeight(isSelected ? .medium : .regular)
                    .lineLimit(1)
            }

            // Preview or last execution time
            HStack {
                Text(script.contentPreview)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if let lastExec = script.lastExecutedAt {
                    Text(formatRelativeTime(lastExec))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        default: return .gray
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

struct ExecutionHistoryRow: View {
    let execution: SavedScript.VersionExecution
    let versionName: String?
    var onSelect: (() -> Void)? = nil

    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(spacing: 8) {
                Image(systemName: execution.statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(formatTime(execution.executedAt))
                            .font(.caption)

                        if execution.isRemote {
                            Label("Remote", systemImage: "network")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(3)
                        }

                        if let version = versionName {
                            Text(version)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(3)
                        }
                    }

                    HStack(spacing: 8) {
                        if execution.commandsExecuted > 0 {
                            Label("\(execution.commandsExecuted)", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if execution.commandsFailed > 0 {
                            Label("\(execution.commandsFailed)", systemImage: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        if let duration = execution.duration {
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(execution.sessionId.uuidString, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .help("Copy Session ID")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch execution.statusColor {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        default: return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Execution Detail View

struct ExecutionDetailView: View {
    let execution: SavedScript.VersionExecution
    let versionName: String?
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("Back to History")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(formatTime(execution.executedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if execution.isRemote {
                    Label("Remote", systemImage: "network")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }

                if let version = versionName {
                    Text(version)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Summary stats
            HStack(spacing: 12) {
                if execution.commandsExecuted > 0 {
                    Label("\(execution.commandsExecuted) succeeded", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if execution.commandsFailed > 0 {
                    Label("\(execution.commandsFailed) failed", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let duration = execution.duration {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Command results list
            if execution.commandResults.isEmpty {
                VStack {
                    Text("No command details available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("(Execution from before UI update)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(execution.commandResults) { result in
                            CommandResultRow(result: result)
                            if result.id != execution.commandResults.last?.id {
                                Divider()
                                    .padding(.leading, 32)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Command Result Row

struct CommandResultRow: View {
    let result: StoredCommandResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Index and status
            HStack(spacing: 4) {
                Text("\(result.index + 1).")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)

                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.isSuccess ? .green : .red)
                    .font(.caption)
            }

            // Command and result/error
            VStack(alignment: .leading, spacing: 4) {
                Text(result.command)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)

                if let error = result.error {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                } else if let value = result.value, !value.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text("→")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                        Text(value)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct NewScriptSheet: View {
    @Binding var name: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("New Script")
                .font(.headline)

            TextField("Script Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    onCreate()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
    }
}

struct RenameScriptSheet: View {
    @Binding var name: String
    let originalName: String
    let onRename: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Script")
                .font(.headline)

            TextField("Script Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    onRename()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || name == originalName)
            }
        }
        .padding(20)
    }
}

struct VersionHistorySheet: View {
    let script: SavedScript
    let onRestore: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersionId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Version History")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Version list
            if script.versions.isEmpty {
                ContentUnavailableView {
                    Label("No Versions", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Save a version to see it here")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(script.versions.enumerated().reversed()), id: \.element.id, selection: $selectedVersionId) { index, version in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("v\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)

                            if version.isRemote {
                                Label("Remote", systemImage: "network")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(3)
                            }

                            Text(formatDate(version.savedAt))
                                .font(.caption)

                            Spacer()

                            if let note = version.note {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Show last execution for this version
                        if let lastExec = script.executions(for: version.id).first {
                            HStack(spacing: 4) {
                                Image(systemName: lastExec.statusIcon)
                                    .foregroundStyle(lastExec.statusColor == "green" ? .green : lastExec.statusColor == "red" ? .red : .orange)
                                    .font(.caption2)
                                Text("Last run: \(formatDate(lastExec.executedAt))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if lastExec.isRemote {
                                    Image(systemName: "network")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        Text(version.content.prefix(100) + (version.content.count > 100 ? "..." : ""))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    .tag(version.id)
                    .contextMenu {
                        Button("Restore This Version") {
                            onRestore(version.id)
                            dismiss()
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer with restore button
            HStack {
                Spacer()
                Button("Restore Selected") {
                    if let id = selectedVersionId {
                        onRestore(id)
                        dismiss()
                    }
                }
                .disabled(selectedVersionId == nil)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ScriptEditorView(appState: AppState())
        .frame(width: 600, height: 500)
}
