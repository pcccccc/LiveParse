import Foundation

public struct LiveParseJSPlatform: Hashable, Codable, Sendable {
    public let pluginId: String
    public let liveTypes: [LiveType]
    public let platformName: String?

    public init(pluginId: String, liveTypes: [LiveType], platformName: String? = nil) {
        self.pluginId = pluginId
        self.liveTypes = liveTypes
        self.platformName = platformName
    }

    /// 兼容旧调用：取首个 liveType 作为主类型。
    public var liveType: LiveType {
        liveTypes.first ?? .bilibili
    }

    public var displayName: String {
        let normalized = platformName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? pluginId : normalized
    }
}

public struct LiveParseJSPlatformInfo: Codable, Sendable {
    public let platform: LiveParseJSPlatform
    public let pluginId: String
    public let liveType: LiveType
    public let liveTypes: [LiveType]
    public let displayName: String
}

public enum LiveParseJSPlatformManager {
    private struct ManifestCandidate {
        let platform: LiveParseJSPlatform
        let version: String
        let sourcePriority: Int
    }

    private struct PlatformRegistry {
        let platforms: [LiveParseJSPlatform]
        let byLiveType: [LiveType: LiveParseJSPlatform]
        let byPluginId: [String: LiveParseJSPlatform]
    }

    /// 按产品展示顺序返回可用平台（由插件 manifest 动态发现，不再写死平台枚举列表）。
    public static var availablePlatforms: [LiveParseJSPlatform] {
        registry().platforms
    }

    public static func availablePlatformInfos() -> [LiveParseJSPlatformInfo] {
        availablePlatforms.map {
            LiveParseJSPlatformInfo(
                platform: $0,
                pluginId: $0.pluginId,
                liveType: $0.liveType,
                liveTypes: $0.liveTypes,
                displayName: $0.displayName
            )
        }
    }

    public static func platform(for liveType: LiveType) -> LiveParseJSPlatform? {
        registry().byLiveType[liveType]
    }

    public static func platform(forPluginId pluginId: String) -> LiveParseJSPlatform? {
        registry().byPluginId[pluginId]
    }

    public static func isAvailable(_ platform: LiveParseJSPlatform) -> Bool {
        registry().byPluginId[platform.pluginId] != nil
    }

    /// 兼容旧调用：当前映射实时扫描，无需手动刷新。
    public static func reloadPlatformRegistry() {
        // no-op
    }

    // MARK: - Plugin API (v2 method names, with v1 fallback)

    public static func getCategoryList(
        platform: LiveParseJSPlatform,
        context: [String: Any] = [:]
    ) async throws -> [LiveMainListModel] {
        try await callWithFallback(
            platform: platform,
            function: "getCategories",
            fallback: "getCategoryList",
            payload: context
        )
    }

    public static func getRoomList(
        platform: LiveParseJSPlatform,
        id: String,
        parentId: String?,
        page: Int,
        context: [String: Any] = [:]
    ) async throws -> [LiveModel] {
        let rooms: [PluginRoomDTO] = try await callWithFallback(
            platform: platform,
            function: "getRooms",
            fallback: "getRoomList",
            payload: mergePayload(context, [
                "id": id,
                "parentId": parentId,
                "page": page
            ])
        )
        return rooms.map { $0.toLiveModel(liveType: platform.liveType) }
    }

    public static func getPlayArgs(
        platform: LiveParseJSPlatform,
        roomId: String,
        userId: String?,
        context: [String: Any] = [:]
    ) async throws -> [LiveQualityModel] {
        try await callWithFallback(
            platform: platform,
            function: "getPlayback",
            fallback: "getPlayArgs",
            payload: mergePayload(context, [
                "roomId": roomId,
                "userId": userId
            ])
        )
    }

    /// 切换清晰度/CDN 时获取指定清晰度的播放地址
    /// quality 字典可包含: rate(Int), cdn(String), lineSeq(Int), gear(Int) 等
    public static func getPlayArgsWithQuality(
        platform: LiveParseJSPlatform,
        roomId: String,
        userId: String?,
        quality: [String: Any],
        context: [String: Any] = [:]
    ) async throws -> [LiveQualityModel] {
        try await callWithFallback(
            platform: platform,
            function: "getPlayback",
            fallback: "getPlayArgs",
            payload: mergePayload(mergePayload(context, quality), [
                "roomId": roomId,
                "userId": userId
            ])
        )
    }

    public static func searchRooms(
        platform: LiveParseJSPlatform,
        keyword: String,
        page: Int,
        context: [String: Any] = [:]
    ) async throws -> [LiveModel] {
        let rooms: [PluginRoomDTO] = try await callWithFallback(
            platform: platform,
            function: "search",
            fallback: "searchRooms",
            payload: mergePayload(context, [
                "keyword": keyword,
                "page": page
            ])
        )
        return rooms.map { $0.toLiveModel(liveType: platform.liveType) }
    }

    public static func getLiveLastestInfo(
        platform: LiveParseJSPlatform,
        roomId: String,
        userId: String?,
        context: [String: Any] = [:]
    ) async throws -> LiveModel {
        let room: PluginRoomDTO = try await callWithFallback(
            platform: platform,
            function: "getRoomDetail",
            fallback: "getLiveLastestInfo",
            payload: mergePayload(context, [
                "roomId": roomId,
                "userId": userId
            ])
        )
        return room.toLiveModel(liveType: platform.liveType)
    }

    public static func getLiveState(
        platform: LiveParseJSPlatform,
        roomId: String,
        userId: String?,
        context: [String: Any] = [:]
    ) async throws -> LiveState {
        let result: PluginLiveStatePayload = try await callDecodable(
            platform: platform,
            function: "getLiveState",
            payload: mergePayload(context, [
                "roomId": roomId,
                "userId": userId
            ])
        )

        if let state = parseLiveState(result) {
            return state
        }

        throw LiveParseError.liveStateParseError("平台状态解析失败", "插件返回值无法映射为可识别直播状态")
    }

    public static func getRoomInfoFromShareCode(
        platform: LiveParseJSPlatform,
        shareCode: String,
        context: [String: Any] = [:]
    ) async throws -> LiveModel {
        let room: PluginRoomDTO = try await callWithFallback(
            platform: platform,
            function: "resolveShare",
            fallback: "getRoomInfoFromShareCode",
            payload: mergePayload(context, [
                "shareCode": shareCode
            ])
        )
        return room.toLiveModel(liveType: platform.liveType)
    }

    public static func getDanmukuArgs(
        platform: LiveParseJSPlatform,
        roomId: String,
        userId: String?,
        context: [String: Any] = [:]
    ) async throws -> ([String: String], [String: String]?) {
        let result: PluginDanmukuResult = try await callWithFallback(
            platform: platform,
            function: "getDanmaku",
            fallback: "getDanmukuArgs",
            payload: mergePayload(context, [
                "roomId": roomId,
                "userId": userId
            ])
        )
        if platform.pluginId == "yy" {
            var args = result.args
            let fallbackRoomId = roomId.trimmingCharacters(in: .whitespacesAndNewlines)

            if (args["roomId"]?.isEmpty ?? true), !fallbackRoomId.isEmpty {
                args["roomId"] = fallbackRoomId
            }
            if (args["sid"]?.isEmpty ?? true), let rid = args["roomId"], !rid.isEmpty {
                args["sid"] = rid
            }
            if (args["ssid"]?.isEmpty ?? true), let sid = args["sid"], !sid.isEmpty {
                args["ssid"] = sid
            }

            let wsUUID: String
            if let existingUUID = args["ws_uuid"], !existingUUID.isEmpty {
                wsUUID = existingUUID
            } else {
                wsUUID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                args["ws_uuid"] = wsUUID
            }

            if args["ws_url"]?.isEmpty ?? true {
                args["ws_url"] = "wss://h5-sinchl.yy.com/websocket?appid=yymwebh5&version=3.2.10&uuid=\(wsUUID)&sign=a8d7eef2"
            }

            return (args, result.headers)
        }
        return (result.args, result.headers)
    }

    // MARK: - Internal

    public static func callDecodable<ResultType: Decodable>(
        platform: LiveParseJSPlatform,
        function: String,
        payload: [String: Any] = [:]
    ) async throws -> ResultType {
        return try await LiveParsePlugins.shared.callDecodable(
            pluginId: platform.pluginId,
            function: function,
            payload: payload
        )
    }

    /// 尝试调用 v2 方法名，如果插件未实现则回退到 v1 方法名
    private static func callWithFallback<ResultType: Decodable>(
        platform: LiveParseJSPlatform,
        function: String,
        fallback: String,
        payload: [String: Any] = [:]
    ) async throws -> ResultType {
        do {
            return try await LiveParsePlugins.shared.callDecodable(
                pluginId: platform.pluginId,
                function: function,
                payload: payload
            )
        } catch let error as LiveParsePluginError {
            // 仅当函数不存在时回退，其他错误直接抛出
            if case .invalidReturnValue(let msg) = error, msg.contains("Missing function") {
                return try await LiveParsePlugins.shared.callDecodable(
                    pluginId: platform.pluginId,
                    function: fallback,
                    payload: payload
                )
            }
            throw error
        }
    }

    private static func mergePayload(_ base: [String: Any], _ extra: [String: Any?]) -> [String: Any] {
        var payload = base
        for (key, value) in extra {
            if let value {
                payload[key] = value
            }
        }
        return payload
    }

    private static func parseLiveState(_ payload: PluginLiveStatePayload) -> LiveState? {
        if let state = payload.liveState {
            return normalizeLiveState(state)
        }
        if let state = payload.stateNumber {
            return normalizeLiveState(String(state))
        }
        if let state = payload.rawState {
            return normalizeLiveState(state)
        }
        if let isLive = payload.isLive {
            return isLive ? .live : .close
        }
        return nil
    }

    private static func normalizeLiveState(_ raw: String) -> LiveState {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if ["1", "live", "on", "true", "yes", "streaming", "playing"].contains(normalized) {
            return .live
        }
        if ["2", "video", "replay", "recording"].contains(normalized) {
            return .video
        }
        if ["0", "close", "offline", "down", "off", "false", "ended"].contains(normalized) {
            return .close
        }
        return .unknow
    }

    private static func registry() -> PlatformRegistry {
        buildRegistry()
    }

    private static func buildRegistry() -> PlatformRegistry {
        var candidatesByPluginId: [String: ManifestCandidate] = [:]

        for manifestURL in discoverBuiltInManifestURLs() {
            guard let candidate = makeCandidate(from: manifestURL, sourcePriority: 1) else { continue }
            mergeCandidate(candidate, into: &candidatesByPluginId)
        }

        for manifestURL in discoverSandboxManifestURLs() {
            guard let candidate = makeCandidate(from: manifestURL, sourcePriority: 2) else { continue }
            mergeCandidate(candidate, into: &candidatesByPluginId)
        }

        let platforms = candidatesByPluginId.values
            .map(\.platform)
            .sorted(by: sortPlatform)

        var byPluginId: [String: LiveParseJSPlatform] = [:]
        var byLiveType: [LiveType: LiveParseJSPlatform] = [:]

        for platform in platforms {
            byPluginId[platform.pluginId] = platform
            for liveType in platform.liveTypes where byLiveType[liveType] == nil {
                byLiveType[liveType] = platform
            }
        }

        return PlatformRegistry(platforms: platforms, byLiveType: byLiveType, byPluginId: byPluginId)
    }

    private static func makeCandidate(from manifestURL: URL, sourcePriority: Int) -> ManifestCandidate? {
        guard let manifest = try? LiveParsePluginManifest.load(from: manifestURL) else { return nil }
        let liveTypes = manifest.liveTypes.compactMap { LiveType(rawValue: $0) }
        guard !manifest.pluginId.isEmpty, !liveTypes.isEmpty else { return nil }

        let platform = LiveParseJSPlatform(
            pluginId: manifest.pluginId,
            liveTypes: liveTypes,
            platformName: manifest.displayName
        )
        return ManifestCandidate(platform: platform, version: manifest.version, sourcePriority: sourcePriority)
    }

    private static func mergeCandidate(_ candidate: ManifestCandidate, into storage: inout [String: ManifestCandidate]) {
        guard let existing = storage[candidate.platform.pluginId] else {
            storage[candidate.platform.pluginId] = candidate
            return
        }

        if candidate.sourcePriority != existing.sourcePriority {
            if candidate.sourcePriority > existing.sourcePriority {
                storage[candidate.platform.pluginId] = candidate
            }
            return
        }

        if semverCompare(candidate.version, existing.version) > 0 {
            storage[candidate.platform.pluginId] = candidate
        }
    }

    private static func discoverSandboxManifestURLs() -> [URL] {
        let storage = LiveParsePlugins.shared.storage
        let pluginsRoot = storage.pluginsRootDirectory
        guard FileManager.default.fileExists(atPath: pluginsRoot.path),
              let pluginDirs = try? FileManager.default.contentsOfDirectory(
                at: pluginsRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var result: [URL] = []
        for pluginDir in pluginDirs where pluginDir.hasDirectoryPath {
            guard let versionDirs = try? FileManager.default.contentsOfDirectory(
                at: pluginDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for versionDir in versionDirs where versionDir.hasDirectoryPath {
                let manifestURL = versionDir.appendingPathComponent("manifest.json", isDirectory: false)
                if FileManager.default.fileExists(atPath: manifestURL.path) {
                    result.append(manifestURL)
                }
            }
        }

        return result
    }

    private static func discoverBuiltInManifestURLs() -> [URL] {
        guard let resourceURL = LiveParsePlugins.shared.bundle.resourceURL else {
            return []
        }

        let pluginsRoot = resourceURL.appendingPathComponent("Plugins", isDirectory: true)
        if FileManager.default.fileExists(atPath: pluginsRoot.path) {
            return discoverManifestURLsInFolderMode(pluginsRoot: pluginsRoot)
        }
        return discoverManifestURLsInFlatMode(resourceURL: resourceURL)
    }

    private static func discoverManifestURLsInFolderMode(pluginsRoot: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: pluginsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent == "manifest.json" {
            result.append(url)
        }
        return result
    }

    private static func discoverManifestURLsInFlatMode(resourceURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name.hasPrefix("lp_plugin_") && name.hasSuffix("_manifest.json") {
                result.append(url)
            }
        }
        return result
    }

    private static func sortPlatform(lhs: LiveParseJSPlatform, rhs: LiveParseJSPlatform) -> Bool {
        let leftNumber = Int(lhs.liveType.rawValue)
        let rightNumber = Int(rhs.liveType.rawValue)

        switch (leftNumber, rightNumber) {
        case let (l?, r?) where l != r:
            return l < r
        case (nil, nil):
            return lhs.pluginId < rhs.pluginId
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.pluginId < rhs.pluginId
        }
    }

    private static func semverCompare(_ lhs: String, _ rhs: String) -> Int {
        func parts(_ text: String) -> [Int] {
            text.split(separator: ".").map { Int($0) ?? 0 } + [0, 0, 0]
        }

        let left = parts(lhs)
        let right = parts(rhs)

        for index in 0..<3 where left[index] != right[index] {
            return left[index] < right[index] ? -1 : 1
        }
        return 0
    }
}

private struct PluginRoomDTO: Decodable {
    let userName: String
    let roomTitle: String
    let roomCover: String
    let userHeadImg: String
    let liveState: String?
    let userId: String
    let roomId: String
    let liveWatchedCount: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userName = container.decodeLossyStringIfPresent(forKey: .userName) ?? ""
        roomTitle = container.decodeLossyStringIfPresent(forKey: .roomTitle) ?? ""
        roomCover = container.decodeLossyStringIfPresent(forKey: .roomCover) ?? ""
        userHeadImg = container.decodeLossyStringIfPresent(forKey: .userHeadImg) ?? ""
        liveState = container.decodeLossyStringIfPresent(forKey: .liveState)
        userId = container.decodeLossyStringIfPresent(forKey: .userId) ?? ""
        roomId = container.decodeLossyStringIfPresent(forKey: .roomId) ?? ""
        liveWatchedCount = container.decodeLossyStringIfPresent(forKey: .liveWatchedCount)
    }

    enum CodingKeys: String, CodingKey {
        case userName
        case roomTitle
        case roomCover
        case userHeadImg
        case liveState
        case userId
        case roomId
        case liveWatchedCount
    }

    func toLiveModel(liveType: LiveType) -> LiveModel {
        LiveModel(
            userName: userName,
            roomTitle: roomTitle,
            roomCover: roomCover,
            userHeadImg: userHeadImg,
            liveType: liveType,
            liveState: liveState,
            userId: userId,
            roomId: roomId,
            liveWatchedCount: liveWatchedCount
        )
    }
}

private struct PluginDanmukuResult: Decodable {
    let args: [String: String]
    let headers: [String: String]?
}

private struct PluginLiveStatePayload: Decodable {
    let liveState: String?
    let stateNumber: Int?
    let rawState: String?
    let isLive: Bool?

    private enum CodingKeys: String, CodingKey {
        case liveState
        case state
        case stateNumber
        case rawState
        case status
        case isLive
        case live
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer() {
            if let value = try? single.decode(String.self) {
                liveState = value
                stateNumber = Int(value)
                rawState = value
                isLive = nil
                return
            }
            if let value = try? single.decode(Int.self) {
                liveState = String(value)
                stateNumber = value
                rawState = String(value)
                isLive = nil
                return
            }
            if let value = try? single.decode(Bool.self) {
                liveState = nil
                stateNumber = nil
                rawState = nil
                isLive = value
                return
            }
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        liveState = container.decodeLossyStringIfPresent(forKey: .liveState)

        if let state = try? container.decode(Int.self, forKey: .state) {
            stateNumber = state
        } else if let state = try? container.decode(String.self, forKey: .state), let intValue = Int(state) {
            stateNumber = intValue
        } else {
            stateNumber = container.decodeLossyIntIfPresent(forKey: .stateNumber)
        }

        rawState = container.decodeLossyStringIfPresent(forKey: .status)
            ?? container.decodeLossyStringIfPresent(forKey: .rawState)

        if let live = try? container.decode(Bool.self, forKey: .isLive) {
            isLive = live
        } else if let live = try? container.decode(Bool.self, forKey: .live) {
            isLive = live
        } else if let liveString = container.decodeLossyStringIfPresent(forKey: .live) {
            isLive = ["1", "true", "yes", "live"].contains(liveString.lowercased())
        } else {
            isLive = nil
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Bool.self, forKey: key) {
            return value ? "true" : "false"
        }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key), let intValue = Int(value) {
            return intValue
        }
        return nil
    }
}
