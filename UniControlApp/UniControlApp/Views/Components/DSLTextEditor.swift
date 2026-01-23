//
//  DSLTextEditor.swift
//  UniControlApp
//
//  Code editor with DSL syntax highlighting using HighlightedTextEditor
//

import SwiftUI
import HighlightedTextEditor

/// DSL Text Editor with syntax highlighting and autocomplete
struct DSLTextEditor: View {
    @Binding var text: String
    var onRun: (() -> Void)?

    @State private var showCompletions = false
    @State private var completions: [DSLCompletionProvider.Completion] = []
    @State private var wordRange: Range<String.Index>?
    @State private var selectedCompletionIndex = 0
    @State private var cursorOffset: CGPoint = .zero
    @State private var textViewRef: NSTextView?

    var body: some View {
        HighlightedTextEditor(text: $text, highlightRules: DSLHighlightRules.rules)
            .onTextChange { newText in
                updateCompletions(for: newText)
            }
            .onSelectionChange { range in
                // Update completions when cursor moves
                let cursorPos = min(range.location, text.count)
                let (newCompletions, newRange) = DSLCompletionProvider.completions(for: text, cursorPosition: cursorPos)
                if !newCompletions.isEmpty && newRange != nil {
                    completions = newCompletions
                    wordRange = newRange
                    selectedCompletionIndex = 0
                    showCompletions = true
                    // Defer cursor offset update to next run loop to ensure textViewRef is set
                    DispatchQueue.main.async {
                        updateCursorOffset(at: range.location)
                    }
                } else {
                    showCompletions = false
                }
            }
            .introspect { editor in
                // Defer state update to avoid "Modifying state during view update"
                if textViewRef !== editor.textView {
                    DispatchQueue.main.async {
                        textViewRef = editor.textView
                    }
                }
                editor.textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                editor.textView.isAutomaticQuoteSubstitutionEnabled = false
                editor.textView.isAutomaticDashSubstitutionEnabled = false
                editor.textView.isAutomaticTextReplacementEnabled = false
                editor.textView.isAutomaticSpellingCorrectionEnabled = false
            }
            // Autocomplete popup - using overlay to render above sibling views
            .overlay(alignment: .topLeading) {
                if showCompletions && !completions.isEmpty {
                    CompletionPopup(
                        completions: completions,
                        selectedIndex: $selectedCompletionIndex,
                        onSelect: { completion in
                            insertCompletion(completion)
                        }
                    )
                    .frame(width: 200)
                    .offset(x: cursorOffset.x, y: cursorOffset.y + 18)
                }
            }
        .onKeyPress(.downArrow) {
            if showCompletions {
                selectedCompletionIndex = min(selectedCompletionIndex + 1, completions.count - 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if showCompletions {
                selectedCompletionIndex = max(selectedCompletionIndex - 1, 0)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.tab) {
            if showCompletions && !completions.isEmpty {
                insertCompletion(completions[selectedCompletionIndex])
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if NSEvent.modifierFlags.contains(.command) {
                onRun?()
                return .handled
            }
            if showCompletions && !completions.isEmpty {
                insertCompletion(completions[selectedCompletionIndex])
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showCompletions {
                showCompletions = false
                return .handled
            }
            return .ignored
        }
    }

    private func updateCompletions(for newText: String) {
        // Find cursor position (end of text for now, as we don't have precise cursor info here)
        let cursorPosition = newText.count
        let (newCompletions, newRange) = DSLCompletionProvider.completions(for: newText, cursorPosition: cursorPosition)

        if !newCompletions.isEmpty && newRange != nil {
            completions = newCompletions
            wordRange = newRange
            selectedCompletionIndex = 0
            showCompletions = true
        } else {
            showCompletions = false
        }
    }

    private func insertCompletion(_ completion: DSLCompletionProvider.Completion) {
        guard let range = wordRange else { return }
        var newText = text
        newText.replaceSubrange(range, with: completion.command + " ")
        text = newText
        showCompletions = false
    }

    private func updateCursorOffset(at position: Int) {
        guard let textView = textViewRef else { return }

        // Use firstRect(forCharacterRange:) which works with both TextKit 1 and 2
        let charIndex = max(0, min(position, text.count))
        let range = NSRange(location: charIndex, length: 0)
        var actualRange = NSRange()
        let rect = textView.firstRect(forCharacterRange: range, actualRange: &actualRange)

        // firstRect returns screen coordinates, convert to textView's coordinate system
        guard let window = textView.window else { return }
        let windowRect = window.convertFromScreen(rect)
        let viewRect = textView.convert(windowRect, from: nil)

        // Position popup below the cursor line
        var point = CGPoint(
            x: viewRect.origin.x,
            y: viewRect.origin.y + viewRect.height
        )

        // Handle edge case where rect is zero (empty text or invalid position)
        if rect == .zero || text.isEmpty {
            point = CGPoint(x: textView.textContainerInset.width + 5, y: 18)
        }

        // Clamp x position to prevent popup from going off-screen
        point.x = min(point.x, textView.bounds.width - 210)
        point.x = max(point.x, 0)

        cursorOffset = point
    }
}

// MARK: - DSL Syntax Highlighting Rules

struct DSLHighlightRules {
    static let rules: [HighlightRule] = [
        // Comments (# or //)
        HighlightRule(
            pattern: try! NSRegularExpression(pattern: "(#|//).*$", options: .anchorsMatchLines),
            formattingRules: [
                TextFormattingRule(key: .foregroundColor) { _, _ in NSColor.systemGreen }
            ]
        ),
        // Commands (launch, find, click, type, wait, log, etc.)
        HighlightRule(
            pattern: try! NSRegularExpression(pattern: "^\\s*(launch|find|click|type|wait|log|getsystem|getwindows|getwindow|getapps|getapp|getelement|press|scroll|drag|hover|focus|resize|move|close|minimize|maximize)\\b", options: [.anchorsMatchLines, .caseInsensitive]),
            formattingRules: [
                TextFormattingRule(key: .foregroundColor) { _, _ in NSColor.systemBlue },
                TextFormattingRule(key: .font) { _, _ in NSFont.monospacedSystemFont(ofSize: 12, weight: .bold) }
            ]
        ),
        // Keywords (role:, type:, index:, active, frontmost, all)
        HighlightRule(
            pattern: try! NSRegularExpression(pattern: "\\b(role|type|index|active|frontmost|all):", options: .caseInsensitive),
            formattingRules: [
                TextFormattingRule(key: .foregroundColor) { _, _ in NSColor.systemPurple }
            ]
        ),
        // AX role names (AXButton, AXTextField, etc.)
        HighlightRule(
            pattern: try! NSRegularExpression(pattern: "\\bAX[A-Za-z]+\\b", options: []),
            formattingRules: [
                TextFormattingRule(key: .foregroundColor) { _, _ in NSColor.systemOrange }
            ]
        ),
        // Numbers
        HighlightRule(
            pattern: try! NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b", options: []),
            formattingRules: [
                TextFormattingRule(key: .foregroundColor) { _, _ in NSColor.systemTeal }
            ]
        ),
        // Quoted strings
        HighlightRule(
            pattern: try! NSRegularExpression(pattern: "\"[^\"]*\"", options: []),
            formattingRules: [
                TextFormattingRule(key: .foregroundColor) { _, _ in NSColor.systemRed }
            ]
        ),
    ]
}

// MARK: - Completion Popup

struct CompletionPopup: View {
    let completions: [DSLCompletionProvider.Completion]
    @Binding var selectedIndex: Int
    let onSelect: (DSLCompletionProvider.Completion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(completions.enumerated()), id: \.element.command) { index, completion in
                            CompletionRow(
                                completion: completion,
                                isSelected: index == selectedIndex
                            )
                            .id(index)
                            .onTapGesture {
                                onSelect(completion)
                            }
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(maxHeight: 120)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
}

struct CompletionRow: View {
    let completion: DSLCompletionProvider.Completion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(completion.command)
                .font(.system(size: 11, weight: .medium, design: .monospaced))

            Text(completion.syntax)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    DSLTextEditor(text: .constant("# Example script\nlaunch Excel\nwait 2\nfind Developer role: AXButton\nclick"))
        .frame(width: 400, height: 300)
}
