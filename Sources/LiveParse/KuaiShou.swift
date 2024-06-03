//
//  KuaiShow.swift
//  
//
//  Created by pangchong on 2024/5/29.
//

import Foundation
import Alamofire

// Define the struct for the game data
struct KSCategoryModel: Codable {
    let id: String
    let name: String
    let poster: String
    let description: String
    let categoryAbbr: String
    let categoryName: String
}

// Define the struct for the list of games
struct KSCategoryList: Codable {
    let list: [KSCategoryModel]
    let hasMore: Bool
}

struct KSCategoryData<T: Codable>: Codable {
    let data: T
}

struct KSRoomList: Codable {
    let list: [KSRoomListModel]
    let hasMore: Bool
}

struct KSRoomListModel: Codable {
    let poster: String
    let caption: String
    let author: KSAuthorModel
}

struct KSAuthorModel: Codable {
    let name: String
    let avatar: String
    let watchingCount: String
    let id: String
}

public struct KuaiShou: LiveParse {
    public static func getCategoryList() async throws -> [LiveMainListModel] {
        return [
            LiveMainListModel(id: "1", title: "热门", icon: "", subList: try await getCategorySubList(id: "1")),
            LiveMainListModel(id: "2", title: "网游", icon: "", subList: try await getCategorySubList(id: "2")),
            LiveMainListModel(id: "3", title: "单机", icon: "", subList: try await getCategorySubList(id: "3")),
            LiveMainListModel(id: "4", title: "手游", icon: "", subList: try await getCategorySubList(id: "4")),
            LiveMainListModel(id: "5", title: "棋牌", icon: "", subList: try await getCategorySubList(id: "5")),
            LiveMainListModel(id: "6", title: "娱乐", icon: "", subList: try await getCategorySubList(id: "6")),
            LiveMainListModel(id: "7", title: "综合", icon: "", subList: try await getCategorySubList(id: "7")),
            LiveMainListModel(id: "8", title: "文化", icon: "", subList: try await getCategorySubList(id: "8"))
        ]
    }
    
    public static func getCategorySubList(id: String) async throws -> [LiveCategoryModel] {
        var hasMore = true
        var page = 1
        var tempArray: [LiveCategoryModel] = []
        while hasMore == true {
            let dataReq = try await AF.request(
                "https://live.kuaishou.com/live_api/category/data",
                method: .get,
                parameters: [
                    "type": id,
                    "page": page,
                    "pageSize": 20
                ]
            ).serializingDecodable(KSCategoryData<KSCategoryList?>.self).value
            if let list = dataReq.data?.list {
                for item in list {
                    tempArray.append(LiveCategoryModel(id: item.id, parentId: "", title: item.name, icon: item.poster))
                }
                hasMore = dataReq.data?.hasMore ?? false
                page += 1
            }
        }
        return tempArray
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        let url = id.count >= 7 ? "https://live.kuaishou.com/live_api/non-gameboard/list" : "https://live.kuaishou.com/live_api/gameboard/list"
        let dataReq = try await AF.request(
            url,
            method: .get,
            parameters: [
                "filterType": 0,
                "page": page,
                "pageSize": 20,
                "gameId": id
            ]
        ).serializingString().value
        print(dataReq)
        return []
    }
    
    static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel] {
        []
    }
    
    static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        []
    }
    
    static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        LiveModel(userName: "", roomTitle: "", roomCover: "", userHeadImg: "", liveType: .ks, liveState: "", userId: "", roomId: "", liveWatchedCount: "")
    }
    
    static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        .close
    }
    
    static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        LiveModel(userName: "", roomTitle: "", roomCover: "", userHeadImg: "", liveType: .ks, liveState: "", userId: "", roomId: "", liveWatchedCount: "")
    }
    
    static func getDanmukuArgs(roomId: String) async throws -> ([String : String], [String : String]?) {
        ([:],[:])
    }
}
