//
//  LogDetailView.swift
//  UniControlApp
//
//  Detail view for a script execution
//

import SwiftUI

struct LogDetailView: View {
    let execution: ScriptExecutionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Script preview
                scriptSection

                // Status summary
                statusSection

                // Command results
                if !execution.results.isEmpty {
                    resultsSection
                }

                // Logs
                if !execution.logs.isEmpty {
                    logsSection
                }
            }
            .padding()
        }
    }

    private var scriptSection: some View {
        GroupBox("Script") {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(execution.script)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
        }
    }

    private var statusSection: some View {
        HStack(spacing: 20) {
            // Status
            HStack {
                Image(systemName: execution.statusIcon)
                    .foregroundStyle(statusColor)

                if let success = execution.success {
                    Text(success ? "Completed" : "Failed")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("Running...")
                        .font(.subheadline.weight(.medium))
                }
            }

            Spacer()

            // Duration
            if let duration = execution.duration {
                Label(formatDuration(duration), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Command counts
            HStack(spacing: 8) {
                if execution.commandsExecuted > 0 {
                    Label("\(execution.commandsExecuted)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if execution.commandsFailed > 0 {
                    Label("\(execution.commandsFailed)", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var resultsSection: some View {
        GroupBox("Command Results") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(execution.results) { result in
                    CommandResultRow(result: result)
                }
            }
        }
    }

    private var logsSection: some View {
        GroupBox("Logs") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(execution.logs) { log in
                    LogEntryRow(log: log)
                }
            }
        }
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.2fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

struct CommandResultRow: View {
    let result: CommandResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Index
            Text("[\(result.index + 1)]")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            // Status icon
            Image(systemName: result.status.icon)
                .foregroundStyle(result.status == .success ? .green : .red)
                .font(.caption)

            // Command and error
            VStack(alignment: .leading, spacing: 2) {
                Text(result.command)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)

                if let error = result.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if let value = result.value, !value.isEmpty {
                    Text("= \(value)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct LogEntryRow: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(formatTime(log.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            // Level icon
            Image(systemName: log.level.icon)
                .foregroundStyle(levelColor)
                .font(.caption)

            // Message
            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch log.level.color {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "gray": return .gray
        default: return .primary
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    LogDetailView(execution: ScriptExecutionRecord(
        script: "launch Calculator\nwait 1\nfind 7\nclick",
        mode: "continue"
    ))
    .frame(width: 300, height: 400)
}
