//
//  YY.swift
//
//
//  Created by pangchong on 2024/6/6.
//

import Foundation
import Alamofire

struct YYCategoryResponse: Codable {
    let data: [YYCategoryListModel]
    let result: String
}

struct YYCategoryListModel: Codable {
    let cover: String
    let desc: String
    let icon: String
    let id: Int
    let label: String
    let operateTime: String
    let `operator`: Int
    let parentId: Int
    let priority: Int
    let title: String
    let url: String
    let visible: Int
}


public struct YY: LiveParse {
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "1", title: "娱乐", icon: "", subList: try await getCategorySubList(id: "1")),
            LiveMainListModel(id: "2", title: "游戏", icon: "", subList: try await getCategorySubList(id: "2")),
            LiveMainListModel(id: "3", title: "其他", icon: "", subList: try await getCategorySubList(id: "3")),
        ]
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        var tempArray: [LiveCategoryModel] = []
        let dataReq = try await AF.request(
            "https://www.yy.com/c/yycom/category/getCategory.action",
            method: .get,
            parameters: [
                "parentId": id,
            ]
        ).serializingDecodable(YYCategoryResponse.self).value
        if dataReq.result == "0" {
            for item in dataReq.data {
                tempArray.append(LiveCategoryModel(id: "\(item.id)", parentId: id, title: item.title, icon: item.cover))
            }
        }
        return tempArray
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
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
        for item in dataReq.data.list {
            tempArray.append(LiveModel(userName: item.author.name, roomTitle: item.caption, roomCover: item.poster, userHeadImg: item.author.avatar, liveType: .ks, liveState: "1", userId: item.author.id, roomId: item.author.id, liveWatchedCount: item.watchingCount))
        }
        return tempArray
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        let dataReq = try await getKSLiveRoom(roomId: roomId)
        var liveQuaityModel = LiveQualityModel(cdn: "线路1", douyuCdnName: "", qualitys: [])
        if let playList = dataReq.liveroom.playList?.first?.liveStream.playUrls?.first?.adaptationSet.representation {
            for item in playList {
                liveQuaityModel.qualitys.append(.init(roomId: roomId, title: roomId, qn: item.bitrate, url: item.url, liveCodeType: .flv, liveType: .ks))
            }
        }
        return [liveQuaityModel]
    }
    
    static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        []
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let dataReq = try await getKSLiveRoom(roomId: roomId)
        return LiveModel(userName: dataReq.liveroom.playList?.first?.author.name ?? "", roomTitle: dataReq.liveroom.playList?.first?.author.name ?? "", roomCover: dataReq.liveroom.playList?.first?.liveStream.poster ?? "", userHeadImg: dataReq.liveroom.playList?.first?.author.avatar ?? "", liveType: .ks, liveState: dataReq.liveroom.playList?.first?.liveStream.playUrls?.count ?? 0 > 0 ? LiveState.live.rawValue : LiveState.close.rawValue, userId: "", roomId: roomId, liveWatchedCount: "")
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
    
    static func getDanmukuArgs(roomId: String) async throws -> ([String : String], [String : String]?) {
        ([:],[:])
    }
}
