//
//  LiveModel.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/10/8.
//

import Foundation
import Alamofire
import CloudKit

public struct LiveModel: Codable {
    let userName: String
    let roomTitle: String
    let roomCover: String
    let userHeadImg: String
    let liveType: LiveType
    var liveState: String?
    let userId: String //B站 userId 抖音id_str
    let roomId: String //B站 roomId 抖音web_rid
    
    init(userName: String, roomTitle: String, roomCover: String, userHeadImg: String, liveType: LiveType, liveState: String?, userId: String, roomId: String) {
        self.userName = userName
        self.roomTitle = roomTitle
        self.roomCover = roomCover
        self.userHeadImg = userHeadImg
        self.liveType = liveType
        self.liveState = liveState
        self.userId = userId
        self.roomId = roomId
    }
    
    var description: String {
        return "\(userName)-\(roomTitle)-\(roomCover)-\(userHeadImg)-\(liveType)-\(liveState ?? "")-\(userId)-\(roomId)"
    }
    
}

public struct LiveQualityModel: Codable {
    var cdn: String
    var douyuCdnName: String? = ""
    var qualitys: [LiveQualityDetail]
}

public struct LiveQualityDetail: Codable {
    var roomId: String
    var title: String
    var qn: Int //bilibili用qn请求地址
    var url: String
    var liveCodeType: LiveCodeType
    var liveType: LiveType
}

public struct LiveCategoryModel {
    let id: String //B站: id; Douyu:cid2; Huya: gid; Douyin: partitionId
    let parentId: String //B站: parent_id; Douyu: 不需要; Huya: 不需要; Douyin: partitionType
    let title: String
    let icon: String
}

public struct LiveMainListModel {
    let id: String
    let title: String
    let icon: String
    var subList: [LiveCategoryModel]
}

public enum LiveType: String, Codable {
    case bilibili = "0",
         huya = "1",
         douyin = "2",
         douyu = "3",
         qie = "4"
}

public enum LiveState: String, Codable {
    case close = "0", //关播
         live = "1", //直播中
         video = "2", //录播、轮播
         unknow = "3" //未知
}

public enum LiveCodeType: String, Codable {
    case flv = "flv",
         hls = "m3u8"
}
