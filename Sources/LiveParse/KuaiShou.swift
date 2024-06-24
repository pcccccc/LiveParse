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
    let caption: String
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
    let playUrls: [KSPlayUrl]?
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
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "1", title: "热门", icon: "", subList: try await getCategorySubList(id: "1")),
            LiveMainListModel(id: "2", title: "网游", icon: "", subList: try await getCategorySubList(id: "2")),
            LiveMainListModel(id: "3", title: "单机", icon: "", subList: try await getCategorySubList(id: "3")),
            LiveMainListModel(id: "4", title: "手游", icon: "", subList: try await getCategorySubList(id: "4")),
            LiveMainListModel(id: "5", title: "棋牌", icon: "", subList: try await getCategorySubList(id: "5")),
            LiveMainListModel(id: "6", title: "娱乐", icon: "", subList: try await getCategorySubList(id: "6")),
            LiveMainListModel(id: "7", title: "综合", icon: "", subList: try await getCategorySubList(id: "7")),
            LiveMainListModel(id: "8", title: "文化", icon: "", subList: try await getCategorySubList(id: "8"))
        ]
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        do {
            var hasMore = true
            var page = 1
            var tempArray: [LiveCategoryModel] = []
            while hasMore == true {
                let dataReq = try await AF.request(
                    "https://live.kuaishou.com/live_api/category/data",
                    method: .get,
                    parameters: [
                        "type": id,
                        "page": page,
                        "pageSize": 20
                    ]
                ).serializingDecodable(KSCategoryData<KSCategoryList?>.self).value
                if let list = dataReq.data?.list {
                    for item in list {
                        tempArray.append(LiveCategoryModel(id: item.id, parentId: "", title: item.name, icon: item.poster))
                    }
                    hasMore = dataReq.data?.hasMore ?? false
                    page += 1
                }
            }
            return tempArray
        }catch {
            print(error)
            var hasMore = true
            var page = 1
            var tempArray: [LiveCategoryModel] = []
            while hasMore == true {
                let dataReq = try await AF.request(
                    "https://live.kuaishou.com/live_api/category/data",
                    method: .get,
                    parameters: [
                        "type": id,
                        "page": page,
                        "pageSize": 20
                    ]
                ).serializingDecodable(KSCategoryData<KSCategoryList?>.self).value
                hasMore = dataReq.data?.hasMore ?? false
                page += 1
            }
            throw(error)
        }
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        do {
            let url = id.count >= 7 ? "https://live.kuaishou.com/live_api/non-gameboard/list" : "https://live.kuaishou.com/live_api/gameboard/list"
            let dataReq = try await AF.request(
                url,
                method: .get,
                parameters: [
                    "filterType": 0,
                    "page": page,
                    "pageSize": 20,
                    "gameId": id
                ]
            ).serializingDecodable(KSCategoryData<KSRoomList>.self).value
            var tempArray = [LiveModel]()
            if let list = dataReq.data.list {
                for item in list {
                    tempArray.append(LiveModel(userName: item.author.name ?? "", roomTitle: item.caption, roomCover: item.poster, userHeadImg: item.author.avatar ?? "", liveType: .ks, liveState: "1", userId: item.author.id ?? "", roomId: item.author.id ?? "", liveWatchedCount: item.watchingCount))
                }
            }
            return tempArray
        }catch {
            print(error)
            let url = id.count >= 7 ? "https://live.kuaishou.com/live_api/non-gameboard/list" : "https://live.kuaishou.com/live_api/gameboard/list"
            let dataReq = try await AF.request(
                url,
                method: .get,
                parameters: [
                    "filterType": 0,
                    "page": page,
                    "pageSize": 20,
                    "gameId": id
                ]
            ).serializingString().value
            print(dataReq)
            throw error
        }
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        let dataReq = try await getKSLiveRoom(roomId: roomId)
        var liveQuaityModel = LiveQualityModel(cdn: "线路1", douyuCdnName: "", qualitys: [])
        if let playList = dataReq.liveroom.playList?.first?.liveStream.playUrls?.first?.adaptationSet.representation {
            for item in playList {
                liveQuaityModel.qualitys.append(.init(roomId: roomId, title: item.name, qn: item.bitrate, url: item.url, liveCodeType: .flv, liveType: .ks))
            }
        }
        return [liveQuaityModel]
    }
    
    static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        []
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let dataReq = try await getKSLiveRoom(roomId: roomId)
        return LiveModel(userName: dataReq.liveroom.playList?.first?.author?.name ?? "", roomTitle: dataReq.liveroom.playList?.first?.author?.name ?? "", roomCover: dataReq.liveroom.playList?.first?.liveStream.poster ?? "", userHeadImg: dataReq.liveroom.playList?.first?.author?.avatar ?? "", liveType: .ks, liveState: dataReq.liveroom.playList?.first?.liveStream.playUrls?.count ?? 0 > 0 ? LiveState.live.rawValue : LiveState.close.rawValue, userId: "", roomId: roomId, liveWatchedCount: "")
    }
    
    static func getKSLiveRoom(roomId: String) async throws -> KSLiveRoot {
        let dataReq = try await AF.request(
            "https://live.kuaishou.com/u/\(roomId)",
            method: .get
        ).serializingString().value
        let pattern = #"<script>window.__INITIAL_STATE__=\s*(.*?)\;"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let matchs =  regex.matches(in: dataReq, range: NSRange(location: 0, length:  dataReq.count))
        for match in matchs {
            let matchRange = Range(match.range, in: dataReq)!
            let matchedSubstring = String(dataReq[matchRange])
            var tempStr = matchedSubstring.replacingOccurrences(of: "<script>window.__INITIAL_STATE__=", with: "")
            
            tempStr = tempStr.replacingOccurrences(of: ";", with: "")
            tempStr = tempStr.replacingOccurrences(of: ":undefined", with: ":\"\"")
            tempStr = String.convertUnicodeEscapes(in: tempStr as String)
            print(tempStr)
            do {
                let data = try JSONDecoder().decode(KSLiveRoot.self, from: tempStr.data(using: .utf8)!)
                return data
            }catch {
                throw error
            }
        }
        throw NSError(domain: "获取快手房间信息失败", code: -10000, userInfo: ["desc": "获取快手房间信息失败"])
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        return LiveState(rawValue: try await getLiveLastestInfo(roomId: roomId, userId: userId).liveState ?? LiveState.unknow.rawValue)!
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        //https://live.kuaishou.com/u/ccyoutai
        var roomId = ""
        var realUrl = ""
        if shareCode.contains("live.kuaishou.com/u") { //长链接
            // 定义正则表达式模式
            let pattern = #"/u/([a-zA-Z0-9]+)"#
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsString = shareCode as NSString
                let results = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsString.length))
                if let match = results.first {
                    // 提取匹配到的值
                    let id = nsString.substring(with: match.range(at: 1))
                    return try await KuaiShou.getLiveLastestInfo(roomId: id, userId: nil)
                } else {
                    throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
                }
            } catch let error {
                throw error
            }
        }else {
            roomId = shareCode
        }
        if roomId == "" {
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }
        return try await KuaiShou.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        ([:],[:])
    }
}
