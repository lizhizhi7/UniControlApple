//
//  ContentView.swift
//  UniControlApp
//
//  Main content view with header, tabs, and content
//

import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    var onDetach: (() -> Void)?
    var isDetached: Bool = false
    var onReattach: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Tab picker
            Picker("Tab", selection: $appState.selectedTab) {
                ForEach(AppState.Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab content
            switch appState.selectedTab {
            case .scripts:
                ScriptEditorView(appState: appState)
            case .extensions:
                ExtensionsView(appState: appState)
            case .settings:
                SettingsView(appState: appState)
            }
        }
        .frame(minWidth: 500, minHeight: 500)
        .alert("Accessibility Permission Required", isPresented: $appState.showAccessibilityAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("UniControl needs accessibility permissions to automate applications. Please grant access in System Settings > Privacy & Security > Accessibility.")
        }
    }

    private var headerView: some View {
        HStack {
            // Server status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(appState.serverManager.status.displayText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Detach/reattach button
            if isDetached {
                Button(action: { onReattach?() }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Reattach to menu bar")
            } else if onDetach != nil {
                Button(action: { onDetach?() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Detach to floating window")
            }

            // Quit button
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Quit UniControl")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var statusColor: Color {
        switch appState.serverManager.status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}

#Preview {
    ContentView(appState: AppState())
        .frame(width: 600, height: 550)
}
