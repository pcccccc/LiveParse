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

let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36"
let referer = "https://live.bilibili.com/"

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
        logDebug("开始获取B站分类列表")

        let dataReq: BilibiliMainData<[BilibiliMainListModel]> = try await LiveParseRequest.get(
            "https://api.live.bilibili.com/room/v1/Area/getList"
        )

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

        logInfo("成功获取B站分类列表，共 \(tempArray.count) 个分类")
        return tempArray
    }


    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        logDebug("开始获取B站直播间列表，分类ID: \(id), 页码: \(page)")

        let headers = try await getHeaders()
        let query = try await Bilibili.biliWbiSign(param: "area_id=\(id)&page=\(page)&parent_area_id=\(parentId ?? "")&platform=web&sort_type=&vajra_business_key=&web_location=444.43&w_webid=\(try await getAccessId())") ?? ""

        let dataReq: BilibiliMainData<BiliBiliCategoryRoomMainModel> = try await LiveParseRequest.get(
            "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?\(query)",
            headers: headers
        )

        guard let listModelArray = dataReq.data.list else {
            logWarning("B站直播间列表为空")
            throw LiveParseError.business(.emptyResult(
                location: "\(#file):\(#line)",
                request: NetworkRequestDetail(
                    url: "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?\(query)",
                    method: "GET"
                )
            ))
        }

        var tempArray: Array<LiveModel> = []
        for item in listModelArray {
            tempArray.append(LiveModel(
                userName: item.uname,
                roomTitle: item.title ?? "",
                roomCover: item.cover ?? "",
                userHeadImg: item.face ?? "",
                liveType: .bilibili,
                liveState: "",
                userId: "\(item.uid)",
                roomId: "\(item.roomid)",
                liveWatchedCount: item.watched_show?.text_small ?? ""
            ))
        }

        logInfo("成功获取B站直播间列表，共 \(tempArray.count) 个房间")
        return tempArray
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        logDebug("开始获取B站直播流地址，房间ID: \(roomId)")

        let headers = try await getHeaders()

        // 第一步：获取可用的清晰度列表
        let dataReq: BilibiliMainData<BiliBiliQualityModel> = try await LiveParseRequest.get(
            "https://api.live.bilibili.com/room/v1/Room/playUrl",
            parameters: [
                "platform": "web",
                "cid": roomId,
                "qn": ""
            ],
            headers: headers
        )

        var liveQualitys: [LiveQualityDetail] = []
        var hostArray: [String] = []

        if let qualityDescription = dataReq.data.quality_description {
            logDebug("找到 \(qualityDescription.count) 个清晰度选项")

            // 第二步：为每个清晰度获取播放地址
            for item in qualityDescription {
                let playInfoReq: BilibiliMainData<BiliBiliPlayURLInfoMain> = try await LiveParseRequest.get(
                    "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
                    parameters: [
                        "platform": "h5",
                        "room_id": roomId,
                        "qn": item.qn,
                        "protocol": "0,1",
                        "format": "0,1,2",
                        "codec": "0",
                        "mask": "0"
                    ],
                    headers: headers
                )

                for streamInfo in playInfoReq.data.playurl_info.playurl.stream {
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

            logInfo("成功获取B站播放地址，共 \(tempArray.count) 条线路")
            return tempArray
        } else {
            // 没有清晰度描述，使用默认清晰度
            logDebug("未找到清晰度描述，使用默认清晰度 1500")

            let playInfoReq: BilibiliMainData<BiliBiliPlayURLInfoMain> = try await LiveParseRequest.get(
                "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
                parameters: [
                    "platform": "h5",
                    "room_id": roomId,
                    "qn": "1500",
                    "protocol": "0,1",
                    "format": "0,2",
                    "codec": "0,1",
                    "mask": "0"
                ],
                headers: headers
            )

            for streamInfo in playInfoReq.data.playurl_info.playurl.stream {
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

            logInfo("成功获取B站播放地址（默认质量），共 \(tempArray.count) 条线路")
            return tempArray
        }
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        logDebug("开始获取B站房间信息，房间ID: \(roomId)")

        let headers = try await getHeaders()
        let dataReq: BilibiliMainData<BilibiliRoomInfoData> = try await LiveParseRequest.get(
            "https://api.live.bilibili.com/xlive/web-room/v1/index/getH5InfoByRoom",
            parameters: [
                "room_id": roomId
            ],
            headers: headers
        )

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
        if roomId != "\(dataReq.data.room_info.room_id)" {
            // 如果两个RoomId不相等，用服务器返回的真实ID
            realRoomId = "\(dataReq.data.room_info.room_id)"
            logDebug("房间ID不匹配，使用真实ID: \(realRoomId)")
        }

        logInfo("成功获取B站房间信息: \(dataReq.data.anchor_info.base_info.uname)")
        return LiveModel(
            userName: dataReq.data.anchor_info.base_info.uname,
            roomTitle: dataReq.data.room_info.title,
            roomCover: dataReq.data.room_info.cover,
            userHeadImg: dataReq.data.anchor_info.base_info.face,
            liveType: .bilibili,
            liveState: liveStatus,
            userId: "\(dataReq.data.room_info.uid)",
            roomId: realRoomId,
            liveWatchedCount: dataReq.data.watched_show?.text_small ?? ""
        )
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        logDebug("开始搜索B站直播间，关键词: \(keyword), 页码: \(page)")

        let headers = try await getHeaders()
        let dataReq: BilibiliSearchMainData = try await LiveParseRequest.get(
            "https://api.bilibili.com/x/web-interface/search/type?context=&search_type=live&cover_type=user_cover",
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
            headers: headers
        )

        var tempArray: Array<LiveModel> = []
        for item in dataReq.data?.result?.live_room ?? [] {
            tempArray.append(LiveModel(
                userName: item.uname,
                roomTitle: item.title ?? "",
                roomCover: "https:\(item.cover ?? "")",
                userHeadImg: "https:\(item.uface ?? "")",
                liveType: .bilibili,
                liveState: Bilibili.getBilibiliLiveStateString(liveState: item.live_status ?? 0).rawValue,
                userId: "\(item.uid)",
                roomId: "\(item.roomid)",
                liveWatchedCount: item.watched_show?.text_small ?? ""
            ))
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
            tempArray.append(LiveModel(
                userName: userName,
                roomTitle: item.title ?? "\(item.cate_name ?? "无分区") · \(flowFormatString)",
                roomCover: "https:\(item.uface ?? "")",
                userHeadImg: "https:\(item.uface ?? "")",
                liveType: .bilibili,
                liveState: Bilibili.getBilibiliLiveStateString(liveState: item.live_status ?? 0).rawValue,
                userId: "\(item.uid)",
                roomId: "\(item.roomid)",
                liveWatchedCount: flowFormatString
            ))
        }

        logInfo("搜索完成，找到 \(tempArray.count) 个结果")
        return tempArray
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        logDebug("获取B站直播状态，房间ID: \(roomId)")

        let headers = try await getHeaders()
        let dataReq = try await LiveParseRequest.requestData(
            "https://api.live.bilibili.com/room/v1/Room/get_info",
            parameters: [
                "room_id": roomId
            ],
            headers: headers
        )

        let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
        let jsonDict = json as! Dictionary<String, Any>
        let dataDict = jsonDict["data"] as? Dictionary<String, Any>
        let liveStatus = dataDict?["live_status"] as? Int ?? -1

        let state: LiveState
        switch liveStatus {
        case 0:
            state = .close
        case 1:
            state = .live
        case 2:
            state = .close
        default:
            state = .unknow
        }

        logInfo("B站直播状态: \(state)")
        return state
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        logDebug("开始解析B站分享码: \(shareCode)")

        var roomId = ""
        var realUrl = ""

        if shareCode.contains("b23.tv") {
            // 短链接
            logDebug("识别为B站短链接")
            let url = shareCode.getUrlStringWithShareCode()
            let headers = BiliBiliCookie.cookie.isEmpty ? nil : HTTPHeaders([
                "cookie": BiliBiliCookie.cookie
            ])
            let redirectResponse = try await LiveParseRequest.requestRaw(
                url,
                headers: headers
            )
            realUrl = redirectResponse.finalURL ?? url
            logDebug("短链接跳转后: \(realUrl)")
        } else if shareCode.contains("live.bilibili.com") {
            // 长链接
            logDebug("识别为B站长链接")
            realUrl = shareCode
        } else {
            // 默认为房间号处理
            logDebug("识别为房间号")
            roomId = shareCode
        }

        if roomId == "" {
            // 如果不是房间号，就解析链接中的房间号
            let pattern = "https://live\\.bilibili\\.com/(\\d+)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                throw LiveParseError.parse(.regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: realUrl
                ))
            }

            let nsString = realUrl as NSString
            let results = regex.matches(in: realUrl, range: NSRange(location: 0, length: nsString.length))

            if let match = results.first {
                let range = match.range(at: 1)
                roomId = nsString.substring(with: range)
                logDebug("从链接中解析出房间号: \(roomId)")
            } else {
                logError("无法从链接中提取房间号: \(realUrl)")
                throw LiveParseError.parse(.regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: realUrl
                ))
            }
        }

        guard !roomId.isEmpty, let roomIdInt = Int(roomId), roomIdInt > 0 else {
            logError("房间号无效: \(roomId)")
            throw LiveParseError.business(.roomNotFound(roomId: roomId))
        }

        logInfo("成功解析房间号: \(roomId)")
        return try await Bilibili.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    public static func getQRCodeUrl() async throws -> BilibiliQRMainModel {
        logDebug("获取B站登录二维码")

        let dataReq: BilibiliQRMainModel = try await LiveParseRequest.get(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/generate"
        )

        logInfo("成功获取B站二维码: \(dataReq.data.qrcode_key ?? "")")
        return dataReq
    }
    
    public static func getQRCodeState(qrcode_key: String) async throws -> (BilibiliQRMainModel, String) {
        logDebug("检查B站二维码扫描状态")

        let rawResponse = try await LiveParseRequest.requestRaw(
            "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
            parameters: [
                "qrcode_key": qrcode_key
            ]
        )

        let decoder = JSONDecoder()
        let dataReq: BilibiliQRMainModel

        do {
            dataReq = try decoder.decode(BilibiliQRMainModel.self, from: rawResponse.data)
        } catch {
            logError("二维码状态解析失败: \(error.localizedDescription)")
            throw LiveParseError.parse(.decodingFailed(
                type: String(describing: BilibiliQRMainModel.self),
                location: "\(#file):\(#line)",
                response: rawResponse.response,
                underlyingError: error
            ))
        }

        if dataReq.data.code == 0 {
            logInfo("二维码扫描成功，已登录")
            let setCookie = rawResponse.httpURLResponse?.value(forHTTPHeaderField: "Set-Cookie") ?? ""
            BiliBiliCookie.cookie = setCookie

            if let respUrl = dataReq.data.url {
                let pattern = "DedeUserID=(\\d+)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsString = respUrl as NSString
                    let results = regex.matches(in: respUrl, options: [], range: NSRange(location: 0, length: nsString.length))

                    if let match = results.first {
                        let range = match.range(at: 1)
                        BiliBiliCookie.uid = nsString.substring(with: range)
                        logDebug("提取到用户ID: \(BiliBiliCookie.uid)")
                    }
                } else {
                    logWarning("解析用户ID的正则表达式创建失败")
                }
            }
            return (dataReq, setCookie)
        }

        logDebug("二维码状态码: \(dataReq.data.code ?? 0)")
        return (dataReq, "")
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        logDebug("获取B站弹幕参数，房间ID: \(roomId)")

        var buvid = ""
        let headers = try await getHeaders()
        let cookie = headers["cookie"] ?? ""

        if cookie.contains("buvid3") == false {
            logDebug("Cookie中没有buvid3，需要获取")
            buvid = try await getBuvid()
            BiliBiliCookie.cookie = cookie + "buvid3=\(buvid);"
        } else {
            // 从cookie中提取buvid3
            let pattern = "buvid3=(.*?);"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matchs = regex.matches(in: cookie, range: NSRange(location: 0, length: cookie.count))
                for match in matchs {
                    let matchRange = Range(match.range, in: cookie)!
                    let matchedSubstring = cookie[matchRange]
                    buvid = "\(matchedSubstring)"
                    buvid = buvid.replacingOccurrences(of: "buvid3=", with: "")
                    buvid = buvid.replacingOccurrences(of: ";", with: "")
                    logDebug("从Cookie中提取buvid: \(buvid)")
                    break
                }
            } else {
                logWarning("解析buvid3的正则表达式创建失败")
            }
        }

        let roomInfo = try await getLiveLastestInfo(roomId: roomId, userId: userId)
        let resp = try await getRoomDanmuDetail(roomId: roomInfo.roomId)

        let wsHost = resp.host_list.first?.host ?? "broadcastlv.chat.bilibili.com"
        let result = [
            "roomId": roomId,
            "buvid": buvid,
            "token": resp.token,
            "ws_url": "wss://\(wsHost)/sub"
        ]

        logInfo("成功获取B站弹幕参数，WebSocket地址: wss://\(wsHost)/sub")
        return (result, nil)
    }
    
    public static func getBuvid() async throws -> String {
        let cookie = BiliBiliCookie.cookie

        if NSString(string: cookie).contains("buvid3") {
            logDebug("从Cookie中提取buvid3")
            let pattern = "buvid3=(.*?);"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matchs = regex.matches(in: cookie, range: NSRange(location: 0, length: cookie.count))
                for match in matchs {
                    let matchRange = Range(match.range, in: cookie)!
                    let matchedSubstring = cookie[matchRange]
                    logDebug("成功提取buvid3: \(matchedSubstring)")
                    return "\(matchedSubstring)"
                }
            }
        }

        // Cookie中没有buvid3，从API获取
        logDebug("从API获取buvid3")
        do {
            let dataReq: BilibiliMainData<BilibiliBuvidModel> = try await LiveParseRequest.get(
                "https://api.bilibili.com/x/frontend/finger/spi"
            )
            logInfo("成功获取buvid3: \(dataReq.data.b_3)")
            return dataReq.data.b_3
        } catch {
            logError("获取buvid3失败: \(error.localizedDescription)")
            return ""
        }
    }
    
    static func getBuvid3And4() async throws -> (String, String) {
        logDebug("获取buvid3和buvid4")

        let dataReq: BilibiliMainData<BilibiliBuvidModel> = try await LiveParseRequest.get(
            "https://api.bilibili.com/x/frontend/finger/spi"
        )

        logDebug("成功获取buvid3: \(dataReq.data.b_3), buvid4: \(dataReq.data.b_4)")
        return (dataReq.data.b_3, dataReq.data.b_4)
    }
    
    static func getHeaders() async throws -> HTTPHeaders {
        let buvids = try await getBuvid3And4()
        var cookie: [String: String] = [:]
        if BiliBiliCookie.cookie == "" {
            cookie["cookie"] = "buvid3=\(buvids.0); buvid4=\(buvids.1);DedeUserID=\(arc4random() % 100000)"
            cookie["User-Agent"] = ua
            cookie["Referer"] = referer
        }else {
            cookie["cookie"] = "\(BiliBiliCookie.cookie);buvid3=\(buvids.0); buvid4=\(buvids.1);DedeUserID=\(BiliBiliCookie.uid)"
            cookie["User-Agent"] = ua
            cookie["Referer"] = referer
        }
        return HTTPHeaders(cookie)
    }
    
    static func getRoomDanmuDetail(roomId: String) async throws -> BilibiliDanmuModel {
        logDebug("获取B站房间弹幕详情，房间ID: \(roomId)")

        let headers = try await getHeaders()
        let query = try await Bilibili.biliWbiSign(param: "id=\(roomId)&type=0&sort_type=&vajra_business_key=&web_location=444.43") ?? ""

        let dataReq: BilibiliMainData<BilibiliDanmuModel> = try await LiveParseRequest.get(
            "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?\(query)",
            headers: headers
        )

        logInfo("成功获取弹幕详情，token: \(dataReq.data.token.prefix(10))...")
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
            let currTime = Int(round((Date().timeIntervalSince1970 * 1000)))
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

            logDebug("获取WBI密钥")
            let dataReq = try await LiveParseRequest.requestData(
                "https://api.bilibili.com/x/web-interface/nav",
                headers: headers
            )

            let json = JSON(dataReq)
            let imgURL = json["data"]["wbi_img"]["img_url"].string ?? ""
            let subURL = json["data"]["wbi_img"]["sub_url"].string ?? ""
            let imgKey = imgURL.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
            let subKey = subURL.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""

            logDebug("成功获取WBI密钥: imgKey=\(imgKey.prefix(10))..., subKey=\(subKey.prefix(10))...")
            return (imgKey, subKey)
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
    
    static func getAccessId() async throws -> String {
        logDebug("获取B站access_id")

        let headers = try await Bilibili.getHeaders()
        let resp = try await LiveParseRequest.requestString(
            "https://live.bilibili.com/lol",
            headers: headers
        )

        // 使用正则表达式匹配
        let pattern = "\"access_id\":\"(.*?)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            logError("创建access_id正则表达式失败")
            throw LiveParseError.parse(.regexMatchFailed(
                pattern: pattern,
                location: "\(#file):\(#line)",
                rawData: resp.prefix(500).description
            ))
        }

        let range = NSRange(resp.startIndex..., in: resp)

        if let match = regex.firstMatch(in: resp, options: [], range: range),
           let rangeMatch = Range(match.range(at: 1), in: resp) {
            let id = String(resp[rangeMatch]).replacingOccurrences(of: "\\", with: "")
            logInfo("成功获取access_id: \(id.prefix(20))...")
            return id
        }

        logError("未能从响应中提取access_id")
        throw LiveParseError.parse(.regexMatchFailed(
            pattern: pattern,
            location: "\(#file):\(#line)",
            rawData: resp.prefix(500).description
        ))
    }
}
