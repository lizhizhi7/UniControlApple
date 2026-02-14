//
//  ExtensionsView.swift
//  UniControlApp
//
//  Extensions management tab showing installed extensions with enable/disable and config
//

import SwiftUI
import UniControlCore

struct ExtensionsView: View {
    @Bindable var appState: AppState

    @State private var extensions: [ExtensionInfo] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Extensions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(extensions.count) installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                if extensions.isEmpty {
                    emptyState
                } else {
                    ForEach(extensions, id: \.identifier) { ext in
                        ExtensionCard(
                            extensionInfo: ext,
                            onToggle: { enabled in
                                toggleExtension(ext.identifier, enabled: enabled)
                            },
                            onConfigChange: { key, value in
                                updateConfig(extensionId: ext.identifier, key: key, value: value)
                            },
                            getConfig: { key in
                                ExtensionRegistry.shared.getConfig(extensionId: ext.identifier, key: key)
                            }
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            refreshExtensions()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No Extensions Installed")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Extensions add application-specific commands to the DSL.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func refreshExtensions() {
        extensions = ExtensionRegistry.shared.registeredExtensions()
    }

    private func toggleExtension(_ identifier: String, enabled: Bool) {
        ExtensionRegistry.shared.setEnabled(enabled, for: identifier)

        // Update persisted settings
        if enabled {
            appState.settings.disabledExtensions.removeAll { $0 == identifier }
        } else {
            if !appState.settings.disabledExtensions.contains(identifier) {
                appState.settings.disabledExtensions.append(identifier)
            }
        }

        refreshExtensions()
    }

    private func updateConfig(extensionId: String, key: String, value: String) {
        ExtensionRegistry.shared.setConfig(extensionId: extensionId, key: key, value: value)

        // Update persisted settings
        if appState.settings.extensionConfigs[extensionId] == nil {
            appState.settings.extensionConfigs[extensionId] = [:]
        }
        appState.settings.extensionConfigs[extensionId]?[key] = value
    }
}

// MARK: - Extension Card

struct ExtensionCard: View {
    let extensionInfo: ExtensionInfo
    let onToggle: (Bool) -> Void
    let onConfigChange: (String, String) -> Void
    let getConfig: (String) -> String?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                // Icon
                Image(systemName: extensionInfo.systemImageName)
                    .font(.title2)
                    .foregroundStyle(extensionInfo.isEnabled ? .blue : .secondary)
                    .frame(width: 32, height: 32)

                // Name + description
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(extensionInfo.displayName)
                            .font(.headline)

                        Text("v\(extensionInfo.version)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Text(extensionInfo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label("\(extensionInfo.commandCount) commands", systemImage: "terminal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if let target = extensionInfo.targetApplication {
                            Label(target, systemImage: "app")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Text("by \(extensionInfo.author)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Toggle
                Toggle("", isOn: Binding(
                    get: { extensionInfo.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(12)

            // Expandable details
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                // Commands list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Commands")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(extensionInfo.commands, id: \.verb) { cmd in
                        HStack(alignment: .top, spacing: 8) {
                            Text(cmd.syntax)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)

                            Text(cmd.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(12)

                // Config section
                if !extensionInfo.configDescriptors.isEmpty {
                    Divider()
                        .padding(.horizontal, 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        ForEach(extensionInfo.configDescriptors, id: \.key) { config in
                            ExtensionConfigRow(
                                config: config,
                                value: getConfig(config.key) ?? config.defaultValue,
                                onChange: { newValue in
                                    onConfigChange(config.key, newValue)
                                }
                            )
                        }
                    }
                    .padding(12)
                }
            }

            // Expand/collapse button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Spacer()
                    Label(isExpanded ? "Less" : "More",
                          systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        )
        .opacity(extensionInfo.isEnabled ? 1.0 : 0.7)
        .padding(.horizontal)
    }
}

// MARK: - Config Row

struct ExtensionConfigRow: View {
    let config: ExtensionConfigInfo
    let value: String
    let onChange: (String) -> Void

    @State private var textValue: String = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(config.displayName)
                    .font(.caption)
                Text(config.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            configControl
        }
        .onAppear {
            textValue = value
        }
    }

    @ViewBuilder
    private var configControl: some View {
        switch config.type {
        case "boolean":
            Toggle("", isOn: Binding(
                get: { value == "true" },
                set: { onChange($0 ? "true" : "false") }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

        default:
            TextField("", text: $textValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .font(.system(.caption, design: .monospaced))
                .onSubmit {
                    onChange(textValue)
                }
        }
    }
}

#Preview {
    ExtensionsView(appState: AppState())
        .frame(width: 500, height: 600)
}
