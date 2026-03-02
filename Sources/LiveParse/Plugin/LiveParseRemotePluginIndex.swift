import Foundation

public struct LiveParseRemotePluginIndex: Codable, Equatable, Sendable {
    public let apiVersion: Int
    public let generatedAt: String?
    public let plugins: [LiveParseRemotePluginItem]
}

public struct LiveParseRemotePluginItem: Codable, Equatable, Sendable {
    public let pluginId: String
    public let version: String
    /// Optional platform identifier for UI metadata.
    public let platform: String?
    /// Optional localized display name for UI metadata.
    public let platformName: String?
    /// Optional icon URL/path for UI metadata.
    public let icon: String?
    /// Optional iOS asset/icon identifier.
    public let iosIcon: String?
    /// Optional macOS asset/icon identifier.
    public let macosIcon: String?
    /// Optional tvOS asset/icon identifier.
    public let tvosIcon: String?
    /// Optional tvOS platform page "big" background identifier.
    public let tvosBigIcon: String?
    /// Optional tvOS platform page "small" overlay identifier.
    public let tvosSmallIcon: String?
    /// Optional tvOS big icon dark-appearance identifier/path.
    public let tvosBigIconDark: String?
    /// Optional tvOS small icon dark-appearance identifier/path.
    public let tvosSmallIconDark: String?
    /// Legacy single-source URL.
    public let zipURL: String?
    /// Multi-source URLs. Prefer this field for domestic/international mirrors.
    public let zipURLs: [String]?
    public let sha256: String
    public let signature: String?
    public let signingKeyId: String?

    public init(
        pluginId: String,
        version: String,
        platform: String? = nil,
        platformName: String? = nil,
        icon: String? = nil,
        iosIcon: String? = nil,
        macosIcon: String? = nil,
        tvosIcon: String? = nil,
        tvosBigIcon: String? = nil,
        tvosSmallIcon: String? = nil,
        tvosBigIconDark: String? = nil,
        tvosSmallIconDark: String? = nil,
        zipURL: String? = nil,
        zipURLs: [String]? = nil,
        sha256: String,
        signature: String? = nil,
        signingKeyId: String? = nil
    ) {
        self.pluginId = pluginId
        self.version = version
        self.platform = platform
        self.platformName = platformName
        self.icon = icon
        self.iosIcon = iosIcon
        self.macosIcon = macosIcon
        self.tvosIcon = tvosIcon
        self.tvosBigIcon = tvosBigIcon
        self.tvosSmallIcon = tvosSmallIcon
        self.tvosBigIconDark = tvosBigIconDark
        self.tvosSmallIconDark = tvosSmallIconDark
        self.zipURL = zipURL
        self.zipURLs = zipURLs
        self.sha256 = sha256
        self.signature = signature
        self.signingKeyId = signingKeyId
    }

    /// Ordered, de-duplicated candidate download URLs.
    /// Prefer `zipURLs` and append legacy `zipURL` as the fallback tail.
    public var downloadURLs: [String] {
        var values: [String] = []

        if let zipURLs {
            values.append(contentsOf: zipURLs)
        }
        if let zipURL {
            values.append(zipURL)
        }

        var seen = Set<String>()
        var orderedUnique: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            orderedUnique.append(trimmed)
        }
        return orderedUnique
    }

    enum CodingKeys: String, CodingKey {
        case pluginId
        case version
        case platform
        case platformName
        case icon
        case iosIcon
        case macosIcon
        case tvosIcon
        case tvosBigIcon
        case tvosSmallIcon
        case tvosBigIconDark
        case tvosSmallIconDark
        case zipURL
        case zipURLs
        case sha256
        case signature
        case signingKeyId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pluginId = try container.decode(String.self, forKey: .pluginId)
        version = try container.decode(String.self, forKey: .version)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        platformName = try container.decodeIfPresent(String.self, forKey: .platformName)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        iosIcon = try container.decodeIfPresent(String.self, forKey: .iosIcon)
        macosIcon = try container.decodeIfPresent(String.self, forKey: .macosIcon)
        tvosIcon = try container.decodeIfPresent(String.self, forKey: .tvosIcon)
        tvosBigIcon = try container.decodeIfPresent(String.self, forKey: .tvosBigIcon)
        tvosSmallIcon = try container.decodeIfPresent(String.self, forKey: .tvosSmallIcon)
        tvosBigIconDark = try container.decodeIfPresent(String.self, forKey: .tvosBigIconDark)
        tvosSmallIconDark = try container.decodeIfPresent(String.self, forKey: .tvosSmallIconDark)
        zipURL = try container.decodeIfPresent(String.self, forKey: .zipURL)
        zipURLs = try container.decodeIfPresent([String].self, forKey: .zipURLs)
        sha256 = try container.decode(String.self, forKey: .sha256)
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        signingKeyId = try container.decodeIfPresent(String.self, forKey: .signingKeyId)

        if downloadURLs.isEmpty {
            throw DecodingError.dataCorruptedError(
                forKey: .zipURLs,
                in: container,
                debugDescription: "Either zipURLs or zipURL must be provided."
            )
        }
    }
}
