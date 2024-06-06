//
//  NeteaseCC.swift
//
//
//  Created by pangchong on 2024/5/21.
//

import Alamofire
import Foundation

fileprivate let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Safari/605.1.15"

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
    //var wy: String? //好像不能打开
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


public struct NeteaseCC: LiveParse {
    

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "1", title: "网游", icon: "", subList: try await getCategorySubList(id: "1")),
            LiveMainListModel(id: "2", title: "单机", icon: "", subList: try await getCategorySubList(id: "2")),
            LiveMainListModel(id: "4", title: "竞技", icon: "", subList: try await getCategorySubList(id: "4")),
            LiveMainListModel(id: "5", title: "综艺", icon: "", subList: try await getCategorySubList(id: "5")),
        ]
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        let dataReq = try await AF.request(
            "https://api.cc.163.com/v1/wapcc/gamecategory",
            method: .get,
            parameters: [
                "catetype": id,
            ],
            headers: [
                "User-Agent": userAgent
            ]
        ).serializingDecodable(CCMainData<CCCategoryInfo>.self).value
        var tempArray: [LiveCategoryModel] = []
        for item in dataReq.data.category_info.game_list {
            tempArray.append(LiveCategoryModel(id: item.gametype, parentId: "", title: item.name, icon: item.cover))
        }
        return tempArray
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        let dataReq = try await AF.request(
            "https://cc.163.com/api/category/\(id)",
            method: .get,
            parameters: [
                "format": "json",
                "tag_id": "0",
                "start": (page - 1) * 20,
                "size": 20
            ],
            headers: [
                "User-Agent": userAgent
            ]
        ).serializingDecodable(CCRoomListModel.self).value
        var tempArray: [LiveModel] = []
        for item in dataReq.lives {
            tempArray.append(LiveModel(userName: item.nickname ?? "", roomTitle: item.title, roomCover: item.poster ?? item.adv_img ?? "", userHeadImg: item.portraiturl ?? item.purl ?? "", liveType: .cc, liveState: "1", userId: "\(item.channel_id ?? 0)", roomId: "\(item.cuteid ?? 0)", liveWatchedCount: "\(item.visitor ?? 0)"))
        }
        return tempArray
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        do {
            let dataReq = try await AF.request(
                "https://cc.163.com/live/channel/?channelids=\(userId ?? roomId)",
                method: .get,
                headers: [
                    "User-Agent": userAgent
                ]
            ).serializingDecodable(CCLastestRoomModel.self).value
            guard let item = dataReq.data.first else {
                throw LiveParseError.throwError("获取房间信息失败，请检查房间号等信息")
            }
            return LiveModel(userName: item.nickname ?? "", roomTitle: item.title, roomCover: item.poster ?? item.adv_img ?? "", userHeadImg: item.portraiturl ?? item.purl ?? "", liveType: .cc, liveState: "1", userId: "\(item.channel_id ?? 0)", roomId: "\(item.cuteid ?? 0)", liveWatchedCount: "\(item.visitor)")
        }catch {
            throw LiveParseError.throwError("获取房间信息失败，请检查房间号等信息")
        }
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        let dataReq = try await AF.request(
            "https://cc.163.com/live/channel/?channelids=\(userId ?? roomId)",
            method: .get,
            headers: [
                "User-Agent": userAgent
            ]
        ).serializingDecodable(CCLastestRoomModel.self).value
        var liveQuality: [LiveQualityModel] = []
        guard let allCdnArray = dataReq.data.first?.quickplay?.priority else {
            throw LiveParseError.throwError("获取房间线路失败,请检查房间号")
        }
        if let original = dataReq.data.first?.quickplay?.resolution?.original {
            var tempArray: [LiveQualityDetail] = []
            if let ali = original.cdn?.ali {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ali", qn: original.vbr ?? 0, url: ali, liveCodeType: .flv, liveType: .cc))
            }
            if let ks = original.cdn?.ks {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ks", qn: original.vbr ?? 0, url: ks, liveCodeType: .flv, liveType: .cc))
            }
            if let hs = original.cdn?.hs {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs", qn: original.vbr ?? 0, url: hs, liveCodeType: .flv, liveType: .cc))
            }
            if let hs2 = original.cdn?.hs2 {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs2", qn: original.vbr ?? 0, url: hs2, liveCodeType: .flv, liveType: .cc))
            }
            if let ws = original.cdn?.ws {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ws", qn: original.vbr ?? 0, url: ws, liveCodeType: .flv, liveType: .cc))
            }
            if let dn = original.cdn?.dn {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 dn", qn: original.vbr ?? 0, url: dn, liveCodeType: .flv, liveType: .cc))
            }
            if let xy = original.cdn?.xy {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 xy", qn: original.vbr ?? 0, url: xy, liveCodeType: .flv, liveType: .cc))
            }
            liveQuality.append(LiveQualityModel(cdn: "原画", qualitys: tempArray))
        }
        
        if let blueray = dataReq.data.first?.quickplay?.resolution?.blueray {
            var tempArray: [LiveQualityDetail] = []
            if let ali = blueray.cdn?.ali {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ali", qn: blueray.vbr ?? 0, url: ali, liveCodeType: .flv, liveType: .cc))
            }
            if let ks = blueray.cdn?.ks {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ks", qn: blueray.vbr ?? 0, url: ks, liveCodeType: .flv, liveType: .cc))
            }
            if let hs = blueray.cdn?.hs {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs", qn: blueray.vbr ?? 0, url: hs, liveCodeType: .flv, liveType: .cc))
            }
            if let hs2 = blueray.cdn?.hs2 {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs2", qn: blueray.vbr ?? 0, url: hs2, liveCodeType: .flv, liveType: .cc))
            }
            if let ws = blueray.cdn?.ws {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ws", qn: blueray.vbr ?? 0, url: ws, liveCodeType: .flv, liveType: .cc))
            }
            if let dn = blueray.cdn?.dn {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 dn", qn: blueray.vbr ?? 0, url: dn, liveCodeType: .flv, liveType: .cc))
            }
            if let xy = blueray.cdn?.xy {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 xy", qn: blueray.vbr ?? 0, url: xy, liveCodeType: .flv, liveType: .cc))
            }
            liveQuality.append(LiveQualityModel(cdn: "蓝光", qualitys: tempArray))
        }
        
        if let ultra = dataReq.data.first?.quickplay?.resolution?.ultra {
            var tempArray: [LiveQualityDetail] = []
            if let ali = ultra.cdn?.ali {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ali", qn: ultra.vbr ?? 0, url: ali, liveCodeType: .flv, liveType: .cc))
            }
            if let ks = ultra.cdn?.ks {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ks", qn: ultra.vbr ?? 0, url: ks, liveCodeType: .flv, liveType: .cc))
            }
            if let hs = ultra.cdn?.hs {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs", qn: ultra.vbr ?? 0, url: hs, liveCodeType: .flv, liveType: .cc))
            }
            if let hs2 = ultra.cdn?.hs2 {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs2", qn: ultra.vbr ?? 0, url: hs2, liveCodeType: .flv, liveType: .cc))
            }
            if let ws = ultra.cdn?.ws {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ws", qn: ultra.vbr ?? 0, url: ws, liveCodeType: .flv, liveType: .cc))
            }
            if let dn = ultra.cdn?.dn {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 dn", qn: ultra.vbr ?? 0, url: dn, liveCodeType: .flv, liveType: .cc))
            }
            if let xy = ultra.cdn?.xy {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 xy", qn: ultra.vbr ?? 0, url: xy, liveCodeType: .flv, liveType: .cc))
            }
            liveQuality.append(LiveQualityModel(cdn: "超清", qualitys: tempArray))
        }
        
        if let high = dataReq.data.first?.quickplay?.resolution?.high {
            var tempArray: [LiveQualityDetail] = []
            if let ali = high.cdn?.ali {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ali", qn: high.vbr ?? 0, url: ali, liveCodeType: .flv, liveType: .cc))
            }
            if let ks = high.cdn?.ks {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ks", qn: high.vbr ?? 0, url: ks, liveCodeType: .flv, liveType: .cc))
            }
            if let hs = high.cdn?.hs {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs", qn: high.vbr ?? 0, url: hs, liveCodeType: .flv, liveType: .cc))
            }
            if let hs2 = high.cdn?.hs2 {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs2", qn: high.vbr ?? 0, url: hs2, liveCodeType: .flv, liveType: .cc))
            }
            if let ws = high.cdn?.ws {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ws", qn: high.vbr ?? 0, url: ws, liveCodeType: .flv, liveType: .cc))
            }
            if let dn = high.cdn?.dn {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 dn", qn: high.vbr ?? 0, url: dn, liveCodeType: .flv, liveType: .cc))
            }
            if let xy = high.cdn?.xy {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 xy", qn: high.vbr ?? 0, url: xy, liveCodeType: .flv, liveType: .cc))
            }
            liveQuality.append(LiveQualityModel(cdn: "高清", qualitys: tempArray))
        }
        
        if let standard = dataReq.data.first?.quickplay?.resolution?.standard {
            var tempArray: [LiveQualityDetail] = []
            if let ali = standard.cdn?.ali {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ali", qn: standard.vbr ?? 0, url: ali, liveCodeType: .flv, liveType: .cc))
            }
            if let ks = standard.cdn?.ks {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ks", qn: standard.vbr ?? 0, url: ks, liveCodeType: .flv, liveType: .cc))
            }
            if let hs = standard.cdn?.hs {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs", qn: standard.vbr ?? 0, url: hs, liveCodeType: .flv, liveType: .cc))
            }
            if let hs2 = standard.cdn?.hs2 {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs2", qn: standard.vbr ?? 0, url: hs2, liveCodeType: .flv, liveType: .cc))
            }
            if let ws = standard.cdn?.ws {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ws", qn: standard.vbr ?? 0, url: ws, liveCodeType: .flv, liveType: .cc))
            }
            if let dn = standard.cdn?.dn {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 dn", qn: standard.vbr ?? 0, url: dn, liveCodeType: .flv, liveType: .cc))
            }
            if let xy = standard.cdn?.xy {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 xy", qn: standard.vbr ?? 0, url: xy, liveCodeType: .flv, liveType: .cc))
            }
            liveQuality.append(LiveQualityModel(cdn: "标清", qualitys: tempArray))
        }
        
        if let medium = dataReq.data.first?.quickplay?.resolution?.medium {
            var tempArray: [LiveQualityDetail] = []
            if let ali = medium.cdn?.ali {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ali", qn: medium.vbr ?? 0, url: ali, liveCodeType: .flv, liveType: .cc))
            }
            if let ks = medium.cdn?.ks {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ks", qn: medium.vbr ?? 0, url: ks, liveCodeType: .flv, liveType: .cc))
            }
            if let hs = medium.cdn?.hs {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs", qn: medium.vbr ?? 0, url: hs, liveCodeType: .flv, liveType: .cc))
            }
            if let hs2 = medium.cdn?.hs2 {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 hs2", qn: medium.vbr ?? 0, url: hs2, liveCodeType: .flv, liveType: .cc))
            }
            if let ws = medium.cdn?.ws {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 ws", qn: medium.vbr ?? 0, url: ws, liveCodeType: .flv, liveType: .cc))
            }
            if let dn = medium.cdn?.dn {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 dn", qn: medium.vbr ?? 0, url: dn, liveCodeType: .flv, liveType: .cc))
            }
            if let xy = medium.cdn?.xy {
                tempArray.append(LiveQualityDetail(roomId: userId ?? roomId, title: "线路 xy", qn: medium.vbr ?? 0, url: xy, liveCodeType: .flv, liveType: .cc))
            }
            liveQuality.append(LiveQualityModel(cdn: "标清", qualitys: tempArray))
        }
        return liveQuality
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        let dataReq = try await AF.request(
            "https://cc.163.com/search/anchor",
            method: .get,
            parameters: [
                "query": keyword,
                "page": page,
                "size": 20
            ],
            headers: [
                "User-Agent": userAgent
            ]
        ).serializingDecodable(CCLiveSearchResult.self).value
        var tempArray: [LiveModel] = []
        let roomList = dataReq.webcc_anchor.result
        for item in roomList {
            tempArray.append(LiveModel(userName: item.nickname ?? "", roomTitle: item.title, roomCover: item.poster ?? item.adv_img ?? "", userHeadImg: item.portraiturl ?? item.purl ?? "", liveType: .cc, liveState: "1", userId: "\(item.channel_id ?? 0)", roomId: "\(item.cuteid ?? 0)", liveWatchedCount: "\(item.visitor)"))
        }
        return tempArray
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        return LiveState(rawValue: try await getLiveLastestInfo(roomId: roomId, userId: userId).liveState ?? "3")!
    }
    
    static func getPropertyNames<T: Codable>(of type: T.Type) -> [String] {
        // 创建一个默认实例
        guard let instance = try? JSONDecoder().decode(T.self, from: Data("{}".utf8)) else {
            return []
        }
        
        let mirror = Mirror(reflecting: instance)
        return mirror.children.compactMap { $0.label }
    }
    

    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        var roomId = ""
        var realUrl = ""
        if shareCode.contains("cc.163.com") { //长链接
            // 定义正则表达式模式
            let pattern = #"https://h5\.cc\.163\.com/cc/(\d+)\?rid=(\d+)&cid=(\d+)"#
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsString = shareCode as NSString
                let results = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first {
                    // 提取匹配到的值
                    let id = nsString.substring(with: match.range(at: 1))
                    let rid = nsString.substring(with: match.range(at: 2))
                    let cid = nsString.substring(with: match.range(at: 3))
                    return try await NeteaseCC.getLiveLastestInfo(roomId: id, userId: cid)
                } else {
                    print("No match found")
                }
            } catch let error {
                print("Invalid regex: \(error.localizedDescription)")
            }
        }else {
            roomId = shareCode
        }

        if roomId == "" || Int(roomId) ?? -1 < 0 {
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }
        
        return try await NeteaseCC.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    static func getDanmukuArgs(roomId: String) async throws -> ([String : String], [String : String]?) {
        return ([:], [:])
    }
}
