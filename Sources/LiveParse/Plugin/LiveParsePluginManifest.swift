import Foundation

public struct LiveParsePluginManifest: Codable, Equatable, Sendable {
    public let pluginId: String
    public let version: String
    public let apiVersion: Int
    public let displayName: String?
    public let liveTypes: [String]
    public let entry: String
    public let minHostVersion: String?

    public init(
        pluginId: String,
        version: String,
        apiVersion: Int,
        displayName: String? = nil,
        liveTypes: [String],
        entry: String,
        minHostVersion: String? = nil
    ) {
        self.pluginId = pluginId
        self.version = version
        self.apiVersion = apiVersion
        self.displayName = displayName
        self.liveTypes = liveTypes
        self.entry = entry
        self.minHostVersion = minHostVersion
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

