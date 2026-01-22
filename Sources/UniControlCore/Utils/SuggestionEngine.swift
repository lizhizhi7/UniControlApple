//
//  SuggestionEngine.swift
//  UniControl
//
//  Element suggestion and similarity matching engine
//

import Foundation
import ApplicationServices
import AppKit

/// Result of a similarity match
public struct SimilarityMatch {
    public let element: AXUIElement
    public let text: String
    public let similarity: Double
    public let role: String

    public init(element: AXUIElement, text: String, similarity: Double, role: String) {
        self.element = element
        self.text = text
        self.similarity = similarity
        self.role = role
    }
}

/// Calculate Levenshtein distance between two strings
public func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let s1 = Array(s1.lowercased())
    let s2 = Array(s2.lowercased())

    let m = s1.count
    let n = s2.count

    // Edge cases
    if m == 0 { return n }
    if n == 0 { return m }

    // Create distance matrix
    var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

    // Initialize first column and row
    for i in 0...m {
        matrix[i][0] = i
    }
    for j in 0...n {
        matrix[0][j] = j
    }

    // Calculate distances
    for i in 1...m {
        for j in 1...n {
            let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
            matrix[i][j] = min(
                matrix[i - 1][j] + 1,      // deletion
                matrix[i][j - 1] + 1,      // insertion
                matrix[i - 1][j - 1] + cost // substitution
            )
        }
    }

    return matrix[m][n]
}

/// Calculate similarity score (0.0 to 1.0) between two strings
public func similarityScore(_ s1: String, _ s2: String) -> Double {
    let s1Lower = s1.lowercased()
    let s2Lower = s2.lowercased()

    // Exact match
    if s1Lower == s2Lower {
        return 1.0
    }

    // Substring match bonus (but penalize very short matches)
    if s2Lower.contains(s1Lower) || s1Lower.contains(s2Lower) {
        let longer = max(s1.count, s2.count)
        let shorter = min(s1.count, s2.count)

        // Require shorter string to be at least 40% of longer string
        // This prevents "E" matching "Check Box" (1/9 = 11%)
        let lengthRatio = Double(shorter) / Double(longer)
        if lengthRatio < 0.4 {
            // Too short - use Levenshtein distance instead
            let distance = levenshteinDistance(s1, s2)
            let maxLength = max(s1.count, s2.count)
            return max(0.0, 1.0 - (Double(distance) / Double(maxLength)))
        }

        return 0.7 + (0.3 * lengthRatio)
    }

    // Levenshtein distance
    let distance = levenshteinDistance(s1, s2)
    let maxLength = max(s1.count, s2.count)

    if maxLength == 0 {
        return 1.0
    }

    let score = 1.0 - (Double(distance) / Double(maxLength))
    return max(0.0, score)
}

/// Find similar elements to a search term
public func findSimilarElements(
    in window: AXUIElement,
    searchTerm: String,
    role: String? = nil,
    maxResults: Int = 10
) -> [SimilarityMatch] {
    let elements = findElements(in: window, role: role)
    var matches: [SimilarityMatch] = []

    for element in elements {
        // Get text from multiple attributes
        let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String
        let description = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String
        let value = getAttribute(element, attribute: kAXValueAttribute as CFString) as? String
        let elementRole = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String ?? "Unknown"

        // Try all text attributes
        let textsToCheck = [title, description, value].compactMap { $0 }

        for text in textsToCheck {
            let score = similarityScore(searchTerm, text)
            if score > 0.3 { // Only include reasonably similar matches
                matches.append(SimilarityMatch(
                    element: element,
                    text: text,
                    similarity: score,
                    role: elementRole
                ))
                break // Only add once per element
            }
        }
    }

    // Sort by similarity (highest first) and limit results
    return matches.sorted { $0.similarity > $1.similarity }
        .prefix(maxResults)
        .map { $0 }
}

/// Format suggestions for display to user
public func formatSuggestions(
    _ matches: [SimilarityMatch],
    searchTerm: String,
    role: String? = nil
) -> String {
    if matches.isEmpty {
        return "No similar elements found."
    }

    var output = ""

    // Find the best match
    let bestMatch = matches.first!

    // Header
    if let role = role {
        output += "📋 Available \(role) elements (showing \(matches.count)):\n"
    } else {
        output += "📋 Available elements (showing \(matches.count)):\n"
    }

    // List matches
    for (index, match) in matches.enumerated() {
        let percentage = Int(match.similarity * 100)
        let star = (index == 0) ? " ⭐ CLOSEST MATCH" : ""
        output += "  [\(index)] \"\(match.text)\" (\(percentage)% match)\(star)\n"
    }

    // Suggestion
    output += "\n💡 Suggestion: Did you mean \"\(bestMatch.text)\"?"
    if let role = role {
        output += " Use: find \(bestMatch.text) role: \(role)"
    } else {
        output += " Use: find \(bestMatch.text)"
    }

    return output
}

/// Generate helpful error message when element not found
public func generateNotFoundMessage(
    window: AXUIElement,
    searchTerm: String,
    role: String? = nil
) -> String {
    var output = ""

    // Get window info
    let windowTitle = getAttribute(window, attribute: kAXTitleAttribute as CFString) as? String ?? "Unknown"
    var appName = "Unknown"

    // Try to get app name
    var pid: pid_t = 0
    if AXUIElementGetPid(window, &pid) == .success {
        if let app = NSRunningApplication(processIdentifier: pid) {
            appName = app.localizedName ?? "Unknown"
        }
    }

    output += "🪟 Window: \"\(windowTitle)\" (\(appName))\n\n"

    // Find similar elements
    let matches = findSimilarElements(in: window, searchTerm: searchTerm, role: role)

    if matches.isEmpty {
        output += "No similar elements found in this window."

        // Show element count by role
        let allElements = findElements(in: window)
        var roleCounts: [String: Int] = [:]
        var buttonTitles: [String] = []

        for element in allElements {
            if let elementRole = getAttribute(element, attribute: kAXRoleAttribute as CFString) as? String {
                roleCounts[elementRole, default: 0] += 1

                // Collect button titles
                if elementRole == "AXButton" {
                    if let title = getAttribute(element, attribute: kAXTitleAttribute as CFString) as? String, !title.isEmpty {
                        buttonTitles.append(title)
                    } else if let desc = getAttribute(element, attribute: kAXDescriptionAttribute as CFString) as? String, !desc.isEmpty {
                        buttonTitles.append(desc)
                    }
                }
            }
        }

        if !roleCounts.isEmpty {
            output += "\n\nAvailable element types:"
            for (role, count) in roleCounts.sorted(by: { $0.value > $1.value }).prefix(5) {
                output += "\n  - \(role): \(count)"
            }
        }

        // Show button names if available
        if !buttonTitles.isEmpty {
            output += "\n\n📋 Available buttons (\(buttonTitles.count) total):"
            let displayButtons = buttonTitles.prefix(20)
            for (index, title) in displayButtons.enumerated() {
                output += "\n  [\(index)]. \"\(title)\""
            }
            if buttonTitles.count > 20 {
                output += "\n  ... and \(buttonTitles.count - 20) more"
            }
            output += "\n\n💡 Use: find <button-name>"
        }
    } else {
        output += formatSuggestions(matches, searchTerm: searchTerm, role: role)
    }

    return output
}
