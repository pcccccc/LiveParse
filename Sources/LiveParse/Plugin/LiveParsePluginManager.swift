import Foundation

public final class LiveParsePluginManager: @unchecked Sendable {
    public typealias LogHandler = JSRuntime.LogHandler

    public let storage: LiveParsePluginStorage
    public let bundle: Bundle
    public let session: URLSession

    private let logHandler: LogHandler?
    private let lock = NSLock()
    private var loadedPlugins: [String: LiveParseLoadedPlugin] = [:]
    private var state: LiveParsePluginState

    public convenience init(bundle: Bundle? = nil, session: URLSession = .shared, logHandler: LogHandler? = nil) throws {
        try self.init(storage: LiveParsePluginStorage(), bundle: bundle, session: session, logHandler: logHandler)
    }

    public init(storage: LiveParsePluginStorage, bundle: Bundle? = nil, session: URLSession = .shared, logHandler: LogHandler? = nil) {
        self.storage = storage
        self.bundle = bundle ?? .module
        self.session = session
        self.logHandler = logHandler
        self.state = storage.loadState()
    }

    public func reload() throws {
        try storage.ensureDirectories()
        state = storage.loadState()
        lock.lock()
        loadedPlugins.removeAll()
        lock.unlock()
    }

    public func pin(pluginId: String, version: String) throws {
        var record = state.plugins[pluginId] ?? .init()
        record.pinnedVersion = version
        state.plugins[pluginId] = record
        try storage.saveState(state)
        try reload()
    }

    public func unpin(pluginId: String) throws {
        var record = state.plugins[pluginId] ?? .init()
        record.pinnedVersion = nil
        state.plugins[pluginId] = record
        try storage.saveState(state)
        try reload()
    }

    public func resolve(pluginId: String) throws -> LiveParseLoadedPlugin {
        lock.lock()
        if let existing = loadedPlugins[pluginId] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let record = state.plugins[pluginId]
        if record?.enabled == false {
            throw LiveParsePluginError.pluginNotFound("\(pluginId) (disabled)")
        }

        let pinned = record?.pinnedVersion
        let selected = try selectBestCandidate(pluginId: pluginId, pinnedVersion: pinned, lastGood: record?.lastGoodVersion)
        let plugin = LiveParseLoadedPlugin(
            manifest: selected.manifest,
            rootDirectory: selected.rootDirectory,
            location: selected.location,
            runtime: JSRuntime(session: session, logHandler: logHandler)
        )

        lock.lock()
        loadedPlugins[pluginId] = plugin
        lock.unlock()
        return plugin
    }

    public func load(pluginId: String) async throws {
        let plugin = try resolve(pluginId: pluginId)
        try await plugin.load()
    }

    public func call(pluginId: String, function: String, payload: [String: Any] = [:]) async throws -> Any {
        let plugin = try resolve(pluginId: pluginId)
        try await plugin.load()
        return try await plugin.runtime.callPluginFunction(name: function, payload: payload)
    }

    public func callDecodable<T: Decodable>(
        pluginId: String,
        function: String,
        payload: [String: Any] = [:],
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let value = try await call(pluginId: pluginId, function: function, payload: payload)
        let data = try JSONSerialization.data(withJSONObject: value)
        return try decoder.decode(T.self, from: data)
    }
}

private extension LiveParsePluginManager {
    struct Candidate {
        let manifest: LiveParsePluginManifest
        let rootDirectory: URL
        let location: LiveParseLoadedPlugin.Location
    }

    func selectBestCandidate(pluginId: String, pinnedVersion: String?, lastGood: String?) throws -> Candidate {
        let sandboxCandidates = try discoverSandboxCandidates(pluginId: pluginId)
        let builtInCandidates = try discoverBuiltInCandidates(pluginId: pluginId)

        func find(version: String, in list: [Candidate]) -> Candidate? {
            list.first { $0.manifest.version == version }
        }

        if let pinnedVersion {
            if let hit = find(version: pinnedVersion, in: sandboxCandidates) ?? find(version: pinnedVersion, in: builtInCandidates) {
                return hit
            }
            throw LiveParsePluginError.pluginNotFound("\(pluginId)@\(pinnedVersion)")
        }

        if let bestSandbox = sandboxCandidates.sorted(by: { semverCompare($0.manifest.version, $1.manifest.version) > 0 }).first {
            return bestSandbox
        }

        if let lastGood, let hit = find(version: lastGood, in: builtInCandidates) {
            return hit
        }

        if let bestBuiltIn = builtInCandidates.sorted(by: { semverCompare($0.manifest.version, $1.manifest.version) > 0 }).first {
            return bestBuiltIn
        }

        throw LiveParsePluginError.pluginNotFound(pluginId)
    }

    func discoverSandboxCandidates(pluginId: String) throws -> [Candidate] {
        let versionDirs = storage.listInstalledVersions(pluginId: pluginId)
        return try versionDirs.compactMap { dir in
            let manifestURL = dir.appendingPathComponent("manifest.json", isDirectory: false)
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
            let manifest = try LiveParsePluginManifest.load(from: manifestURL)
            guard manifest.pluginId == pluginId else { return nil }
            return Candidate(manifest: manifest, rootDirectory: dir, location: .sandbox)
        }
    }

    func discoverBuiltInCandidates(pluginId: String) throws -> [Candidate] {
        guard let resourceURL = bundle.resourceURL else {
            return []
        }

        // 兼容两种内置资源布局：
        // 1) 目录结构：Plugins/<pluginId>/manifest.json (理想情况)
        // 2) 资源被“扁平化”拷贝到 bundle 根目录：lp_plugin_<id>_<ver>_manifest.json（当前 SwiftPM 构建常见）

        let pluginsRoot = resourceURL.appendingPathComponent("Plugins", isDirectory: true)
        if FileManager.default.fileExists(atPath: pluginsRoot.path) {
            return try discoverBuiltInCandidatesFolderMode(pluginId: pluginId, pluginsRoot: pluginsRoot)
        }
        return try discoverBuiltInCandidatesFlatMode(pluginId: pluginId, resourceURL: resourceURL)
    }

    func discoverBuiltInCandidatesFolderMode(pluginId: String, pluginsRoot: URL) throws -> [Candidate] {
        guard let enumerator = FileManager.default.enumerator(
            at: pluginsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [Candidate] = []
        for case let url as URL in enumerator {
            guard url.lastPathComponent == "manifest.json" else { continue }
            let manifest = try LiveParsePluginManifest.load(from: url)
            guard manifest.pluginId == pluginId else { continue }
            results.append(Candidate(manifest: manifest, rootDirectory: url.deletingLastPathComponent(), location: .builtIn))
        }
        return results
    }

    func discoverBuiltInCandidatesFlatMode(pluginId: String, resourceURL: URL) throws -> [Candidate] {
        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [Candidate] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            guard name.hasPrefix("lp_plugin_") && name.hasSuffix("_manifest.json") else { continue }
            let manifest = try LiveParsePluginManifest.load(from: url)
            guard manifest.pluginId == pluginId else { continue }
            results.append(Candidate(manifest: manifest, rootDirectory: url.deletingLastPathComponent(), location: .builtIn))
        }
        return results
    }

    func semverCompare(_ lhs: String, _ rhs: String) -> Int {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0) ?? 0 } + [0, 0, 0]
        }
        let a = parts(lhs)
        let b = parts(rhs)
        for i in 0..<3 {
            if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }
        }
        return 0
    }
}
