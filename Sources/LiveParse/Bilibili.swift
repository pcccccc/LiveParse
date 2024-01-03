//
//  Bilibili.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/7/4.
//

import Foundation
import Alamofire

public struct BiliBiliCookie {
    public static var cookie = UserDefaults.standard.value(forKey: "LiveParse.Bilibili.Cookie") as? String ?? "" {
        didSet {
            UserDefaults.standard.setValue(cookie, forKey: "LiveParse.Bilibili.Cookie")
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
    let code: Int
    let message: String
    let ttl: Int
    let data: BilibiliQRMainData
}

struct BilibiliQRMainData: Codable {
    let url: String?
    let qrcode_key: String?
    let refresh_token: String?
    let timestamp: Int?
    let code: Int?
    let message: String?
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
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        let dataReq = try await AF.request(
            "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList",
            method: .get,
            parameters: [
                "platform": "web",
                "parent_area_id": parentId ?? "",
                "area_id": id,
                "sort_type": "",
                "page": page
            ],
            headers: [
            ]
        ).serializingDecodable(BilibiliMainData<BiliBiliCategoryRoomMainModel>.self).value
        if let listModelArray = dataReq.data.list {
            var tempArray: Array<LiveModel> = []
            for item in listModelArray {
                tempArray.append(LiveModel(userName: item.uname, roomTitle: item.title ?? "", roomCover: item.cover ?? "", userHeadImg: item.face ?? "", liveType: .bilibili, liveState: "", userId: "\(item.uid)", roomId: "\(item.roomid)", liveWatchedCount: item.watched_show?.text_small ?? ""))
            }
            return tempArray
        }else {
            return []
        }
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        let dataReq = try await AF.request(
            "https://api.live.bilibili.com/room/v1/Room/playUrl",
            method: .get,
            parameters: [
                "platform": "web",
                "cid": roomId,
                "qn": ""
            ],
            headers: BiliBiliCookie.cookie == "" ? nil : [
                "cookie": BiliBiliCookie.cookie
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
        }
        return []
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let dataReq = try await AF.request(
            "https://api.live.bilibili.com/xlive/web-room/v1/index/getH5InfoByRoom",
            parameters: [
                "room_id": roomId
            ],
            headers: BiliBiliCookie.cookie == "" ? nil : [
                "cookie": BiliBiliCookie.cookie
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
        
        //WARNING: 11
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {

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
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
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
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        
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
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }
        
        return try await Bilibili.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    public static func getQRCodeUrl() async throws -> BilibiliQRMainModel {
        let dataReq = try await AF.request(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/generate",
            method: .get
        ).serializingDecodable(BilibiliQRMainModel.self).value
        return dataReq
    }
    
    public static func getQRCodeState(qrcode_key: String) async throws -> BilibiliQRMainModel {
        let resp = AF.request(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
            method: .get,
            parameters: [
                "qrcode_key": qrcode_key
            ]
        )
        
        let dataReq = try await resp.serializingDecodable(BilibiliQRMainModel.self).value
        if dataReq.data.code == 0 {
            UserDefaults.standard.setValue(resp.response?.headers["Set-Cookie"] ?? "", forKey: "BilibiliCookie")
        }
        return dataReq
    }
    
    public static func getDanmukuArgs(roomId: String) async throws -> ([String : String], [String : String]?) {
        let buvid = try await getBuvid()
        let resp = try await getRoomDanmuDetail(roomId: roomId)
        return (["roomId": roomId, "buvid": buvid,"token": resp.token], nil)
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
                    method: .get,
                    headers: BiliBiliCookie.cookie == "" ? nil : [
                        "cookie": BiliBiliCookie.cookie
                    ]
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
            ],
            headers: BiliBiliCookie.cookie == "" ? nil : [
                "cookie": BiliBiliCookie.cookie
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
}
