//
//  ExecutionHistoryView.swift
//  UniControlApp
//
//  Execution history list and detail view
//

import SwiftUI

struct ExecutionHistoryView: View {
    @Bindable var appState: AppState

    var body: some View {
        HSplitView {
            // Left: Execution list
            executionList
                .frame(minWidth: 150, idealWidth: 180, maxWidth: 250)

            // Right: Detail view
            detailView
                .frame(minWidth: 200)
        }
    }

    private var executionList: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("Executions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !appState.executionHistory.isEmpty {
                    Button(action: { appState.clearHistory() }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear history")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // List content
            if appState.executionHistory.isEmpty {
                ContentUnavailableView {
                    Label("No Executions", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Script executions will appear here")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.executionHistory, selection: $appState.selectedExecutionId) { execution in
                    ExecutionRow(execution: execution)
                        .tag(execution.id)
                        .contextMenu {
                            Button("Remove") {
                                appState.removeExecution(execution.id)
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let execution = appState.selectedExecution {
            LogDetailView(execution: execution)
        } else {
            ContentUnavailableView {
                Label("Select an Execution", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Select an execution from the list to view details")
            }
        }
    }
}

struct ExecutionRow: View {
    let execution: ScriptExecutionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: execution.statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.caption)

                Text(execution.scriptPreview)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }

            HStack {
                Text(formatTime(execution.startTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let duration = execution.duration {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !execution.isComplete {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 2)
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

#Preview {
    ExecutionHistoryView(appState: AppState())
        .frame(width: 400, height: 400)
}
