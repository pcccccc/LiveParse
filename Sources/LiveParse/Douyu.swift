//
//  Douyu.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/10/2.
//

import Foundation
import Alamofire

struct DouyuMainListModel: Codable {
    let id: String
    let name: String
    var list: Array<DouyuSubListModel>
}

struct DouyuSubListMain: Codable {
    var error: Int
    var msg: String
    var data: DouyuSubListData
}

struct DouyuSubListData: Codable {
    let total: Int
    let list: Array<DouyuSubListModel>
}

struct DouyuSubListModel: Codable {
    let cid1: Int
    let cid2: Int
    let shortName: String
    let cname2: String
    let orderdisplay: Int
    let isGameCate: Int
    let isRelate: Int
    let pushVerticalScreen: Int
    let pushNearby: Int
    let count: Int
    let isAudio: Int
    let squareIconUrlW: String
    let isHidden: Int
    let cateDesc: String
    let isVM: Int
    let hn: Int
    let cate2Url: String
}

struct DouyuRoomMain: Codable {
    var code: Int
    var msg: String
    var data: DouyuRoomListData
}

struct DouyuRoomListData: Codable {
    let rl: Array<DouyuRoomModel>
    let pgcnt: Int
}

struct DouyuRoomModel: Codable {
    let type: Int
    let rid: Int?
    let rn: String?
    let uid: Int?
    let nn: String?
    let cid1: Int?
    let cid2: Int?
    let cid3: Int?
    let iv: Int?
    let av: String?
    let ol: Int?
    let c2url: String?
    let c2name: String?
    let rs16_avif: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(Int.self, forKey: .type)
        self.rid = try container.decodeIfPresent(Int.self, forKey: .rid)
        self.rn = try container.decodeIfPresent(String.self, forKey: .rn)
        self.uid = try container.decodeIfPresent(Int.self, forKey: .uid)
        self.nn = try container.decodeIfPresent(String.self, forKey: .nn)
        self.cid1 = try container.decodeIfPresent(Int.self, forKey: .cid1)
        self.cid2 = try container.decodeIfPresent(Int.self, forKey: .cid2)
        self.cid3 = try container.decodeIfPresent(Int.self, forKey: .cid3)
        self.iv = try container.decodeIfPresent(Int.self, forKey: .iv)
        let av = try container.decodeIfPresent(String.self, forKey: .av)
        self.av = "https://apic.douyucdn.cn/upload/\(av ?? "")_middle.jpg"
        self.ol = try container.decodeIfPresent(Int.self, forKey: .ol)
        self.c2url = try container.decodeIfPresent(String.self, forKey: .c2url)
        self.c2name = try container.decodeIfPresent(String.self, forKey: .c2name)
        self.rs16_avif = try container.decodeIfPresent(String.self, forKey: .rs16_avif)
        
    }
}

struct DouyuPlayInfoData: Codable {
    let error: Int
    let msg: String
    let data: DouyuPlayInfoModel?
}

struct DouyuPlayInfoModel: Codable {
    let rtmp_url: String
    let rtmp_live: String
    let play_url: String
    let cdnsWithName: Array<Dictionary<String, String>>
    let multirates: Array<DouyuPlayQuality>
}

struct DouyuPlayQuality: Codable {
    let highBit: Int
    let bit: Int
    let name: String
    let diamondFan: Int
    let rate: Int
}

struct DouyuSearchResult: Codable {
    let data: DouyuSearchResultData
}

struct DouyuSearchResultData: Codable {
    let relateShow: Array<DouyuSearchRelateShow>
}

struct DouyuSearchRelateShow: Codable {
    let rid: Int
    let roomName: String
    let roomSrc: String
    let roomType: Int
    let nickName: String
    let avatar: String
    let hot: String
}

public struct Douyu: LiveParse {
    
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "PCgame", title: "网游竞技", icon: "", subList: try await getCategoryList(id: "PCgame")),
            LiveMainListModel(id: "djry", title: "单机热游", icon: "", subList: try await getCategoryList(id: "djry")),
            LiveMainListModel(id: "syxx", title: "手游休闲", icon: "", subList: try await getCategoryList(id: "syxx")),
            LiveMainListModel(id: "yl", title: "娱乐天地", icon: "", subList: try await getCategoryList(id: "yl")),
            LiveMainListModel(id: "yz", title: "颜值", icon: "", subList: try await getCategoryList(id: "yz")),
            LiveMainListModel(id: "kjwh", title: "科技文化", icon: "", subList: try await getCategoryList(id: "kjwh")),
            LiveMainListModel(id: "yp", title: "语言互动", icon: "", subList: try await getCategoryList(id: "yp")),
        ]
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        let dataReq = try await AF.request(
            "https://www.douyu.com/gapi/rkc/directory/mixList/2_\(id)/\(page)",
            method: .get
        ).serializingDecodable(DouyuRoomMain.self).value
        var tempArray: Array<LiveModel> = []
        for item in dataReq.data.rl {
            if item.type == 1 {
                tempArray.append(LiveModel(userName: item.nn!, roomTitle: item.rn!, roomCover: item.rs16_avif!, userHeadImg: item.av!, liveType: .douyu, liveState: "", userId: "\(item.uid!)", roomId: "\(item.rid!)", liveWatchedCount: "\(item.ol ?? 0)"))
            }
        }
        return tempArray
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        return try await getRealPlayArgs(roomId: roomId, rate: 0, cdn: nil)
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let dataReq = try await AF.request(
            "https://www.douyu.com/betard/\(roomId)",
            method: .get,
            headers: HTTPHeaders([
                HTTPHeader.init(name: "referer", value: "https://www.douyu.com/\(roomId)"),
                HTTPHeader.init(name: "user-agent", value: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"),
            ])
        ).serializingData().value
        let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
        let jsonDict = json as! Dictionary<String, Any>
        let roomDict = jsonDict["room"] as! Dictionary<String, Any>
        let liveStatus = roomDict["show_status"] as? Int ?? -1
        let videoLoop = roomDict["videoLoop"] as? Int ?? -1
        var liveState = ""
        if liveStatus == 1 && videoLoop == 0 {
            liveState = LiveState.live.rawValue
        }else if liveStatus == 0 && videoLoop == 1 {
            liveState = LiveState.video.rawValue
        }else {
            liveState = LiveState.close.rawValue
        }
        let roomBizAll = roomDict["room_biz_all"] as? Dictionary<String, Any>
        return LiveModel(userName: roomDict["nickname"] as? String ?? "", roomTitle: roomDict["room_name"] as? String ?? "", roomCover: roomDict["room_pic"] as? String ?? "", userHeadImg: roomDict["owner_avatar"] as? String ?? "", liveType: .douyu, liveState: liveState, userId: "\(roomDict["owner_id"] as? Int ?? 0)", roomId: roomId, liveWatchedCount: "\(roomBizAll?["hot"] as? String ?? "")")
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        let dataReq = try await Douyu.getLiveLastestInfo(roomId: roomId, userId: userId)
        return LiveState(rawValue: dataReq.liveState ?? "unknow") ?? .unknow
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        let did = String.generateRandomString(length: 32)
        let dataReq =  try await AF.request(
            "https://www.douyu.com/japi/search/api/searchShow",
            method: .get,
            parameters: [
                "kw": keyword,
                "page": page,
                "pageSize": 20
            ],
            headers: HTTPHeaders([
                HTTPHeader.init(name: "referer", value: "https://www.douyu.com/search/"),
                HTTPHeader.init(name: "user-agent", value: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"),
                HTTPHeader.init(name: "Cookie", value: "dy_did=\(did);acf_did=\(did)"),
            ])
        ).serializingDecodable(DouyuSearchResult.self).value
        var tempArray: Array<LiveModel> = []
        for item in dataReq.data.relateShow {
            tempArray.append(LiveModel(userName: item.nickName, roomTitle: item.roomName, roomCover: item.roomSrc, userHeadImg: item.avatar, liveType: .douyu, liveState: item.roomType == 0 ? "正在直播" :"已下播", userId: "\(item.rid)", roomId: "\(item.rid)", liveWatchedCount: item.hot))
        }
        return tempArray
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        var roomId = ""
        var realUrl = ""
        if shareCode.contains("douyu.com") { //长链接
            realUrl = shareCode
        }else { //默认为房间号处理
            roomId = shareCode
        }
        if roomId == "" { //如果不是房间号，就解析链接中的房间号
            let pattern = "https://www\\.douyu\\.com/(\\d+)"
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
        if roomId == "" || Int(roomId) ?? -1 < 0 { //最后尝试是不是平台的短链接，需要进行重定向
            let dataReq = await AF.request(shareCode).serializingData().response
            realUrl = dataReq.response?.url?.absoluteString ?? ""
            let pattern = "rid=(\\d+)"
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
        
        return try await Douyu.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    public static func getDanmukuArgs(roomId: String) async throws -> ([String : String], [String : String]?) {
        (["roomId": roomId], nil)
    }
    
    public static func getCategoryList(id: String) async throws -> Array<LiveCategoryModel> {
        let dataReq = try await AF.request(
            "https://www.douyu.com/japi/weblist/api/getC2List",
            method: .get,
            parameters: [
                "shortName": id,
                "offset": 0,
                "limit": 200,
            ]
        ).serializingDecodable(DouyuSubListMain.self).value
        var tempArray: [LiveCategoryModel] = []
        for item in dataReq.data.list {
            tempArray.append(.init(id: "\(item.cid2)", parentId: "\(item.cid1)", title: item.cname2, icon: item.squareIconUrlW))
        }
        return tempArray
    }
    
    public static func getRealPlayArgs(roomId: String, rate: Int = 0, cdn: String?) async throws -> [LiveQualityModel] {
        let jsEncReq = try await AF.request(
            "https://www.douyu.com/swf_api/homeH5Enc?rids=\(roomId)",
            method: .get,
            headers: HTTPHeaders([
                HTTPHeader.init(name: "referer", value: "https://www.douyu.com/\(roomId)"),
                HTTPHeader.init(name: "user-agent", value: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"),
            ])
        ).serializingData().value
        let jsEncJson = try JSONSerialization.jsonObject(with: jsEncReq, options: .mutableContainers)
        let jsEncDict = jsEncJson as! Dictionary<String, Any>
        let jsEncData = jsEncDict["data"] as! Dictionary<String, Any>
        let cryText = jsEncData["room\(roomId)"] as? String ?? ""
        
        let regex = try NSRegularExpression(pattern: "(vdwdae325w_64we[\\s\\S]*function ub98484234[\\s\\S]*?)function", options: [])
        let matchs =  regex.matches(in: cryText, range: NSRange(location: 0, length:  cryText.count))
        if matchs.count > 0 {
            let match = matchs.first!
            let matchRange = Range(match.range, in: cryText)!
            let matchedSubstring = cryText[matchRange]
            let nsstr = NSString(string: "\(matchedSubstring.prefix(matchedSubstring.count - 9))")
            let regex = "eval.*?;\\}"
            let RE = try NSRegularExpression(pattern: regex, options: .caseInsensitive)
            let res = RE.stringByReplacingMatches(in: String(nsstr), options: .reportProgress, range: NSRange(location: 0, length: String(nsstr).count), withTemplate: "strc;}")
            var request = URLRequest(url: URL(string: "http://alive.nsapps.cn/api/AllLive/DouyuSign")!)
            request.httpMethod = "post"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
            let parameter = [
                "html": res,
                "rid": roomId
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: parameter)
            let dataReq = try await AF.request(request).serializingData().value
            let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
            let jsonDict = json as! Dictionary<String, Any>
            if jsonDict["code"] as? Int ?? -1 == 0 {
                var playData = NSString(string: "{\"\(jsonDict["data"] as? String ?? "")\"}")
                playData = playData.replacingOccurrences(of: "&", with: "\",\"") as NSString
                playData = playData.replacingOccurrences(of: "=", with: "\":\"") as NSString
                let finalData = (playData as String).data(using: .utf8) ?? Data()
                let jsEncJson = try JSONSerialization.jsonObject(with: finalData, options: .mutableContainers)
                var jsEncDict = jsEncJson as! Dictionary<String, Any>

                jsEncDict.updateValue(rate, forKey: "rate")
                if cdn != nil {
                    jsEncDict.updateValue(cdn!, forKey: "cdn")
                }
                let dataReq = try await AF.request(
                    "https://www.douyu.com/lapi/live/getH5Play/\(roomId)",
                    method: .post,
                    parameters: jsEncDict,
                    headers: HTTPHeaders([
                        HTTPHeader.init(name: "referer", value: "https://www.douyu.com/\(roomId)"),
                        HTTPHeader.init(name: "user-agent", value: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"),
                    ])
                ).serializingString().value
                let resData = dataReq.data(using: .utf8) ?? Data()
                let resJson = try JSONSerialization.jsonObject(with: resData, options: .mutableContainers)
                let resDict = resJson as! Dictionary<String, Any>
                let dataDict = resDict["data"] as! Dictionary<String, Any>
                var playQualitys: Array<DouyuPlayQuality> = []
                if let multirates = dataDict["multirates"] as? Array<Dictionary<String, Any>> {
                    for item in multirates {
                        let playQualityData = jsonToData(jsonDic: item)
                        let playQuality = try JSONDecoder().decode(DouyuPlayQuality.self, from: playQualityData ?? Data())
                        playQualitys.append(playQuality)
                    }
                }
                
                var cdnsArray: [LiveQualityModel] = []
                if let cdns = dataDict["cdnsWithName"] as? Array<Dictionary<String, Any>> {
                    for item in cdns {
                        var tempArray: [LiveQualityDetail] = []
                        for i in 0..<playQualitys.count {
                            let playQuality = playQualitys[i]
                            tempArray.append(.init(roomId: roomId, title: playQuality.name, qn: playQuality.rate, url: "\(dataDict["rtmp_url"] as? String ?? "")/\(dataDict["rtmp_live"] as? String ?? "")", liveCodeType: .flv, liveType: .douyu))
                        }
                        let serverCdn = item["cdn"] as? String ?? ""
                        if serverCdn == cdn || cdn == nil {
                            cdnsArray.append(.init(cdn: item["name"] as? String ?? "", douyuCdnName: serverCdn, qualitys: tempArray))
                        }
                    }
                }
                return cdnsArray
            }
        }
        return []
    }
    
    static func jsonToData(jsonDic:Dictionary<String, Any>) -> Data? {
        if (!JSONSerialization.isValidJSONObject(jsonDic)) {
            print("is not a valid json object")
            return nil
        }
        //利用自带的json库转换成Data
        //如果设置options为JSONSerialization.WritingOptions.prettyPrinted，则打印格式更好阅读
        let data = try? JSONSerialization.data(withJSONObject: jsonDic, options: [])
        //输出json字符串
        return data
    }
    
}
