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

    struct YYRoomInfoMain: Codable {
        let resultCode: Int
        let data: YYRoomInfo?
    }

    struct YYRoomInfo: Codable {
        let type: Int
        let uid: Int
        let name: String
        let thumb2: String
        let desc: String
        let biz: String
        let users: Int
        let sid: Int
        let ssid: Int
        let pid: String
        let tag: String
        let tagStyle: String
        let tpl: String?
        let linkMic: Int
        let gameThumb: String
        let avatar: String
        let yyNum: Int
        let totalViewer: String
        let configId: Int
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
        let asid: String
        let liveOn: String
        let aliasName: String
        let yyid: Int
        let subscribe: String
        let dataType: Int
        let yynum: String
        let auth_state: String
        let headurl: String
        let ssid: String
        let subbiz: String
        let sid: String
        let uid: String
        let tpl: String?
        let stageName: String
        let name: String
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
    
    public static func getPlayArgs(roomId: String, userId: String? = "-1") async throws -> [LiveQualityModel] {
        return try await getRealPlayArgs(roomId: roomId)
    }
    
    public static func getRealPlayArgs(roomId: String, lineSeq: Int? = -1, gear: Int? = 4) async throws -> [LiveQualityModel] {
        let millis_13 = Int(Date().timeIntervalSince1970 * 1000)
        let millis_10 = Int(Date().timeIntervalSince1970)
        let params: [String: Any] = [
            "head": [
              "seq": millis_13,
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
              "send_time": millis_10,
              "line_seq": lineSeq,
              "gear": gear,
              "ssl": 1,
              "stream_format": 0
            ]
          ]
        let jsonData = try! JSONSerialization.data(withJSONObject: params, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let dataReq = try await AF.request(
            "https://stream-manager.yy.com/v3/channel/streams?uid=0&cid=\(roomId)&sid=\(roomId)&appid=0&sequence=\(millis_13)&encode=json",
            method: .post,
            encoding: JSONStringEncoding(jsonString),
            headers: [HTTPHeader(name: "content-type", value: "text/plain;charset=UTF-8"), HTTPHeader(name: "referer", value: "https://www.yy.com")]
        ).serializingData().value
        let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
        let jsonDict = json as! Dictionary<String, Any>
        var liveQuality =  [LiveQualityModel]()
        var realUrl = ""
        if let roomDict = jsonDict["avp_info_res"] as? Dictionary<String, Any> {
            if let stramLineList = roomDict["stream_line_list"] as? Dictionary<String, Any> {
                for key in stramLineList.keys {
                    if let lineDict = stramLineList[key] as? [String: Any] {
                        if let lineInfos = lineDict["line_infos"] as? [[String: Any]] {
                            for item in lineInfos {
                                var liveQuaityModel = LiveQualityModel(cdn: "\(item["line_print_name"] as? String ?? "")", yyLineSeq: "\(item["line_seq"] as? Int ?? 0)", qualitys: [])
                                if liveQuality.contains { $0.cdn == liveQuaityModel.cdn } == false {
                                    liveQuality.append(liveQuaityModel)
                                }
                            }
                        }
                    }
                }
            }
            if let lineAddr = roomDict["stream_line_addr"] as? Dictionary<String, Any> {
                for key in lineAddr.keys {
                    if let streamCdnInfo = lineAddr[key] as? Dictionary<String, Any> {
                        if let cdnInfo = streamCdnInfo["cdn_info"] as? Dictionary<String, Any> {
                            if let url = cdnInfo["url"] as? String {
                                realUrl = url
                            }
                        }
                    }
                }
            }
        }
        var liveQualityDetails = [LiveQualityDetail]()
        if let channelStreamInfo = jsonDict["channel_stream_info"] as? Dictionary<String, Any> {
            if let streams = channelStreamInfo["streams"] as? [[String: Any]] {
                for stream in streams {
                    if let streamJsonString = stream["json"] as? String {
                        let gearJson = try JSONSerialization.jsonObject(with: streamJsonString.data(using: .utf8)!, options: .mutableContainers)
                        let gearDict = gearJson as! Dictionary<String, Any>
                        if let gearInfo = gearDict["gear_info"] as? Dictionary<String, Any> {
                            let rate = gearInfo["gear"] as? Int ?? 0
                            var liveQualityDetail = LiveQualityDetail(roomId: roomId, title: gearInfo["name"] as? String ?? "", qn: rate, url: realUrl, liveCodeType: .flv, liveType: .yy)
                            if liveQualityDetails.contains { $0.title == liveQualityDetail.title } == false {
                                liveQualityDetails.append(liveQualityDetail)
                            }
                        }
                    }
                }
            }
        }
        var finalLiveQualitys = [LiveQualityModel]()
        for item in liveQuality {
            finalLiveQualitys.append(.init(cdn: item.cdn, yyLineSeq: item.yyLineSeq, qualitys: liveQualityDetails))
        }
        return finalLiveQualitys
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        let dataReq = try await AF.request("https://www.yy.com/apiSearch/doSearch.json?q=\(keyword)&t=1&n=\(page)").serializingDecodable(YYSearchMain.self).value
        var roomList = [LiveModel]()
        if let searchResp = dataReq.data.searchResult.response {
            for item in searchResp.one.docs {
                roomList.append(.init(userName: item.name, roomTitle: item.stageName, roomCover: item.headurl, userHeadImg: item.headurl, liveType: .yy, liveState: item.liveOn, userId: item.uid, roomId: item.sid, liveWatchedCount: "0"))
            }
        }
        return roomList
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let dataReq = try await AF.request("https://www.yy.com/api/liveInfoDetail/\(roomId)/\(roomId)/0").serializingDecodable(YYRoomInfoMain.self).value
        if let data = dataReq.data {
            return LiveModel(userName: data.name, roomTitle: data.desc, roomCover: data.gameThumb, userHeadImg: data.avatar, liveType: .yy, liveState: "1", userId: roomId, roomId: roomId, liveWatchedCount: "\(data.users)")
        }else {
            throw NSError(domain: "查询不到房间信息、可能是已经下播", code: -10000, userInfo: ["desc": "查询不到房间信息、可能是已经下播"])
        }
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        return LiveState(rawValue: try await getLiveLastestInfo(roomId: roomId, userId: userId).liveState ?? LiveState.unknow.rawValue)!
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        var roomId = ""
        var realUrl = ""
        if shareCode.contains("yy.com") {
            if shareCode.contains("sid") { //分享码
                // 定义正则表达式模式
                let pattern = "sid=(\\d+)"
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsString = shareCode as NSString
                    let results = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsString.length))
                    if let match = results.first {
                        // 提取匹配到的值
                        let id = nsString.substring(with: match.range(at: 1))
                        roomId = id
                    } else {
                        throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
                    }
                } catch let error {
                    throw error
                }
            }else { //长链接
                // 定义正则表达式模式
                let pattern = #"/([a-zA-Z0-9]+)/"#
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsString = shareCode as NSString
                    let results = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsString.length))
                    if let match = results.first {
                        // 提取匹配到的值
                        let id = nsString.substring(with: match.range(at: 1))
                        roomId = id
                    } else {
                        throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
                    }
                } catch let error {
                    throw error
                }
            }
        }else {
            roomId = shareCode
        }
        if roomId == "" {
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }
        return try await YY.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        ([:],[:])
    }
}

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
