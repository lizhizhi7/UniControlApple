//
//  PersistenceManager.swift
//  UniControlApp
//
//  Handles file-based persistence for scripts
//

import Foundation

/// Singleton manager for file-based persistence
class PersistenceManager {
    static let shared = PersistenceManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Base directory for UniControl data
    private var appSupportDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("UniControl", isDirectory: true)
    }

    /// Directory for script files
    private var scriptsDirectory: URL {
        appSupportDirectory.appendingPathComponent("scripts", isDirectory: true)
    }

    /// Path to scripts manifest file
    private var scriptsManifestURL: URL {
        scriptsDirectory.appendingPathComponent("manifest.json")
    }

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ensureDirectoriesExist()
    }

    // MARK: - Directory Management

    private func ensureDirectoriesExist() {
        do {
            try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directories: \(error)")
        }
    }

    // MARK: - Scripts

    /// Load all scripts from disk
    func loadScripts() -> [SavedScript] {
        guard fileManager.fileExists(atPath: scriptsManifestURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: scriptsManifestURL)
            let scripts = try decoder.decode([SavedScript].self, from: data)
            return scripts
        } catch {
            print("Failed to load scripts: \(error)")
            return []
        }
    }

    /// Save all scripts to disk
    func saveScripts(_ scripts: [SavedScript]) {
        do {
            let data = try encoder.encode(scripts)
            try data.write(to: scriptsManifestURL, options: .atomic)
        } catch {
            print("Failed to save scripts: \(error)")
        }
    }

    /// Delete a script and its file
    func deleteScript(id: UUID) {
        var scripts = loadScripts()
        scripts.removeAll { $0.id == id }
        saveScripts(scripts)

        // Also delete the individual script file if it exists
        let scriptFileURL = scriptsDirectory.appendingPathComponent("\(id.uuidString).unictl")
        try? fileManager.removeItem(at: scriptFileURL)
    }

    /// Export a script to a file URL
    func exportScript(_ script: SavedScript, to url: URL) throws {
        try script.content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Import a script from a file URL
    func importScript(from url: URL, name: String? = nil) throws -> SavedScript {
        let content = try String(contentsOf: url, encoding: .utf8)
        let scriptName = name ?? url.deletingPathExtension().lastPathComponent
        return SavedScript(name: scriptName, content: content)
    }
}
