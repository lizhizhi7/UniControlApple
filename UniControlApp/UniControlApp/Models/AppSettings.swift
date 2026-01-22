//
//  AppSettings.swift
//  UniControlApp
//
//  Application settings with UserDefaults persistence
//

import Foundation
import UniControlCore

struct AppSettings: Codable, Equatable {
    var executionMode: ExecutionModeOption = .continue
    var logLevel: LogLevelOption = .debug
    var serverPort: Int = 8080
    var autoStartServer: Bool = true
    var maxHistoryItems: Int = 100

    enum ExecutionModeOption: String, Codable, CaseIterable {
        case strict = "strict"
        case `continue` = "continue"
        case interactive = "interactive"

        var displayName: String {
            switch self {
            case .strict: return "Strict"
            case .continue: return "Continue"
            case .interactive: return "Interactive"
            }
        }

        var description: String {
            switch self {
            case .strict: return "Stop immediately on error"
            case .continue: return "Log errors and continue"
            case .interactive: return "Pause and prompt on errors"
            }
        }

        func toExecutionMode() -> ExecutionMode {
            switch self {
            case .strict: return .strict
            case .continue: return .continue
            case .interactive: return .interactive
            }
        }
    }

    enum LogLevelOption: String, Codable, CaseIterable {
        case debug = "debug"
        case quiet = "quiet"

        var displayName: String {
            switch self {
            case .debug: return "Debug"
            case .quiet: return "Quiet"
            }
        }

        var description: String {
            switch self {
            case .debug: return "Show detailed execution logs"
            case .quiet: return "Show only errors and log commands"
            }
        }
    }
}

// MARK: - UserDefaults Persistence

extension AppSettings {
    private static let userDefaultsKey = "UniControlAppSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}
