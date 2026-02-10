import Foundation

public struct LiveParsePluginStorage: Sendable {
    public let baseDirectory: URL

    public init(baseDirectory: URL? = nil) throws {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
            return
        }

        let supportDir = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.baseDirectory = supportDir.appendingPathComponent("LiveParse", isDirectory: true)
    }

    public var pluginsRootDirectory: URL {
        baseDirectory.appendingPathComponent("plugins", isDirectory: true)
    }

    public var stateFileURL: URL {
        baseDirectory.appendingPathComponent("state.json", isDirectory: false)
    }

    public func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pluginsRootDirectory, withIntermediateDirectories: true)
    }

    public func loadState() -> LiveParsePluginState {
        guard let data = try? Data(contentsOf: stateFileURL) else {
            return LiveParsePluginState()
        }
        return (try? JSONDecoder().decode(LiveParsePluginState.self, from: data)) ?? LiveParsePluginState()
    }

    public func saveState(_ state: LiveParsePluginState) throws {
        try ensureDirectories()
        let data = try JSONEncoder().encode(state)
        try data.write(to: stateFileURL, options: [.atomic])
    }

    public func pluginDirectory(pluginId: String) -> URL {
        pluginsRootDirectory.appendingPathComponent(pluginId, isDirectory: true)
    }

    public func pluginVersionDirectory(pluginId: String, version: String) -> URL {
        pluginDirectory(pluginId: pluginId).appendingPathComponent(version, isDirectory: true)
    }

    public func listInstalledVersions(pluginId: String) -> [URL] {
        let dir = pluginDirectory(pluginId: pluginId)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls.filter { $0.hasDirectoryPath }
    }
}

