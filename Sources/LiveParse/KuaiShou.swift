//
//  KuaiShow.swift
//  
//
//  Created by pangchong on 2024/5/29.
//

import Foundation
import Alamofire

// Define the struct for the game data
struct KSCategoryModel: Codable {
    let id: String
    let name: String
    let poster: String
    let description: String
    let categoryAbbr: String
    let categoryName: String
}

// Define the struct for the list of games
struct KSCategoryList: Codable {
    let list: [KSCategoryModel]?
    let hasMore: Bool?
}

struct KSCategoryData<T: Codable>: Codable {
    let data: T
}

struct KSRoomList: Codable {
    let list: [KSRoomListModel]?
    let hasMore: Bool?
}

// MARK: - List
struct KSRoomListModel: Codable {
    let id: String
    let poster: String
    let playUrls: [PlayUrl]
    let caption: String?
    let startTime: Int
    let author: Author
    let gameInfo: GameInfo
    let hasRedPack: Bool
    let hasBet: Bool
    let followed: Bool
    let expTag: String
    let hotIcon: String
    let living: Bool
    let quality: String
    let watchingCount: String
    let landscape: Bool
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, poster, playUrls, caption
        case startTime = "statrtTime"
        case author, gameInfo, hasRedPack, hasBet, followed, expTag, hotIcon, living, quality, watchingCount, landscape, type
    }
}

// MARK: - Author
struct Author: Codable {
    let id: String?
    let name: String?
    let description: String?
    let avatar: String?
    let sex: String?
    let living: Bool?
    let followStatus: String?
    let constellation: String?
    let cityName: String?
    let originUserId: Int?
    let privacy: Bool?
    let isNew: Bool?
    let timestamp: Int?
    let verifiedStatus: VerifiedStatus?
    let bannedStatus: BannedStatus?
    let counts: Counts?
}

// MARK: - BannedStatus
struct BannedStatus: Codable {
    let banned, socialBanned, isolate, defriend: Bool
}

// MARK: - Counts
struct Counts: Codable {
}

// MARK: - VerifiedStatus
struct VerifiedStatus: Codable {
    let verified: Bool
    let description: String
    let type: Int
    let new: Bool
}

// MARK: - GameInfo
struct GameInfo: Codable {
    let id: Int?
    let name: String?
    let poster: String?
}

// MARK: - PlayUrl
struct PlayUrl: Codable {
    let hideAuto: Bool
    let autoDefaultSelect: Bool
    let cdnFeature: [String]
    let businessType: Int
    let freeTrafficCdn: Bool
    let version, type: String
    let adaptationSet: AdaptationSet
}

// MARK: - AdaptationSet
struct AdaptationSet: Codable {
    let gopDuration: Int
    let representation: [Representation]
}

// MARK: - Representation
struct Representation: Codable {
    let bitrate: Int
    let qualityType: String
    let level: Int
    let hidden, enableAdaptive, defaultSelect: Bool
    let id: Int
    let url, name, shortName: String
}

// MARK: - KSRoot
struct KSLiveRoot: Codable {
    let liveroom: KSLiveroom
}


// MARK: - KSLiveroom
struct KSLiveroom: Codable {
    let activeIndex: Int
    let websocketUrls: [String]?
    let token: String
    let noticeList: [KSNotice]
    let playList: [KSPlayList]?
    let loading: Bool
}

// MARK: - KSNotice
struct KSNotice: Codable {
    let userId: Int
    let userName: String
    let userGender: String
    let content: String
}

// MARK: - KSPlayList
struct KSPlayList: Codable {
    let liveStream: KSLiveStream
    let url: String?
    let location: String?
    let type: String?
    let liveGuess: Bool?
    let expTag: String?
    let privateLive: Bool?
    let author: KSAuthor?
    let gameInfo: KSGameInfo?
    let isLiving: Bool?
    let authToken: String?
    let config: KSConfig?
    let status: KSStatus?
}

// MARK: - KSLiveStream
struct KSLiveStream: Codable {
    let id: String?
    let poster: String?
    let playUrls: KSPlayUrls?
}

struct KSPlayUrls: Codable {
    let h264: KSPlayUrl?
    let hevc: KSPlayUrl?
}

// MARK: - KSPlayUrl
struct KSPlayUrl: Codable {
    let hideAuto: Bool
    let autoDefaultSelect: Bool
    let cdnFeature: [String]
    let businessType: Int
    let freeTrafficCdn: Bool
    let version, type: String
    let adaptationSet: KSAdaptationSet
}

// MARK: - KSAdaptationSet
struct KSAdaptationSet: Codable {
    let gopDuration: Int
    let representation: [KSRepresentation]
}

// MARK: - KSRepresentation
struct KSRepresentation: Codable {
    let bitrate: Int
    let qualityType: String
    let level: Int
    let hidden, enableAdaptive, defaultSelect: Bool
    let id: Int
    let url, name, shortName: String
}

// MARK: - KSAuthor
struct KSAuthor: Codable {
    let id: String?
    let name: String?
    let description: String?
    let avatar: String?
    let sex: String?
    let living: Bool?
    let followStatus: String?
    let constellation: String?
    let cityName: String?
    let originUserId: Int?
    let privacy: Bool?
    let isNew: Bool?
    let timestamp: Int?
    let verifiedStatus: KSVerifiedStatus?
    let bannedStatus: KSBannedStatus?
    let counts: KSCounts?
}

// MARK: - KSVerifiedStatus
struct KSVerifiedStatus: Codable {
    let verified: Bool
    let description: String
    let type: Int
    let new: Bool
}

// MARK: - KSBannedStatus
struct KSBannedStatus: Codable {
    let banned, socialBanned, isolate, defriend: Bool
}

// MARK: - KSCounts
struct KSCounts: Codable {
    let fan: String
    let follow: String
}

// MARK: - KSGameInfo
struct KSGameInfo: Codable {
    let id: String?
    let name: String?
    let poster: String?
    let description: String?
    let categoryAbbr: String?
    let categoryName: String?
    let watchingCount: String?
}

// MARK: - KSConfig
struct KSConfig: Codable {
    let canSendGift: Bool
    let needLoginToWatchHD: Bool
}

// MARK: - KSStatus
struct KSStatus: Codable {
    let forbiddenState: Int
}


public struct KuaiShou: LiveParse {
    private static let categoryURL = "https://live.kuaishou.com/live_api/category/data"
    private static let gameListURL = "https://live.kuaishou.com/live_api/gameboard/list"
    private static let nonGameListURL = "https://live.kuaishou.com/live_api/non-gameboard/list"
    private static let userLinkPattern = #"/u/([A-Za-z0-9_-]+)"#
    private static let liveLinkPattern = #"/live/([A-Za-z0-9_-]+)"#
    private static let shortLinkPattern = #"https://v\.kuaishou\.com/[A-Za-z0-9]+"#

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        logDebug("开始获取快手分类列表")

        let categories: [(String, String)] = [
            ("1", "热门"),
            ("2", "网游"),
            ("3", "单机"),
            ("4", "手游"),
            ("5", "棋牌"),
            ("6", "娱乐"),
            ("7", "综合"),
            ("8", "文化")
        ]

        var result: [LiveMainListModel] = []
        for (id, title) in categories {
            let subList = try await getCategorySubList(id: id)
            result.append(LiveMainListModel(id: id, title: title, icon: "", subList: subList))
        }

        logInfo("成功获取快手分类列表，共 \(result.count) 个分类")
        return result
    }

    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        logDebug("开始获取快手子分类，type: \(id)")

        var page = 1
        var hasMore = true
        var categoryList: [LiveCategoryModel] = []
        var firstRequestDetail: NetworkRequestDetail?

        while hasMore {
            let parameters: Parameters = [
                "type": id,
                "page": page,
                "pageSize": 20
            ]

            if firstRequestDetail == nil {
                firstRequestDetail = buildRequestDetail(url: categoryURL, method: .get, parameters: parameters)
            }

            let dataReq: KSCategoryData<KSCategoryList?> = try await LiveParseRequest.get(
                categoryURL,
                parameters: parameters
            )

            guard let data = dataReq.data else {
                logWarning("快手子分类返回空数据，type: \(id)，page: \(page)")
                break
            }

            if let list = data.list {
                for item in list {
                    categoryList.append(LiveCategoryModel(id: item.id, parentId: "", title: item.name, icon: item.poster))
                }
            }

            hasMore = data.hasMore ?? false
            page += 1
        }

        guard !categoryList.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "KuaiShou.getCategorySubList",
                request: firstRequestDetail
            ))
        }

        logInfo("快手子分类获取完成，type: \(id)，共 \(categoryList.count) 个子分类")
        return categoryList
    }

    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        let isNonGame = id.count >= 7
        let url = isNonGame ? nonGameListURL : gameListURL
        let parameters: Parameters = [
            "filterType": 0,
            "page": page,
            "pageSize": 20,
            "gameId": id
        ]

        logDebug("开始获取快手直播间列表，分类ID: \(id)，页码: \(page)")

        let dataReq: KSCategoryData<KSRoomList> = try await LiveParseRequest.get(
            url,
            parameters: parameters
        )

        guard let list = dataReq.data.list, !list.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "KuaiShou.getRoomList",
                request: buildRequestDetail(url: url, method: .get, parameters: parameters)
            ))
        }

        let rooms: [LiveModel] = list.map { item in
            let isLiving = item.living
            return LiveModel(
                userName: item.author.name ?? "",
                roomTitle: item.caption ?? "\(item.author.name ?? "")的直播间",
                roomCover: item.poster,
                userHeadImg: item.author.avatar ?? "",
                liveType: .ks,
                liveState: isLiving ? LiveState.live.rawValue : LiveState.close.rawValue,
                userId: item.author.id ?? item.id,
                roomId: item.author.id ?? item.id,
                liveWatchedCount: item.watchingCount
            )
        }

        logInfo("成功获取快手直播间列表，分类ID: \(id)，共 \(rooms.count) 个房间")
        return rooms
    }

    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        logDebug("开始获取快手播放参数，房间ID: \(roomId)")

        let liveData = try await getKSLiveRoom(roomId: roomId)

        guard let playList = liveData.liveroom.playList?.first,
              let playUrls = playList.liveStream.playUrls else {
            throw LiveParseError.business(.liveNotStarted(roomId: roomId))
        }

        var qualityDetails: [LiveQualityDetail] = []
        if let h264 = playUrls.h264 {
            qualityDetails.append(contentsOf: makeQualityDetails(from: h264, roomId: roomId))
        }
        if let hevc = playUrls.hevc {
            qualityDetails.append(contentsOf: makeQualityDetails(from: hevc, roomId: roomId))
        }

        guard !qualityDetails.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "KuaiShou.getPlayArgs",
                request: buildRequestDetail(url: "https://live.kuaishou.com/u/\(roomId)", method: .get)
            ))
        }

        logInfo("成功获取快手播放参数，房间ID: \(roomId)，共 \(qualityDetails.count) 条清晰度")
        return [LiveQualityModel(cdn: "线路1", qualitys: qualityDetails)]
    }

    static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        logInfo("快手暂未提供搜索接口，关键词: \(keyword)")
        return []
    }

    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        logDebug("开始获取快手房间信息，房间ID: \(roomId)")

        let liveData = try await getKSLiveRoom(roomId: roomId)

        guard let current = liveData.liveroom.playList?.first else {
            throw LiveParseError.business(.roomNotFound(roomId: roomId))
        }

        let author = current.author
        let hasH264 = !(current.liveStream.playUrls?.h264?.adaptationSet.representation.isEmpty ?? true)
        let hasHevc = !(current.liveStream.playUrls?.hevc?.adaptationSet.representation.isEmpty ?? true)
        let hasStream = hasH264 || hasHevc
        let liveState = (current.isLiving ?? hasStream) ? LiveState.live.rawValue : LiveState.close.rawValue

        let roomTitle = author?.description ?? current.gameInfo?.name ?? (author?.name ?? "")
        let model = LiveModel(
            userName: author?.name ?? "",
            roomTitle: roomTitle,
            roomCover: current.liveStream.poster ?? author?.avatar ?? "",
            userHeadImg: author?.avatar ?? "",
            liveType: .ks,
            liveState: liveState,
            userId: author?.id ?? roomId,
            roomId: author?.id ?? roomId,
            liveWatchedCount: current.gameInfo?.watchingCount
        )

        logInfo("成功获取快手房间信息，房间ID: \(roomId)，主播: \(model.userName)")
        return model
    }

    static func getKSLiveRoom(roomId: String) async throws -> KSLiveRoot {
        let url = "https://live.kuaishou.com/u/\(roomId)"

        do {
            let html = try await LiveParseRequest.requestString(url)
            let pattern = #"<script>window.__INITIAL_STATE__=\s*(.*?)\;"#
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let nsString = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

            guard let match = matches.first else {
                throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "服务器返回信息：\(html)")
            }

            let matchedSubstring = nsString.substring(with: match.range)
            var tempStr = matchedSubstring
            tempStr = tempStr.replacingOccurrences(of: "<script>window.__INITIAL_STATE__=", with: "")
            tempStr = tempStr.replacingOccurrences(of: ";", with: "")
            tempStr = tempStr.replacingOccurrences(of: ":undefined", with: ":\"\"")
            tempStr = String.convertUnicodeEscapes(in: tempStr as String)

            guard let data = tempStr.data(using: .utf8) else {
                throw LiveParseError.parse(.invalidDataFormat(
                    expected: "UTF-8 JSON",
                    actual: "无法编码",
                    location: "KuaiShou.getKSLiveRoom"
                ))
            }

            return try JSONDecoder().decode(KSLiveRoot.self, from: data)
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }

    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        logDebug("开始获取快手直播状态，房间ID: \(roomId)")

        let liveInfo = try await getLiveLastestInfo(roomId: roomId, userId: userId)

        guard let value = liveInfo.liveState, let state = LiveState(rawValue: value) else {
            throw LiveParseError.parse(.invalidDataFormat(
                expected: "LiveState",
                actual: liveInfo.liveState ?? "nil",
                location: "KuaiShou.getLiveState"
            ))
        }

        logInfo("快手直播状态获取成功，房间ID: \(roomId)，状态: \(state)")
        return state
    }

    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        let trimmed = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        logDebug("开始解析快手分享码: \(trimmed)")

        if let url = extractShortLink(from: trimmed) {
            logDebug("识别为快手短链接: \(url)")
            let finalUrl = try await resolveShortLink(url)
            if let liveId = extractLiveId(from: finalUrl) {
                logDebug("短链接解析到 liveId: \(liveId)")
                return try await getLiveLastestInfo(roomId: liveId, userId: nil)
            }
            if let userId = extractUserId(from: finalUrl) {
                logDebug("短链接解析到用户ID: \(userId)")
                return try await getLiveLastestInfo(roomId: userId, userId: nil)
            }
            throw LiveParseError.shareCodeParseError(
                "快手分享码解析失败",
                "未能从短链接解析房间号，URL: \(finalUrl)"
            )
        }

        if trimmed.contains("live.kuaishou.com") {
            if let userId = extractUserId(from: trimmed) {
                logDebug("解析到快手用户链接，用户ID: \(userId)")
                return try await getLiveLastestInfo(roomId: userId, userId: nil)
            }

            if let liveId = extractLiveId(from: trimmed) {
                logDebug("解析到快手 live 链接，liveId: \(liveId)")
                return try await getLiveLastestInfo(roomId: liveId, userId: nil)
            }
        }

        if isValidRoomId(trimmed) {
            logDebug("识别为快手房间ID: \(trimmed)")
            return try await getLiveLastestInfo(roomId: trimmed, userId: nil)
        }

        throw LiveParseError.shareCodeParseError(
            "快手分享码解析失败",
            "无法解析房间号，请检查分享码/链接是否正确"
        )
    }

    static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        logInfo("快手暂未开放弹幕接口，房间ID: \(roomId)")
        return ([:], nil)
    }

    // MARK: - Helpers

    private static func makeQualityDetails(from playUrl: KSPlayUrl, roomId: String) -> [LiveQualityDetail] {
        playUrl.adaptationSet.representation.map { representation in
            LiveQualityDetail(
                roomId: roomId,
                title: representation.name,
                qn: representation.bitrate,
                url: representation.url,
                liveCodeType: .flv,
                liveType: .ks
            )
        }
    }

    private static func extractUserId(from text: String) -> String? {
        firstMatch(in: text, pattern: userLinkPattern)
    }

    private static func extractLiveId(from text: String) -> String? {
        firstMatch(in: text, pattern: liveLinkPattern)
    }

    private static func extractShortLink(from text: String) -> String? {
        firstMatch(in: text, pattern: shortLinkPattern, captureGroup: 0)
    }

    private static func firstMatch(in text: String, pattern: String, captureGroup: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        let targetRange = captureGroup == 0 ? match.range : match.range(at: captureGroup)
        guard targetRange.location != NSNotFound, let swiftRange = Range(targetRange, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func isValidRoomId(_ roomId: String) -> Bool {
        let pattern = "^[A-Za-z0-9_-]{3,}$"
        return roomId.range(of: pattern, options: .regularExpression) != nil
    }

    private static func resolveShortLink(_ url: String) async throws -> String {
        let rawResponse = try await LiveParseRequest.requestRaw(url)
        if let finalURL = rawResponse.finalURL {
            return finalURL
        }
        return rawResponse.request.url
    }

    private static func buildRequestDetail(
        url: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) -> NetworkRequestDetail {
        NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters
        )
    }
}
