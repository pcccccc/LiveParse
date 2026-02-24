import Foundation

public enum LiveParseJSPlatform: String, CaseIterable, Codable, Sendable {
    case bilibili
    case huya
    case douyin
    case douyu
    case cc
    case ks
    case yy
    case soop

    public var pluginId: String {
        rawValue
    }

    public var liveType: LiveType {
        switch self {
        case .bilibili:
            return .bilibili
        case .huya:
            return .huya
        case .douyin:
            return .douyin
        case .douyu:
            return .douyu
        case .cc:
            return .cc
        case .ks:
            return .ks
        case .yy:
            return .yy
        case .soop:
            return .soop
        }
    }

    public var displayName: String {
        LiveParseTools.getLivePlatformName(liveType)
    }
}

public struct LiveParseJSPlatformInfo: Codable, Sendable {
    public let platform: LiveParseJSPlatform
    public let pluginId: String
    public let liveType: LiveType
    public let displayName: String
}

public enum LiveParseJSPlatformManager {
    /// 按产品展示顺序声明 7 个可用平台。
    public static let availablePlatforms: [LiveParseJSPlatform] = [.bilibili, .huya, .douyin, .douyu, .cc, .ks, .yy, .soop]

    public static func availablePlatformInfos() -> [LiveParseJSPlatformInfo] {
        availablePlatforms.map {
            LiveParseJSPlatformInfo(
                platform: $0,
                pluginId: $0.pluginId,
                liveType: $0.liveType,
                displayName: $0.displayName
            )
        }
    }

    public static func platform(for liveType: LiveType) -> LiveParseJSPlatform? {
        availablePlatforms.first(where: { $0.liveType == liveType })
    }

    public static func isAvailable(_ platform: LiveParseJSPlatform) -> Bool {
        availablePlatforms.contains(platform)
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
        return (result.args, result.headers)
    }

    // MARK: - Internal

    public static func callDecodable<ResultType: Decodable>(
        platform: LiveParseJSPlatform,
        function: String,
        payload: [String: Any] = [:]
    ) async throws -> ResultType {
        try await LiveParsePlugins.shared.callDecodable(
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
