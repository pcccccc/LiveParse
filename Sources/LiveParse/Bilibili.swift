//
//  Bilibili.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/7/4.
//

import Foundation
import Alamofire
import Foundation
import CommonCrypto
import SwiftyJSON

public struct BiliBiliCookie {
    public static var cookie = UserDefaults.standard.value(forKey: "LiveParse.Bilibili.Cookie") as? String ?? "" {
        didSet {
            UserDefaults.standard.setValue(cookie, forKey: "LiveParse.Bilibili.Cookie")
        }
    }
    public static var uid = UserDefaults.standard.value(forKey: "LiveParse.Bilibili.uid") as? String ?? "0" {
        didSet {
            UserDefaults.standard.setValue(uid, forKey: "LiveParse.Bilibili.uid")
        }
    }
}

struct BilibiliMainData<T: Codable>: Codable {
    var code: Int
    var msg: String
    var data: T
    
    enum CodingKeys: String, CodingKey {
        case code
        case msg = "message"
        case data
    }
}

struct BilibiliMainListModel: Codable {
    let id: Int
    let name: String
    let list: Array<BilibiliCategoryModel>?
}

struct BilibiliCategoryModel: Codable {
    let id: String
    let parent_id: String
    let old_area_id: String
    let name: String
    let act_id: String
    let pk_status: String
    let hot_status: Int
    let lock_status: String
    let pic: String
    let parent_name: String
    let area_type: Int
}


struct BiliBiliCategoryRoomMainModel: Codable {
    let banner: Array<BiliBiliCategoryBannerModel>?
    let list: Array<BiliBiliCategoryListModel>?
}

struct BiliBiliCategoryBannerModel: Codable {
    let id: Int
    let title: String
    let location: String
    let position: Int
    let pic: String
    let link: String
    let weight: Int
    let room_id: Int
    let up_id: Int
    let parent_area_id: Int
    let area_id: Int
    let live_status: Int
    let av_id: Int
    let is_ad: Bool
}

struct BiliBiliCategoryListModel: Codable {
    let roomid: Int
    let uid: Int
    let title: String?
    let uname: String
    let online: Int?
    let user_cover: String?
    let user_cover_flag: Int?
    let system_cover: String?
    let cover: String?
    let show_cover: String?
    let link: String?
    let face: String?
    let uface: String?
    let parent_id: Int?
    let parent_name: String?
    let area_id: Int?
    let area_name: String?
    let area_v2_parent_id: Int?
    let area_v2_parent_name: String?
    let area_v2_id: Int?
    let area_v2_name: String?
    let session_id: String?
    let group_id: Int?
    let show_callback: String?
    let click_callback: String?
    let live_status: Int?
    let attentions: Int?
    let cate_name: String?
    //    let verify: BiliBiliVerifyModel?
    let watched_show: BiliBiliWatchedShowModel?
}

struct BiliBiliVerifyModel: Codable {
    let role: Int?
    let desc: String?
    let type: Int?
}

struct BiliBiliWatchedShowModel: Codable {
    
    let the_switch: Bool?
    let num: Int?
    let text_small: String?
    let text_large: String?
    let icon: String?
    let icon_location: Int?
    let icon_web: String?
    
    private enum CodingKeys: String, CodingKey {
        case the_switch = "switch"
        case num
        case text_small
        case text_large
        case icon
        case icon_location
        case icon_web
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.the_switch = try container.decodeIfPresent(Bool.self, forKey: .the_switch)
        self.num = try container.decodeIfPresent(Int.self, forKey: .num)
        self.text_small = try container.decodeIfPresent(String.self, forKey: .text_small)
        self.text_large = try container.decodeIfPresent(String.self, forKey: .text_large)
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        // icon_location首先尝试解码 Int
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .icon_location) {
            icon_location = intValue
        // 如果 Int 解码失败，则尝试解码 String，然后将其转换为 Int
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .icon_location), let intValue = Int(stringValue) {
            icon_location = intValue
        } else {
            icon_location = nil
        }
        self.icon_web = try container.decodeIfPresent(String.self, forKey: .icon_web)
    }
}


struct BiliBiliQualityModel: Codable {
    let current_qn: Int
    let quality_description: Array<BiliBiliQualityDetailModel>?
    //    let durl: Array<BilibiliPlayInfoModel>?
}

struct BiliBiliQualityDetailModel: Codable {
    let qn: Int
    let desc: String
}


struct BiliBiliPlayURLInfoMain: Codable {
    var playurl_info: BiliBiliPlayURLPlayURLInfo
    
    //    var room_id: Int
}

struct BiliBiliPlayURLPlayURLInfo: Codable {
    var playurl: BiliBiliPlayURLPlayURL
    var conf_json: String
}

struct BiliBiliPlayURLPlayURL: Codable {
    var stream: Array<BiliBiliPlayURLStreamInfo>
}

struct BiliBiliPlayURLStreamInfo: Codable {
    var protocol_name: String
    var format: Array<BiliBiliPlayURLFormatInfo>
}

struct BiliBiliPlayURLFormatInfo: Codable {
    var format_name: String
    var codec: Array<BiliBiliPlayURLCodeCInfo>
}


struct BiliBiliPlayURLCodeCInfo: Codable {
    var codec_name: String
    var base_url: String
    var url_info: Array<BilibiliPlayInfoModel>
}

struct BilibiliPlayInfoModel: Codable {
    let host: String
    let extra: String
}

public struct BilibiliQRMainModel: Codable {
    public let code: Int
    public let message: String
    public let ttl: Int
    public let data: BilibiliQRMainData
}

public struct BilibiliQRMainData: Codable {
    public let url: String?
    public let qrcode_key: String?
    public let refresh_token: String?
    public let timestamp: Int?
    public let code: Int?
    public let message: String?
}

struct BilibiliBuvidModel: Codable {
    let b_3: String
    let b_4: String
}

public struct BilibiliDanmuModel: Codable {
    let group: String
    let business_id: Int
    let refresh_row_factor: Double
    let refresh_rate: Int
    let max_delay: Int
    let token: String
    let host_list: Array<BilibiliDanmuServerInfo>
}

struct BilibiliDanmuServerInfo: Codable {
    let host: String
    let port: Int
    let wss_port: Int
    let ws_port: Int
}

struct BilibiliSearchMainData: Codable {
    var code: Int
    var msg: String
    var data: BilibiliSearchResultData?
    
    enum CodingKeys: String, CodingKey {
        case code
        case msg = "message"
        case data
    }
}

struct BilibiliSearchResultData: Codable {
    let result: BilibiliSearchResultMain?
}

struct BilibiliSearchResultMain: Codable {
    let live_room: Array<BiliBiliCategoryListModel>?
    let live_user: Array<BiliBiliCategoryListModel>?
}

struct BilibiliRoomInfoData: Codable {
    let room_info: BilibiliRoomInfoModel
    let anchor_info: BilibiliRoomAnchorInfo
    let watched_show: BiliBiliWatchedShowModel?
}

struct BilibiliRoomInfoModel: Codable {
    let uid: Int
    let room_id: Int
    let title: String
    let cover: String
    let live_status: Int
}

struct BilibiliRoomAnchorInfo: Codable {
    let base_info: BilibiliRoomAnchorBaseInfo
}

struct BilibiliRoomAnchorBaseInfo: Codable {
    let uname: String
    let face: String
}

public struct Bilibili: LiveParse {

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        do {
            let dataReq = try await AF.request("https://api.live.bilibili.com/room/v1/Area/getList", method: .get).serializingDecodable(BilibiliMainData<[BilibiliMainListModel]>.self).value
            var tempArray: [LiveMainListModel] = []
            for item in dataReq.data {
                var subList: [LiveCategoryModel] = []
                guard let subCategoryList = item.list else {
                    continue
                }
                for subItem in subCategoryList {
                    subList.append(.init(id: subItem.id, parentId: subItem.parent_id, title: subItem.name, icon: subItem.pic))
                }
                tempArray.append(.init(id: "\(item.id)", title: item.name, icon: "", subList: subList))
            }
            return tempArray
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
//    ?platform=web&parent_area_id=2&area_id=0&sort_type=sort_type_124&page=3&web_location=444.43&w_rid=d83b3b7a86f542d77171a87b69ea93e6&wts=1743988984
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        do {
            let query = try await Bilibili.biliWbiSign(param: "area_id=\(id)&page=\(page)&parent_area_id=\(parentId ?? "")&platform=web&sort_type=&vajra_business_key=&web_location=444.43") ?? ""
            let dataReq = try await AF.request(
                "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?\(query)",
                method: .get,
                headers: [
                    "user-agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
//                    "cookie": BiliBiliCookie.cookie,
                    "referer": "https://live.bilibili.com/"
                ]
            ).serializingDecodable(BilibiliMainData<BiliBiliCategoryRoomMainModel>.self).value
            if let listModelArray = dataReq.data.list {
                var tempArray: Array<LiveModel> = []
                for item in listModelArray {
                    tempArray.append(LiveModel(userName: item.uname, roomTitle: item.title ?? "", roomCover: item.cover ?? "", userHeadImg: item.face ?? "", liveType: .bilibili, liveState: "", userId: "\(item.uid)", roomId: "\(item.roomid)", liveWatchedCount: item.watched_show?.text_small ?? ""))
                }
                return tempArray
            }else {
                
                throw
                LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\("请求B站直播间列表失败,返回的列表为空")")
            }
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        do {
            let dataReq = try await AF.request(
                "https://api.live.bilibili.com/room/v1/Room/playUrl",
                method: .get,
                parameters: [
                    "platform": "web",
                    "cid": roomId,
                    "qn": ""
                ],
                headers: BiliBiliCookie.cookie == "" ? nil : [
                    "cookie": BiliBiliCookie.cookie,
                ]
            ).serializingDecodable(BilibiliMainData<BiliBiliQualityModel>.self).value
            var liveQualitys: [LiveQualityDetail] = []
            var hostArray: [String] = []
            if let qualityDescription = dataReq.data.quality_description {
                for item in qualityDescription {
                    let dataReq = try await AF.request(
                        "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
                        method: .get,
                        parameters: [
                            "platform": "h5",
                            "room_id": roomId,
                            "qn": item.qn,
                            "protocol": "0,1",
                            "format": "0,1,2",
                            "codec": "0",
                            "mask": "0"
                        ],
                        headers: BiliBiliCookie.cookie == "" ? nil : [
                            "cookie": BiliBiliCookie.cookie
                        ]
                    ).serializingDecodable(BilibiliMainData<BiliBiliPlayURLInfoMain>.self).value
                    for streamInfo in dataReq.data.playurl_info.playurl.stream {
                        if streamInfo.protocol_name == "http_hls" || streamInfo.protocol_name == "http_stream" {
                            if hostArray.contains((streamInfo.format.last?.codec.last?.url_info.last?.host ?? "")) == false {
                                hostArray.append((streamInfo.format.last?.codec.last?.url_info.last?.host ?? ""))
                            }
                            let url = (streamInfo.format.last?.codec.last?.url_info.last?.host ?? "") + (streamInfo.format.last?.codec.last?.base_url ?? "") + (streamInfo.format.last?.codec.last?.url_info.last?.extra ?? "")
                            liveQualitys.append(.init(roomId: roomId, title: item.desc, qn: item.qn, url: url, liveCodeType: streamInfo.protocol_name == "http_hls" ? .hls : .flv, liveType: .bilibili))
                        }
                    }
                }
                var tempArray: [LiveQualityModel] = []
                for i in 0..<hostArray.count {
                    let host = hostArray[i]
                    var qualitys: [LiveQualityDetail] = []
                    for item in liveQualitys {
                        if item.url.contains(host) == true {
                            qualitys.append(item)
                        }
                    }
                    tempArray.append(LiveQualityModel(cdn: "线路 \(i + 1)", qualitys: qualitys))
                }
                return tempArray
            }else {
                let dataReq = try await AF.request(
                    "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
                    method: .get,
                    parameters: [
                        "platform": "h5",
                        "room_id": roomId,
                        "qn": "1500",
                        "protocol": "0,1",
                        "format": "0,2",
                        "codec": "0,1",
                        "mask": "0"
                    ],
                    headers: BiliBiliCookie.cookie == "" ? nil : [
                        "cookie": BiliBiliCookie.cookie
                    ]
                ).serializingDecodable(BilibiliMainData<BiliBiliPlayURLInfoMain>.self).value
                for streamInfo in dataReq.data.playurl_info.playurl.stream {
                    if streamInfo.protocol_name == "http_hls" || streamInfo.protocol_name == "http_stream" {
                        if hostArray.contains((streamInfo.format.last?.codec.last?.url_info.last?.host ?? "")) == false {
                            hostArray.append((streamInfo.format.last?.codec.last?.url_info.last?.host ?? ""))
                        }
                        let url = (streamInfo.format.last?.codec.last?.url_info.last?.host ?? "") + (streamInfo.format.last?.codec.last?.base_url ?? "") + (streamInfo.format.last?.codec.last?.url_info.last?.extra ?? "")
                        liveQualitys.append(.init(roomId: roomId, title: "默认", qn: 1500, url: url, liveCodeType: streamInfo.protocol_name == "http_hls" ? .hls : .flv, liveType: .bilibili))
                    }
                }
                var tempArray: [LiveQualityModel] = []
                for i in 0..<hostArray.count {
                    let host = hostArray[i]
                    var qualitys: [LiveQualityDetail] = []
                    for item in liveQualitys {
                        if item.url.contains(host) == true {
                            qualitys.append(item)
                        }
                    }
                    tempArray.append(LiveQualityModel(cdn: "线路 \(i + 1)", qualitys: qualitys))
                }
                return tempArray
            }
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\("B站直播流解析失败，解析后的数据为空")")
        } catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        do {
            let dataReq = try await AF.request(
                "https://api.live.bilibili.com/xlive/web-room/v1/index/getH5InfoByRoom",
                parameters: [
                    "room_id": roomId
                ]
            ).serializingDecodable(BilibiliMainData<BilibiliRoomInfoData>.self).value
            var liveStatus = LiveState.unknow.rawValue
            switch dataReq.data.room_info.live_status {
            case 0:
                liveStatus = LiveState.close.rawValue
            case 1:
                liveStatus = LiveState.live.rawValue
            case 2:
                liveStatus = LiveState.close.rawValue
            default:
                liveStatus = LiveState.unknow.rawValue
            }
            var realRoomId = roomId
            if roomId != "\(dataReq.data.room_info.room_id)" { //如果两个RoomId不想等，用服务器返回的真实ID
                realRoomId = "\(dataReq.data.room_info.room_id)"
            }
            return LiveModel(userName: dataReq.data.anchor_info.base_info.uname, roomTitle: dataReq.data.room_info.title, roomCover: dataReq.data.room_info.cover, userHeadImg: dataReq.data.anchor_info.base_info.face, liveType: .bilibili, liveState: liveStatus, userId: "\(dataReq.data.room_info.uid)", roomId: realRoomId, liveWatchedCount: dataReq.data.watched_show?.text_small ?? "")
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        do {
            let dataReq = try await AF.request(
                "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live&cover_type=user_cover",
                method: .get,
                parameters: [
                    "order": "",
                    "keyword": keyword,
                    "category_id": "",
                    "__refresh__": "",
                    "_extra": "",
                    "highlight": 0,
                    "single_column": 0,
                    "page": page
                ],
                headers: BiliBiliCookie.cookie == "" ?
                ["cookie": "buvid3=infoc"] :
                    ["cookie": BiliBiliCookie.cookie]
            ).serializingDecodable(BilibiliSearchMainData.self).value
            
            var tempArray: Array<LiveModel> = []
            for item in dataReq.data?.result?.live_room ?? [] {
                tempArray.append(LiveModel(userName: item.uname, roomTitle: item.title ?? "", roomCover: "https:\(item.cover ?? "")", userHeadImg: "https:\(item.uface ?? "")", liveType: .bilibili, liveState: Bilibili.getBilibiliLiveStateString(liveState: item.live_status ?? 0).rawValue, userId: "\(item.uid)", roomId: "\(item.roomid)", liveWatchedCount: item.watched_show?.text_small ?? ""))
            }
            for item in dataReq.data?.result?.live_user ?? [] {
                let flowCount = item.attentions ?? 0
                var flowFormatString = ""
                if flowCount > 10000 {
                    flowFormatString = String(format: "%.2f 万人关注直播间", Float(flowCount) / 10000.0)
                }else {
                    flowFormatString = "\(flowCount) 人关注直播间"
                }
                let userName = String.stripHTML(from: item.uname)
                tempArray.append(LiveModel(userName: userName, roomTitle: item.title ?? "\(item.cate_name ?? "无分区") · \(flowFormatString)", roomCover: "https:\(item.uface ?? "")", userHeadImg: "https:\(item.uface ?? "")", liveType: .bilibili, liveState: Bilibili.getBilibiliLiveStateString(liveState: item.live_status ?? 0).rawValue, userId: "\(item.uid)", roomId: "\(item.roomid)", liveWatchedCount: flowFormatString))
            }
            return tempArray
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        do {
            let dataReq = try await AF.request(
                "https://api.live.bilibili.com/room/v1/Room/get_info",
                method: .get,
                parameters: [
                    "room_id": roomId
                ],
                headers: BiliBiliCookie.cookie == "" ? nil : [
                    "cookie": BiliBiliCookie.cookie
                ]
            ).serializingData().value
            let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
            let jsonDict = json as! Dictionary<String, Any>
            let dataDict = jsonDict["data"] as! Dictionary<String, Any>
            let liveStatus = dataDict["live_status"] as? Int ?? -1
            switch liveStatus {
            case 0:
                return .close
            case 1:
                return .live
            case 2:
                return .close
            default:
                return .unknow
            }
        }catch {
            throw LiveParseError.liveStateParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        do {
            var roomId = ""
            var realUrl = ""
            if shareCode.contains("b23.tv") { //短链接
                let url = shareCode.getUrlStringWithShareCode()
                let dataReq = await AF.request(url, headers: BiliBiliCookie.cookie == "" ? nil : [
                    "cookie": BiliBiliCookie.cookie
                ]).serializingData().response
                realUrl = dataReq.response?.url?.absoluteString ?? ""
                
            }else if shareCode.contains("live.bilibili.com") { //长链接
                realUrl = shareCode
            }else { //默认为房间号处理
                roomId = shareCode
            }
            if roomId == "" { //如果不是房间号，就解析链接中的房间号
                let pattern = "https://live\\.bilibili\\.com/(\\d+)"
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let nsString = realUrl as NSString
                    let results = regex.matches(in: realUrl, range: NSRange(location: 0, length: nsString.length))
                    if let match = results.first {
                        let range = match.range(at: 1) // 第1个捕获组
                        let numberString = nsString.substring(with: range)
                        roomId = numberString
                    } else {
                        roomId = ""
                    }
                } catch {
                    roomId = ""
                }
            }
            if roomId == "" || Int(roomId) ?? -1 < 0 {
                throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\("解析房间号失败，请检查分享码/分享链接是否正确")")
            }
            return try await Bilibili.getLiveLastestInfo(roomId: roomId, userId: nil)
        }catch {
            throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getQRCodeUrl() async throws -> BilibiliQRMainModel {
        let dataReq = try await AF.request(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/generate",
            method: .get
        ).serializingDecodable(BilibiliQRMainModel.self).value
        return dataReq
    }
    
    public static func getQRCodeState(qrcode_key: String) async throws -> (BilibiliQRMainModel, String) {
        let resp = AF.request(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
            method: .get,
            parameters: [
                "qrcode_key": qrcode_key
            ]
        )
        
        let dataReq = try await resp.serializingDecodable(BilibiliQRMainModel.self).value
        if dataReq.data.code == 0 {
            BiliBiliCookie.cookie = resp.response?.headers["Set-Cookie"] ?? ""
            if let respUrl = dataReq.data.url {
                let pattern = "DedeUserID=(\\d+)"
                    do {
                        let regex = try NSRegularExpression(pattern: pattern, options: [])
                        let nsString = respUrl as NSString
                        let results = regex.matches(in: respUrl, options: [], range: NSRange(location: 0, length: nsString.length))
                        
                        // 检查是否有匹配结果，并返回第一个匹配的DedeUserID值
                        if let match = results.first {
                            let range = match.range(at: 1) // 获取第一个捕获组的范围
                            BiliBiliCookie.uid = nsString.substring(with: range)
                        }
                    } catch let error {
                        print("Invalid regex: \(error.localizedDescription)")
                    }
                
            }
            return (dataReq, resp.response?.headers["Set-Cookie"] ?? "")
        }
        return (dataReq, "")
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        do {
            let buvid = try await getBuvid()
            let resp = try await getRoomDanmuDetail(roomId: roomId)
            return (["roomId": roomId, "buvid": buvid, "token": resp.token, "ws_url": "wss://\(resp.host_list.first?.host ?? "broadcastlv.chat.bilibili.com")/sub"], nil)
        }catch {
            throw LiveParseError.danmuArgsParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getBuvid() async throws -> String {
        do {
            let cookie = BiliBiliCookie.cookie
            if NSString(string: cookie).contains("buvid3") {
                let regex = try NSRegularExpression(pattern: "buvid3=(.*?);", options: [])
                let matchs =  regex.matches(in: cookie, range: NSRange(location: 0, length: cookie.count))
                for match in matchs {
                    let matchRange = Range(match.range, in: cookie)!
                    let matchedSubstring = cookie[matchRange]
                    return "\(matchedSubstring)"
                }
            }else {
                let dataReq = try await AF.request(
                    "https://api.bilibili.com/x/frontend/finger/spi",
                    method: .get
                ).serializingDecodable(BilibiliMainData<BilibiliBuvidModel>.self).value
                return dataReq.data.b_3
            }
        }catch {
            return ""
        }
        return ""
    }
    
    static func getRoomDanmuDetail(roomId: String) async throws -> BilibiliDanmuModel {
        let dataReq = try await AF.request(
            "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo",
            method: .get,
            parameters: [
                "id":roomId
            ]
        ).serializingDecodable(BilibiliMainData<BilibiliDanmuModel>.self).value
        return dataReq.data
    }
    
    public static func getBilibiliLiveStateString(liveState: Int) -> LiveState {
        switch liveState {
        case 0:
            return .close
        case 1:
            return .live
        case 2:
            return .close
        default:
            return .unknow
        }
    }

    public static func biliWbiSign(param: String) async throws -> String? {
        func getMixinKey(orig: String) -> String {
            return String(mixinKeyEncTab.map { orig[orig.index(orig.startIndex, offsetBy: $0)] }.prefix(32))
        }
        
        func encWbi(params: [String: Any], imgKey: String, subKey: String) -> [String: Any] {
            var params = params
            let mixinKey = getMixinKey(orig: imgKey + subKey)
            let currTime = Int(round((Date().timeIntervalSince1970 * 1000))) ?? 0
//            let currTime = 1744010953
            params["wts"] = currTime
            params = params.sorted { $0.key < $1.key }.reduce(into: [:]) { $0[$1.key] = $1.value }
            params = params.mapValues { String(describing: $0).filter { !"!'()*".contains($0) } }
            let sortdKeys = params.keys.sorted()
            let query = sortdKeys.map { "\($0)=\(params[$0] ?? "")" }.joined(separator: "&")
            let wbiSign = calculateMD5(string: query + mixinKey)
            params["w_rid"] = wbiSign
            return params
        }
        
        func getWbiKeys() async throws -> (String, String) {
           let headers: HTTPHeaders = [
               "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
               "Referer": "https://www.bilibili.com/"
           ]
           
            let dataReq = try await AF.request("https://api.bilibili.com/x/web-interface/nav", headers: headers).serializingData().value
            let json = JSON(dataReq)
            let imgURL = json["data"]["wbi_img"]["img_url"].string ?? ""
            let subURL = json["data"]["wbi_img"]["sub_url"].string ?? ""
            let imgKey = imgURL.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
            let subKey = subURL.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
            return (imgKey, subKey)
//            return ("7cd084941338484aae1ad9425b84077c", "4932caff0ff746eab6f01bf08b70ac45")
       }
        

        
        func calculateMD5(string: String) -> String {
            let data = Data(string.utf8)
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = data.withUnsafeBytes {
                CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
            }
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }
        
        let mixinKeyEncTab = [
            46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
            33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
            61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
            36, 20, 34, 44, 52
        ]
        
        let keys = try await getWbiKeys()
        let spdParam = param.components(separatedBy: "&")
        var spdDicParam = [String: String]()
        spdParam.forEach { pair in
            let components = pair.components(separatedBy: "=")
            if components.count == 2 {
                spdDicParam[components[0]] = components[1]
            }
        }
        
        let signedParams = encWbi(params: spdDicParam, imgKey: keys.0, subKey: keys.1)
        let query = signedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return query
    }
}
