//
//  SettingsView.swift
//  UniControlApp
//
//  Settings tab view
//

import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var portText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Server section
                serverSection

                Divider()

                // Execution mode section
                executionModeSection

                Divider()

                // Log level section
                logLevelSection

                Divider()

                // Accessibility section
                accessibilitySection

                Spacer()
            }
            .padding()
        }
        .onAppear {
            portText = String(appState.settings.serverPort)
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server")
                .font(.headline)

            HStack {
                Text("Port:")
                    .frame(width: 100, alignment: .leading)

                TextField("Port", text: $portText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onChange(of: portText) { _, newValue in
                        if let port = Int(newValue), port > 0 && port <= 65535 {
                            appState.settings.serverPort = port
                        }
                    }
            }

            HStack(spacing: 10) {
                Button(appState.serverManager.status.isRunning ? "Stop" : "Start") {
                    if appState.serverManager.status.isRunning {
                        appState.serverManager.stop()
                    } else {
                        appState.serverManager.start(port: appState.settings.serverPort)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(appState.serverManager.status.isRunning ? .red : .green)

                Button("Restart") {
                    appState.serverManager.restart(port: appState.settings.serverPort)
                }
                .buttonStyle(.bordered)
                .disabled(!appState.serverManager.status.isRunning)
            }

            Toggle("Auto-start server on launch", isOn: $appState.settings.autoStartServer)
        }
    }

    private var executionModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Execution Mode")
                .font(.headline)

            Picker("Mode", selection: $appState.settings.executionMode) {
                ForEach(AppSettings.ExecutionModeOption.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(appState.settings.executionMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var logLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Level")
                .font(.headline)

            Picker("Log Level", selection: $appState.settings.logLevel) {
                ForEach(AppSettings.LogLevelOption.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)

            Text(appState.settings.logLevel.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            HStack {
                Image(systemName: "accessibility")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text("Accessibility Access")
                        .font(.subheadline)
                    Text("Required for UI automation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(10)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

#Preview {
    SettingsView(appState: AppState())
        .frame(width: 400, height: 500)
}
