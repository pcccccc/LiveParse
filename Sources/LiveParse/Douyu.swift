//
//  Douyu.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/10/2.
//

import Foundation
import Alamofire
import CommonCrypto
import JavaScriptCore

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
    let total: Int?
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

struct DouyuCate1Info: Codable {
    let cate1Id: Int
    let cate1Name: String
    let shortName: String
}

struct DouyuCate2Info: Codable {
    let cate1Id: Int
    let cate2Id: Int
    let cate2Name: String
    let shortName: String
    let pic: String
    let icon: String
    let smallIcon: String
    let count: Int
    let isVertical: Int
}

struct DouyuCateV2Model: Codable {
    let code: Int
    let data: DouyuCateV2Data
}

struct DouyuCateV2Data: Codable {
    let cate1Info: [DouyuCate1Info]
    let cate2Info: [DouyuCate2Info]
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
    private static let desktopUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43"
    private static let defaultReferer = "https://www.douyu.com/"

    private static func buildRequestDetail(
        url: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        parameters: Parameters? = nil,
        body: String? = nil
    ) -> NetworkRequestDetail {
        NetworkRequestDetail(
            url: url,
            method: method.rawValue,
            headers: headers?.dictionary,
            parameters: parameters,
            body: body
        )
    }

    private static func isValidRoomId(_ roomId: String?) -> Bool {
        guard let roomId = roomId, let value = Int(roomId), value > 0 else {
            return false
        }
        return true
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        return nsText.substring(with: match.range(at: 1))
    }

    private static func extractUrl(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "[a-zA-Z]+://[^\\s]+") else {
            return nil
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }
        return nsText.substring(with: match.range)
    }

    private static func sanitizedSnippet(_ text: String, limit: Int = 300) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= limit {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<index])..."
    }

    public static func getCategoryList() async throws -> [LiveMainListModel] {
        let url = "https://m.douyu.com/api/cate/list"

        logDebug("开始获取斗鱼分类列表")

        let dataReq: DouyuCateV2Model = try await LiveParseRequest.get(url)

        guard dataReq.code == 0 else {
            logWarning("斗鱼分类接口返回错误 code: \(dataReq.code)")
            throw LiveParseError.business(.permissionDenied(
                reason: "斗鱼分类接口返回错误 (code: \(dataReq.code))"
            ))
        }

        var finalList: [LiveMainListModel] = []
        for cate1 in dataReq.data.cate1Info {
            var categoryArray: [LiveCategoryModel] = []
            for cate2 in dataReq.data.cate2Info where cate2.cate1Id == cate1.cate1Id {
                categoryArray.append(LiveCategoryModel(
                    id: "\(cate2.cate2Id)",
                    parentId: "\(cate2.cate1Id)",
                    title: cate2.cate2Name,
                    icon: cate2.icon
                ))
            }

            let listModel = LiveMainListModel(
                id: "\(cate1.cate1Id)",
                title: cate1.cate1Name,
                icon: "",
                subList: categoryArray
            )
            finalList.append(listModel)
        }

        guard !finalList.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "Douyu.getCategoryList",
                request: buildRequestDetail(url: url, method: .get)
            ))
        }

        logInfo("成功获取斗鱼分类列表，共 \(finalList.count) 个分类")
        return finalList
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        let url = "https://www.douyu.com/gapi/rkc/directory/mixList/2_\(id)/\(page)"

        logDebug("开始获取斗鱼直播间列表，分类ID: \(id)，页码: \(page)")

        let dataReq: DouyuRoomMain = try await LiveParseRequest.get(url)

        guard dataReq.code == 0 else {
            logWarning("斗鱼直播间接口返回错误 code: \(dataReq.code), msg: \(dataReq.msg)")
            throw LiveParseError.business(.permissionDenied(
                reason: "斗鱼直播间接口返回错误 (code: \(dataReq.code)) - \(dataReq.msg)"
            ))
        }

        var result: [LiveModel] = []
        for item in dataReq.data.rl where item.type == 1 {
            result.append(LiveModel(
                userName: item.nn ?? "",
                roomTitle: item.rn ?? "",
                roomCover: item.rs16_avif ?? item.av ?? "",
                userHeadImg: item.av ?? "",
                liveType: .douyu,
                liveState: "",
                userId: "\(item.uid ?? 0)",
                roomId: "\(item.rid ?? 0)",
                liveWatchedCount: "\(item.ol ?? 0)"
            ))
        }

        guard !result.isEmpty else {
            logWarning("斗鱼直播间列表为空，分类ID: \(id)，页码: \(page)")
            throw LiveParseError.business(.emptyResult(
                location: "Douyu.getRoomList",
                request: buildRequestDetail(url: url, method: .get)
            ))
        }

        logInfo("成功获取斗鱼直播间列表，共 \(result.count) 个房间")
        return result
    }
    
    public static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        logDebug("开始获取斗鱼播放线路，房间ID: \(roomId)")

        let qualities = try await getRealPlayArgs(roomId: roomId, rate: 0, cdn: nil)

        guard !qualities.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "Douyu.getPlayArgs",
                request: buildRequestDetail(url: "https://www.douyu.com/lapi/live/getH5Play/\(roomId)", method: .post)
            ))
        }

        logInfo("成功获取斗鱼播放线路，共 \(qualities.count) 条")
        return qualities
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let url = "https://www.douyu.com/betard/\(roomId)"
        let headers = HTTPHeaders([
            HTTPHeader(name: "referer", value: "\(defaultReferer)\(roomId)"),
            HTTPHeader(name: "user-agent", value: desktopUserAgent),
        ])

        logDebug("开始获取斗鱼房间详情，房间ID: \(roomId)")

        let raw = try await LiveParseRequest.requestRaw(
            url,
            method: .get,
            headers: headers
        )

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: raw.data, options: .mutableContainers)
        } catch {
            throw LiveParseError.parse(.invalidJSON(
                location: "Douyu.getLiveLastestInfo.parseJSON",
                request: raw.request,
                response: raw.response
            ))
        }

        guard let jsonDict = jsonObject as? [String: Any] else {
            throw LiveParseError.parse(.invalidDataFormat(
                expected: "Dictionary",
                actual: String(describing: type(of: jsonObject)),
                location: "Douyu.getLiveLastestInfo.parseRoot"
            ))
        }

        guard let roomDict = jsonDict["room"] as? [String: Any] else {
            throw LiveParseError.parse(.missingRequiredField(
                field: "room",
                location: "Douyu.getLiveLastestInfo.room",
                response: raw.response
            ))
        }

        let liveStatus = roomDict["show_status"] as? Int ?? -1
        let videoLoop = roomDict["videoLoop"] as? Int ?? -1

        let liveState: String
        if liveStatus == 1 && videoLoop == 0 {
            liveState = LiveState.live.rawValue
        } else if liveStatus == 0 && videoLoop == 1 {
            liveState = LiveState.video.rawValue
        } else if liveStatus == 1 && videoLoop == 1 {
            liveState = LiveState.video.rawValue
        } else {
            liveState = LiveState.close.rawValue
        }

        let roomBizAll = roomDict["room_biz_all"] as? [String: Any]

        let model = LiveModel(
            userName: roomDict["nickname"] as? String ?? "",
            roomTitle: roomDict["room_name"] as? String ?? "",
            roomCover: roomDict["room_pic"] as? String ?? "",
            userHeadImg: roomDict["owner_avatar"] as? String ?? "",
            liveType: .douyu,
            liveState: liveState,
            userId: "\(roomDict["owner_id"] as? Int ?? 0)",
            roomId: roomId,
            liveWatchedCount: roomBizAll?["hot"] as? String ?? ""
        )

        logInfo("成功获取斗鱼房间详情: \(model.userName) - 房间 \(model.roomId)")
        return model
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        logDebug("开始获取斗鱼房间状态，房间ID: \(roomId)")

        do {
            let info = try await Douyu.getLiveLastestInfo(roomId: roomId, userId: userId)
            let state = LiveState(rawValue: info.liveState ?? LiveState.unknow.rawValue) ?? .unknow
            logInfo("斗鱼房间状态: \(state.rawValue) - 房间 \(roomId)")
            return state
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.liveStateParseError(
                "斗鱼房间状态获取失败",
                "房间ID: \(roomId)\n原因：\(error.localizedDescription)"
            )
        }
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        logDebug("开始搜索斗鱼直播间，关键词: \(keyword)，页码: \(page)")

        let did = String.generateRandomString(length: 32)

        let headers = HTTPHeaders([
            HTTPHeader(name: "referer", value: "https://www.douyu.com/search/"),
            HTTPHeader(name: "user-agent", value: desktopUserAgent),
            HTTPHeader(name: "Cookie", value: "dy_did=\(did);acf_did=\(did)")
        ])

        let parameters: Parameters = [
            "kw": keyword,
            "page": page,
            "pageSize": 20
        ]

        let dataReq: DouyuSearchResult = try await LiveParseRequest.get(
            "https://www.douyu.com/japi/search/api/searchShow",
            parameters: parameters,
            headers: headers
        )

        var finalArray: [LiveModel] = []
        for item in dataReq.data.relateShow {
            finalArray.append(LiveModel(
                userName: item.nickName,
                roomTitle: item.roomName,
                roomCover: item.roomSrc,
                userHeadImg: item.avatar,
                liveType: .douyu,
                liveState: item.roomType == 0 ? LiveState.live.rawValue : LiveState.close.rawValue,
                userId: "\(item.rid)",
                roomId: "\(item.rid)",
                liveWatchedCount: item.hot
            ))
        }

        guard !finalArray.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "Douyu.searchRooms",
                request: buildRequestDetail(
                    url: "https://www.douyu.com/japi/search/api/searchShow",
                    method: .get,
                    headers: headers,
                    parameters: parameters
                )
            ))
        }

        logInfo("斗鱼搜索结果: \(finalArray.count) 条，关键词: \(keyword)")
        return finalArray
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        let trimmed = shareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        logDebug("开始解析斗鱼分享码: \(trimmed)")

        do {
            if isValidRoomId(trimmed) {
                logInfo("斗鱼分享码解析到房间ID: \(trimmed)")
                return try await Douyu.getLiveLastestInfo(roomId: trimmed, userId: nil)
            }

            var resolvedRoomId: String?
            var responseDetail: NetworkResponseDetail?
            var htmlSnippet: String?
            var finalURLString: String?

            if trimmed.contains("douyu.com") {
                resolvedRoomId = firstMatch(in: trimmed, pattern: "douyu\\.com/(\\d+)")
                if !isValidRoomId(resolvedRoomId) {
                    resolvedRoomId = firstMatch(in: trimmed, pattern: "rid=(\\d+)")
                }
            }

            var candidateUrl: String?
            if let directUrl = extractUrl(from: trimmed) {
                candidateUrl = directUrl
            } else if trimmed.hasPrefix("http") {
                candidateUrl = trimmed
            } else if trimmed.contains("douyu") {
                candidateUrl = "https://www.douyu.com/\(trimmed)"
            }

            if !isValidRoomId(resolvedRoomId), let url = candidateUrl {
                let raw = try await LiveParseRequest.requestRaw(url)
                responseDetail = raw.response
                finalURLString = raw.finalURL ?? raw.request.url

                if let finalURLString = finalURLString {
                    resolvedRoomId = firstMatch(in: finalURLString, pattern: "(?:douyu\\.com/|rid=)(\\d+)")
                }

                if !isValidRoomId(resolvedRoomId) {
                    let html = String(data: raw.data, encoding: .utf8) ?? ""
                    if !html.isEmpty {
                        htmlSnippet = sanitizedSnippet(html)
                        let patterns = [
                            "\\\"room_id\\\":\\s*(\\d+)",
                            "\\\"rid\\\":\\s*\\\"?(\\d+)",
                            "roomId\\s*[:=]\\s*\\\"?(\\d+)"
                        ]
                        for pattern in patterns {
                            resolvedRoomId = firstMatch(in: html, pattern: pattern)
                            if isValidRoomId(resolvedRoomId) {
                                break
                            }
                        }
                    }
                }
            }

            guard let roomId = resolvedRoomId, isValidRoomId(roomId) else {
                var detail = "分享码: \(trimmed)"
                if let finalURLString = finalURLString {
                    detail += "\n重定向 URL: \(finalURLString)"
                }
                if let snippet = htmlSnippet, !snippet.isEmpty {
                    detail += "\nHTML 片段:\n\(snippet)"
                }
                if let responseDetail = responseDetail {
                    detail += "\n\n响应详情:\n\(responseDetail.formattedString)"
                }
                throw LiveParseError.shareCodeParseError("斗鱼分享码解析失败", detail)
            }

            logInfo("斗鱼分享码解析成功，房间ID: \(roomId)")
            return try await Douyu.getLiveLastestInfo(roomId: roomId, userId: nil)
        } catch let error as LiveParseError {
            throw error
        } catch {
            throw LiveParseError.shareCodeParseError(
                "斗鱼分享码解析失败",
                "分享码: \(trimmed)\n原因：\(error.localizedDescription)"
            )
        }
    }
    
    public static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        (["roomId": roomId], nil)
    }
    
    public static func getCategoryList(id: String, name: String) async throws -> Array<LiveCategoryModel> {
        logDebug("开始获取斗鱼子分类列表，分类ID: \(id)，名称: \(name)")

        let parameters: Parameters = [
            "shortName": name,
            "customClassId": id,
            "offset": 0,
            "limit": 200
        ]

        let dataReq: DouyuSubListMain = try await LiveParseRequest.get(
            "https://www.douyu.com/japi/weblist/apinc/getC2List",
            parameters: parameters
        )

        guard dataReq.error == 0 else {
            logWarning("斗鱼子分类接口返回错误 error: \(dataReq.error), msg: \(dataReq.msg)")
            throw LiveParseError.business(.permissionDenied(
                reason: "斗鱼子分类接口返回错误 (code: \(dataReq.error)) - \(dataReq.msg)"
            ))
        }

        var tempArray: [LiveCategoryModel] = []
        for item in dataReq.data.list {
            tempArray.append(.init(
                id: "\(item.cid2)",
                parentId: "\(item.cid1)",
                title: item.cname2,
                icon: item.squareIconUrlW
            ))
        }

        guard !tempArray.isEmpty else {
            throw LiveParseError.business(.emptyResult(
                location: "Douyu.getCategoryList.sub",
                request: buildRequestDetail(
                    url: "https://www.douyu.com/japi/weblist/apinc/getC2List",
                    method: .get,
                    parameters: parameters
                )
            ))
        }

        logInfo("成功获取斗鱼子分类，共 \(tempArray.count) 个")
        return tempArray
    }
    
    private static func calculateMD5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    private static func getDouyuSign(roomId: String) async throws -> [String: String] {
        // Fetch JS encryption code
        let jsEncReq = try await AF.request(
            "https://www.douyu.com/swf_api/homeH5Enc?rids=\(roomId)",
            method: .get,
            headers: HTTPHeaders([
                HTTPHeader(name: "referer", value: "https://www.douyu.com/\(roomId)"),
                HTTPHeader(name: "user-agent", value: desktopUserAgent),
            ])
        ).serializingData().value

        let jsEncJson = try JSONSerialization.jsonObject(with: jsEncReq, options: .mutableContainers)
        guard let jsEncDict = jsEncJson as? [String: Any],
              let jsEncData = jsEncDict["data"] as? [String: Any],
              var jsEnc = jsEncData["room\(roomId)"] as? String else {
            throw LiveParseError.liveParseError("获取JS加密代码失败", "房间ID: \(roomId)")
        }

        // Replace return eval to extract sign functions
        jsEnc = jsEnc.replacingOccurrences(of: "return eval", with: "return [strc, vdwdae325w_64we];")

        // Extract the encryption function
        let pattern = "(vdwdae325w_64we[\\s\\S]*function ub98484234[\\s\\S]*?)function"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            throw LiveParseError.liveParseError("正则表达式创建失败", "")
        }

        let nsText = jsEnc as NSString
        let matches = regex.matches(in: jsEnc, range: NSRange(location: 0, length: nsText.length))
        guard let match = matches.first else {
            throw LiveParseError.liveParseError("未找到加密函数", "JS代码可能已更新")
        }

        let matchRange = match.range
        var encFunction = nsText.substring(with: NSRange(location: matchRange.location, length: matchRange.length - 8))

        // Replace eval pattern
        let evalPattern = "eval.*?;\\}"
        guard let evalRegex = try? NSRegularExpression(pattern: evalPattern, options: .caseInsensitive) else {
            throw LiveParseError.liveParseError("正则表达式创建失败", "")
        }
        encFunction = evalRegex.stringByReplacingMatches(in: encFunction, options: [], range: NSRange(location: 0, length: encFunction.count), withTemplate: "strc;}")

        // Execute JavaScript to get sign function and sign_v
        guard let jsContext = JSContext() else {
            throw LiveParseError.liveParseError("JavaScript引擎初始化失败", "")
        }

        // Execute the encryption function
        let jsCode = "\(encFunction);ub98484234();"
        guard let result = jsContext.evaluateScript(jsCode),
              let resultArray = result.toArray() as? [Any],
              resultArray.count >= 2,
              var signFun = resultArray[0] as? String,
              let signV = resultArray[1] as? String else {
            throw LiveParseError.liveParseError("执行JS代码失败", "返回值格式不正确")
        }

        // Generate timestamps and hashes
        let tt = String(Int(Date().timeIntervalSince1970))
        let did = calculateMD5(tt)
        let rb = calculateMD5("\(roomId)\(did)\(tt)\(signV)")

        // Replace CryptoJS.MD5 call with calculated rb
        signFun = signFun.trimmingCharacters(in: CharacterSet(charactersIn: ";"))
            .replacingOccurrences(of: "CryptoJS.MD5(cb).toString()", with: "\"\(rb)\"")
        signFun += "(\"\(roomId)\",\"\(did)\",\"\(tt)\");"

        // Execute the final sign function to get parameters
        guard let paramsResult = jsContext.evaluateScript(signFun),
              let paramsString = paramsResult.toString() else {
            throw LiveParseError.liveParseError("生成签名参数失败", "")
        }

        // Parse query string into dictionary
        var params: [String: String] = [:]
        let pairs = paramsString.components(separatedBy: "&")
        for pair in pairs {
            let components = pair.components(separatedBy: "=")
            if components.count == 2 {
                params[components[0]] = components[1]
            }
        }

        return params
    }

    public static func getRealPlayArgs(roomId: String, rate: Int = 0, cdn: String?) async throws -> [LiveQualityModel] {
        do {
            // Get sign parameters locally
            var signParams = try await getDouyuSign(roomId: roomId)

            // Update with rate and cdn if provided
            signParams["rate"] = "\(rate)"
            if let cdn = cdn {
                signParams["cdn"] = cdn
            }

            // Make request to getH5Play API
            let dataReq = try await AF.request(
                "https://www.douyu.com/lapi/live/getH5Play/\(roomId)",
                method: .post,
                parameters: signParams,
                headers: HTTPHeaders([
                    HTTPHeader(name: "referer", value: "https://www.douyu.com/\(roomId)"),
                    HTTPHeader(name: "user-agent", value: desktopUserAgent),
                ])
            ).serializingString().value

            guard let resData = dataReq.data(using: .utf8) else {
                throw LiveParseError.liveParseError("数据解析失败", "无法转换响应数据")
            }

            let resJson = try JSONSerialization.jsonObject(with: resData, options: .mutableContainers)
            guard let resDict = resJson as? [String: Any],
                  let dataDict = resDict["data"] as? [String: Any] else {
                throw LiveParseError.liveParseError("数据解析失败", "响应格式不正确")
            }

            // Parse play qualities
            var playQualitys: [DouyuPlayQuality] = []
            if let multirates = dataDict["multirates"] as? [[String: Any]] {
                for item in multirates {
                    let playQualityData = jsonToData(jsonDic: item)
                    let playQuality = try JSONDecoder().decode(DouyuPlayQuality.self, from: playQualityData ?? Data())
                    playQualitys.append(playQuality)
                }
            }

            // Build CDN array
            var cdnsArray: [LiveQualityModel] = []
            if let cdns = dataDict["cdnsWithName"] as? [[String: Any]] {
                for item in cdns {
                    var tempArray: [LiveQualityDetail] = []
                    for playQuality in playQualitys {
                        let rtmpUrl = dataDict["rtmp_url"] as? String ?? ""
                        let rtmpLive = dataDict["rtmp_live"] as? String ?? ""
                        tempArray.append(.init(
                            roomId: roomId,
                            title: playQuality.name,
                            qn: playQuality.rate,
                            url: "\(rtmpUrl)/\(rtmpLive)",
                            liveCodeType: .flv,
                            liveType: .douyu
                        ))
                    }
                    let serverCdn = item["cdn"] as? String ?? ""
                    if serverCdn == cdn || cdn == nil {
                        cdnsArray.append(.init(
                            cdn: item["name"] as? String ?? "",
                            douyuCdnName: serverCdn,
                            qualitys: tempArray
                        ))
                    }
                }
            }

            return cdnsArray
        } catch {
            throw LiveParseError.liveParseError("错误位置\(#file)-\(#function)", "错误信息：\(error.localizedDescription)")
        }
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
