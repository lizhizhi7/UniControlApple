//
//  MenuBarController.swift
//  UniControlApp
//
//  Controls the menu bar status item and popover
//

import SwiftUI

@MainActor
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var detachedWindow: NSWindow?
    private let appState: AppState

    @Published var isDetached: Bool = false

    init(appState: AppState) {
        self.appState = appState
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbol for menu bar icon
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "UniControl")
            button.image = image?.withSymbolConfiguration(config)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 420, height: 500)
        popover?.behavior = .transient
        popover?.animates = true

        let contentView = ContentView(
            appState: appState,
            onDetach: { [weak self] in self?.detachToWindow() }
        )
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        if isDetached {
            // If detached, bring window to front
            detachedWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func detachToWindow() {
        // Close popover
        popover?.performClose(nil)

        // Create floating window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "UniControl"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = ContentView(
            appState: appState,
            onDetach: nil,
            isDetached: true,
            onReattach: { [weak self] in self?.reattachFromWindow() }
        )
        window.contentViewController = NSHostingController(rootView: contentView)

        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isDetached = false
            self?.detachedWindow = nil
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        detachedWindow = window
        isDetached = true
    }

    func reattachFromWindow() {
        detachedWindow?.close()
        detachedWindow = nil
        isDetached = false

        // Show popover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.togglePopover()
        }
    }

    func updateStatusItemIcon(isRunning: Bool) {
        guard let button = statusItem?.button else { return }

        let symbolName = isRunning ? "terminal.fill" : "terminal"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "UniControl")
        button.image = image?.withSymbolConfiguration(config)
    }
}
