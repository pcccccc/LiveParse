import Foundation

public struct LiveParsePluginState: Codable, Equatable, Sendable {
    public struct PluginRecord: Codable, Equatable, Sendable {
        public var pinnedVersion: String?
        public var lastGoodVersion: String?
        public var enabled: Bool

        public init(pinnedVersion: String? = nil, lastGoodVersion: String? = nil, enabled: Bool = true) {
            self.pinnedVersion = pinnedVersion
            self.lastGoodVersion = lastGoodVersion
            self.enabled = enabled
        }
    }

    public var plugins: [String: PluginRecord]

    public init(plugins: [String: PluginRecord] = [:]) {
        self.plugins = plugins
    }
}

