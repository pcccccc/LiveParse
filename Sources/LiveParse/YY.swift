//
//  YY.swift
//
//
//  Created by pangchong on 2024/6/6.
//

import Foundation
import Alamofire

// MARK: - Models

struct YYCategoryRoot: Codable {
    let code: Int
    let message: String
    let data: [YYCategoryList]?
}

struct YYCategoryList: Codable {
    let id: Int
    let name: String
    let platform: Int?
    let biz: String?
    let sort: Int?
    let selected: Int?
    let url: String?
    let pic: String?
    let darkPic: String?
    let serv: Int?
    let navs: [YYCategorySubList]?
    let icon: Int?
}

struct YYCategorySubList: Codable {
    let id: Int
    let name: String
    let platform: Int?
    let biz: String?
    let sort: Int?
    let selected: Int?
    let serv: Int?
    let navs: [YYCategorySubList]?
}

struct YYRoomResponse: Codable {
    let code: Int?
    let message: String?
    let data: [YYRoomSection]?
}

struct YYRoomSection: Codable {
    let id: Int?
    let name: String?
    let data: [YYRoomListData]?
}

struct YYRoomListData: Codable {
    let uid: Int?
    let sid: Int?
    let name: String?
    let desc: String?
    let avatar: String?
    let users: Int?
    let img: String?
}

struct YYRoomInfoMain: Codable {
    let resultCode: Int
    let data: YYRoomInfo?
}

struct YYRoomInfo: Codable {
    let type: Int?
    let uid: Int
    let name: String
    let thumb2: String?
    let desc: String
    let biz: String?
    let users: Int
    let sid: Int
    let ssid: Int?
    let pid: String?
    let tag: String?
    let tagStyle: String?
    let tpl: String?
    let linkMic: Int?
    let gameThumb: String?
    let avatar: String
    let yyNum: Int?
    let totalViewer: String?
    let configId: Int?
}

struct YYSearchMain: Codable {
    let success: Bool
    let status: Int
    let message: String
    let data: YYSearchMainData
}

struct YYSearchMainData: Codable {
    let searchResult: YYSearchResult
}

struct YYSearchResult: Codable {
    let response: YYSearchResponse?
}

struct YYSearchResponse: Codable {
    let one: YYDocs

    enum CodingKeys: String, CodingKey {
        case one = "1"
    }
}

struct YYDocs: Codable {
    let docs: [YYSearchRoom]
}

struct YYSearchRoom: Codable {
    let asid: String?
    let liveOn: String?
    let aliasName: String?
    let yyid: Int?
    let subscribe: String?
    let dataType: Int?
    let yynum: String?
    let auth_state: String?
    let headurl: String?
    let ssid: String?
    let subbiz: String?
    let sid: String?
    let uid: String?
    let tpl: String?
    let stageName: String?
    let name: String?
}

private struct YYLineInfo {
    let name: String
    let lineSeq: String
}

// MARK: - YY Platform

public struct YY: LiveParse {

    private static let defaultHeaders: HTTPHeaders = [
        HTTPHeader(name: "user-agent", value: " Platform/iOS17.5.1 APP/yymip8.40.0 Model/iPhone Browerser:Default Scale/3.00 YY(ClientVersion:8.40.0 ClientEdition:yymip) HostName/yy HostVersion/8.40.0 HostId/1 UnionVersion/2.690.0 Build1492 HostExtendInfo/b576b278cba95c5100f84a69b26dc36bf44f080608b937825dcd64ee5911351f74dbda4ac85cfb011f32eb00b7c16ecc6bad4eaa3cd9f69c923177e74f6212682492886a946abdcf921a84c93ff329d4fd9e2bc67f5fe727d9a7b10ee65fbbbf"),
        HTTPHeader(name: "accept-language", value: "zh-Hans-CN;q=1"),
        HTTPHeader(name: "accept-encoding", value: "gzip, deflate, br, zstd"),
        HTTPHeader(name: "content-type", value: "application/json; charset=utf-8"),
        HTTPHeader(name: "Accept", value: "application/json")
    ]

    private static let categoryURL = "https://rubiks-idx.yy.com/navs"
    private static let idxRoomURLTemplate = "https://yyapp-idx.yy.com/mobyy/nav/%@/%@"
    private static let navRoomURLTemplate = "https://rubiks-idx.yy.com/nav/%@/%@"
    private static let searchURL = "https://www.yy.com/apiSearch/doSearch.json"
    private static let roomInfoURLTemplate = "https://www.yy.com/api/liveInfoDetail/%@/%@/0"
    private static let playURL = "https://stream-manager.yy.com/v3/channel/streams"
    private static let shareCodeDelimiters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "|"))
    private static let playHeaders: HTTPHeaders = [
        HTTPHeader(name: "content-type", value: "text/plain;charset=UTF-8"),
        HTTPHeader(name: "referer", value: "https://www.yy.com")
    ]
    private static let sidQueryKeys = ["sid", "ssid", "roomId"]
    private static let numericRoomPattern = "^\\d{3,}$"

    // MARK: - Category

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        if LiveParseConfig.enableJSPlugins {
            do {
                let result: [LiveMainListModel] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "yy",
                    function: "getCategoryList",
                    payload: [:]
                )
                logInfo("YY.getCategoryList 使用 JS 插件返回 \(result.count) 个主分类")
                return result
            } catch {
                logWarning("YY.getCategoryList JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始获取 YY 分类列表")

        let response: YYCategoryRoot = try await LiveParseRequest.get(
            categoryURL,
            headers: defaultHeaders
        )

        guard response.code == 0 else {
            throw LiveParseError.business(.permissionDenied(reason: "YY 分类接口返回 code: \(response.code) - \(response.message)"))
        }

        let lists = response.data ?? []
        var result: [LiveMainListModel] = []

        for item in lists {
            if item.name == "附近" { continue }

            var subList: [LiveCategoryModel] = []
            let navs = item.navs ?? []
            for nav in navs {
                subList.append(LiveCategoryModel(
                    id: "\(nav.id)",
                    parentId: "\(item.id)",
                    title: nav.name,
                    icon: "",
                    biz: nav.biz ?? ""
                ))
            }

            if subList.isEmpty {
                subList.append(LiveCategoryModel(
                    id: "0",
                    parentId: "\(item.id)",
                    title: item.name,
                    icon: "",
                    biz: "idx"
                ))
            }

            result.append(LiveMainListModel(
                id: "\(item.id)",
                title: item.name,
                icon: item.pic ?? "",
                biz: item.biz ?? "",
                subList: subList
            ))
        }

        logInfo("YY 分类列表获取成功，共 \(result.count) 个")
        return result
    }

    // MARK: - Room List

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
                    pluginId: "yy",
                    function: "getRoomList",
                    payload: [
                        "id": id,
                        "parentId": parentId as Any,
                        "page": page
                    ]
                )
                logInfo("YY.getRoomList 使用 JS 插件返回 \(rooms.count) 个房间")
                return rooms.map {
                    LiveModel(
                        userName: $0.userName,
                        roomTitle: $0.roomTitle,
                        roomCover: $0.roomCover,
                        userHeadImg: $0.userHeadImg,
                        liveType: .yy,
                        liveState: $0.liveState,
                        userId: $0.userId,
                        roomId: $0.roomId,
                        liveWatchedCount: $0.liveWatchedCount
                    )
                }
            } catch {
                logWarning("YY.getRoomList JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let resolvedParentId = parentId ?? ""
        let url = buildRoomListURL(id: id, parentId: resolvedParentId)
        logDebug("开始获取 YY 房间列表，分类: \(id)，父级: \(resolvedParentId)")

        do {
            let response: YYRoomResponse = try await LiveParseRequest.get(
                url,
                headers: defaultHeaders
            )

            if let code = response.code, code != 0 {
                throw LiveParseError.business(.permissionDenied(reason: "YY 房间接口返回 code: \(code) - \(response.message ?? "")"))
            }

            let sections = response.data ?? []
            let rooms = sections.flatMap { section -> [LiveModel] in
                guard let items = section.data else { return [] }
                return items.compactMap { item -> LiveModel? in
                    guard let sid = item.sid else { return nil }
                    if let name = item.name, name.contains("预告") || name.contains("活动") {
                        return nil
                    }
                    let uid = item.uid.map { String($0) } ?? String(sid)
                    return LiveModel(
                        userName: item.name ?? "",
                        roomTitle: item.desc ?? "",
                        roomCover: item.img ?? "",
                        userHeadImg: item.avatar ?? "",
                        liveType: .yy,
                        liveState: LiveState.live.rawValue,
                        userId: uid,
                        roomId: String(sid),
                        liveWatchedCount: String(item.users ?? 0)
                    )
                }
            }

            if rooms.isEmpty {
                logWarning("YY 房间列表为空，分类: \(id)")
            } else {
                logInfo("YY 房间列表获取成功，共 \(rooms.count) 条")
            }
            return rooms
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.liveParseError("YY.getRoomList", "错误信息：\(error.localizedDescription)")
        }
    }

    private static func buildRoomListURL(id: String, parentId: String) -> String {
        if id == "index" {
            return String(format: idxRoomURLTemplate, id, parentId)
        }
        return String(format: navRoomURLTemplate, id, parentId)
    }

    // MARK: - Play Args

    public static func getPlayArgs(roomId: String, userId: String? = "-1") async throws -> [LiveQualityModel] {
        if LiveParseConfig.enableJSPlugins {
            do {
                let result: [LiveQualityModel] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "yy",
                    function: "getPlayArgs",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("YY.getPlayArgs 使用 JS 插件返回 \(result.count) 组线路")
                return result
            } catch {
                logWarning("YY.getPlayArgs JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始获取 YY 播放参数，房间: \(roomId)")
        let result = try await getRealPlayArgs(roomId: roomId)
        if let first = result.first {
            logInfo("YY 播放参数获取成功，线路: \(result.count)，清晰度: \(first.qualitys.count)")
        }
        return result
    }

    public static func getRealPlayArgs(roomId: String, lineSeq: Int? = -1, gear: Int? = 4) async throws -> [LiveQualityModel] {
        let millis13 = Int(Date().timeIntervalSince1970 * 1000)
        let millis10 = Int(Date().timeIntervalSince1970)

        let params: [String: Any] = [
            "head": [
                "seq": millis13,
                "appidstr": "0",
                "bidstr": "121",
                "cidstr": roomId,
                "sidstr": roomId,
                "uid64": 0,
                "client_type": 108,
                "client_ver": "5.18.2",
                "stream_sys_ver": 1,
                "app": "yylive_web",
                "playersdk_ver": "5.18.2",
                "thundersdk_ver": "0",
                "streamsdk_ver": "5.18.2"
            ],
            "client_attribute": [
                "client": "web",
                "model": "web1",
                "cpu": "",
                "graphics_card": "",
                "os": "chrome",
                "osversion": "125.0.0.0",
                "vsdk_version": "",
                "app_identify": "",
                "app_version": "",
                "business": "",
                "width": "1920",
                "height": "1080",
                "scale": "",
                "client_type": 8,
                "h265": 0
            ],
            "avp_parameter": [
                "version": 1,
                "client_type": 8,
                "service_type": 0,
                "imsi": 0,
                "send_time": millis10,
                "line_seq": lineSeq ?? -1,
                "gear": gear ?? 4,
                "ssl": 1,
                "stream_format": 0
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: params, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LiveParseError.parse(.invalidDataFormat(
                expected: "UTF-8 JSON",
                actual: "无法编码",
                location: "YY.getRealPlayArgs"
            ))
        }

        let url = "\(playURL)?uid=0&cid=\(roomId)&sid=\(roomId)&appid=0&sequence=\(millis13)&encode=json"

        let rawResponse = try await LiveParseRequest.requestRaw(
            url,
            method: .post,
            encoding: JSONStringEncoding(jsonString),
            headers: playHeaders
        )

        return try parsePlayResponse(rawResponse: rawResponse, roomId: roomId)
    }

    private static func parsePlayResponse(rawResponse: NetworkRawResponse, roomId: String) throws -> [LiveQualityModel] {
        let location = "YY.parsePlayResponse"

        guard let jsonObject = try JSONSerialization.jsonObject(with: rawResponse.data, options: []) as? [String: Any] else {
            throw LiveParseError.parse(.invalidJSON(
                location: location,
                request: rawResponse.request,
                response: rawResponse.response
            ))
        }

        guard let avpInfo = jsonObject["avp_info_res"] as? [String: Any] else {
            throw LiveParseError.parse(.missingRequiredField(
                field: "avp_info_res",
                location: location,
                response: rawResponse.response
            ))
        }

        let lineInfos = parseLineInfos(from: avpInfo)
        guard let playURL = extractPlayURL(from: avpInfo) else {
            throw LiveParseError.parse(.missingRequiredField(
                field: "stream_line_addr.cdn_info.url",
                location: location,
                response: rawResponse.response
            ))
        }

        let qualityDetails = try parseQualityDetails(
            from: jsonObject,
            defaultURL: playURL,
            roomId: roomId,
            response: rawResponse.response
        )

        return lineInfos.map { line in
            LiveQualityModel(cdn: line.name, yyLineSeq: line.lineSeq, qualitys: qualityDetails)
        }
    }

    private static func parseLineInfos(from avpInfo: [String: Any]) -> [YYLineInfo] {
        guard let streamLineList = avpInfo["stream_line_list"] as? [String: Any] else {
            return []
        }

        var result: [YYLineInfo] = []
        for value in streamLineList.values {
            guard let lineDict = value as? [String: Any],
                  let lineInfos = lineDict["line_infos"] as? [[String: Any]] else { continue }

            for info in lineInfos {
                guard let name = info["line_print_name"] as? String, !name.isEmpty else { continue }
                let lineSeq = String(info["line_seq"] as? Int ?? -1)
                if result.contains(where: { $0.name == name }) { continue }
                result.append(YYLineInfo(name: name, lineSeq: lineSeq))
            }
        }
        return result
    }

    private static func extractPlayURL(from avpInfo: [String: Any]) -> String? {
        guard let lineAddr = avpInfo["stream_line_addr"] as? [String: Any] else {
            return nil
        }

        for value in lineAddr.values {
            guard let streamInfo = value as? [String: Any],
                  let cdnInfo = streamInfo["cdn_info"] as? [String: Any],
                  let url = cdnInfo["url"] as? String,
                  !url.isEmpty else { continue }
            return url
        }
        return nil
    }

    private static func parseQualityDetails(
        from jsonObject: [String: Any],
        defaultURL: String,
        roomId: String,
        response: NetworkResponseDetail
    ) throws -> [LiveQualityDetail] {
        let location = "YY.parseQualityDetails"
        guard let channelInfo = jsonObject["channel_stream_info"] as? [String: Any],
              let streams = channelInfo["streams"] as? [[String: Any]] else {
            throw LiveParseError.parse(.missingRequiredField(
                field: "channel_stream_info.streams",
                location: location,
                response: response
            ))
        }

        var details: [LiveQualityDetail] = []
        for stream in streams {
            guard let jsonString = stream["json"] as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let decoded = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                  let gearInfo = decoded["gear_info"] as? [String: Any] else { continue }

            let rate = gearInfo["gear"] as? Int ?? 0
            let title = gearInfo["name"] as? String ?? "默认"

            if details.contains(where: { $0.qn == rate && $0.title == title }) {
                continue
            }

            details.append(LiveQualityDetail(
                roomId: roomId,
                title: title,
                qn: rate,
                url: defaultURL,
                liveCodeType: .flv,
                liveType: .yy
            ))
        }

        guard !details.isEmpty else {
            throw LiveParseError.parse(.missingRequiredField(
                field: "gear_info",
                location: location,
                response: response
            ))
        }

        return details
    }

    // MARK: - Room Detail

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
                    pluginId: "yy",
                    function: "getLiveLastestInfo",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("YY.getLiveLastestInfo 使用 JS 插件成功")
                return LiveModel(
                    userName: info.userName,
                    roomTitle: info.roomTitle,
                    roomCover: info.roomCover,
                    userHeadImg: info.userHeadImg,
                    liveType: .yy,
                    liveState: info.liveState,
                    userId: info.userId,
                    roomId: info.roomId,
                    liveWatchedCount: info.liveWatchedCount
                )
            } catch {
                logWarning("YY.getLiveLastestInfo JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let url = String(format: roomInfoURLTemplate, roomId, roomId)
        logDebug("开始获取 YY 房间信息，房间: \(roomId)")

        let response: YYRoomInfoMain = try await LiveParseRequest.get(url)

        guard response.resultCode == 0, let info = response.data else {
            throw LiveParseError.business(.roomNotFound(roomId: roomId))
        }

        return LiveModel(
            userName: info.name,
            roomTitle: info.desc,
            roomCover: info.thumb2 ?? info.gameThumb ?? "",
            userHeadImg: info.avatar,
            liveType: .yy,
            liveState: LiveState.live.rawValue,
            userId: String(info.uid),
            roomId: String(info.sid),
            liveWatchedCount: String(info.users)
        )
    }

    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveState: Decodable {
                let liveState: String
            }

            do {
                let result: PluginLiveState = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "yy",
                    function: "getLiveState",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )

                if let state = LiveState(rawValue: result.liveState) {
                    logInfo("YY.getLiveState 使用 JS 插件成功")
                    return state
                }

                logWarning("YY.getLiveState JS 插件返回无效状态：\(result.liveState)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw LiveParseError.liveStateParseError(
                        "YY 直播状态获取失败",
                        "插件返回未知状态值: \(result.liveState)"
                    )
                }
            } catch {
                logWarning("YY.getLiveState JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let latest = try await getLiveLastestInfo(roomId: roomId, userId: userId)
        return LiveState(rawValue: latest.liveState ?? LiveState.unknow.rawValue) ?? .unknow
    }

    // MARK: - Search

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
                    pluginId: "yy",
                    function: "searchRooms",
                    payload: [
                        "keyword": keyword,
                        "page": page
                    ]
                )
                logInfo("YY.searchRooms 使用 JS 插件返回 \(rooms.count) 个房间")
                return rooms.map {
                    LiveModel(
                        userName: $0.userName,
                        roomTitle: $0.roomTitle,
                        roomCover: $0.roomCover,
                        userHeadImg: $0.userHeadImg,
                        liveType: .yy,
                        liveState: $0.liveState,
                        userId: $0.userId,
                        roomId: $0.roomId,
                        liveWatchedCount: $0.liveWatchedCount
                    )
                }
            } catch {
                logWarning("YY.searchRooms JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logDebug("开始搜索 YY 房间，关键词: \(keyword)")

        let parameters: Parameters = [
            "q": keyword,
            "t": 1,
            "n": page
        ]

        let response: YYSearchMain = try await LiveParseRequest.get(
            searchURL,
            parameters: parameters
        )

        guard response.success else {
            throw LiveParseError.business(.permissionDenied(reason: "YY 搜索接口: \(response.message)"))
        }

        guard let docs = response.data.searchResult.response?.one.docs else {
            return []
        }

        return docs.compactMap { doc in
            guard let roomId = doc.sid, !roomId.isEmpty else { return nil }
            return LiveModel(
                userName: doc.name ?? doc.stageName ?? "",
                roomTitle: doc.stageName ?? doc.name ?? "",
                roomCover: doc.headurl ?? "",
                userHeadImg: doc.headurl ?? "",
                liveType: .yy,
                liveState: doc.liveOn ?? LiveState.unknow.rawValue,
                userId: doc.uid ?? roomId,
                roomId: roomId,
                liveWatchedCount: "0"
            )
        }
    }

    // MARK: - Share Code

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
                    pluginId: "yy",
                    function: "getRoomInfoFromShareCode",
                    payload: [
                        "shareCode": shareCode
                    ]
                )
                logInfo("YY.getRoomInfoFromShareCode 使用 JS 插件成功")
                return LiveModel(
                    userName: info.userName,
                    roomTitle: info.roomTitle,
                    roomCover: info.roomCover,
                    userHeadImg: info.userHeadImg,
                    liveType: .yy,
                    liveState: info.liveState,
                    userId: info.userId,
                    roomId: info.roomId,
                    liveWatchedCount: info.liveWatchedCount
                )
            } catch {
                logWarning("YY.getRoomInfoFromShareCode JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let roomId = try resolveRoomId(from: shareCode)
        logDebug("YY 分享码解析成功，房间: \(roomId)")
        return try await getLiveLastestInfo(roomId: roomId, userId: nil)
    }

    private static func resolveRoomId(from shareCode: String) throws -> String {
        let trimmed = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LiveParseError.shareCodeParseError("YY 分享码解析失败", "分享内容为空")
        }

        if let url = extractFirstURL(from: trimmed) {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                for key in sidQueryKeys {
                    if let value = components.queryItems?.first(where: { $0.name == key })?.value,
                       isValidRoomId(value) {
                        return value
                    }
                }
            }

            let pathIds = url.pathComponents.filter { isValidRoomId($0) }
            if let candidate = pathIds.last {
                return candidate
            }
        }

        for token in trimmed.components(separatedBy: shareCodeDelimiters) where isValidRoomId(token) {
            return token
        }

        if isValidRoomId(trimmed) {
            return trimmed
        }

        throw LiveParseError.shareCodeParseError(
            "YY 分享码解析失败",
            "无法解析房间号，请检查分享码/分享链接是否正确"
        )
    }

    private static func extractFirstURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = detector.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        return match.url
    }

    private static func isValidRoomId(_ value: String) -> Bool {
        return value.range(of: numericRoomPattern, options: .regularExpression) != nil
    }

    // MARK: - Danmaku

    static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        if LiveParseConfig.enableJSPlugins {
            struct PluginResult: Decodable {
                let args: [String: String]
                let headers: [String: String]?
            }

            do {
                let result: PluginResult = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "yy",
                    function: "getDanmukuArgs",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("YY.getDanmukuArgs 使用 JS 插件成功")
                return (result.args, result.headers)
            } catch {
                logWarning("YY.getDanmukuArgs JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        logInfo("YY 暂未开放弹幕接口，房间: \(roomId)")
        return ([:], nil)
    }
}

// MARK: - Helpers

struct JSONStringEncoding: ParameterEncoding {
    private let jsonString: String

    init(_ jsonString: String) {
        self.jsonString = jsonString
    }

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = jsonString.data(using: .utf8)
        return request
    }
}
