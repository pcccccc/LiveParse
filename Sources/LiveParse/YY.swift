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

struct YYRoomResponse: Codable {
    let code: Int
    let message: String
    let data: [YYRoomSection]
}

struct YYRoomSection: Codable {
    let id: Int
    let name: String
    let data: [YYRoomListData]
}

struct YYRoomListData: Codable {
    let uid: Int
    let sid: Int
    let name: String
    let desc: String
    let avatar: String
    let users: Int
    let img: String
}

public struct YY: LiveParse {
    
    fileprivate static let headers = [
        "user-agent": " Platform/iOS17.5.1 APP/yymip8.40.0 Model/iPhone Browerser:Default Scale/3.00 YY(ClientVersion:8.40.0 ClientEdition:yymip) HostName/yy HostVersion/8.40.0 HostId/1 UnionVersion/2.690.0 Build1492 HostExtendInfo/b576b278cba95c5100f84a69b26dc36bf44f080608b937825dcd64ee5911351f74dbda4ac85cfb011f32eb00b7c16ecc6bad4eaa3cd9f69c923177e74f6212682492886a946abdcf921a84c93ff329d4fd9e2bc67f5fe727d9a7b10ee65fbbbf",
        "accept-language": "zh-Hans-CN;q=1",
        "accept-encoding": "gzip, deflate, br, zstd",
        "content-type": "application/json; charset=utf-8",
        "Accept": "application/json"
    ]
    

    struct YYCategoryRoot: Codable {
        let code: Int
        let message: String
        let data: [YYCategoryList]
    }

    struct YYCategoryList: Codable {
        let id: Int
        let name: String
        let platform: Int
        let biz: String
        let sort: Int
        let selected: Int
        let url: String?
        let pic: String?
        let darkPic: String?
        let serv: Int
        let navs: [YYCategorySubList]
        let icon: Int?
    }

    // MARK: - Nav
    struct YYCategorySubList: Codable {
        let id: Int
        let name: String
        let platform: Int
        let biz: String
        let sort: Int
        let selected: Int
        let serv: Int
        let navs: [YYCategorySubList]
    }

    
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        let dataReq = try await AF.request("https://rubiks-idx.yy.com/navs", method: .get, headers: HTTPHeaders(headers)).serializingDecodable( YYCategoryRoot.self).value
        var categoryList = [LiveMainListModel]()
        for item in dataReq.data {
            if item.name == "附近" { //去掉附近选项
                continue
            }
            var subList = [LiveCategoryModel]()
            for subItem in item.navs {
                subList.append(.init(id: "\(subItem.id)", parentId: "item.id", title: subItem.name, icon: "", biz: subItem.biz ?? ""))
            }
            if item.navs.count == 0 { //处理热门等没有子菜单的
                subList.append(.init(id: "0", parentId: "\(item.id)", title: item.name, icon: "", biz: "idx"))
            }
            categoryList.append(.init(id: "\(item.id)", title: item.name, icon: "", biz: item.biz ?? "", subList: subList))
        }
        return categoryList
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        do {
            let url = id == "index" ? "https://yyapp-idx.yy.com/mobyy/nav/\(id)/\(parentId ?? "")" : "https://rubiks-idx.yy.com/nav/\(id)/\(parentId)"
            let dataReq = try await AF.request(
                url,
                method: .get,
                headers: HTTPHeaders(headers)
            ).serializingDecodable(YYRoomResponse.self).value
            var tempArray = [LiveModel]()
            for item in dataReq.data {
                if item.name.contains("预告") { //去掉直播预告相关内容
                    continue
                }
                for realItem in item.data {
                    tempArray.append(LiveModel(userName: realItem.name, roomTitle: realItem.desc, roomCover: realItem.img, userHeadImg: realItem.avatar, liveType: .yy, liveState: "1", userId: "\(realItem.uid)", roomId: "\(realItem.sid)", liveWatchedCount: "\(realItem.users)"))
                }
            }
            return tempArray
        }catch {
            print(error)
        
            let url = id == "index" ? "https://yyapp-idx.yy.com/mobyy/nav/\(id)/\(parentId ?? "")" : "https://rubiks-idx.yy.com/nav/\(id)/\(parentId)"
            let dataReq = try await AF.request(
                url,
                method: .get,
                headers: HTTPHeaders(headers)
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
