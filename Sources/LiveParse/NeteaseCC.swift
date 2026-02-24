//
//  NeteaseCC.swift
//
//
//  Created by pangchong on 2024/5/21.
//

import Alamofire
import Foundation

fileprivate let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"

struct CCMainData<T: Codable>: Codable {
    var code: Int
    var msg: String
    var data: T
}

struct CCCategoryInfo: Codable {
    var category_info: CCCategoryGameListModel
}

struct CCCategoryGameListModel: Codable {
    var game_list: [CCGameListModel]
}

struct CCGameListModel: Codable {
    var url: String
    var cover: String
    var name: String
    var gametype: String
}

struct CCRoomListModel: Codable {
    var lives: [CCRoomModel]
}

struct CCLastestRoomModel: Codable {
    var data: [CCRoomModel]
}

struct CCRoomModel: Codable {
    var visitor: Int?
    var title: String
    var roomid: Int?
    var channel_id: Int?
    var nickname: String?
    var hot_score: Int?
    var poster: String?
    var portraiturl: String?
    var adv_img: String?
    var purl: String?
    var cuteid: Int?
    var quickplay: CCLiveQuickModel?
}

struct CCLiveQuickModel: Codable {
    var priority: [String]?
    var resolution: CCLiveResolutionModel?
}

struct CCLiveResolutionModel: Codable {
    var high: CCLiveResolutionInfo?
    var ultra: CCLiveResolutionInfo?
    var standard: CCLiveResolutionInfo?
    var blueray: CCLiveResolutionInfo?
    var medium: CCLiveResolutionInfo?
    var original: CCLiveResolutionInfo?
}

struct CCLiveResolutionInfo: Codable {
    var vbr: Int?
    var cdn: CCLiveResolutionDetail?
}

struct CCLiveResolutionDetail: Codable {
    var ks: String?
    var ali: String?
    var hs: String?
    var hs2: String?
    var ws: String?
    var dn: String?
    var xy: String?
}

struct CCLiveSearchResult: Codable {
    var webcc_anchor: CCLiveAnchorModel
}

struct CCLiveAnchorModel: Codable {
    var result: [CCRoomModel]
}

struct CCDanmakuResponse: Codable {
    let data: [String: CCDanmakuChannel]
}

struct CCDanmakuChannel: Codable {
    let channel_id: Int?
    let room_id: Int?
    let gametype: Int?
}

public struct NeteaseCC: LiveParse {
    private static let categoryURL = "https://api.cc.163.com/v1/wapcc/gamecategory"
    private static let roomListURLTemplate = "https://cc.163.com/api/category/%@"
    private static let channelDetailURL = "https://cc.163.com/live/channel/"
    private static let searchURL = "https://cc.163.com/search/anchor"
    private static let danmakuURL = "https://api.cc.163.com/v1/activitylives/anchor/lives"
    private static let defaultHeaders: HTTPHeaders = [HTTPHeader(name: "User-Agent", value: userAgent)]

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        if LiveParseConfig.enableJSPlugins {
            do {
                let result: [LiveMainListModel] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "getCategories",
                    payload: [:]
                )
                logInfo("NeteaseCC.getCategoryList 使用 JS 插件返回 \(result.count) 个主分类")
                return result
            } catch {
                logWarning("NeteaseCC.getCategoryList JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始获取 CC 分类列表")

        let categories: [(String, String)] = [
            ("1", "网游"),
            ("2", "单机"),
            ("4", "竞技"),
            ("5", "综艺")
        ]

        var result: [LiveMainListModel] = []
        for (id, title) in categories {
            let subList = try await getCategorySubList(id: id)
            result.append(LiveMainListModel(id: id, title: title, icon: "", subList: subList))
        }

        logInfo("CC 分类列表获取成功，共 \(result.count) 个分类")
        return result
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        logDebug("开始获取 CC 子分类，catetype: \(id)")

        let parameters: Parameters = ["catetype": id]
        let dataReq: CCMainData<CCCategoryInfo> = try await LiveParseRequest.get(
            categoryURL,
            parameters: parameters,
            headers: defaultHeaders
        )

        let list = dataReq.data.category_info.game_list
        guard !list.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "NeteaseCC.getCategorySubList",
                request: buildRequestDetail(url: categoryURL, parameters: parameters)
            ))
        }

        let result = list.map { LiveCategoryModel(id: $0.gametype, parentId: "", title: $0.name, icon: $0.cover) }
        logInfo("CC 子分类获取成功，catetype: \(id)，共 \(result.count) 个")
        return result
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        if LiveParseConfig.enableJSPlugins {
            struct PluginRoom: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let rooms: [PluginRoom] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "getRooms",
                    payload: [
                        "id": id,
                        "parentId": parentId as Any,
                        "page": page
                    ]
                )
                logInfo("NeteaseCC.getRoomList 使用 JS 插件返回 \(rooms.count) 个房间")
                return rooms.map {
                    LiveModel(
                        userName: $0.userName,
                        roomTitle: $0.roomTitle,
                        roomCover: $0.roomCover,
                        userHeadImg: $0.userHeadImg,
                        liveType: .cc,
                        liveState: $0.liveState,
                        userId: $0.userId,
                        roomId: $0.roomId,
                        liveWatchedCount: $0.liveWatchedCount
                    )
                }
            } catch {
                logWarning("NeteaseCC.getRoomList JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let url = String(format: roomListURLTemplate, id)
        let parameters: Parameters = [
            "format": "json",
            "tag_id": "0",
            "start": (page - 1) * 20,
            "size": 20
        ]

        logDebug("开始获取 CC 房间列表，分类: \(id)，页码: \(page)")

        let dataReq: CCRoomListModel = try await LiveParseRequest.get(
            url,
            parameters: parameters,
            headers: defaultHeaders
        )

        guard !dataReq.lives.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "NeteaseCC.getRoomList",
                request: buildRequestDetail(url: url, parameters: parameters)
            ))
        }

        let rooms = dataReq.lives.map { item -> LiveModel in
            let resolvedRoomId = String(item.cuteid ?? item.roomid ?? 0)
            let resolvedUserId = String(item.channel_id ?? 0)
            let isLive = (item.cuteid ?? 0) > 0

            return LiveModel(
                userName: item.nickname ?? "",
                roomTitle: item.title,
                roomCover: item.poster ?? item.adv_img ?? "",
                userHeadImg: item.portraiturl ?? item.purl ?? "",
                liveType: .cc,
                liveState: isLive ? LiveState.live.rawValue : LiveState.close.rawValue,
                userId: resolvedUserId,
                roomId: resolvedRoomId,
                liveWatchedCount: String(item.visitor ?? 0)
            )
        }

        logInfo("CC 房间列表获取成功，分类: \(id)，返回 \(rooms.count) 条")
        return rooms
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveInfo: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveType: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let info: PluginLiveInfo = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "getRoomDetail",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("NeteaseCC.getLiveLastestInfo 使用 JS 插件成功")
                return LiveModel(
                    userName: info.userName,
                    roomTitle: info.roomTitle,
                    roomCover: info.roomCover,
                    userHeadImg: info.userHeadImg,
                    liveType: .cc,
                    liveState: info.liveState,
                    userId: info.userId,
                    roomId: info.roomId,
                    liveWatchedCount: info.liveWatchedCount
                )
            } catch {
                logWarning("NeteaseCC.getLiveLastestInfo JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let (room, channelId, resolvedRoomId) = try await fetchRoomDetail(roomId: roomId, userId: userId)
        let isLive = (room.cuteid ?? 0) > 0

        return LiveModel(
            userName: room.nickname ?? "",
            roomTitle: room.title,
            roomCover: room.poster ?? room.adv_img ?? "",
            userHeadImg: room.portraiturl ?? room.purl ?? "",
            liveType: .cc,
            liveState: isLive ? LiveState.live.rawValue : LiveState.close.rawValue,
            userId: channelId,
            roomId: resolvedRoomId,
            liveWatchedCount: String(room.visitor ?? 0)
        )
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        if LiveParseConfig.enableJSPlugins {
            do {
                let result: [LiveQualityModel] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "getPlayback",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("NeteaseCC.getPlayArgs 使用 JS 插件返回 \(result.count) 组线路")
                return result
            } catch {
                logWarning("NeteaseCC.getPlayArgs JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let (room, channelId, resolvedRoomId) = try await fetchRoomDetail(roomId: roomId, userId: userId)

        guard let resolution = room.quickplay?.resolution else {
            throw LiveParseError.business(.emptyResult(
                location: "NeteaseCC.getPlayArgs",
                request: buildRequestDetail(url: channelDetailURL, parameters: ["channelids": channelId])
            ))
        }

        let mapping: [(String, CCLiveResolutionInfo?)] = [
            ("原画", resolution.original),
            ("蓝光", resolution.blueray),
            ("超清", resolution.ultra),
            ("高清", resolution.high),
            ("标准", resolution.standard),
            ("标清", resolution.medium)
        ]

        var qualities: [LiveQualityModel] = []
        for (label, info) in mapping {
            if let model = buildQualityModel(label: label, resolution: info, roomId: resolvedRoomId) {
                qualities.append(model)
            }
        }

        guard !qualities.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "NeteaseCC.getPlayArgs",
                request: buildRequestDetail(url: channelDetailURL, parameters: ["channelids": channelId])
            ))
        }

        return qualities
    }

    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        if LiveParseConfig.enableJSPlugins {
            struct PluginRoom: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let rooms: [PluginRoom] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "search",
                    payload: [
                        "keyword": keyword,
                        "page": page
                    ]
                )
                logInfo("NeteaseCC.searchRooms 使用 JS 插件返回 \(rooms.count) 个房间")
                return rooms.map {
                    LiveModel(
                        userName: $0.userName,
                        roomTitle: $0.roomTitle,
                        roomCover: $0.roomCover,
                        userHeadImg: $0.userHeadImg,
                        liveType: .cc,
                        liveState: $0.liveState,
                        userId: $0.userId,
                        roomId: $0.roomId,
                        liveWatchedCount: $0.liveWatchedCount
                    )
                }
            } catch {
                logWarning("NeteaseCC.searchRooms JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始搜索 CC 直播间，关键词: \(keyword)，页码: \(page)")

        let parameters: Parameters = [
            "query": keyword,
            "page": page,
            "size": 20
        ]

        let dataReq: CCLiveSearchResult = try await LiveParseRequest.get(
            searchURL,
            parameters: parameters,
            headers: defaultHeaders
        )

        let roomList = dataReq.webcc_anchor.result
        guard !roomList.isEmpty else {
            logWarning("CC 搜索结果为空，关键词: \(keyword)")
            return []
        }

        let results = roomList.map { item -> LiveModel in
            let resolvedRoomId = String(item.cuteid ?? item.roomid ?? 0)
            let resolvedUserId = String(item.channel_id ?? 0)
            let isLive = (item.cuteid ?? 0) > 0

            return LiveModel(
                userName: item.nickname ?? "",
                roomTitle: item.title,
                roomCover: item.poster ?? item.adv_img ?? "",
                userHeadImg: item.portraiturl ?? item.purl ?? "",
                liveType: .cc,
                liveState: isLive ? LiveState.live.rawValue : LiveState.close.rawValue,
                userId: resolvedUserId,
                roomId: resolvedRoomId,
                liveWatchedCount: String(item.visitor ?? 0)
            )
        }

        logInfo("CC 搜索返回 \(results.count) 条结果，关键词: \(keyword)")
        return results
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveState: Decodable {
                let liveState: String
            }

            do {
                let result: PluginLiveState = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "getLiveState",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )

                if let state = LiveState(rawValue: result.liveState) {
                    logInfo("NeteaseCC.getLiveState 使用 JS 插件成功")
                    return state
                }

                logWarning("NeteaseCC.getLiveState JS 插件返回无效状态：\(result.liveState)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw LiveParseError.liveStateParseError(
                        "CC 直播状态获取失败",
                        "插件返回未知状态值: \(result.liveState)"
                    )
                }
            } catch {
                logWarning("NeteaseCC.getLiveState JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始获取 CC 直播状态，roomId: \(roomId)")
        let info = try await getLiveLastestInfo(roomId: roomId, userId: userId)
        guard let stateValue = info.liveState, let state = LiveState(rawValue: stateValue) else {
            throw LiveParseError.parse(.invalidDataFormat(
                expected: "LiveState",
                actual: info.liveState ?? "nil",
                location: "NeteaseCC.getLiveState"
            ))
        }
        return state
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveInfo: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveType: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let info: PluginLiveInfo = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "resolveShare",
                    payload: [
                        "shareCode": shareCode
                    ]
                )
                logInfo("NeteaseCC.getRoomInfoFromShareCode 使用 JS 插件成功")
                return LiveModel(
                    userName: info.userName,
                    roomTitle: info.roomTitle,
                    roomCover: info.roomCover,
                    userHeadImg: info.userHeadImg,
                    liveType: .cc,
                    liveState: info.liveState,
                    userId: info.userId,
                    roomId: info.roomId,
                    liveWatchedCount: info.liveWatchedCount
                )
            } catch {
                logWarning("NeteaseCC.getRoomInfoFromShareCode JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let trimmed = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        logDebug("开始解析 CC 分享码: \(trimmed)")

        if let ids = extractShareIds(from: trimmed) {
            return try await getLiveLastestInfo(roomId: ids.roomId, userId: ids.channelId)
        }

        let resolved = formatId(input: trimmed)
        guard !resolved.isEmpty, Int(resolved) != nil else {
            throw LiveParseError.shareCodeParseError(
                "CC 分享码解析失败",
                "无法识别分享码内容: \(trimmed)"
            )
        }

        return try await getLiveLastestInfo(roomId: resolved, userId: nil)
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        if LiveParseConfig.enableJSPlugins {
            struct PluginResult: Decodable {
                let args: [String: String]
                let headers: [String: String]?
            }

            do {
                let result: PluginResult = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "cc",
                    function: "getDanmaku",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("NeteaseCC.getDanmukuArgs 使用 JS 插件成功")
                return (result.args, result.headers)
            } catch {
                logWarning("NeteaseCC.getDanmukuArgs JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始获取 CC 弹幕参数，roomId: \(roomId)")

        let parameters: Parameters = ["anchor_ccid": roomId]
        let response: CCDanmakuResponse = try await LiveParseRequest.get(
            danmakuURL,
            parameters: parameters,
            headers: defaultHeaders
        )

        let channelData = response.data[roomId] ?? response.data.values.first
        guard let info = channelData,
              let channelId = info.channel_id,
              let roomValue = info.room_id else {
            return ([:], nil)
        }

        logInfo("CC 弹幕参数获取成功，roomId: \(roomId)")
        return (["cid": "\(channelId)", "gametype": "\(info.gametype ?? 0)", "roomId": "\(roomValue)"], nil)
    }

    private static func fetchRoomDetail(roomId: String, userId: String?) async throws -> (CCRoomModel, String, String) {
        let sanitized = sanitizeId(userId ?? roomId)
        let parameters: Parameters = ["channelids": sanitized]

        let dataReq: CCLastestRoomModel = try await LiveParseRequest.get(
            channelDetailURL,
            parameters: parameters,
            headers: defaultHeaders
        )

        guard let room = dataReq.data.first else {
            throw LiveParseError.business(.roomNotFound(roomId: roomId))
        }

        let resolvedChannelId = String(room.channel_id ?? Int(sanitized) ?? 0)
        let resolvedRoomId = {
            if let cute = room.cuteid { return String(cute) }
            if let rid = room.roomid { return String(rid) }
            return formatId(input: roomId)
        }()

        return (room, resolvedChannelId, resolvedRoomId)
    }

    private static func buildQualityModel(label: String, resolution: CCLiveResolutionInfo?, roomId: String) -> LiveQualityModel? {
        guard let resolution = resolution, let cdn = resolution.cdn else { return nil }

        let cdnCandidates: [(String, String?)] = [
            ("ali", cdn.ali),
            ("ks", cdn.ks),
            ("hs", cdn.hs),
            ("hs2", cdn.hs2),
            ("ws", cdn.ws),
            ("dn", cdn.dn),
            ("xy", cdn.xy)
        ]

        var details: [LiveQualityDetail] = []
        for (name, url) in cdnCandidates {
            guard let url = url, !url.isEmpty else { continue }
            details.append(LiveQualityDetail(
                roomId: roomId,
                title: "线路 \(name)",
                qn: resolution.vbr ?? 0,
                url: url,
                liveCodeType: .flv,
                liveType: .cc
            ))
        }

        guard !details.isEmpty else { return nil }
        return LiveQualityModel(cdn: label, qualitys: details)
    }

    private static func sanitizeId(_ value: String) -> String {
        return value.contains("Optional") ? formatId(input: value) : value
    }

    private static func buildRequestDetail(url: String, parameters: Parameters? = nil) -> NetworkRequestDetail {
        NetworkRequestDetail(
            url: url,
            method: HTTPMethod.get.rawValue,
            headers: ["User-Agent": userAgent],
            parameters: parameters
        )
    }

    private static func extractShareIds(from text: String) -> (roomId: String, channelId: String?)? {
        let h5Pattern = #"https://h5\.cc\.163\.com/cc/(\d+)\?rid=(\d+)&cid=(\d+)"#
        if let regex = try? NSRegularExpression(pattern: h5Pattern, options: []) {
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let roomId = nsString.substring(with: match.range(at: 1))
                let channelId = nsString.substring(with: match.range(at: 3))
                return (roomId, channelId)
            }
        }

        let pcPattern = #"https://cc\.163\.com/(\d+)/?"#
        if let regex = try? NSRegularExpression(pattern: pcPattern, options: []) {
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let roomId = nsString.substring(with: match.range(at: 1))
                return (roomId, nil)
            }
        }

        return nil
    }
    
    static func formatId(input: String) -> String {
        do {
            let pattern = "\\d+"
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = input as NSString
            let results = regex.matches(in: input, options: [], range: NSMakeRange(0, nsString.length))
            for result in results {
                return nsString.substring(with: result.range(at: 0))
            }
            return input
        }catch {
            return input
        }
    }
}
