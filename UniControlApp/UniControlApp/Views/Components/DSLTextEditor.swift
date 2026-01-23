//
//  DSLTextEditor.swift
//  UniControlApp
//
//  NSTextView-based editor with DSL autocomplete support
//

import SwiftUI
import AppKit

/// NSViewRepresentable wrapper for NSTextView with DSL autocomplete
struct DSLTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onRun: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Monospace font
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // Text color
        textView.textColor = NSColor.textColor

        // Background
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true

        // Line wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        // Set initial text
        textView.string = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text differs to avoid cursor jumping
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DSLTextEditor
        private var completionWindow: NSWindow?
        private var completionTableView: NSTableView?
        private var completions: [DSLCompletionProvider.Completion] = []
        private var wordRange: Range<String.Index>?

        init(_ parent: DSLTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Check for completions
            let cursorPosition = textView.selectedRange().location
            let (completions, range) = DSLCompletionProvider.completions(for: textView.string, cursorPosition: cursorPosition)

            if !completions.isEmpty && range != nil {
                self.completions = completions
                self.wordRange = range
                showCompletionWindow(for: textView)
            } else {
                hideCompletionWindow()
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Cmd+Enter to run
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.command) {
                    parent.onRun?()
                    return true
                }
            }

            // Handle completion navigation
            if completionWindow?.isVisible == true {
                if commandSelector == #selector(NSResponder.moveDown(_:)) {
                    selectNextCompletion()
                    return true
                }
                if commandSelector == #selector(NSResponder.moveUp(_:)) {
                    selectPreviousCompletion()
                    return true
                }
                if commandSelector == #selector(NSResponder.insertTab(_:)) ||
                   commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    insertSelectedCompletion(into: textView)
                    return true
                }
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    hideCompletionWindow()
                    return true
                }
            }

            return false
        }

        private func showCompletionWindow(for textView: NSTextView) {
            if completionWindow == nil {
                createCompletionWindow()
            }

            guard let window = completionWindow,
                  let tableView = completionTableView else { return }

            // Reload data
            tableView.reloadData()
            if !completions.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }

            // Position window below cursor
            let cursorRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)
            if cursorRect != .zero {
                let screenPoint = NSPoint(x: cursorRect.origin.x, y: cursorRect.origin.y - 5)
                window.setFrameTopLeftPoint(screenPoint)
            }

            // Resize to fit content
            let height = min(CGFloat(completions.count) * 22 + 4, 200)
            window.setContentSize(NSSize(width: 250, height: height))

            // Show window
            if !window.isVisible {
                textView.window?.addChildWindow(window, ordered: .above)
                window.orderFront(nil)
            }
        }

        private func hideCompletionWindow() {
            completionWindow?.orderOut(nil)
            completionWindow?.parent?.removeChildWindow(completionWindow!)
        }

        private func createCompletionWindow() {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 250, height: 150),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = NSColor.windowBackgroundColor
            window.isOpaque = false
            window.hasShadow = true
            window.level = .floating

            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .lineBorder
            scrollView.autoresizingMask = [.width, .height]

            let tableView = NSTableView()
            tableView.headerView = nil
            tableView.rowHeight = 22
            tableView.intercellSpacing = NSSize(width: 0, height: 0)
            tableView.backgroundColor = .clear
            tableView.target = self
            tableView.doubleAction = #selector(completionDoubleClicked)

            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
            column.width = 248
            tableView.addTableColumn(column)

            tableView.dataSource = self
            tableView.delegate = self

            scrollView.documentView = tableView
            window.contentView = scrollView

            self.completionWindow = window
            self.completionTableView = tableView
        }

        @objc private func completionDoubleClicked() {
            guard let textView = (completionWindow?.parent?.contentView?.subviews.first as? NSScrollView)?.documentView as? NSTextView else { return }
            insertSelectedCompletion(into: textView)
        }

        private func selectNextCompletion() {
            guard let tableView = completionTableView else { return }
            let nextRow = min(tableView.selectedRow + 1, completions.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(nextRow)
        }

        private func selectPreviousCompletion() {
            guard let tableView = completionTableView else { return }
            let prevRow = max(tableView.selectedRow - 1, 0)
            tableView.selectRowIndexes(IndexSet(integer: prevRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(prevRow)
        }

        private func insertSelectedCompletion(into textView: NSTextView) {
            guard let tableView = completionTableView,
                  tableView.selectedRow >= 0,
                  tableView.selectedRow < completions.count,
                  let range = wordRange else {
                hideCompletionWindow()
                return
            }

            let completion = completions[tableView.selectedRow]
            var newText = textView.string
            newText.replaceSubrange(range, with: completion.command + " ")
            textView.string = newText
            parent.text = newText

            // Move cursor after the inserted text
            let newPosition = textView.string.distance(from: textView.string.startIndex, to: range.lowerBound) + completion.command.count + 1
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))

            hideCompletionWindow()
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension DSLTextEditor.Coordinator: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        completions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < completions.count else { return nil }

        let completion = completions[row]

        let cellView = NSTableCellView()
        cellView.identifier = NSUserInterfaceItemIdentifier("CompletionCell")

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let commandLabel = NSTextField(labelWithString: completion.command)
        commandLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        commandLabel.textColor = .labelColor

        let syntaxLabel = NSTextField(labelWithString: completion.syntax)
        syntaxLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        syntaxLabel.textColor = .secondaryLabelColor

        stackView.addArrangedSubview(commandLabel)
        stackView.addArrangedSubview(syntaxLabel)

        cellView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -6),
            stackView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        // Could show detail for selected completion
    }
}
