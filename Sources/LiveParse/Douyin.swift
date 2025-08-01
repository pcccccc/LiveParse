//
//  Douyin.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/9/14.
//

import Foundation
import Alamofire
import SwiftyJSON
import JavaScriptCore
import CryptoKit

struct DouyinMainModel: Codable {
    let categoryData: Array<DouyinCategoryData>
}

struct DouyinCategoryData: Codable {
    let partition: DouyinPartitionData
    let sub_partition: Array<DouyinCategoryData>?
}

struct DouyinPartitionData: Codable {
    let id_str : String
    let type: Int
    let title: String
}

struct DouyinRoomMainResponse: Codable {
    let data: DouyinRoomListData
}

struct DouyinRoomListData: Codable {
    let count: Int
    let offset: Int
    let data: Array<DouyinStreamerData>
}

struct DouyinSecUserIdRoomData: Codable {
    let data: DouyinStreamerData
}

struct DouyinStreamerData: Codable {
    let tag_name: String?
    let uniq_id: String?
    let web_rid: String?
    let is_recommend: Int?
    let title_type: Int?
    let cover_type: Int?
    let room: DouyinRoomData
    let owner: DouyinRoomOwnerData?
}

struct DouyinRoomData: Codable {
    let id_str: String
    let status: Int
    let status_str: String?
    let title: String
    let user_count_str: String?
    let cover: DouyinRoomCoverData
    let stream_url: DouyinRoomStreamUrlData
    let mosaic_status: Int?
    let mosaic_status_str: String?
    //    let admin_user_ids: Array
    //    let admin_user_ids_str: Array
    let owner: DouyinRoomOwnerData
    let live_room_mode: Int?
    let stats: DouyinRoomStatsData
    let has_commerce_goods: Bool?
    //    let linker_map: Dictionary
    let room_view_stats: DouyinRoomViewStatsData
    //    let ecom_data: Dictionary
    //    let AnchorABMap: Dictionary
    let like_count: Int
    let owner_user_id_str: String?
    //    let paid_live_data: Dictionary
    //    let others: Dictionary
}

struct DouyinRoomCoverData: Codable {
    let url_list: Array<String>
}



struct DouyinRoomStreamUrlData: Codable {
    let hls_pull_url_map: DouyinRoomLiveQualityData?
    let default_resolution: String
    let stream_orientation: Int?
}

struct DouyinRoomLiveQualityData: Codable {
    let FULL_HD1: String?
    let HD1: String?
    let SD1: String?
    let SD2: String?
}

struct DouyinRoomOwnerData: Codable {
    let id_str: String
    let sec_uid: String
    let nickname: String
    let web_rid: String?
    let avatar_thumb: DouyinRoomOwnerAvatarThumbData
}

struct DouyinRoomOwnerAvatarThumbData: Codable {
    let url_list: Array<String>
}

struct DouyinRoomStatsData: Codable {
    let total_user_desp: String?
    let like_count: Int?
    let total_user_str: String?
    let user_count_str: String?
}

struct DouyinRoomViewStatsData: Codable {
    let is_hidden: Bool?
    let display_short: String?
    let display_middle: String?
    let display_long: String?
    let display_value: Int?
    let display_version: Int64?
    let incremental: Bool?
    let display_type: Int?
    let display_short_anchor: String?
    let display_middle_anchor: String?
    let display_long_anchor: String?
}

struct DouyinRoomPlayInfoMainData: Codable {
    let data: DouyinRoomPlayInfoData?
}

struct DouyinRoomPlayInfoData: Codable {
    let data: Array<DouyinPlayQualitiesInfo>?
    let user: DouyinLiveUserInfo?
}

struct DouyinLiveSimlarRooms: Codable {
    let room: Array<DouyinLiveSimlarRoomsInfo>?
}

struct DouyinLiveSimlarRoomsInfo: Codable {
    let cover: DouyinLiveUserAvatarInfo
    let stream_url: DouyinPlayQualities?
}

struct DouyinPlayQualitiesInfo: Codable {
    let status: Int?
    let stream_url: DouyinPlayQualities?
    let id_str: String?
    let title: String?
    let user_count_str: String?
    let cover: DouyinLiveUserAvatarInfo?
    let owner: DouyinRoomOwnerData?
}

struct DouyinLiveCoreSDKData: Codable {
    let pull_data: DouyinLivePullData?
}


struct DouyinLivePullData: Codable {
    let stream_data: String?
}

struct DouyinLiveUserInfo: Codable {
    let id_str: String?
    let nickname: String?
    let avatar_thumb: DouyinLiveUserAvatarInfo?
}

struct DouyinLiveUserAvatarInfo: Codable {
    let url_list: Array<String>?
}



struct DouyinPlayQualities: Codable {
    let hls_pull_url_map: DouyinPlayQualitiesHlsMap
    let live_core_sdk_data: DouyinLiveCoreSDKData?
}

struct DouyinPlayQualitiesHlsMap: Codable {
    let FULL_HD1: String?
    let HD1: String?
    let SD1: String?
    let SD2: String?
}

struct DouyinTKMainData: Codable {
    let code: Int
    let msg: String
    let data: DouyinTKData
}

public struct DouyinTKData: Codable {
    public let xbogus: String
    public let mstoken: String
    public let ttwid: String
    public let url: String
}

struct DouyinSearchMain: Codable {
    let status_code: Int
    let data: Array<DouyinSearchList>
}

struct DouyinSearchList: Codable {
    let lives: DouyinSearchLives
}

struct DouyinSearchLives: Codable {
    let rawdata: String
}

var headers = HTTPHeaders.init([
    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7; application/json",
    "Authority": "live.douyin.com",
    "Referer": "https://live.douyin.com",
    "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36",
])

public struct Douyin: LiveParse {
    
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        do {
            if headers["cookie"] == nil || headers["cookie"] == "" {
                let cookie = try await Douyin.getCookie(roomId: "117908807")
                headers["cookie"] = cookie
            }
            let dataReq = try await AF.request("https://live.douyin.com", method: .get, headers: headers).serializingString().value
            let regex = try NSRegularExpression(pattern: "categoryData.*?\\]\\)", options: [])
            let matchs =  regex.matches(in: dataReq, range: NSRange(location: 0, length:  dataReq.count))
            for match in matchs {
                let matchRange = Range(match.range, in: dataReq)!
                let matchedSubstring = dataReq[matchRange]
                var nsstr = NSString(string: "\(matchedSubstring.prefix(matchedSubstring.count - 6))")
                nsstr = ("{\"" + (nsstr as String)) as NSString
                let data = try JSONDecoder().decode(DouyinMainModel.self, from: nsstr.replacingOccurrences(of: "\\", with: "").data(using: .utf8)!)
                var tempArray: [LiveMainListModel] = []
                for item in data.categoryData {
                    if item.sub_partition?.isEmpty ?? false == true {
                        var subList: [LiveCategoryModel] = []
                        subList.append(.init(id: item.partition.id_str, parentId:
                                                "\(item.partition.type)", title: item.partition.title, icon: ""))
                        tempArray.append(.init(id: item.partition.id_str, title: item.partition.title, icon: "", subList: subList))
                    }else {
                        var subList: [LiveCategoryModel] = []
                        if let sub_partition = item.sub_partition {
                            if sub_partition.isEmpty {
                                subList.append(.init(id: item.partition.id_str, parentId: item.partition.id_str, title: item.partition.title, icon: ""))
                            }else {
                                for subItem in sub_partition {
                                    if let thirdSubPartition = subItem.sub_partition {
                                        if thirdSubPartition.isEmpty == false {
                                            var thirdList: [LiveCategoryModel] = []
                                            for thirdItem in thirdSubPartition {
                                                thirdList.append(.init(id: thirdItem.partition.id_str, parentId: "\(thirdItem.partition.type)", title: thirdItem.partition.title, icon: ""))
                                            }
                                            tempArray.append(.init(id: subItem.partition.id_str, title: subItem.partition.title, icon: "", subList: thirdList))
                                        }
                                    }else {
                                        subList.append(.init(id: subItem.partition.id_str, parentId: "\(subItem.partition.type)", title: subItem.partition.title, icon: ""))
                                    }
                                }
                            }
                        }
                    }
                }
                return tempArray
            }
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\("请求抖音直播间列表失败,返回的列表为空")")
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        do {
            let parameter: Dictionary<String, Any> = [
                "aid": 6383,
                "app_name": "douyin_web",
                "live_id": 1,
                "device_platform": "web",
                "count": 15,
                "offset": (page - 1) * 15,
                "partition": id,
                "partition_type": parentId ?? "",
                "req_from": 2
            ]
            
            let dataReq = try await AF.request("https://live.douyin.com/webcast/web/partition/detail/room/", method: .get, parameters: parameter, headers: headers).serializingDecodable(DouyinRoomMainResponse.self).value
            let listModelArray = dataReq.data.data
            var tempArray: Array<LiveModel> = []
            for item in listModelArray {
                tempArray.append(LiveModel(userName: item.room.owner.nickname, roomTitle: item.room.title, roomCover: item.room.cover.url_list.first ?? "", userHeadImg: item.room.owner.avatar_thumb.url_list.first ?? "", liveType: .douyin, liveState: "", userId: item.room.id_str, roomId: item.web_rid ?? "", liveWatchedCount: item.room.user_count_str ?? ""))
            }
            return tempArray
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        do {
            let liveData = try await Douyin.getDouyinRoomDetail(roomId: roomId, userId: userId ?? "")
            var tempArray: [LiveQualityDetail] = []
            if liveData.data?.data?.count ?? 0 > 0 {
                if liveData.data?.data?.first?.stream_url?.live_core_sdk_data?.pull_data?.stream_data ?? "" != "" {
                    var resJson = liveData.data?.data?.first?.stream_url?.live_core_sdk_data?.pull_data?.stream_data ?? ""
                    if let jsonData = resJson.data(using: .utf8) {
                        do {
                            let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
                            let liveData = dictionary?["data"] as? [String: Any]
                            let origin = liveData?["origin"] as? [String: Any]
                            let origin_main = origin?["main"] as? [String: Any]
                            if let origin_flv = origin_main?["flv"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "原画_FLV", qn: 0, url: origin_flv, liveCodeType: .flv, liveType: .douyin))
                            }
                            if let origin_hls = origin_main?["hls"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "原画_HLS", qn: 0, url: origin_hls, liveCodeType: .hls, liveType: .douyin))
                            }
                            
                            let uhd = liveData?["uhd"] as? [String: Any]
                            let uhd_main = uhd?["main"] as? [String: Any]
                            if let uhd_flv = uhd_main?["flv"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "蓝光_FLV", qn: 0, url: uhd_flv, liveCodeType: .flv, liveType: .douyin))
                            }
                            if let uhd_hls = uhd_main?["hls"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "蓝光_HLS", qn: 0, url: uhd_hls, liveCodeType: .hls, liveType: .douyin))
                            }
                            
                            let hd = liveData?["hd"] as? [String: Any]
                            let hd_main = hd?["main"] as? [String: Any]
                            if let hd_flv = hd_main?["flv"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "超清_FLV", qn: 0, url: hd_flv, liveCodeType: .flv, liveType: .douyin))
                            }
                            if let hd_hls = hd_main?["hls"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "超清_HLS", qn: 0, url: hd_hls, liveCodeType: .hls, liveType: .douyin))
                            }
                            
                            let sd = liveData?["sd"] as? [String: Any]
                            let sd_main = sd?["main"] as? [String: Any]
                            if let sd_flv = sd_main?["flv"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "高清_FLV", qn: 0, url: sd_flv, liveCodeType: .flv, liveType: .douyin))
                            }
                            if let sd_hls = sd_main?["hls"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "高清_HLS", qn: 0, url: sd_hls, liveCodeType: .hls, liveType: .douyin))
                            }
                            
                            let ld = liveData?["ld"] as? [String: Any]
                            let ld_main = ld?["main"] as? [String: Any]
                            if let ld_flv = ld_main?["flv"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "标清_FLV", qn: 0, url: ld_flv, liveCodeType: .flv, liveType: .douyin))
                            }
                            if let ld_hls = ld_main?["hls"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "标清_HLS", qn: 0, url: ld_hls, liveCodeType: .hls, liveType: .douyin))
                            }
                            
                            let md = liveData?["md"] as? [String: Any]
                            let md_main = md?["main"] as? [String: Any]
                            if let md_flv = md_main?["flv"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "标清2_FLV", qn: 0, url: md_flv, liveCodeType: .flv, liveType: .douyin))
                            }
                            if let md_hls = md_main?["hls"] as? String {
                                tempArray.append(.init(roomId: roomId, title: "标清2_HLS", qn: 0, url: md_hls, liveCodeType: .hls, liveType: .douyin))
                            }
                            var qualityHls = LiveQualityModel(cdn: "线路 HLS", qualitys: [])
                            var qualityFlv = LiveQualityModel(cdn: "线路 FLV", qualitys: [])
                            for model in tempArray {
                                if model.liveCodeType == .hls {
                                    qualityHls.qualitys.append(model)
                                }
                                if model.liveCodeType == .flv {
                                    qualityFlv.qualitys.append(model)
                                }
                            }
                            return [qualityFlv, qualityHls]
                        } catch {
                            print(error)
                        }
                    }
                }
                if tempArray.isEmpty { //尝试原始方法
                    let FULL_HD1 = liveData.data?.data?.first?.stream_url?.hls_pull_url_map.FULL_HD1 ?? ""
                    let HD1 = liveData.data?.data?.first?.stream_url?.hls_pull_url_map.HD1 ?? ""
                    let SD1 = liveData.data?.data?.first?.stream_url?.hls_pull_url_map.SD1 ?? ""
                    let SD2 = liveData.data?.data?.first?.stream_url?.hls_pull_url_map.SD2 ?? ""
                    
                    if FULL_HD1 != "" {
                        tempArray.append(.init(roomId: roomId, title: "超清", qn: 0, url: FULL_HD1, liveCodeType: .hls, liveType: .douyin))
                    }
                    if HD1 != "" {
                        tempArray.append(.init(roomId: roomId, title: "高清", qn: 0, url: HD1, liveCodeType: .hls, liveType: .douyin))
                    }
                    if SD1 != "" {
                        tempArray.append(.init(roomId: roomId, title: "标清 1", qn: 0, url: SD1, liveCodeType: .hls, liveType: .douyin))
                    }
                    if SD2 != "" {
                        tempArray.append(.init(roomId: roomId, title: "标清 2", qn: 0, url: SD2, liveCodeType: .hls, liveType: .douyin))
                    }
                    return [.init(cdn: "线路 1", qualitys: tempArray)]
                }
            }
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\("请求抖音直播间列表失败,返回的列表为空")")
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        do {
            let serverUrl = "https://www.douyin.com/aweme/v1/web/live/search/"
            var components = URLComponents(string: serverUrl)!
            components.scheme = "https"
            components.port = 443
            let text = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            let queryItems = [
                URLQueryItem(name: "device_platform", value: "webapp"),
                URLQueryItem(name: "aid", value: "6383"),
                URLQueryItem(name: "channel", value: "channel_pc_web"),
                URLQueryItem(name: "search_channel", value: "aweme_live"),
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "search_source", value: "switch_tab"),
                URLQueryItem(name: "query_correct_type", value: "1"),
                URLQueryItem(name: "is_filter_search", value: "0"),
                URLQueryItem(name: "from_group_id", value: ""),
                URLQueryItem(name: "offset", value: "\((page - 1) * 10)"),
                URLQueryItem(name: "count", value: "10"),
                URLQueryItem(name: "pc_client_type", value: "1"),
                URLQueryItem(name: "version_code", value: "170400"),
                URLQueryItem(name: "version_name", value: "17.4.0"),
                URLQueryItem(name: "cookie_enabled", value: "true"),
                URLQueryItem(name: "screen_width", value: "1980"),
                URLQueryItem(name: "screen_height", value: "1080"),
                URLQueryItem(name: "browser_language", value: "zh-CN"),
                URLQueryItem(name: "browser_platform", value: "Win32"),
                URLQueryItem(name: "browser_name", value: "Edge"),
                URLQueryItem(name: "browser_version", value: "126.0.0.0"),
                URLQueryItem(name: "browser_online", value: "true"),
                URLQueryItem(name: "engine_name", value: "Blink"),
                URLQueryItem(name: "engine_version", value: "126.0.0.0"),
                URLQueryItem(name: "os_name", value: "Windows"),
                URLQueryItem(name: "os_version", value: "10"),
                URLQueryItem(name: "cpu_core_num", value: "12"),
                URLQueryItem(name: "device_memory", value: "8"),
                URLQueryItem(name: "platform", value: "PC"),
                URLQueryItem(name: "downlink", value: "4.7"),
                URLQueryItem(name: "effective_type", value: "4g"),
                URLQueryItem(name: "round_trip_time", value: "100"),
                URLQueryItem(name: "webid", value: "7247041636524377637")
            ]
            
            components.queryItems = queryItems
            var msstub: [String: String] = [:]
            for item in queryItems {
                msstub.updateValue(item.value ?? "", forKey: item.name)
            }
            let xmsStub = Douyin.getXMsStub(params: msstub)
            let jsDom = """
                    document = {};
                    window = {};
                    navigator = {
                    'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
                    };
                    """
            let jsContext = JSContext()
            if let jsPath = Bundle.module.path(forResource: "webmssdk", ofType: "js") {
                jsContext?.evaluateScript(try? jsDom + String(contentsOfFile: jsPath))
            }
            let signature = jsContext?.evaluateScript("get_sign('\(xmsStub)')").toString()
            let requestUrl = components.url!.absoluteString + "a_bogus=\(signature)"
            let reqHeaders = HTTPHeaders.init([
                "Accept":"application/json, text/plain, */*",
                "Authority": "live.douyin.com",
                "Referer": "https://www.douyin.com/search/\(text ?? "")?source=switch_tab&type=live",
                "User-Agent":
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                "Cookie": headers["cookie"] ?? "" + "__ac_nonce=\(String.generateRandomString(length: 21))"
            ])
            let dataReq0 = try await AF.request(requestUrl, method: .get, headers:reqHeaders).serializingString().value
            let dataReq = try await AF.request(requestUrl, method: .get, headers:reqHeaders).serializingDecodable(DouyinSearchMain.self).value
            var tempArray: Array<LiveModel> = []
            for item in dataReq.data {
                let dict = try JSON(data: item.lives.rawdata.data(using: .utf8) ?? Data())
                tempArray.append(LiveModel(userName: dict["owner"]["nickname"].stringValue, roomTitle: dict["title"].stringValue, roomCover: dict["cover"]["url_list"][0].stringValue, userHeadImg: dict["owner"]["avatar_thumb"]["url_list"][0].stringValue, liveType: .douyin, liveState: "", userId: dict["id_str"].stringValue, roomId: dict["owner"]["web_rid"].stringValue, liveWatchedCount: dict["user_count"].stringValue))
            }
            return tempArray
        } catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        do {
            let dataReq = try await getDouyinRoomDetail(roomId: roomId, userId: userId ?? "")
            var liveState = ""
            switch dataReq.data?.data?.first?.status {
            case 4:
                liveState = LiveState.close.rawValue
            case 2:
                let playArgs = try await getPlayArgs(roomId: roomId, userId: userId) //增加一个如果能解析出直播地址，则算作正在直播
                if playArgs.count > 0 {
                    let playItem = playArgs.first
                    if playItem?.qualitys.count ?? 0 > 0 {
                        liveState = LiveState.live.rawValue
                    }else {
                        liveState = LiveState.close.rawValue
                    }
                }else {
                    liveState = LiveState.close.rawValue
                }
            default:
                liveState = LiveState.unknow.rawValue
            }
            return LiveModel(userName: dataReq.data?.user?.nickname ?? "", roomTitle: dataReq.data?.data?.first?.title ?? "", roomCover: dataReq.data?.data?.first?.cover?.url_list?.first ?? "", userHeadImg: dataReq.data?.user?.avatar_thumb?.url_list?.first ?? "", liveType: .douyin, liveState: liveState, userId: userId ?? (dataReq.data?.data?.first?.id_str ?? ""), roomId: roomId, liveWatchedCount: dataReq.data?.data?.first?.user_count_str ?? "")
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        do {
            let dataReq = try await Douyin.getDouyinRoomDetail(roomId: roomId, userId: userId ?? "")
            switch dataReq.data?.data?.first?.status {
            case 4:
                return .close
            case 2:
                return .live
            default:
                return .unknow
            }
        }catch {
            throw LiveParseError.liveStateParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    static func getDouyinRoomDetail(roomId: String, userId: String) async throws -> DouyinRoomPlayInfoMainData {
        var errorTime = 0
        while errorTime < 3 {
            do {
                let parameter: Dictionary<String, Any> = [
                    "aid": 6383,
                    "app_name": "douyin_web",
                    "live_id": 1,
                    "device_platform": "web",
                    "enter_from": "web_live",
                    "web_rid": roomId,
                    "room_id_str": userId,
                    "enter_source": "",
                    "Room-Enter-User-Login-Ab": 0,
                    "is_need_double_stream": false,
                    "cookie_enabled": true,
                    "screen_width": 1980,
                    "screen_height": 1080,
                    "browser_language": "zh-CN",
                    "browser_platform": "Win32",
                    "browser_name": "Edge",
                    "browser_version": "138.0.0.0",
                ]
                let cookie = try await Douyin.getCookie(roomId: roomId)
                var headers = headers
                headers.add(name: "cookie", value: cookie)
                headers.add(name: "accept", value: "application/json, text/plain, */*")
                let resString = try await AF.request("https://live.douyin.com/webcast/room/web/enter/", method: .get, parameters: parameter, headers: headers).serializingString().value
                let data = resString.data(using: .utf8) ?? Data()
                let jsonDecoder = JSONDecoder()
                let resp = try jsonDecoder.decode(DouyinRoomPlayInfoMainData.self, from: data)
                return resp
            }catch {
                errorTime += 1
                if errorTime == 3 {
                    throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
                }else {
                    print("获取抖音直播间详情失败，正在重试...(\(errorTime))")
                    
                }
            }
        }
        throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：请求抖音直播间详情失败")
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        do {
            if shareCode.contains("v.douyin.com") { //短链接 or 分享码
                let url = shareCode.getUrlStringWithShareCode()
                let dataReq = await AF.request(url).serializingData().response
                let redirectUrl = dataReq.response?.url?.absoluteString ?? ""
                let pattern = "douyin/webcast/reflow/(\\d+)"
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let nsString = redirectUrl as NSString
                    let results = regex.matches(in: redirectUrl, range: NSRange(location: 0, length: nsString.length))
                    if let match = results.first {
                        let range = match.range(at: 1) // 临时roomId
                        let roomId = nsString.substring(with: range)
                        let secUserIdPattern = "sec_user_id=([\\w\\d_\\-]+)&"
                        let regex = try NSRegularExpression(pattern: secUserIdPattern)
                        let nsString = redirectUrl as NSString
                        let results = regex.matches(in: redirectUrl, range: NSRange(location: 0, length: nsString.length))
                        var sec_user_id = ""
                        if let match = results.first {
                            let range = match.range(at: 1) // sec_user_id
                            sec_user_id = nsString.substring(with: range)
                        }
                    
                        let requestUrl = "https://webcast.amemv.com/webcast/room/reflow/info/?verifyFp=verify_lk07kv74_QZYCUApD_xhiB_405x_Ax51_GYO9bUIyZQVf&type_id=0&live_id=1&room_id=\(roomId)&sec_user_id=\(sec_user_id)&app_id=1128&msToken=wrqzbEaTlsxt52-vxyZo_mIoL0RjNi1ZdDe7gzEGMUTVh_HvmbLLkQrA_1HKVOa2C6gkxb6IiY6TY2z8enAkPEwGq--gM-me3Yudck2ailla5Q4osnYIHxd9dI4WtQ=="
                        let res = try await AF.request(requestUrl, headers: [
                            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                            "Accept-Language": "zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2",
                            "Cookie": "s_v_web_id=verify_lk07kv74_QZYCUApD_xhiB_405x_Ax51_GYO9bUIyZQVf"
                        ]).serializingDecodable(DouyinSecUserIdRoomData.self).value
                        var liveStatus = LiveState.unknow.rawValue
                        switch res.data.room.status {
                        case 4:
                            liveStatus = LiveState.close.rawValue
                        case 0:
                            liveStatus = LiveState.close.rawValue
                        case 2:
                            liveStatus = LiveState.live.rawValue
                        default:
                            liveStatus = LiveState.unknow.rawValue
                        }
                        return LiveModel(userName: res.data.room.owner.nickname, roomTitle: res.data.room.title, roomCover: res.data.room.cover.url_list.first ?? "", userHeadImg: res.data.room.owner.avatar_thumb.url_list.first ?? "", liveType: .douyin, liveState: liveStatus, userId: res.data.room.id_str, roomId: res.data.room.owner.web_rid ?? "", liveWatchedCount: res.data.room.user_count_str ?? "")
                    } else {
                        throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\("解析房间号失败，请检查分享码/分享链接是否正确")")
                    }
                } catch {
                    throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\("解析房间号失败，请检查分享码/分享链接是否正确")")
                }
                
            }else if shareCode.contains("live.douyin.com") { //长链接
                let pattern = "live.douyin.com/(\\d+)"
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let nsString = shareCode as NSString
                    let results = regex.matches(in: shareCode, range: NSRange(location: 0, length: nsString.length))
                    if let match = results.first {
                        let range = match.range(at: 1) // 临时roomId
                        let roomId = nsString.substring(with: range)
                        return try await Douyin.getLiveLastestInfo(roomId: roomId, userId: roomId)
                    }
                }catch {
                    throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\("解析房间号失败，请检查分享码/分享链接是否正确")")
                }
            }else {
                return try await Douyin.getLiveLastestInfo(roomId: shareCode, userId: nil)
            }
            throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\("解析房间号失败，请检查分享码/分享链接是否正确")")
        }catch {
            throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        do {
            var finalUserId = ""
            let room = try await getLiveLastestInfo(roomId: roomId, userId: nil) //防止传进来的roomId不是真实的web_rid，而是链接的短roomid
            finalUserId = room.userId
            var userUniqueId = Douyin.getUserUniqueId()
            let cookie = try await getCookie(roomId: roomId)
            
            let sigParams = [
                "live_id": "1",
                "aid": "6383",
                "version_code": "180800",
                "webcast_sdk_version": "1.0.14-beta.0",
                "room_id": finalUserId,
                "sub_room_id": "",
                "sub_channel_id": "",
                "did_rule": "3",
                "user_unique_id": userUniqueId,
                "device_platform": "web",
                "device_type": "",
                "ac": "",
                "identity": "audience",
            ]
            let xmsStub = Douyin.getXMsStub(params: sigParams)
            let jsDom = """
                    document = {};
                    window = {};
                    navigator = {
                    'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
                    };
                    """
            let jsContext = JSContext()
            if let jsPath = Bundle.module.path(forResource: "webmssdk", ofType: "js") {
                jsContext?.evaluateScript(try? jsDom + String(contentsOfFile: jsPath))

            }
            let signature = jsContext?.evaluateScript("get_sign('\(xmsStub)')").toString()
            let ts = Int(Date().timeIntervalSince1970 * 1000)
            return (
                [
                    "room_id": finalUserId,
                    "compress": "gzip",
                    "version_code": "180800",
                    "webcast_sdk_version": "1.0.14-beta.0",
                    "live_id": "1",
                    "did_rule": "3",
                    "user_unique_id": userUniqueId,
                    "identity": "audience",
                    "signature": signature ?? "",
                    "aid": "6383",
                    "device_platform": "web",
                    "browser_language": "zh-CN",
                    "browser_platform": "MacIntel",
                    "browser_name": "Mozilla",
                    "browser_version": "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
                ],
                [
                    "cookie": headers["cookie"] ?? "",
                    "User-Agnet": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
                ]
            )
        }catch {
            throw LiveParseError.danmuArgsParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func randomHexString(length: Int) -> String {
        let allowedChars = "0123456789ABCDEF"
        let allowedCharsCount = UInt32(allowedChars.count)
        var randomString = ""
        
        for _ in 0..<length {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
            let randomChar = allowedChars[randomIndex]
            randomString += String(randomChar)
        }
        return randomString
    }
    
    public static func getRequestHeaders() async throws {
        let dataReq = await AF.request("https://live.douyin.com", headers: headers).serializingData().response
        headers.add(HTTPHeader(name: "cookie", value: (dataReq.response?.allHeaderFields["Set-Cookie"] ?? "") as! String))
    }
    
    public static func getUserUniqueId(roomId: String) async throws -> String {
        var httpHeaders = headers
        let cookie = try await Douyin.getCookie(roomId: roomId)
        httpHeaders.add(name: "cookie", value: cookie)
        httpHeaders.add(name: "Authority", value: "live.douyin.com")
        httpHeaders.add(name: "Referer", value: "https://live.douyin.com/\(roomId)")
        httpHeaders.add(name: "Accept", value: "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7")
        let dataReq = try await AF.request("https://live.douyin.com/\(roomId)", method: .get, headers: httpHeaders).serializingString().value
        do {
            let regex = try NSRegularExpression(pattern: "user_unique_id.*?,", options: [])
            let userUniqueIdMatchs = regex.matches(in: dataReq, range: NSRange(location: 0, length:  dataReq.count))
            for sub in userUniqueIdMatchs {
                let matchRange = Range(sub.range, in: dataReq)!
                let matchedSubstring = String(describing: dataReq[matchRange])
                print(matchedSubstring)
                let uidRegex = try NSRegularExpression(pattern: "[1-9]+\\.?[0-9]*", options: [])
                let uidMatchs = uidRegex.matches(in: matchedSubstring, range: NSRange(location: 0, length:  matchedSubstring.count))
                for uid in uidMatchs {
                    let matchRange = Range(uid.range, in: matchedSubstring)!
                    let matchedSubstring = String(describing: matchedSubstring[matchRange])
                    return matchedSubstring
                }
            }
        }catch {
            return ""
        }
        return ""
    }
    
    public static func getCookie(roomId: String) async throws -> String {
        var httpHeaders = headers
        httpHeaders.add(name: "Cookie", value: "__ac_nonce=\(Douyin.randomHexString(length: 21))")
        let dataReq = await AF.request("https://live.douyin.com/\(roomId)", method: .get, headers: httpHeaders).serializingString().response.response?.allHeaderFields
        return dataReq?["Set-Cookie"] as? String ?? ""
    }
    
//    public static func signURL(_ url: String) async throws -> DouyinTKData {
//        
//        var request = URLRequest(url: URL(string: "https://dy.nsapps.cn/abogus")!)
//        request.httpMethod = "post"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        let parameter = [
//            "url": url,
//            "userAgent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
//        ]
//        request.httpBody = try JSONSerialization.data(withJSONObject: parameter)
//        let dataReq2 = try await AF.request(request).serializingString().value
//        let dataReq = try await AF.request(request).serializingDecodable(DouyinTKMainData.self).value
//        return dataReq.data
//    }
    
    static func getXMsStub(params: [String: String]) -> String {
//        let sigParams = params.map { "\($0)=\($1)" }.joined(separator: ",")
        let sigParams = "live_id=\(params["live_id"] ?? ""),aid=\(params["aid"] ?? ""),version_code=\(params["version_code"] ?? ""),webcast_sdk_version=\(params["webcast_sdk_version"] ?? ""),room_id=\(params["room_id"] ?? ""),sub_room_id=,sub_channel_id=,did_rule=\(params["did_rule"] ?? ""),user_unique_id=\(params["user_unique_id"] ?? ""),device_platform=\(params["device_platform"] ?? ""),device_type=,ac=,identity=\(params["identity"] ?? "")"
        let sigParamsData = Data(sigParams.utf8)
        let md5Digest = Insecure.MD5.hash(data: sigParamsData)
        let md5Hex = md5Digest.map { String(format: "%02hhx", $0) }.joined()
        return md5Hex
    }
    
    static func getUserUniqueId() -> String {
        let lowerBound: UInt64 = 7300000000000000000
        let upperBound: UInt64 = 7999999999999999999
        let randomId = UInt64.random(in: lowerBound...upperBound)
        return String(randomId)
    }
}

