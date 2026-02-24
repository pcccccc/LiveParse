//
//  LiveModel.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/10/8.
//

import Foundation
import Alamofire
import CloudKit

public struct LiveModel: Identifiable, Codable, Equatable, Hashable, Sendable {

    public var id = UUID()
    public let userName: String
    public let roomTitle: String
    public let roomCover: String
    public let userHeadImg: String
    public let liveType: LiveType
    public var liveState: String?
    public let userId: String //B站 userId 抖音id_str
    public let roomId: String //B站 roomId 抖音web_rid
    public let liveWatchedCount: String?

    public init(userName: String, roomTitle: String, roomCover: String, userHeadImg: String, liveType: LiveType, liveState: String?, userId: String, roomId: String, liveWatchedCount: String?) {
        self.userName = userName
        self.roomTitle = roomTitle
        self.roomCover = roomCover
        self.userHeadImg = userHeadImg
        self.liveType = liveType
        self.liveState = liveState
        self.userId = userId
        self.roomId = roomId
        self.liveWatchedCount = liveWatchedCount
    }

    public var description: String {
        return "\(userName)-\(roomTitle)-\(roomCover)-\(userHeadImg)-\(liveType)-\(liveState ?? "")-\(userId)-\(roomId)"
    }

    public static func ==(lhs: LiveModel, rhs: LiveModel) -> Bool {
        return lhs.roomId == rhs.roomId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public func liveStateFormat() -> String {
        switch LiveState(rawValue: liveState ?? "0") {
            case .close:
                return "已下播"
            case .live:
                return "正在直播"
            case .video:
                return "回放/轮播"
            case .unknow:
                return "未知状态"
            case .none:
                return "未知状态"
        }
    }
}

public struct LiveQualityModel: Codable, Sendable {
    public var cdn: String
    public var douyuCdnName: String? = ""
    public var yyLineSeq: String? = ""
    public var qualitys: [LiveQualityDetail]
    
    init(cdn: String, douyuCdnName: String? = nil, yyLineSeq: String? = nil, qualitys: [LiveQualityDetail]) {
        self.cdn = cdn
        self.douyuCdnName = douyuCdnName
        self.yyLineSeq = yyLineSeq
        self.qualitys = qualitys
    }
}

public struct LiveQualityDetail: Codable, Sendable {
    public var roomId: String
    public var title: String
    public var qn: Int //bilibili用qn请求地址
    public var url: String
    public var liveCodeType: LiveCodeType
    public var liveType: LiveType
}

public struct LiveCategoryModel: Codable {
    public var id: String //B站: id; Douyu:cid2; Huya: gid; Douyin: partitionId
    public var parentId: String //B站: parent_id; Douyu: 不需要; Huya: 不需要; Douyin: partitionType
    public let title: String
    public let icon: String
    public var biz: String? //YY请求子分类房间的biz，其他平台为空
    
    init(id: String, parentId: String, title: String, icon: String, biz: String? = "") {
        self.id = id
        self.parentId = parentId
        self.title = title
        self.icon = icon
        self.biz = biz
    }
}

public struct LiveMainListModel: Codable {
    public let id: String
    public let title: String
    public let icon: String
    public let biz: String? //YY请求分类房间的biz，其他平台为空
    public var subList: [LiveCategoryModel]
    
    init(id: String, title: String, icon: String, biz: String? = "", subList: [LiveCategoryModel]) {
        self.id = id
        self.title = title
        self.icon = icon
        self.biz = biz
        self.subList = subList
    }
}

public enum LiveType: String, Codable, Sendable {
    case bilibili = "0",
         huya = "1",
         douyin = "2",
         douyu = "3",
         cc = "4",
         ks = "5",
         yy = "6"
}

public enum LiveState: String, Codable {
    case close = "0", //关播
         live = "1", //直播中
         video = "2", //录播、轮播
         unknow = "3" //未知
}

public enum LiveCodeType: String, Codable, Sendable {
    case flv = "flv",
         hls = "m3u8"
}

