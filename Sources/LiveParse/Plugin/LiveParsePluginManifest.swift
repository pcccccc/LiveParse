import Foundation

public struct LiveParsePluginManifest: Codable, Equatable, Sendable {
    public let pluginId: String
    public let version: String
    public let apiVersion: Int
    public let displayName: String?
    public let liveTypes: [String]
    public let entry: String
    public let minHostVersion: String?
    /// 插件入口脚本执行前需要预加载的脚本文件名列表（相对于插件根目录或 bundle 资源目录）
    public let preloadScripts: [String]?

    public init(
        pluginId: String,
        version: String,
        apiVersion: Int,
        displayName: String? = nil,
        liveTypes: [String],
        entry: String,
        minHostVersion: String? = nil,
        preloadScripts: [String]? = nil
    ) {
        self.pluginId = pluginId
        self.version = version
        self.apiVersion = apiVersion
        self.displayName = displayName
        self.liveTypes = liveTypes
        self.entry = entry
        self.minHostVersion = minHostVersion
        self.preloadScripts = preloadScripts
    }
}

extension LiveParsePluginManifest {
    static func load(from url: URL) throws -> LiveParsePluginManifest {
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(LiveParsePluginManifest.self, from: data)
        } catch {
            throw LiveParsePluginError.invalidManifest(error.localizedDescription)
        }
    }
}

