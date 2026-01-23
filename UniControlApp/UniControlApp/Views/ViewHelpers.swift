//
//  ViewHelpers.swift
//  UniControlApp
//
//  Shared view utilities and reusable components
//

import SwiftUI

// MARK: - Formatting Utilities

enum Formatters {
    static func relativeTime(_ date: Date) -> String {
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

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    static func duration(_ duration: TimeInterval) -> String {
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

// MARK: - Status Color Helper

extension Color {
    static func forStatus(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        default: return .gray
        }
    }
}

// MARK: - Reusable Badge Components

struct RemoteBadge: View {
    var body: some View {
        Label("Remote", systemImage: "network")
            .font(.caption2)
            .foregroundStyle(.blue)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(3)
    }
}

struct VersionBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(3)
    }
}

// MARK: - Consolidated Script Sheet

struct ScriptNameSheet: View {
    enum Mode {
        case create
        case rename(originalName: String)

        var title: String {
            switch self {
            case .create: return "New Script"
            case .rename: return "Rename Script"
            }
        }

        var buttonTitle: String {
            switch self {
            case .create: return "Create"
            case .rename: return "Rename"
            }
        }
    }

    @Binding var name: String
    let mode: Mode
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        if case .rename(let original) = mode {
            return name != original
        }
        return true
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(mode.title)
                .font(.headline)

            TextField("Script Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(mode.buttonTitle) {
                    onConfirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
    }
}
