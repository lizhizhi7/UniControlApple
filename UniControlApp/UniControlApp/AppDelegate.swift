//
//  AppDelegate.swift
//  UniControlApp
//
//  Application delegate for managing menu bar and server lifecycle
//

import SwiftUI
import UniControlCore

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Create menu bar controller
        menuBarController = MenuBarController(appState: appState)

        // Auto-start server if configured
        if appState.settings.autoStartServer {
            appState.serverManager.start(port: appState.settings.serverPort)
        }

        // Check for accessibility permissions
        if !checkAccessibilityPermission() {
            // Show notification about permissions
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.appState.showAccessibilityAlert = true
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop server on quit
        appState.serverManager.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window closes - we're a menu bar app
        return false
    }
}
