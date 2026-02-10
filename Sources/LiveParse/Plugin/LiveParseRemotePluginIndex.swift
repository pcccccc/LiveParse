import Foundation

public struct LiveParseRemotePluginIndex: Codable, Equatable, Sendable {
    public let apiVersion: Int
    public let generatedAt: String?
    public let plugins: [LiveParseRemotePluginItem]
}

public struct LiveParseRemotePluginItem: Codable, Equatable, Sendable {
    public let pluginId: String
    public let version: String
    public let zipURL: String
    public let sha256: String
    public let signature: String?
    public let signingKeyId: String?
}

