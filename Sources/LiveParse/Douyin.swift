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
    let count: Int?
    let offset: Int?
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
    let htmlStreamData: DouyinStreamDataResponse?
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

struct DouyinStreamDataResponse: Codable {
    let H265_streamData: DouyinStreamData?
    let H264_streamData: DouyinStreamData?
    let UGC_streamData: DouyinStreamData?
}

struct DouyinStreamData: Codable {
    let common: DouyinStreamCommon?
    let options: DouyinStreamOptions?
    let stream: DouyinStreamStreams?
}

struct DouyinStreamCommon: Codable {
    let app_id: String?
    let backup_push_id: Int?
    let common_sdk_params: DouyinCommonSDKParams?
    let common_trace: String?
    let lines: DouyinLines?
    let main_push_id: Int?
    let major_anchor_level: String?
    let mode: String?
    let p2p_params: DouyinP2PParams?
    let rule_ids: String?
    let session_id: String?
    let stream: String?
    let stream_data_content_encoding: String?
    let stream_name: String?
    let ts: String?
    let version: Int?
}

struct DouyinCommonSDKParams: Codable {
    let main: String?
}

struct DouyinLines: Codable {
    let main: String?
}

struct DouyinP2PParams: Codable {
    let PcdnIsolationConfig: DouyinPcdnIsolationConfig?
}

struct DouyinPcdnIsolationConfig: Codable {
    let FsV4Domain: String?
    let FsV6Domain: String?
    let HoleV4Domain: String?
    let HoleV6Domain: String?
    let IsolationName: String?
    let StunV4Domain: String?
    let StunV6Domain: String?
}

struct DouyinStreamOptions: Codable {
    let default_quality: DouyinQuality?
    let qualities: [DouyinQuality]?
}

struct DouyinQuality: Codable {
    let additional_content: String?
    let disable: Int?
    let fps: Int?
    let level: Int?
    let name: String?
    let resolution: String?
    let sdk_key: String?
    let v_bit_rate: Int?
    let v_codec: String?
}

struct DouyinStreamStreams: Codable {
    let ao: DouyinStreamQuality?
    let hd: DouyinStreamQuality?
    let ld: DouyinStreamQuality?
    let md: DouyinStreamQuality?
    let origin: DouyinStreamQuality?
    let sd: DouyinStreamQuality?
}

struct DouyinStreamQuality: Codable {
    let main: DouyinStreamMain?
}

struct DouyinStreamMain: Codable {
    let cmaf: String?
    let dash: String?
    let enableEncryption: Bool?
    let flv: String?
    let hls: String?
    let http_ts: String?
    let ll_hls: String?
    let lls: String?
    let sdk_params: String?
    let templateRealTimeInfo: DouyinTemplateRealTimeInfo?
    let tile: String?
    let tsl: String?
}

struct DouyinTemplateRealTimeInfo: Codable {
    let bitrateKbps: Double?
    let name: String?
    let updatedTime: Int64?
}

private var dyua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
private var browserVer = "141.0.0.0"
private var browserType = "edge"
private var fakeRoomId = "870887192950"


var headers = HTTPHeaders.init([
    "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7; application/json",
    "Authority": "live.douyin.com",
    "Referer": "https://live.douyin.com",
    "User-Agent": dyua,
])

public struct Douyin: LiveParse {}

extension Douyin {
    private static func ensureCookie(for roomId: String) async throws -> String {
        if let existing = headers["cookie"], existing.isEmpty == false {
            return existing
        }

        logDebug("抖音 Cookie 缺失，开始获取新 Cookie，房间ID: \(roomId)")
        let cookie = try await Douyin.getCookie(roomId: roomId)
        headers["cookie"] = cookie
        logInfo("已刷新抖音 Cookie")
        return cookie
    }

    private static func buildRequestDetail(
        url: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        parameters: Parameters? = nil
    ) -> NetworkRequestDetail {
        return NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters
        )
    }

    private static func appendNonce(to cookie: String) -> String {
        if cookie.contains("__ac_nonce") {
            return cookie
        }
        return cookie + (cookie.hasSuffix(";") ? "" : ";") + "__ac_nonce=\(String.generateRandomString(length: 21))"
    }

    private static func cookieWithNonce() async throws -> String {
        let cookie = try await ensureCookie(for: fakeRoomId)
        return appendNonce(to: cookie)
    }

    private static func fetchFinalURL(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw LiveParseError.network(.invalidURL(urlString))
        }

        let requestDetail = NetworkRequestDetail(url: urlString, method: "GET")
        logDebug("请求抖音分享重定向: \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LiveParseError.network(.invalidResponse(request: requestDetail, response: nil))
            }

            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
                if let key = item.key as? String {
                    result[key] = "\(item.value)"
                }
            }

            let bodyString = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            let responseDetail = NetworkResponseDetail(
                statusCode: httpResponse.statusCode,
                headers: headers,
                body: bodyString
            )

            if httpResponse.statusCode >= 400 {
                throw LiveParseError.network(.serverError(
                    statusCode: httpResponse.statusCode,
                    message: bodyString ?? "未知错误",
                    request: requestDetail,
                    response: responseDetail
                ))
            }

            let finalURL = httpResponse.url?.absoluteString ?? urlString
            logInfo("抖音分享重定向成功，最终地址: \(finalURL)")
            return finalURL
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.network(
                .requestFailed(
                    request: requestDetail,
                    response: nil,
                    underlyingError: error
                )
            )
        }

    }

    private static func generateSignature(for stub: String, userAgent: String = dyua) throws -> String {
        let jsDom = """
                document = {};
                window = {};
                navigator = {
                'userAgent': '\(userAgent)'
                };
                """
        let jsContext = JSContext()

        guard let jsPath = Bundle.module.path(forResource: "webmssdk", ofType: "js") else {
            throw LiveParseError.parse(
                .missingRequiredField(
                    field: "webmssdk.js",
                    location: "\(#file):\(#line)",
                    response: nil
                )
            )
        }

        do {
            let script = try String(contentsOfFile: jsPath)
            jsContext?.evaluateScript(jsDom + script)
        } catch {
            throw LiveParseError.parse(
                .invalidDataFormat(
                    expected: "有效的 webmssdk 脚本",
                    actual: error.localizedDescription,
                    location: "\(#file):\(#line)"
                )
            )
        }

        guard let signature = jsContext?.evaluateScript("get_sign('\(stub)')").toString(), signature.isEmpty == false else {
            throw LiveParseError.parse(
                .missingRequiredField(
                    field: "a_bogus",
                    location: "\(#file):\(#line)",
                    response: nil
                )
            )
        }

        return signature
    }


    public static func getCategoryList() async throws -> [LiveMainListModel] {
        logDebug("开始获取抖音分类列表")

        let cookie = try await ensureCookie(for: fakeRoomId)
        headers["cookie"] = cookie

        let url = "https://live.douyin.com"
        let pageHTML = try await LiveParseRequest.requestString(url, headers: headers)
        
        let pattern = "categoryData.*?\\]\\)"
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            logError("抖音分类正则编译失败: \(error.localizedDescription)")
            throw LiveParseError.parse(
                .regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: nil
                )
            )
        }

        guard let match = regex.firstMatch(in: pageHTML, range: NSRange(location: 0, length: pageHTML.count)),
              let range = Range(match.range, in: pageHTML) else {
            logWarning("未从抖音页面解析到分类数据")
            throw LiveParseError.parse(
                .regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: pageHTML
                )
            )
        }

        var matchedSubstring = String(pageHTML[range])
        if matchedSubstring.count >= 6 {
            matchedSubstring = String(matchedSubstring.dropLast(6))
        }

        let cleanedString = ("{\"" + matchedSubstring).replacingOccurrences(of: "\\", with: "")

        guard let jsonData = cleanedString.data(using: .utf8) else {
            throw LiveParseError.parse(
                .invalidDataFormat(
                    expected: "UTF-8 字符串",
                    actual: "nil",
                    location: "\(#file):\(#line)"
                )
            )
        }

        let decodedModel: DouyinMainModel
        do {
            decodedModel = try JSONDecoder().decode(DouyinMainModel.self, from: jsonData)
        } catch {
            logError("抖音分类数据解析失败: \(error.localizedDescription)")
            throw LiveParseError.parse(
                .decodingFailed(
                    type: "DouyinMainModel",
                    location: "\(#file):\(#line)",
                    response: nil,
                    underlyingError: error
                )
            )
        }

        var result: [LiveMainListModel] = []

        for item in decodedModel.categoryData {
            if item.sub_partition?.isEmpty == true {
                let subList = [LiveCategoryModel(
                    id: item.partition.id_str,
                    parentId: "\(item.partition.type)",
                    title: item.partition.title,
                    icon: ""
                )]
                result.append(LiveMainListModel(
                    id: item.partition.id_str,
                    title: item.partition.title,
                    icon: "",
                    subList: subList
                ))
                continue
            }

            guard let subPartition = item.sub_partition else { continue }

            if subPartition.isEmpty {
                let subList = [LiveCategoryModel(
                    id: item.partition.id_str,
                    parentId: item.partition.id_str,
                    title: item.partition.title,
                    icon: ""
                )]
                result.append(LiveMainListModel(
                    id: item.partition.id_str,
                    title: item.partition.title,
                    icon: "",
                    subList: subList
                ))
                continue
            }

            var subList: [LiveCategoryModel] = []

            for subItem in subPartition {
                if let thirdPartition = subItem.sub_partition, thirdPartition.isEmpty == false {
                    var thirdList: [LiveCategoryModel] = []
                    for thirdItem in thirdPartition {
                        thirdList.append(LiveCategoryModel(
                            id: thirdItem.partition.id_str,
                            parentId: "\(thirdItem.partition.type)",
                            title: thirdItem.partition.title,
                            icon: ""
                        ))
                    }
                    result.append(LiveMainListModel(
                        id: subItem.partition.id_str,
                        title: subItem.partition.title,
                        icon: "",
                        subList: thirdList
                    ))
                } else {
                    subList.append(LiveCategoryModel(
                        id: subItem.partition.id_str,
                        parentId: "\(subItem.partition.type)",
                        title: subItem.partition.title,
                        icon: ""
                    ))
                }
            }

            if !subList.isEmpty {
                result.append(LiveMainListModel(
                    id: item.partition.id_str,
                    title: item.partition.title,
                    icon: "",
                    subList: subList
                ))
            }
        }

        guard !result.isEmpty else {
            logWarning("抖音分类结果为空")
            throw LiveParseError.business(
                .emptyResult(
                    location: "\(#file):\(#line)",
                    request: buildRequestDetail(url: url, method: .get, headers: headers)
                )
            )
        }

        logInfo("成功获取抖音分类列表，共 \(result.count) 个分类")
        return result
    }

    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        logDebug("开始获取抖音直播间列表，分类ID: \(id), 页码: \(page)")

        let parameters: [String: String] = [
            "aid": "6383",
            "app_name": "douyin_web",
            "live_id": "1",
            "device_platform": "web",
            "language": "zh-CN",
            "enter_from": "link_share",
            "cookie_enabled": "true",
            "screen_width": "1980",
            "screen_height": "1080",
            "browser_language": "zh-CN",
            "browser_platform": "Win32",
            "browser_name": "Edge",
            "browser_version": "139.0.0.0",
            "browser_online": "true",
            "count": "15",
            "offset": "\((page - 1) * 15)",
            "partition": id,
            "partition_type": parentId ?? "",
            "req_from": "2"
        ]

        let urlParams = parameters
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")

        let baseCookie = try await ensureCookie(for: fakeRoomId)
        headers["cookie"] = baseCookie

        let signature = try generateSignature(for: urlParams, userAgent: dyua)
        let requestUrl = "https://live.douyin.com/webcast/web/partition/detail/room/v2/?\(urlParams)&a_bogus=\(signature)"
        let cookieHeader = try await cookieWithNonce()
        let requestHeaders = HTTPHeaders([
            "Accept": "application/json, text/plain, */*",
            "Authority": "live.douyin.com",
            "Referer": "https://live.douyin.com/",
            "User-Agent": dyua,
            "Cookie": cookieHeader
        ])

        let response: DouyinRoomMainResponse = try await LiveParseRequest.get(
            requestUrl,
            headers: requestHeaders
        )

        let rooms = response.data.data
        guard rooms.isEmpty == false else {
            logWarning("抖音直播间列表为空，分类ID: \(id)")
            throw LiveParseError.business(
                .emptyResult(
                    location: "\(#file):\(#line)",
                    request: buildRequestDetail(url: requestUrl, method: .get, headers: requestHeaders)
                )
            )
        }

        let result = rooms.map { item in
            LiveModel(
                userName: item.room.owner.nickname,
                roomTitle: item.room.title,
                roomCover: item.room.cover.url_list.first ?? "",
                userHeadImg: item.room.owner.avatar_thumb.url_list.first ?? "",
                liveType: .douyin,
                liveState: "",
                userId: item.room.id_str,
                roomId: item.web_rid ?? "",
                liveWatchedCount: item.room.stats.user_count_str ?? ""
            )
        }

        logInfo("成功获取抖音直播间列表，共 \(result.count) 个房间")
        return result
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        logDebug("开始获取抖音播放地址，房间ID: \(roomId)")

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
                            logInfo("成功获取抖音播放地址（JSON 流）共 \(tempArray.count) 条")
                            return [qualityFlv, qualityHls]
                        } catch {
                            logError("抖音播放地址 JSON 解析失败: \(error.localizedDescription)")
                        }
                    }
                }
                
                // 尝试从htmlStreamData解析流媒体URL
                if tempArray.isEmpty, let htmlStreamData = liveData.htmlStreamData {
                    // H265流数据解析
                    if let h265StreamData = htmlStreamData.H265_streamData?.stream {
                        tempArray.append(contentsOf: extractStreamUrls(from: h265StreamData, roomId: roomId, codec: "H265"))
                    }
                    
                    // H264流数据解析
                    if let h264StreamData = htmlStreamData.H264_streamData?.stream {
                        tempArray.append(contentsOf: extractStreamUrls(from: h264StreamData, roomId: roomId, codec: "H264"))
                    }
                    
                    if !tempArray.isEmpty {
                        var qualityHls = LiveQualityModel(cdn: "线路 HLS", qualitys: [])
                        var qualityFlv = LiveQualityModel(cdn: "线路 FLV", qualitys: [])
                        var qualityLls = LiveQualityModel(cdn: "线路 LLS", qualitys: [])
                        
                        for model in tempArray {
                            switch model.liveCodeType {
                            case .hls:
                                qualityHls.qualitys.append(model)
                            case .flv:
                                qualityFlv.qualitys.append(model)
                            default:
                                qualityFlv.qualitys.append(model)
                            }
                        }
                        
                        var result: [LiveQualityModel] = []
                        if !qualityHls.qualitys.isEmpty { result.append(qualityHls) }
                        // HTML 数据暂未返回 FLV/LLS 线路，后续可按需开启
                        logInfo("成功获取抖音播放地址（HTML 流）共 \(tempArray.count) 条")
                        return result
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
                    logInfo("成功获取抖音播放地址（HLS 兜底）共 \(tempArray.count) 条")
                    return [.init(cdn: "线路 1", qualitys: tempArray)]
                }
            }
            logWarning("抖音播放地址为空，房间ID: \(roomId)")
            throw LiveParseError.business(
                .emptyResult(
                    location: "\(#file):\(#line)",
                    request: nil
                )
            )
        }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        logDebug("开始搜索抖音直播间，关键词: \(keyword), 页码: \(page)")

        let serverUrl = "https://www.douyin.com/aweme/v1/web/live/search/"
        guard var components = URLComponents(string: serverUrl) else {
            throw LiveParseError.network(.invalidURL(serverUrl))
        }
        components.scheme = "https"
        components.port = 443

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

        var stubParams: [String: String] = [:]
        for item in queryItems {
            stubParams[item.name] = item.value ?? ""
        }

        let signatureStub = Douyin.getXMsStub(params: stubParams)
        let signature = try generateSignature(
            for: signatureStub,
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        )

        guard let baseURL = components.url else {
            throw LiveParseError.network(.invalidURL(serverUrl))
        }

        let requestUrl = baseURL.absoluteString + "a_bogus=\(signature)"
        let refererKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword

        let baseCookie = try await ensureCookie(for: fakeRoomId)
        headers["cookie"] = baseCookie
        let cookieHeader = try await cookieWithNonce()

        let requestHeaders = HTTPHeaders([
            "Accept": "application/json, text/plain, */*",
            "Authority": "live.douyin.com",
            "Referer": "https://www.douyin.com/search/\(refererKeyword)?source=switch_tab&type=live",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
            "Cookie": cookieHeader
        ])

        let response: DouyinSearchMain = try await LiveParseRequest.get(
            requestUrl,
            headers: requestHeaders
        )

        var models: [LiveModel] = []
        for item in response.data {
            guard let rawData = item.lives.rawdata.data(using: .utf8) else {
                logWarning("抖音搜索结果原始数据为空，已跳过")
                continue
            }

            do {
                let dict = try JSON(data: rawData)
                models.append(
                    LiveModel(
                        userName: dict["owner"]["nickname"].stringValue,
                        roomTitle: dict["title"].stringValue,
                        roomCover: dict["cover"]["url_list"][0].stringValue,
                        userHeadImg: dict["owner"]["avatar_thumb"]["url_list"][0].stringValue,
                        liveType: .douyin,
                        liveState: "",
                        userId: dict["id_str"].stringValue,
                        roomId: dict["owner"]["web_rid"].stringValue,
                        liveWatchedCount: dict["user_count"].stringValue
                    )
                )
            } catch {
                logError("抖音搜索结果解析失败: \(error.localizedDescription)")
            }
        }

        guard models.isEmpty == false else {
            logWarning("抖音搜索结果为空，关键词: \(keyword)")
            throw LiveParseError.business(
                .emptyResult(
                    location: "\(#file):\(#line)",
                    request: buildRequestDetail(url: requestUrl, method: .get, headers: requestHeaders)
                )
            )
        }

        logInfo("成功搜索抖音直播间，共 \(models.count) 个结果")
        return models
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        logDebug("开始获取抖音房间最新信息，房间ID: \(roomId)")

        let detail = try await getDouyinRoomDetail(roomId: roomId, userId: userId ?? "")

        guard let roomInfo = detail.data?.data?.first else {
            logWarning("未找到抖音房间信息，房间ID: \(roomId)")
            throw LiveParseError.business(.roomNotFound(roomId: roomId))
        }

        var liveState = LiveState.unknow
        switch roomInfo.status {
        case 4:
            liveState = .close
        case 2:
            let playArgs = try await getPlayArgs(roomId: roomId, userId: userId)
            if let firstQuality = playArgs.first, firstQuality.qualitys.isEmpty == false {
                liveState = .live
            } else {
                liveState = .close
            }
        default:
            liveState = .unknow
        }

        let model = LiveModel(
            userName: detail.data?.user?.nickname ?? "",
            roomTitle: roomInfo.title ?? "",
            roomCover: roomInfo.cover?.url_list?.first ?? "",
            userHeadImg: detail.data?.user?.avatar_thumb?.url_list?.first ?? "",
            liveType: .douyin,
            liveState: liveState.rawValue,
            userId: userId ?? roomInfo.id_str ?? "",
            roomId: roomId,
            liveWatchedCount: roomInfo.user_count_str ?? ""
        )

        logInfo("成功获取抖音房间最新信息，状态: \(liveState)")
        return model
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        logDebug("开始获取抖音房间状态，房间ID: \(roomId)")

        let detail = try await Douyin.getDouyinRoomDetail(roomId: roomId, userId: userId ?? "")
        guard let status = detail.data?.data?.first?.status else {
            logWarning("未找到抖音房间状态，房间ID: \(roomId)")
            throw LiveParseError.business(.roomNotFound(roomId: roomId))
        }

        let state: LiveState
        switch status {
        case 4:
            state = .close
        case 2:
            state = .live
        default:
            state = .unknow
        }

        logInfo("获取抖音房间状态成功，状态: \(state)")
        return state
    }
    
    static func getDouyinRoomDetail(roomId: String, userId: String) async throws -> DouyinRoomPlayInfoMainData {
        var apiErrorCount = 0
        var lastError: Error?

        while apiErrorCount < 3 {
            do {
                return try await Douyin._getRoomDetailByWebRidApi(roomId, userId: userId)
            } catch let error as LiveParseError {
                apiErrorCount += 1
                lastError = error
                logWarning("抖音房间详情 API 获取失败，正在重试 (\(apiErrorCount)/3)：\(error)")
                if apiErrorCount < 3 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            } catch {
                apiErrorCount += 1
                lastError = error
                logWarning("抖音房间详情 API 获取出现未知错误：\(error.localizedDescription)，重试计数 \(apiErrorCount)/3")
                if apiErrorCount < 3 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }

        logInfo("抖音房间详情 API 连续失败3次，尝试 HTML 方案")

        do {
            return try await Douyin._getRoomDetailByWebRidHtml(roomId)
        } catch let error as LiveParseError {
            logError("抖音房间详情 HTML 解析失败: \(error)")
            throw error
        } catch {
            logError("抖音房间详情 HTML 解析出现未知错误: \(error.localizedDescription)")
            if let lastError = lastError {
                throw LiveParseError.parse(
                    .invalidDataFormat(
                        expected: "抖音房间详情",
                        actual: lastError.localizedDescription,
                        location: "\(#file):\(#line)"
                    )
                )
            }
            throw LiveParseError.parse(
                .invalidDataFormat(
                    expected: "抖音房间详情",
                    actual: error.localizedDescription,
                    location: "\(#file):\(#line)"
                )
            )
        }
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        logDebug("开始解析抖音分享链接: \(shareCode)")

        if shareCode.contains("v.douyin.com") {
            let resolvedUrl = shareCode.getUrlStringWithShareCode()
            let redirectUrl = try await fetchFinalURL(resolvedUrl)

            let roomPattern = "douyin/webcast/reflow/(\\d+)"
            let redirectNSString = redirectUrl as NSString
            let roomRegex: NSRegularExpression
            do {
                roomRegex = try NSRegularExpression(pattern: roomPattern)
            } catch {
                throw LiveParseError.parse(
                    .regexMatchFailed(
                        pattern: roomPattern,
                        location: "\(#file):\(#line)",
                        rawData: nil
                    )
                )
            }

            guard let roomMatch = roomRegex.matches(in: redirectUrl, range: NSRange(location: 0, length: redirectNSString.length)).first else {
                throw LiveParseError.parse(
                    .regexMatchFailed(
                        pattern: roomPattern,
                        location: "\(#file):\(#line)",
                        rawData: redirectUrl
                    )
                )
            }

            let roomId = redirectNSString.substring(with: roomMatch.range(at: 1))

            let secUserPattern = "sec_user_id=([\\w\\d_\\-]+)&"
            let secRegex = try? NSRegularExpression(pattern: secUserPattern)
            var secUserId = ""
            if let secRegex = secRegex,
               let secMatch = secRegex.matches(in: redirectUrl, range: NSRange(location: 0, length: redirectNSString.length)).first {
                secUserId = redirectNSString.substring(with: secMatch.range(at: 1))
            }

            let requestUrl = "https://webcast.amemv.com/webcast/room/reflow/info/?verifyFp=verify_lk07kv74_QZYCUApD_xhiB_405x_Ax51_GYO9bUIyZQVf&type_id=0&live_id=1&room_id=\(roomId)&sec_user_id=\(secUserId)&app_id=1128&msToken=wrqzbEaTlsxt52-vxyZo_mIoL0RjNi1ZdDe7gzEGMUTVh_HvmbLLkQrA_1HKVOa2C6gkxb6IiY6TY2z8enAkPEwGq--gM-me3Yudck2ailla5Q4osnYIHxd9dI4WtQ=="
            let response: DouyinSecUserIdRoomData = try await LiveParseRequest.get(
                requestUrl,
                headers: HTTPHeaders([
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                    "Accept-Language": "zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2",
                    "Cookie": "s_v_web_id=verify_lk07kv74_QZYCUApD_xhiB_405x_Ax51_GYO9bUIyZQVf"
                ])
            )

            let liveStatus: String
            switch response.data.room.status {
            case 4, 0:
                liveStatus = LiveState.close.rawValue
            case 2:
                liveStatus = LiveState.live.rawValue
            default:
                liveStatus = LiveState.unknow.rawValue
            }

            let model = LiveModel(
                userName: response.data.room.owner.nickname,
                roomTitle: response.data.room.title,
                roomCover: response.data.room.cover.url_list.first ?? "",
                userHeadImg: response.data.room.owner.avatar_thumb.url_list.first ?? "",
                liveType: .douyin,
                liveState: liveStatus,
                userId: response.data.room.id_str,
                roomId: response.data.room.owner.web_rid ?? "",
                liveWatchedCount: response.data.room.user_count_str ?? ""
            )

            logInfo("成功解析抖音短链接分享，房间ID: \(model.roomId)")
            return model
        }

        if shareCode.contains("live.douyin.com") {
            let pattern = "live.douyin.com/(\\d+)"
            let regex = try? NSRegularExpression(pattern: pattern)
            let nsString = shareCode as NSString
            if let match = regex?.matches(in: shareCode, range: NSRange(location: 0, length: nsString.length)).first {
                let roomId = nsString.substring(with: match.range(at: 1))
                logInfo("成功解析抖音长链接分享，房间ID: \(roomId)")
                return try await Douyin.getLiveLastestInfo(roomId: roomId, userId: roomId)
            }

            throw LiveParseError.parse(
                .regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: shareCode
                )
            )
        }

        let model = try await Douyin.getLiveLastestInfo(roomId: shareCode, userId: nil)
        logInfo("解析抖音房间号成功，房间ID: \(model.roomId)")
        return model
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        logDebug("开始生成抖音弹幕参数，房间ID: \(roomId)")

        do {
            let room = try await getLiveLastestInfo(roomId: roomId, userId: nil)
            let finalUserId = room.userId
            let userUniqueId = Douyin.getUserUniqueId()

            headers["cookie"] = appendNonce(to: try await getCookie(roomId: roomId))

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
                "identity": "audience"
            ]

            let xmsStub = Douyin.getXMsStub(params: sigParams)
            let signature = try generateSignature(
                for: xmsStub,
                userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            )

            let payload: [String: String] = [
                "room_id": finalUserId,
                "compress": "gzip",
                "version_code": "180800",
                "webcast_sdk_version": "1.0.14-beta.0",
                "live_id": "1",
                "did_rule": "3",
                "user_unique_id": userUniqueId,
                "identity": "audience",
                "signature": signature,
                "aid": "6383",
                "device_platform": "web",
                "browser_language": "zh-CN",
                "browser_platform": "MacIntel",
                "browser_name": "Mozilla",
                "browser_version": "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            ]

            let headerPayload: [String: String] = [
                "cookie": headers["cookie"] ?? "",
                "User-Agnet": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            ]

            logInfo("生成抖音弹幕参数成功，房间ID: \(finalUserId)")
            return (payload, headerPayload)
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.websocket(
                .authenticationFailed(
                    platform: .douyin,
                    request: nil
                )
            )
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
        headers.add(HTTPHeader(name: "cookie", value: try await getCookie(roomId: fakeRoomId)))
    }
    
    public static func getUserUniqueId(roomId: String) async throws -> String {
        logDebug("获取抖音 userUniqueId，房间ID: \(roomId)")

        var requestHeaders = headers
        requestHeaders.add(name: "cookie", value: try await Douyin.getCookie(roomId: roomId))
        requestHeaders.add(name: "Authority", value: "live.douyin.com")
        requestHeaders.add(name: "Referer", value: "https://live.douyin.com/\(roomId)")
        requestHeaders.add(name: "Accept", value: "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7")

        let html = try await LiveParseRequest.requestString(
            "https://live.douyin.com/\(roomId)",
            headers: requestHeaders
        )

        do {
            let regex = try NSRegularExpression(pattern: "user_unique_id.*?,", options: [])
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.count))
            for match in matches {
                guard let range = Range(match.range, in: html) else { continue }
                let candidate = String(html[range])
                logDebug("匹配到 user_unique_id 片段: \(candidate)")
                let uidRegex = try NSRegularExpression(pattern: "[1-9]+\\.?[0-9]*", options: [])
                let uidMatches = uidRegex.matches(in: candidate, range: NSRange(location: 0, length: candidate.count))
                if let uidMatch = uidMatches.first, let uidRange = Range(uidMatch.range, in: candidate) {
                    let uniqueId = String(candidate[uidRange])
                    logInfo("获取 user_unique_id 成功: \(uniqueId)")
                    return uniqueId
                }
            }
        } catch {
            logWarning("解析 user_unique_id 失败: \(error.localizedDescription)")
            return ""
        }

        logWarning("未找到 user_unique_id，返回空字符串")
        return ""
    }
    
    public static func getCookie(roomId: String) async throws -> String {
        let urlString = "https://live.douyin.com/\(roomId)"
        logDebug("获取抖音 Cookie，房间ID: \(roomId)")

        guard let url = URL(string: urlString) else {
            throw LiveParseError.network(.invalidURL(urlString))
        }

        let requestDetail = NetworkRequestDetail(url: urlString, method: "GET")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LiveParseError.network(.invalidResponse(request: requestDetail, response: nil))
            }

            guard let setCookieHeaders = httpResponse.allHeaderFields["Set-Cookie"] as? String else {
                let fallback = "ttwid=\(try await DouyinUtils.getTtwid());__ac_nonce=\(String.generateRandomString(length: 21));\(DouyinUtils.generateMsToken())"
                logWarning("未获取到 Set-Cookie 头，使用默认 Cookie")
                return fallback
            }

            var dyCookie = ""
            let cookies = setCookieHeaders.components(separatedBy: ",")
            for cookieString in cookies {
                let cookie = cookieString.components(separatedBy: ";")[0].trimmingCharacters(in: .whitespaces)
                if cookie.contains("ttwid") {
                    dyCookie += "\(cookie);"
                } else {
                    dyCookie += "ttwid=\(try await DouyinUtils.getTtwid());"
                }

                if cookie.contains("__ac_nonce") {
                    dyCookie += "\(cookie);"
                } else {
                    dyCookie += "__ac_nonce=\(String.generateRandomString(length: 21));"
                }

                if cookie.contains("msToken") {
                    dyCookie += "\(cookie);"
                } else {
                    dyCookie += "\(DouyinUtils.generateMsToken())"
                }
            }

            logInfo("获取抖音 Cookie 成功")
            return dyCookie
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.network(
                .requestFailed(
                    request: requestDetail,
                    response: nil,
                    underlyingError: error
                )
            )
        }
    }
    
//    public static func signURL(_ url: String) async throws -> DouyinTKData {
// 
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
    
    // 从流数据中提取URL的辅助函数
    private static func extractStreamUrls(from streams: DouyinStreamStreams, roomId: String, codec: String) -> [LiveQualityDetail] {
        var tempArray: [LiveQualityDetail] = []
        
        // 原画质量
        if let originMain = streams.origin?.main {
            if let flvUrl = originMain.flv, !flvUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "原画_\(codec)_FLV", qn: 0, url: flvUrl, liveCodeType: .flv, liveType: .douyin))
            }
            if let hlsUrl = originMain.hls, !hlsUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "原画_\(codec)_HLS", qn: 0, url: hlsUrl, liveCodeType: .hls, liveType: .douyin))
            }
        }
        
        // 超清质量
        if let hdMain = streams.hd?.main {
            if let flvUrl = hdMain.flv, !flvUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "超清_\(codec)_FLV", qn: 0, url: flvUrl, liveCodeType: .flv, liveType: .douyin))
            }
            if let hlsUrl = hdMain.hls, !hlsUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "超清_\(codec)_HLS", qn: 0, url: hlsUrl, liveCodeType: .hls, liveType: .douyin))
            }
        }
        
        // 高清质量
        if let sdMain = streams.sd?.main {
            if let flvUrl = sdMain.flv, !flvUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "高清_\(codec)_FLV", qn: 0, url: flvUrl, liveCodeType: .flv, liveType: .douyin))
            }
            if let hlsUrl = sdMain.hls, !hlsUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "高清_\(codec)_HLS", qn: 0, url: hlsUrl, liveCodeType: .hls, liveType: .douyin))
            }
        }
        
        // 标清质量
        if let ldMain = streams.ld?.main {
            if let flvUrl = ldMain.flv, !flvUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "标清_\(codec)_FLV", qn: 0, url: flvUrl, liveCodeType: .flv, liveType: .douyin))
            }
            if let hlsUrl = ldMain.hls, !hlsUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "标清_\(codec)_HLS", qn: 0, url: hlsUrl, liveCodeType: .hls, liveType: .douyin))
            }
        }
        
        // 标清2质量
        if let mdMain = streams.md?.main {
            if let flvUrl = mdMain.flv, !flvUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "标清2_\(codec)_FLV", qn: 0, url: flvUrl, liveCodeType: .flv, liveType: .douyin))
            }
            if let hlsUrl = mdMain.hls, !hlsUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "标清2_\(codec)_HLS", qn: 0, url: hlsUrl, liveCodeType: .hls, liveType: .douyin))
            }
        }
        
        // 音频
        if let aoMain = streams.ao?.main {
            if let flvUrl = aoMain.flv, !flvUrl.isEmpty {
                tempArray.append(.init(roomId: roomId, title: "音频_\(codec)_FLV", qn: 0, url: flvUrl, liveCodeType: .flv, liveType: .douyin))
            }
        }
        
        return tempArray
    }
    
    private static func generateRandomNumber(digits: Int) -> String {
        var result = ""
        for _ in 0..<digits {
            result += String(Int.random(in: 0...9))
        }
        return result
    }
    
    private static func _getRoomDataByApi(_ webRid: String, userId: String) async throws -> DouyinRoomPlayInfoMainData {
        let url = "https://live.douyin.com/webcast/room/web/enter/"
        let urlParams = DouyinUtils.buildRequestUrl(roomId: webRid, userId: userId)
        let customFP = BrowserFingerprintGenerator.generateFingerprint(browserType: browserType)
        let abogus = ABogus(fp: customFP, userAgent: dyua)
        let signature = abogus.generateAbogus(params: urlParams).1
        let cookie = try await Douyin.getCookie(roomId: webRid)

        var requestHeaders = headers
        requestHeaders.add(name: "cookie", value: cookie)
        requestHeaders.add(name: "accept", value: "application/json, text/plain, */*")

        let requestUrl = "\(url)?\(urlParams)&a_bogus=\(signature)"
        logDebug("抖音房间详情请求 URL: \(requestUrl)")

        let response: DouyinRoomPlayInfoMainData = try await LiveParseRequest.get(
            requestUrl,
            headers: requestHeaders
        )

        return response

    }
    
    private static func _getRoomDataByHtml(_ webRid: String) async throws -> [String: Any] {
        logDebug("通过 HTML 获取抖音房间详情，房间ID: \(webRid)")

        let cookie = try await Douyin.getCookie(roomId: webRid)
        var requestHeaders = headers
        requestHeaders.add(name: "cookie", value: cookie)
        requestHeaders.add(name: "Referer", value: "https://live.douyin.com/\(webRid)")

        let requestUrl = "https://live.douyin.com/\(webRid)"
        let htmlResponse = try await LiveParseRequest.requestString(
            requestUrl,
            headers: requestHeaders
        )

        let pattern = "(\\{\\\\\"state\\\\\":\\{\\\\\"appStore.*?\\]\\\\n)"
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            throw LiveParseError.parse(
                .regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: nil
                )
            )
        }

        let matches = regex.matches(in: htmlResponse, range: NSRange(location: 0, length: htmlResponse.count))

        guard let match = matches.first, let matchRange = Range(match.range(at: 1), in: htmlResponse) else {
            throw LiveParseError.parse(
                .regexMatchFailed(
                    pattern: pattern,
                    location: "\(#file):\(#line)",
                    rawData: htmlResponse
                )
            )
        }

        var jsonString = String(htmlResponse[matchRange])
        jsonString = jsonString
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "]\\n", with: "")

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LiveParseError.parse(
                .invalidDataFormat(
                    expected: "UTF-8 字符串",
                    actual: "nil",
                    location: "\(#file):\(#line)"
                )
            )
        }

        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                logInfo("通过 HTML 获取抖音房间详情成功")
                return jsonObject
            }
        } catch {
            throw LiveParseError.parse(
                .invalidJSON(
                    location: "\(#file):\(#line)",
                    request: buildRequestDetail(url: requestUrl, method: .get, headers: requestHeaders),
                    response: nil
                )
            )
        }

        throw LiveParseError.parse(
            .invalidDataFormat(
                expected: "字典对象",
                actual: "nil",
                location: "\(#file):\(#line)"
            )
        )
    }
    
    static func _getRoomDetailByWebRidApi(_ roomId: String, userId: String) async throws -> DouyinRoomPlayInfoMainData {
        return try await _getRoomDataByApi(roomId, userId: userId)
    }
    
    static func _getRoomDetailByWebRidHtml(_ webRid: String) async throws -> DouyinRoomPlayInfoMainData {
        let roomData = try await _getRoomDataByHtml(webRid)
        
        guard let state = roomData["state"] as? [String: Any],
              let roomStore = state["roomStore"] as? [String: Any],
              let streamStore = state["streamStore"] as? [String: Any],
              let roomInfo = roomStore["roomInfo"] as? [String: Any],
              let room = roomInfo["room"] as? [String: Any],
              let userStore = state["userStore"] as? [String: Any],
              let odin = userStore["odin"] as? [String: Any] else {
            throw LiveParseError.parse(
                .missingRequiredField(
                    field: "state/roomStore/streamStore",
                    location: "\(#file):\(#line)",
                    response: nil
                )
            )
        }
        
        let roomId = room["id_str"] as? String ?? ""
        let userUniqueId = odin["user_unique_id"] as? String ?? ""

        let owner = room["owner"] as? [String: Any]
        let anchor = roomInfo["anchor"] as? [String: Any]
        
        let roomStatus = (room["status"] as? Int ?? 0) == 2
        
        let cookie = try await getCookie(roomId: webRid)
        
        // 构建DouyinLiveUserInfo
        let userInfo = DouyinLiveUserInfo(
            id_str: roomId,
            nickname: roomStatus ? (owner?["nickname"] as? String) : (anchor?["nickname"] as? String),
            avatar_thumb: DouyinLiveUserAvatarInfo(
                url_list: roomStatus ? 
                    ((owner?["avatar_thumb"] as? [String: Any])?["url_list"] as? [String]) :
                    ((anchor?["avatar_thumb"] as? [String: Any])?["url_list"] as? [String])
            )
        )
        
        // 转换streamData字典到DouyinStreamDataResponse模型
        var htmlStreamData: DouyinStreamDataResponse?
        if let streamDataDict = streamStore["streamData"] as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: streamDataDict, options: [])
                htmlStreamData = try JSONDecoder().decode(DouyinStreamDataResponse.self, from: jsonData)
            } catch {
                logWarning("解析 HTML streamData 失败: \(error.localizedDescription)")
            }
        }
        
        // 构建DouyinPlayQualitiesInfo
        let playQualitiesInfo = DouyinPlayQualitiesInfo(
            status: room["status"] as? Int,
            stream_url: DouyinPlayQualities(
                hls_pull_url_map: DouyinPlayQualitiesHlsMap(
                    FULL_HD1: ((room["stream_url"] as? [String: Any])?["hls_pull_url_map"] as? [String: Any])?["FULL_HD1"] as? String,
                    HD1: ((room["stream_url"] as? [String: Any])?["hls_pull_url_map"] as? [String: Any])?["HD1"] as? String,
                    SD1: ((room["stream_url"] as? [String: Any])?["hls_pull_url_map"] as? [String: Any])?["SD1"] as? String,
                    SD2: ((room["stream_url"] as? [String: Any])?["hls_pull_url_map"] as? [String: Any])?["SD2"] as? String
                ), live_core_sdk_data: DouyinLiveCoreSDKData(pull_data: DouyinLivePullData(stream_data: (((room["stream_url"] as? [String: Any])?["live_core_sdk_data"] as? [String: Any])?["pull_data"] as? [String: Any])?["stream_data"] as? String ?? ""))
            ),
            id_str: roomId,
            title: room["title"] as? String,
            user_count_str: ((room["room_view_stats"] as? [String: Any])?["display_value"] as? Int)?.description, cover: DouyinLiveUserAvatarInfo(
                url_list: ((room["cover"] as? [String: Any])?["url_list"] as? [String])
            ),
            owner: DouyinRoomOwnerData(
                id_str: (owner?["id_str"] as? String) ?? "",
                sec_uid: (owner?["sec_uid"] as? String) ?? "",
                nickname: (owner?["nickname"] as? String) ?? "",
                web_rid: (owner?["web_rid"] as? String),
                avatar_thumb: DouyinRoomOwnerAvatarThumbData(
                    url_list: ((owner?["avatar_thumb"] as? [String: Any])?["url_list"] as? [String]) ?? []
                )
            ))
        // 构建DouyinRoomPlayInfoData
        let playInfoData = DouyinRoomPlayInfoData(
            data: [playQualitiesInfo],
            user: userInfo
        )
        
        return DouyinRoomPlayInfoMainData(data: playInfoData, htmlStreamData: htmlStreamData)
    }
}

public struct DouyinUtils {
    
    // 字符集定义，对应 Python 版本的 LONG_CHATSET
    private static let longCharset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    
    // 生成随机 msToken
    public static func generateMsToken() -> String {
        let charsetArray = Array(longCharset)
        var result = ""
        
        for _ in 0..<184 {
            let randomIndex = Int.random(in: 0..<charsetArray.count)
            result.append(charsetArray[randomIndex])
        }
        
        return result
    }
    
    // 更高效的版本，使用 SystemRandomNumberGenerator
    public static func generateMsTokenOptimized() -> String {
        let charsetArray = Array(longCharset)
        var generator = SystemRandomNumberGenerator()
        
        return String((0..<184).map { _ in
            charsetArray[Int.random(in: 0..<charsetArray.count, using: &generator)]
        })
    }
    
    public static func buildRequestUrl(roomId: String, userId: String) -> String {
        return "\("aid=6383&app_name=douyin_web&live_id=1&device_platform=web&language=zh-CN&enter_from=web_live&cookie_enabled=true&screen_width=1920&screen_height=1080&browser_language=zh-CN&browser_platform=\(browserType == "edge" ? "MacIntel" : "Win32")&browser_name=Chrome&browser_version=\(browserVer)&web_rid=\(roomId)&room_id_str=\(userId)&enter_source=&is_need_double_stream=false&insert_task_id=&live_reason=")"
    }
    
    public static func getTtwid() async -> String {
        do {
            // 创建 URL
            guard let url = URL(string:"https://ttwid.bytedance.com/ttwid/union/register/") else {
                return ""
            }
            // 创建请求
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // 创建请求体数据
            let requestData: [String: Any] = [
                "region": "cn",
                "aid": 1768,
                "needFid": false,
                "service": "www.ixigua.com",
                "migrate_info": [
                    "ticket": "",
                    "source": "node"
                ],
                "cbUrlProtocol": "https",
                "union": true
            ]
            
            // 将数据转换为 JSON
            request.httpBody = try JSONSerialization.data(withJSONObject:
                                                            requestData)
            
            // 发送请求
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // 获取 Set-Cookie header
            guard let httpResponse = response as? HTTPURLResponse,
                  let setCookieHeaders =
                    httpResponse.allHeaderFields["Set-Cookie"] as? String else {
                return ""
            }
            
            // 使用正则表达式提取 ttwid
            let pattern = "ttwid=([^;]+)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: setCookieHeaders, range:
                                                NSRange(setCookieHeaders.startIndex..., in: setCookieHeaders)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: setCookieHeaders) {
                return String(setCookieHeaders[range])
            }
            
            return ""
            
        } catch {
            logWarning("获取 ttwid 失败: \(error.localizedDescription)")
            return ""
        }
    }
}
