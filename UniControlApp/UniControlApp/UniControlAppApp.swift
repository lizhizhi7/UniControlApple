//
//  UniControlAppApp.swift
//  UniControlApp
//
//  Menu bar application for UniControl
//

import SwiftUI

@main
struct UniControlAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - we're a menu bar only app
        Settings {
            EmptyView()
        }
    }
}
