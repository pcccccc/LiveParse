//
//  YoutubeParse.swift
//
//
//  Created by pc on 2024/6/12.
//

import Foundation
import YouTubeKit
import Alamofire

public struct YoutubeParse: LiveParse {
    
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        []
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        []
    }
    
    public static func getPlayArgs(roomId: String, userId: String? = "-1") async throws -> [LiveQualityModel] {
        var liveQualitys = [LiveQualityModel]()
        let dataReq = try await YouTube(videoID: roomId).livestreams
        var detailQualitys = [LiveQualityDetail]()
        for (index, item) in dataReq.enumerated() {
            detailQualitys.append(.init(roomId: roomId, title: "地址\(index + 1)", qn: 0, url: item.url.absoluteString ?? "", liveCodeType: .hls, liveType: .youtube))
        }
        liveQualitys.append(.init(cdn: "默认线路", qualitys: detailQualitys))
        return liveQualitys
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        []
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        let dataReq = try await YouTube(videoID: roomId).videoDetails
        let dataInfo = try await YouTube(videoID: roomId).videoInfos.first
        return LiveModel(userName: dataReq.title, roomTitle: dataReq.title, roomCover: dataReq.thumbnail.thumbnails.first?.url.absoluteString ?? "", userHeadImg: dataReq.thumbnail.thumbnails.first?.url.absoluteString ?? "", liveType: .youtube, liveState: dataInfo?.playabilityStatus?.status ?? "" == "OK" ? "1" : "0", userId: "", roomId: roomId, liveWatchedCount: "-")
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        return LiveState(rawValue: (try await getLiveLastestInfo(roomId: roomId, userId: nil).liveState)!) ?? .close
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        var roomId = ""
        if shareCode.contains("youtube.com") { //长链接
            let pattern = "v=([^&]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
               throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
            }
            let nsText = shareCode as NSString
            let matches = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsText.length))
            if let match = matches.first, match.numberOfRanges > 1 {
                let videoIDRange = match.range(at: 1)
                var videoID = nsText.substring(with: videoIDRange)
                if videoID.hasSuffix("/") { //避免结尾为/报错
                    videoID.dropLast()
                }
                roomId = videoID
            }
        }else {
            roomId = shareCode
        }
        if roomId == "" {
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }
        return try await YoutubeParse.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    static func getDanmukuArgs(roomId: String) async throws -> ([String : String], [String : String]?) {
        ([:],[:])
    }
}
