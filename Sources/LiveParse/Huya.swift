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

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "1", title: "网游", icon: "", subList: try await getCategorySubList(id: "1")),
            LiveMainListModel(id: "2", title: "单机", icon: "", subList: try await getCategorySubList(id: "2")),
            LiveMainListModel(id: "8", title: "娱乐", icon: "", subList: try await getCategorySubList(id: "8")),
            LiveMainListModel(id: "3", title: "手游", icon: "", subList: try await getCategorySubList(id: "3")),
        ]
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        do {
            let dataReq = try await AF.request("https://live.cdn.huya.com/liveconfig/game/bussLive", method: .get, parameters: ["bussType": id]).serializingDecodable(HuyaMainData<[HuyaSubListModel]>.self).value
            var finalArray: [LiveCategoryModel] = []
            for item in dataReq.data {
                finalArray.append(LiveCategoryModel(id: "\(item.gid)", parentId: "", title: item.gameFullName, icon: item.pic))
            }
            return finalArray
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int = 1) async throws -> [LiveModel] {
        do {
            let dataReq = try await AF.request(
                "https://www.huya.com/cache.php",
                method: .get,
                parameters: [
                    "m": "LiveList",
                    "do": "getLiveListByPage",
                    "tagAll": 0,
                    "gameId": id,
                    "page": page
                ]
            ).serializingDecodable(HuyaRoomMainData.self).value
            var finalArray: Array<LiveModel> = []
            for item in dataReq.data.datas {
                finalArray.append(LiveModel(userName: item.nick, roomTitle: item.introduction, roomCover: item.screenshot, userHeadImg: item.avatar180, liveType: .huya, liveState: "", userId: item.uid, roomId: item.profileRoom, liveWatchedCount: item.totalCount))
            }
            return finalArray
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        do {
            let dataReq = try await AF.request(
                "https://m.huya.com/\(roomId)",
                method: .get,
                headers: [
                    HTTPHeader(name: "user-agent", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Mobile/15E148 Safari/604.1")
                ]
            ).serializingString().value
            let pattern = #"window\.HNF_GLOBAL_INIT\s*=\s*(.*?)</script>"#
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            var tempArray: [LiveQualityModel] = []
            let matchs =  regex.matches(in: dataReq, range: NSRange(location: 0, length:  dataReq.count))
            for match in matchs {
                let matchRange = Range(match.range, in: dataReq)!
                let matchedSubstring = dataReq[matchRange]
                var nsstr = NSString(string: "\(matchedSubstring.prefix(matchedSubstring.count - 10))")
                nsstr = nsstr.replacingOccurrences(of: "window.HNF_GLOBAL_INIT =", with: "") as NSString
                nsstr = nsstr.replacingOccurrences(of: "\n", with: "") as NSString
                nsstr = removeIncludeFunctionValue(in: nsstr as String) as NSString
                nsstr = String.convertUnicodeEscapes(in: nsstr as String) as NSString
                let liveData = try JSONDecoder().decode(HuyaRoomInfoMainModel.self, from: (nsstr as String).data(using: .utf8)!)
                if let streamInfo = liveData.roomInfo.tLiveInfo.tLiveStreamInfo?.vStreamInfo.value.first {
                    var playQualitiesInfo: Dictionary<String, String> = [:]
                    if let urlComponent = URLComponents(string: "?\(streamInfo.sFlvAntiCode ?? "")") {
                        if let queryItems = urlComponent.queryItems {
                            for item in queryItems {
                                playQualitiesInfo.updateValue(item.value ?? "", forKey: item.name)
                            }
                        }
                    }
                   
                    playQualitiesInfo.updateValue("1", forKey: "ver")
                    playQualitiesInfo.updateValue("202411221719", forKey: "sv")
                    let uid = Huya.getUid(t: 13, e: 10)
                    let now = Int(Date().timeIntervalSince1970) * 1000
                    playQualitiesInfo.updateValue("\(Int(uid) ?? 0 + Int(now))", forKey: "seqid")
                    playQualitiesInfo.updateValue(uid, forKey: "uid")
                    playQualitiesInfo.updateValue(Huya.getUUID(), forKey: "uuid")
                    playQualitiesInfo.updateValue("103", forKey: "t")
                    playQualitiesInfo.updateValue("tars_mobile", forKey: "ctype")
                    playQualitiesInfo.updateValue("mseh-0", forKey: "dMod")
                    playQualitiesInfo.updateValue("1_1", forKey: "sdkPcdn")
                    playQualitiesInfo.updateValue("1732862566708", forKey: "sdk_sid")
                    playQualitiesInfo.updateValue("0", forKey: "a_block")
                    let ss = "\(playQualitiesInfo["seqid"] ?? "")|\(playQualitiesInfo["ctype"] ?? "")|\(playQualitiesInfo["t"] ?? "")".md5
                    let base64EncodedData = (playQualitiesInfo["fm"] ?? "").data(using: .utf8)!
                    if let data = Data(base64Encoded: base64EncodedData) {
                        let fm = String(data: data, encoding: .utf8)!
                        var nsFM = fm as NSString
                        nsFM = nsFM.replacingOccurrences(of: "$0", with: uid).replacingOccurrences(of: "$1", with: streamInfo.sStreamName ?? "").replacingOccurrences(of: "$2", with: ss).replacingOccurrences(of: "$3", with: playQualitiesInfo["wsTime"] ?? "") as NSString
                        playQualitiesInfo.updateValue((nsFM as String).md5, forKey: "wsSecret")
                        playQualitiesInfo.removeValue(forKey: "fm")
                        playQualitiesInfo.removeValue(forKey: "txyp")
                        var playInfo: Array<URLQueryItem> = []
                        for key in playQualitiesInfo.keys {
                            let value = playQualitiesInfo[key] ?? ""
                            playInfo.append(.init(name: key, value: value))
                        }
                        var urlComps = URLComponents(string: "")!
                        urlComps.queryItems = playInfo
                        let result = urlComps.url!
                        let res = result.absoluteString as NSString
                        for streamInfo in liveData.roomInfo.tLiveInfo.tLiveStreamInfo!.vStreamInfo.value {
                            let bitRateInfoArray  = liveData.roomInfo.tLiveInfo.tLiveStreamInfo!.vBitRateInfo.value
                            var liveQualtys: [LiveQualityDetail] = []
                            for index in 0 ..< bitRateInfoArray.count {
                                var url = ""
                                let bitRateInfo = bitRateInfoArray[index]
                                if streamInfo.iMobilePriorityRate > 15 { //15帧以下，KSPlayer可能会产生抽动问题。如果使用IINA则可以正常播放
                                    if bitRateInfo.iBitRate > 0 && bitRateInfo.sDisplayName.contains("HDR") == false { //如果HDR视频包含ratio参数会直接报错
                                        url = try await Huya.getPlayURL(url: streamInfo.sFlvUrl, cdnType: streamInfo.sCdnType, streamName: streamInfo.sStreamName, iBitRate: bitRateInfo.iBitRate)
                                    }else {
                                        url = try await Huya.getPlayURL(url: streamInfo.sFlvUrl, cdnType: streamInfo.sCdnType, streamName: streamInfo.sStreamName, iBitRate: bitRateInfo.iBitRate)
                                    }
                                    
                                    liveQualtys.append(.init(roomId: roomId, title: bitRateInfo.sDisplayName, qn: bitRateInfo.iBitRate, url: url, liveCodeType: .flv, liveType: .huya))
                                }
                            }
                            if liveQualtys.isEmpty == false {
                                tempArray.append(.init(cdn: "线路 \(streamInfo.sCdnType)", qualitys: liveQualtys))
                               
                            }
                        }
                        
                        return tempArray
                    }
                }else {
                    if let replyInfo = liveData.roomInfo.tReplayInfo?.tReplayVideoInfo {
                        var liveQualtys: [LiveQualityDetail] = []
                        liveQualtys.append(.init(roomId: roomId, title: "回放", qn: replyInfo.iVideoSyncTime, url: replyInfo.sHlsUrl ?? "", liveCodeType: .hls, liveType: .huya))
                        tempArray.append(.init(cdn: "回放", qualitys: liveQualtys))
                    }
                    return tempArray
                }
            }
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\("获取Huya直播地址失败，服务器返回信息为：\(dataReq)")")
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getPlayURL(url: String, cdnType: String, streamName: String, iBitRate: Int) async throws -> String {
        var req = GetCdnTokenReq()
        req.cdnType = cdnType
        req.streamName = streamName
        do {
            let resp = try await tupClient.tupRequest("getCdnTokenInfo", tReq: req, tRsp: GetCdnTokenResp())
            var url = "\(url)/\(resp.streamName).flv?\(resp.antiCode)&codec=264"
            if iBitRate > 0 {
                url += "&ratio=\(iBitRate)"
            }
            return url
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        do {
            let dataReq = try await AF.request(
                "https://m.huya.com/\(roomId)",
                method: .get,
                headers: [
                    HTTPHeader(name: "user-agent", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69")
                ]
            ).serializingString().value
            let pattern = #"window\.HNF_GLOBAL_INIT\s*=\s*(.*?)</script>"#
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let matchs =  regex.matches(in: dataReq, range: NSRange(location: 0, length:  dataReq.count))
            for match in matchs {
                let matchRange = Range(match.range, in: dataReq)!
                let matchedSubstring = dataReq[matchRange]
                var nsstr = NSString(string: "\(matchedSubstring.prefix(matchedSubstring.count - 10))")
                nsstr = nsstr.replacingOccurrences(of: "\n", with: "") as NSString
                nsstr = removeIncludeFunctionValue(in: nsstr as String) as NSString
                nsstr = String.convertUnicodeEscapes(in: nsstr as String) as NSString
                nsstr = nsstr.replacingOccurrences(of: "window.HNF_GLOBAL_INIT =", with: "") as NSString
                do {
                    let data = try JSONDecoder().decode(HuyaRoomInfoMainModel.self, from: (nsstr as String).data(using: .utf8)!)
                    var liveStatus = ""
                    var liveInfo = data.roomInfo.tLiveInfo
                    switch data.roomInfo.eLiveStatus {
                        case 2:
                            liveStatus = LiveState.live.rawValue
                            liveInfo = data.roomInfo.tLiveInfo
                        case 3:
                            liveStatus = LiveState.video.rawValue
                            liveInfo = data.roomInfo.tReplayInfo!
                    default:
                        liveStatus = LiveState.close.rawValue
                            liveInfo = data.roomInfo.tRecentLive
                    }
                    return LiveModel(userName: liveInfo.sNick, roomTitle: liveInfo.sIntroduction, roomCover: liveInfo.sScreenshot, userHeadImg: liveInfo.sAvatar180, liveType: .huya, liveState: liveStatus, userId: "\(liveInfo.lYyid)", roomId: roomId, liveWatchedCount: "\(liveInfo.lTotalCount)")
                }catch {
                    throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
                }
            }
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\("获取虎牙直播信息失败，服务器返回信息为：\(dataReq)")")
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        do {
            guard let liveStatus = try await Huya.getLiveLastestInfo(roomId: roomId, userId: userId).liveState else { return .unknow }
            return LiveState(rawValue: liveStatus)!
        }catch {
            throw LiveParseError.liveStateParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        do {
            let dataReq = try await AF.request(
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
            ).serializingDecodable(HuyaSearchResult.self).value
            var finalArray: Array<LiveModel> = []
            for item in dataReq.response.three.docs {
                finalArray.append(LiveModel(userName: item.game_nick, roomTitle: item.game_introduction, roomCover: item.game_screenshot, userHeadImg: item.game_imgUrl, liveType: .huya, liveState: "1", userId: "\(item.uid)", roomId: "\(item.room_id)", liveWatchedCount: "\(item.game_total_count)"))
            }
            return finalArray
        }catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        do {
            var roomId = ""
            var realUrl = ""
            if shareCode.contains("huya.com") { //长链接
                realUrl = shareCode
            }else { //默认为房间号处理
                roomId = shareCode
            }
            if roomId == "" { //如果不是房间号，就解析链接中的房间号
                let pattern = "(?:huya\\.com/)(\\d+)"
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
            if roomId == "" || Int(roomId) ?? -1 < 0 { //最后尝试是不是平台的短链接，从html里面把房间号找到
                let dataReq = try await AF.request(shareCode, headers: [
                    HTTPHeader(name: "user-agent", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69")
                ]).serializingString().value
                let pattern = "\"lProfileRoom\":(\\d+),"
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let nsString = dataReq as NSString
                    let results = regex.matches(in: dataReq, range: NSRange(location: 0, length: nsString.length))
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
            return try await Huya.getLiveLastestInfo(roomId: roomId, userId: nil)
        }catch {
            throw LiveParseError.shareCodeParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        do {
            let dataReq = try await AF.request(
                "https://m.huya.com/\(roomId)",
                method: .get,
                headers: [
                    HTTPHeader(name: "user-agent", value: "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1 Edg/91.0.4472.69")
                ]
            ).serializingString().value
            let pattern = #"window\.HNF_GLOBAL_INIT\s*=\s*(.*?)</script>"#
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let matchs =  regex.matches(in: dataReq, range: NSRange(location: 0, length:  dataReq.count))
            for match in matchs {
                let matchRange = Range(match.range, in: dataReq)!
                let matchedSubstring = dataReq[matchRange]
                var nsstr = NSString(string: "\(matchedSubstring.prefix(matchedSubstring.count - 10))")
                nsstr = nsstr.replacingOccurrences(of: "\n", with: "") as NSString
                nsstr = removeIncludeFunctionValue(in: nsstr as String) as NSString
                nsstr = String.convertUnicodeEscapes(in: nsstr as String) as NSString
                nsstr = nsstr.replacingOccurrences(of: "window.HNF_GLOBAL_INIT =", with: "") as NSString
                let liveData = try JSONDecoder().decode(HuyaRoomInfoMainModel.self, from: (nsstr as String).data(using: .utf8)!)
                return (
                    [
                        "lYyid": "\(liveData.roomInfo.tLiveInfo.lYyid )",
                        "lChannelId": "\(liveData.roomInfo.tLiveInfo.tLiveStreamInfo!.vStreamInfo.value.first?.lChannelId ?? 0)",
                        "lSubChannelId": "\(liveData.roomInfo.tLiveInfo.tLiveStreamInfo!.vStreamInfo.value.first?.lSubChannelId ?? 0)"
                    ],
                    nil
                )
            }
            throw LiveParseError.danmuArgsParseError("错误位置\(#file)-\(#function)", "错误信息：\("获取斗鱼弹幕信息失败，服务器返回信息为：\(dataReq)")")
        }catch {
            throw LiveParseError.danmuArgsParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
    }
    
    public static func getUUID() -> String {
        let now = Date().timeIntervalSince1970 * 1000
        let rand = Int(arc4random() % 1000 | 0)
        let uuid = (Int(now) % 10000000000 * 1000 + rand) % 4294967295
        return "\(uuid)"
    }
    
    public static func getAnonymousUid() async throws -> String {
        var request = URLRequest(url: URL(string: "https://udblgn.huya.com/web/anonymousLogin")!)
        request.httpMethod = "post"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let parameter = [
            "appId": 5002,
            "byPass": 3,
            "context": "",
            "version": "2.4",
            "data": [:]
        ] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: parameter)
        let dataReq = try await AF.request(request).serializingData().value
        let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
        let jsonDict = json as! Dictionary<String, Any>
        if jsonDict["returnCode"] as? Int ?? -1 == 0 {
            let data = jsonDict["data"] as? Dictionary<String, Any>
            return data?["uid"] as? String ?? ""
        }
        return ""
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

