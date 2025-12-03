//
//  Huya.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/10/4.
//

import Foundation
import Alamofire
import CommonCrypto
import TarsKit

struct HuyaMainListModel: Codable {
    let id: String
    let name: String
    var list: Array<HuyaSubListModel>
}

struct HuyaMainData<T: Codable>: Codable {
    var status: Int
    var msg: String
    var data: T
}

struct HuyaSubListModel: Codable {
    let gid: Int
    let totalCount: Int
    let profileNum: Double
    let gameFullName: String
    //    let gameHostName: String?
    let gameType: Double
    let bussType: Double
    let isHide: Double
    let pic: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.gid = try container.decode(Int.self, forKey: .gid)
        self.totalCount = try container.decode(Int.self, forKey: .totalCount)
        self.profileNum = try container.decode(Double.self, forKey: .profileNum)
        self.gameFullName = try container.decode(String.self, forKey: .gameFullName)
        //        self.gameHostName = try container.decode(String?.self, forKey: .gameHostName)
        self.gameType = try container.decode(Double.self, forKey: .gameType)
        self.bussType = try container.decode(Double.self, forKey: .bussType)
        self.isHide = try container.decode(Double.self, forKey: .isHide)
        self.pic = "https://huyaimg.msstatic.com/cdnimage/game/\(gid)-MS.jpg"
    }
}

struct HuyaRoomMainData: Codable {
    var status: Int
    var message: String
    var data: HuyaRoomData
}

struct HuyaRoomData: Codable {
    let page: Int
    let pageSize: Int
    let totalPage: Int
    let totalCount: Int
    let datas: Array<HuyaRoomModel>
}

struct HuyaRoomModel: Codable {
    let nick: String
    let introduction: String
    let screenshot: String
    let avatar180: String
    let uid: String
    let profileRoom: String
    let totalCount: String
}


struct HuyaRoomInfoMainModel: Codable {
    let roomInfo: HuyaRoomInfoModel
    
}

struct HuyaRoomInfoModel: Codable {
    let eLiveStatus: Int
    let tLiveInfo: HuyaRoomTLiveInfo
    let tRecentLive: HuyaRoomTLiveInfo
    let tReplayInfo: HuyaRoomTLiveInfo?
}

struct HuyaRoomTLiveInfo: Codable {
    let lYyid: Int
    let tLiveStreamInfo: HuyaRoomTLiveStreamInfo?
    let sNick: String
    let sAvatar180: String
    let sIntroduction: String
    let sScreenshot: String
    let lTotalCount: Int
    let tReplayVideoInfo: HuyaReplayVideoInfo?
}

struct HuyaReplayVideoInfo: Codable {
    let sUrl: String
    let sHlsUrl: String
    let iVideoSyncTime: Int
}

struct HuyaRoomTLiveStreamInfo: Codable {
    let vStreamInfo: HuyaRoomVStreamInfo
    let vBitRateInfo:HuyaRoomBitRateInfo
}

struct HuyaRoomBitRateInfo: Codable {
    let value: Array<HuyaRoomLiveQualityModel>
}

struct HuyaRoomVStreamInfo: Codable {
    let value: Array<HuyaRoomLiveStreamModel>
}

struct HuyaRoomLiveStreamModel: Codable {
    let sCdnType: String //'AL': '阿里', 'TX': '腾讯', 'HW': '华为', 'HS': '火山', 'WS': '网宿', 'HY': '虎牙'
    let iIsMaster: Int
    let sStreamName: String
    let sFlvUrl: String
    let sFlvUrlSuffix: String
    let sFlvAntiCode: String
    let sHlsUrl: String
    let sHlsUrlSuffix: String
    let sHlsAntiCode: String
    let sCodec: String?
    let iMobilePriorityRate: Int
    let lChannelId: Int
    let lSubChannelId: Int
}

struct HuyaRoomLiveQualityModel: Codable {
    let sDisplayName: String
    let iBitRate: Int
    let iCodecType: Int
    let iCompatibleFlag: Int
    let iHEVCBitRate: Int
    
}

struct HuyaSearchResult: Codable {
    let response: HuyaSearchResponse
}

struct HuyaSearchResponse: Codable {
    let three: HuyaSearchDocses
    
    enum CodingKeys: String, CodingKey {
        case three = "3"
    }
}

struct HuyaSearchDocses: Codable {
    let docs: Array<HuyaSearchDocs>
}

struct HuyaSearchDocs: Codable {
    let game_nick: String
    let room_id: Int
    let uid: Int
    let game_introduction: String
    let game_imgUrl: String
    let game_screenshot: String
    let game_total_count: Int
}

public struct Huya: LiveParse {
    
    static let tupClient = TarsHttp(baseUrl: "http://wup.huya.com", servantName: "liveui")
    
    // MARK: - 正则表达式常量
    private static let roomIdPattern = "(?:huya\\.com/)(\\d+)"
    private static let htmlRoomIdPattern = "\"lProfileRoom\":(\\d+),"
    private static let urlPattern = "[a-zA-z]+://[^\\s]*"
    
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "1", title: "网游", icon: "", subList: try await getCategorySubList(id: "1")),
            LiveMainListModel(id: "2", title: "单机", icon: "", subList: try await getCategorySubList(id: "2")),
            LiveMainListModel(id: "8", title: "娱乐", icon: "", subList: try await getCategorySubList(id: "8")),
            LiveMainListModel(id: "3", title: "手游", icon: "", subList: try await getCategorySubList(id: "3")),
        ]
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        let dataReq: HuyaMainData<[HuyaSubListModel]> = try await LiveParseRequest.get(
            "https://live.cdn.huya.com/liveconfig/game/bussLive",
            parameters: [
                "bussType": id
            ]
        )

        var finalArray: [LiveCategoryModel] = []
        for item in dataReq.data {
            finalArray.append(LiveCategoryModel(id: "\(item.gid)", parentId: "", title: item.gameFullName, icon: item.pic))
        }
        return finalArray
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int = 1) async throws -> [LiveModel] {
        let dataReq: HuyaRoomMainData = try await LiveParseRequest.get(
            "https://www.huya.com/cache.php",
            parameters: [
                "m": "LiveList",
                "do": "getLiveListByPage",
                "tagAll": 0,
                "gameId": id,
                "page": page
            ]
        )

        var finalArray: [LiveModel] = []
        for item in dataReq.data.datas {
            finalArray.append(LiveModel(
                userName: item.nick,
                roomTitle: item.introduction,
                roomCover: item.screenshot,
                userHeadImg: item.avatar180,
                liveType: .huya,
                liveState: "",
                userId: item.uid,
                roomId: item.profileRoom,
                liveWatchedCount: item.totalCount
            ))
        }
        return finalArray
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Mobile/15E148 Safari/604.1"
        let (html, rawResponse) = try await fetchHTML(
            "https://m.huya.com/\(roomId)",
            headers: [HTTPHeader(name: "user-agent", value: userAgent)],
            context: "Huya.getPlayArgs.fetch"
        )

        let liveData = try decodeHuyaGlobalInit(
            from: html,
            context: "Huya.getPlayArgs.decode",
            responseDetail: rawResponse.response
        )

        var results: [LiveQualityModel] = []

        if let liveStreamInfo = liveData.roomInfo.tLiveInfo.tLiveStreamInfo {
            let streams = liveStreamInfo.vStreamInfo.value
            let bitRates = liveStreamInfo.vBitRateInfo.value

            if let sampleStream = streams.first {
                var playQualitiesInfo: [String: String] = [:]
                if let urlComponent = URLComponents(string: "?\(sampleStream.sFlvAntiCode)") {
                    urlComponent.queryItems?.forEach { item in
                        playQualitiesInfo[item.name] = item.value ?? ""
                    }
                }

                playQualitiesInfo["ver"] = "1"
                playQualitiesInfo["sv"] = "202411221719"
                let uid = Huya.getUid(t: 13, e: 10)
                let now = Int(Date().timeIntervalSince1970) * 1000
                playQualitiesInfo["seqid"] = "\((Int(uid) ?? 0) + Int(now))"
                playQualitiesInfo["uid"] = uid
                playQualitiesInfo["uuid"] = Huya.getUUID()
                playQualitiesInfo["t"] = "103"
                playQualitiesInfo["ctype"] = "tars_mobile"
                playQualitiesInfo["dMod"] = "mseh-0"
                playQualitiesInfo["sdkPcdn"] = "1_1"
                playQualitiesInfo["sdk_sid"] = "1732862566708"
                playQualitiesInfo["a_block"] = "0"

                let ss = "\(playQualitiesInfo["seqid"] ?? "")|\(playQualitiesInfo["ctype"] ?? "")|\(playQualitiesInfo["t"] ?? "")".md5

                if let fmEncoded = playQualitiesInfo["fm"],
                   let fmData = Data(base64Encoded: fmEncoded),
                   let fmString = String(data: fmData, encoding: .utf8) {
                    var fm = fmString as NSString
                    fm = fm.replacingOccurrences(of: "$0", with: uid) as NSString
                    fm = fm.replacingOccurrences(of: "$1", with: sampleStream.sStreamName) as NSString
                    fm = fm.replacingOccurrences(of: "$2", with: ss) as NSString
                    fm = fm.replacingOccurrences(of: "$3", with: playQualitiesInfo["wsTime"] ?? "") as NSString

                    playQualitiesInfo["wsSecret"] = (fm as String).md5
                    playQualitiesInfo.removeValue(forKey: "fm")
                    playQualitiesInfo.removeValue(forKey: "txyp")
                }
            }

            for stream in streams {
                guard stream.iMobilePriorityRate > 15 else { continue }

                var qualities: [LiveQualityDetail] = []
                for bitRate in bitRates {
                    if bitRate.sDisplayName.contains("HDR") { continue }

                    let playUrl = try await Huya.getPlayURL(
                        url: stream.sFlvUrl,
                        cdnType: stream.sCdnType,
                        streamName: stream.sStreamName,
                        iBitRate: bitRate.iBitRate
                    )

                    qualities.append(
                        .init(
                            roomId: roomId,
                            title: bitRate.sDisplayName,
                            qn: bitRate.iBitRate,
                            url: playUrl,
                            liveCodeType: .flv,
                            liveType: .huya
                        )
                    )
                }

                if !qualities.isEmpty {
                    results.append(.init(cdn: "线路 \(stream.sCdnType)", qualitys: qualities))
                }
            }

            if !results.isEmpty {
                return results
            }
        }

        if let replayInfo = liveData.roomInfo.tReplayInfo?.tReplayVideoInfo {
            let replay = LiveQualityDetail(
                roomId: roomId,
                title: "回放",
                qn: replayInfo.iVideoSyncTime,
                url: replayInfo.sHlsUrl,
                liveCodeType: .hls,
                liveType: .huya
            )
            return [.init(cdn: "回放", qualitys: [replay])]
        }

        throw LiveParseError.business(.emptyResult(
            location: "Huya.getPlayArgs",
            request: rawResponse.request
        ))
    }

    
    public static func getPlayURL(url: String, cdnType: String, streamName: String, iBitRate: Int) async throws -> String {
        let requestDetail = NetworkRequestDetail(
            url: "tars://wup.huya.com/liveui/getCdnTokenInfo",
            method: "TARS",
            parameters: [
                "cdnType": cdnType,
                "streamName": streamName,
                "iBitRate": iBitRate
            ]
        )

        if url.isEmpty {
            throw LiveParseError.business(.emptyResult(
                location: "Huya.getPlayURL.input",
                request: requestDetail
            ))
        }

        do {
            let req = GetCdnTokenReq()
            req.cdnType = cdnType
            req.streamName = streamName
            let resp = try await tupClient.tupRequest("getCdnTokenInfo", tReq: req, tRsp: GetCdnTokenResp())

            let responseDetail = NetworkResponseDetail(
                statusCode: 200,
                headers: nil,
                body: "streamName=\(resp.streamName), antiCodeLength=\(resp.antiCode.count)"
            )

            guard !resp.streamName.isEmpty, !resp.antiCode.isEmpty else {
                throw LiveParseError.network(.invalidResponse(
                    request: requestDetail,
                    response: responseDetail
                ))
            }

            var finalURL = "\(url)/\(resp.streamName).flv?\(resp.antiCode)&codec=264"
            if iBitRate > 0 {
                finalURL += "&ratio=\(iBitRate)"
            }

            logDebug("生成虎牙播放地址: \(finalURL)")

            return finalURL
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.network(.requestFailed(
                request: requestDetail,
                response: nil,
                underlyingError: error
            ))
        }
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69"
        let (html, rawResponse) = try await fetchHTML(
            "https://m.huya.com/\(roomId)",
            headers: [HTTPHeader(name: "user-agent", value: userAgent)],
            context: "Huya.getLiveLastestInfo.fetch"
        )

        let data = try decodeHuyaGlobalInit(
            from: html,
            context: "Huya.getLiveLastestInfo.decode",
            responseDetail: rawResponse.response
        )

        var liveInfo = data.roomInfo.tLiveInfo
        var liveStatus = LiveState.close.rawValue

        switch data.roomInfo.eLiveStatus {
        case 2:
            liveStatus = LiveState.live.rawValue
            liveInfo = data.roomInfo.tLiveInfo
        case 3:
            if let replay = data.roomInfo.tReplayInfo {
                liveStatus = LiveState.video.rawValue
                liveInfo = replay
            } else {
                liveStatus = LiveState.close.rawValue
            }
        default:
            liveStatus = LiveState.close.rawValue
            liveInfo = data.roomInfo.tRecentLive
        }

        return LiveModel(
            userName: liveInfo.sNick,
            roomTitle: liveInfo.sIntroduction,
            roomCover: liveInfo.sScreenshot,
            userHeadImg: liveInfo.sAvatar180,
            liveType: .huya,
            liveState: liveStatus,
            userId: "\(liveInfo.lYyid)",
            roomId: roomId,
            liveWatchedCount: "\(liveInfo.lTotalCount)"
        )
    }

    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        guard let liveStatus = try await Huya.getLiveLastestInfo(roomId: roomId, userId: userId).liveState else { return .unknow }
        return LiveState(rawValue: liveStatus)!
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        let dataReq: HuyaSearchResult = try await LiveParseRequest.get(
            "https://search.cdn.huya.com/",
            parameters: [
                "m": "Search",
                "do": "getSearchContent",
                "q": keyword,
                "uid": 0,
                "v": 4,
                "typ": -5,
                "livestate": 0,
                "rows": 20,
                "start": (page - 1) * 20,
            ]
        )
        var finalArray: [LiveModel] = []
        for item in dataReq.response.three.docs {
            finalArray.append(LiveModel(userName: item.game_nick, roomTitle: item.game_introduction, roomCover: item.game_screenshot, userHeadImg: item.game_imgUrl, liveType: .huya, liveState: "1", userId: "\(item.uid)", roomId: "\(item.room_id)", liveWatchedCount: "\(item.game_total_count)"))
        }
        return finalArray
    }

    
    // MARK: - 辅助方法
    
    /// 从 URL 中提取房间号
    private static func extractRoomId(from url: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: roomIdPattern) else { return nil }
        let nsString = url as NSString
        let results = regex.matches(in: url, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = results.first else { return nil }
        let range = match.range(at: 1)
        return nsString.substring(with: range)
    }
    
    /// 从 HTML 内容中提取房间号
    private static func extractRoomIdFromHtml(_ html: String, context: String) throws -> String {
        guard let regex = try? NSRegularExpression(pattern: htmlRoomIdPattern) else {
            throw LiveParseError.parse(.regexMatchFailed(
                pattern: htmlRoomIdPattern,
                location: context,
                rawData: String(html.prefix(500))
            ))
        }

        let nsString = html as NSString
        let results = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        guard let match = results.first else {
            throw LiveParseError.parse(.regexMatchFailed(
                pattern: htmlRoomIdPattern,
                location: context,
                rawData: String(html.prefix(500))
            ))
        }

        let range = match.range(at: 1)
        return nsString.substring(with: range)
    }
    
    /// 解析短链接获取真实 URL
    private static func resolveShortUrl(_ shortUrl: String) async throws -> String? {
        let rawResponse = try await LiveParseRequest.requestRaw(shortUrl)
        return rawResponse.finalURL ?? rawResponse.request.url
    }
    
    /// 从分享码中提取 URL
    private static func extractUrl(from shareCode: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: urlPattern) else { return nil }
        let nsString = shareCode as NSString
        let results = regex.matches(in: shareCode, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = results.first else { return nil }
        let range = match.range(at: 0)
        return nsString.substring(with: range)
    }
    
    /// 验证房间号是否有效
    private static func isValidRoomId(_ roomId: String?) -> Bool {
        guard let roomId = roomId, !roomId.isEmpty else { return false }
        return (Int(roomId) ?? -1) > 0
    }

    /// 拉取 HTML 内容并提供原始响应
    private static func fetchHTML(
        _ url: String,
        headers: HTTPHeaders? = nil,
        context: String
    ) async throws -> (html: String, raw: NetworkRawResponse) {
        let rawResponse = try await LiveParseRequest.requestRaw(
            url,
            headers: headers
        )

        guard let html = String(data: rawResponse.data, encoding: .utf8) else {
            throw LiveParseError.parse(.invalidDataFormat(
                expected: "UTF-8 String",
                actual: "无法解析的二进制",
                location: context
            ))
        }

        return (html, rawResponse)
    }

    /// 从虎牙页面提取并解析 HNF_GLOBAL_INIT 数据
    private static func decodeHuyaGlobalInit(
        from html: String,
        context: String,
        responseDetail: NetworkResponseDetail?
    ) throws -> HuyaRoomInfoMainModel {
        let pattern = #"window\.HNF_GLOBAL_INIT\s*=\s*(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            throw LiveParseError.parse(.regexMatchFailed(
                pattern: pattern,
                location: context,
                rawData: html
            ))
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
        guard let match = matches.first, let range = Range(match.range, in: html) else {
            throw LiveParseError.parse(.regexMatchFailed(
                pattern: pattern,
                location: context,
                rawData: html
            ))
        }

        var jsonString = String(html[range])
        jsonString = String(jsonString.prefix(jsonString.count - 10))
        jsonString = jsonString.replacingOccurrences(of: "\n", with: "")
        jsonString = jsonString.replacingOccurrences(of: "window.HNF_GLOBAL_INIT =", with: "")
        jsonString = removeIncludeFunctionValue(in: jsonString)
        jsonString = String.convertUnicodeEscapes(in: jsonString)
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LiveParseError.parse(.invalidDataFormat(
                expected: "UTF-8 JSON",
                actual: "无法解析",
                location: context
            ))
        }

        do {
            return try JSONDecoder().decode(HuyaRoomInfoMainModel.self, from: jsonData)
        } catch {
            let detail = NetworkResponseDetail(
                statusCode: responseDetail?.statusCode ?? -1,
                headers: responseDetail?.headers,
                body: jsonString
            )
            throw LiveParseError.parse(.decodingFailed(
                type: String(describing: HuyaRoomInfoMainModel.self),
                location: context,
                response: detail,
                underlyingError: error
            ))
        }
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        do {
            var roomId: String?
            var htmlContext: (html: String, response: NetworkResponseDetail?)?

            if isValidRoomId(shareCode) {
                roomId = shareCode
            } else if shareCode.contains("huya.com") {
                roomId = extractRoomId(from: shareCode)
            } else if shareCode.contains("hy.fan") {
                if let shortUrl = extractUrl(from: shareCode),
                   let redirectUrl = try await resolveShortUrl(shortUrl) {
                    roomId = extractRoomId(from: redirectUrl)
                }
            } else if let url = extractUrl(from: shareCode) {
                roomId = extractRoomId(from: url)
            }

            if !isValidRoomId(roomId) {
                let (html, raw) = try await fetchHTML(
                    shareCode,
                    headers: [
                        HTTPHeader(name: "user-agent", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69")
                    ],
                    context: "Huya.getRoomInfoFromShareCode.fetchHtml"
                )
                htmlContext = (html, raw.response)
                roomId = try extractRoomIdFromHtml(html, context: "Huya.getRoomInfoFromShareCode.extractHtml")
            }

            guard let resolvedRoomId = roomId, isValidRoomId(resolvedRoomId) else {
                var detail = "分享码: \(shareCode)"
                if let html = htmlContext?.html {
                    let cleaned = html.trimmingCharacters(in: .whitespacesAndNewlines)
                    let snippet = cleaned.count > 300 ? "\(cleaned.prefix(300))..." : cleaned
                    detail += "\nHTML 片段:\n\(snippet)"
                }
                if let response = htmlContext?.response {
                    detail += "\n\n响应详情:\n\(response.formattedString)"
                }
                throw LiveParseError.shareCodeParseError(
                    "虎牙分享码解析失败",
                    detail
                )
            }

            return try await Huya.getLiveLastestInfo(roomId: resolvedRoomId, userId: nil)

        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.shareCodeParseError(
                "虎牙分享码解析失败",
                "分享码: \(shareCode)\n原因：\(error.localizedDescription)"
            )
        }
    }

    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69"
        let (html, rawResponse) = try await fetchHTML(
            "https://m.huya.com/\(roomId)",
            headers: [HTTPHeader(name: "user-agent", value: userAgent)],
            context: "Huya.getDanmukuArgs.fetch"
        )

        let liveData = try decodeHuyaGlobalInit(
            from: html,
            context: "Huya.getDanmukuArgs.decode",
            responseDetail: rawResponse.response
        )

        guard let streamInfo = liveData.roomInfo.tLiveInfo.tLiveStreamInfo?.vStreamInfo.value.first else {
            throw LiveParseError.danmuArgsParseError(
                "获取虎牙弹幕信息失败",
                "未找到直播流信息。\n\(rawResponse.response.formattedString)"
            )
        }

        return (
            [
                "lYyid": "\(liveData.roomInfo.tLiveInfo.lYyid)",
                "lChannelId": "\(streamInfo.lChannelId)",
                "lSubChannelId": "\(streamInfo.lSubChannelId)"
            ],
            nil
        )
    }




    
    public static func getUUID() -> String {
        let now = Date().timeIntervalSince1970 * 1000
        let rand = Int(arc4random() % 1000 | 0)
        let uuid = (Int(now) % 10000000000 * 1000 + rand) % 4294967295
        return "\(uuid)"
    }
    
    public static func getAnonymousUid() async throws -> String {
        let parameter: [String : Any] = [
            "appId": 5002,
            "byPass": 3,
            "context": "",
            "version": "2.4",
            "data": [:]
        ]

        let rawResponse = try await LiveParseRequest.requestRaw(
            "https://udblgn.huya.com/web/anonymousLogin",
            method: .post,
            parameters: parameter,
            encoding: JSONEncoding.default,
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json;charset=UTF-8"
            ]
        )

        do {
            let json = try JSONSerialization.jsonObject(with: rawResponse.data, options: .mutableContainers)
            guard let jsonDict = json as? [String: Any] else {
                throw LiveParseError.parse(.invalidJSON(
                    location: "Huya.getAnonymousUid",
                    request: rawResponse.request,
                    response: rawResponse.response
                ))
            }

            let returnCode = jsonDict["returnCode"] as? Int ?? -1
            let message = (jsonDict["message"] as? String) ?? (jsonDict["msg"] as? String) ?? ""

            guard returnCode == 0 else {
                throw LiveParseError.business(.permissionDenied(
                    reason: "匿名 UID 获取失败(returnCode=\(returnCode)) \(message)"
                ))
            }

            guard
                let data = jsonDict["data"] as? [String: Any],
                let uid = data["uid"] as? String,
                !uid.isEmpty
            else {
                throw LiveParseError.network(.invalidResponse(
                    request: rawResponse.request,
                    response: rawResponse.response
                ))
            }

            return uid
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.parse(.decodingFailed(
                type: "AnonymousUid",
                location: "Huya.getAnonymousUid",
                response: rawResponse.response,
                underlyingError: error
            ))
        }
    }

    
    static func getUid(t: Int? = nil, e: Int? = nil) -> String {
        let n = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var o = Array(repeating: "", count: 36)
        
        if let t = t {
            for i in 0..<t {
                let randomIndex = Int(arc4random_uniform(UInt32(e ?? n.count)))
                o[i] = String(n[randomIndex])
            }
        } else {
            o[8] = "-"
            o[13] = "-"
            o[18] = "-"
            o[23] = "-"
            o[14] = "4"
            
            for i in 0..<36 {
                if o[i].isEmpty {
                    let r = Int(arc4random_uniform(16))
                    o[i] = String(n[i == 19 ? (r & 3) | 8 : r])
                }
            }
        }
        return o.joined()
    }
    
    static func removeIncludeFunctionValue(in string: String) -> String {
        let pattern = "function\\s*\\([^}]*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let mutableString = NSMutableString(string: string)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..<string.endIndex, in: string))
        for match in matches.reversed() {
            mutableString.replaceCharacters(in: match.range, with: "\"\"")
        }
        return mutableString as String
    }
    
}
