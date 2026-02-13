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
        if LiveParseConfig.enableJSPlugins {
            do {
                let result: [LiveMainListModel] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getCategoryList",
                    payload: [:]
                )
                logInfo("YoutubeParse.getCategoryList 使用 JS 插件返回 \(result.count) 个主分类")
                return result
            } catch {
                logWarning("YoutubeParse.getCategoryList JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        return []
    }
    
    public static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel] {
        if LiveParseConfig.enableJSPlugins {
            struct PluginRoom: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let rooms: [PluginRoom] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getRoomList",
                    payload: [
                        "id": id,
                        "parentId": parentId as Any,
                        "page": page
                    ]
                )
                logInfo("YoutubeParse.getRoomList 使用 JS 插件返回 \(rooms.count) 个房间")
                return rooms.map {
                    LiveModel(
                        userName: $0.userName,
                        roomTitle: $0.roomTitle,
                        roomCover: $0.roomCover,
                        userHeadImg: $0.userHeadImg,
                        liveType: .youtube,
                        liveState: $0.liveState,
                        userId: $0.userId,
                        roomId: $0.roomId,
                        liveWatchedCount: $0.liveWatchedCount
                    )
                }
            } catch {
                logWarning("YoutubeParse.getRoomList JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        return []
    }
    
    public static func getPlayArgs(roomId: String, userId: String? = "-1") async throws -> [LiveQualityModel] {
        if LiveParseConfig.enableJSPlugins {
            do {
                let result: [LiveQualityModel] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getPlayArgs",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("YoutubeParse.getPlayArgs 使用 JS 插件返回 \(result.count) 条线路")
                return result
            } catch {
                logWarning("YoutubeParse.getPlayArgs JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        var liveQualitys = [LiveQualityModel]()
        let streams = try await YouTube(videoID: roomId).livestreams
        var detailQualitys = [LiveQualityDetail]()
        for (index, item) in streams.enumerated() {
            detailQualitys.append(.init(
                roomId: roomId,
                title: "地址\(index + 1)",
                qn: 0,
                url: item.url.absoluteString,
                liveCodeType: .hls,
                liveType: .youtube
            ))
        }
        liveQualitys.append(.init(cdn: "默认线路", qualitys: detailQualitys))
        return liveQualitys
    }
    
    public static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel] {
        if LiveParseConfig.enableJSPlugins {
            struct PluginRoom: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let rooms: [PluginRoom] = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "searchRooms",
                    payload: [
                        "keyword": keyword,
                        "page": page
                    ]
                )
                logInfo("YoutubeParse.searchRooms 使用 JS 插件返回 \(rooms.count) 个房间")
                return rooms.map {
                    LiveModel(
                        userName: $0.userName,
                        roomTitle: $0.roomTitle,
                        roomCover: $0.roomCover,
                        userHeadImg: $0.userHeadImg,
                        liveType: .youtube,
                        liveState: $0.liveState,
                        userId: $0.userId,
                        roomId: $0.roomId,
                        liveWatchedCount: $0.liveWatchedCount
                    )
                }
            } catch {
                logWarning("YoutubeParse.searchRooms JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        return []
    }
    
    public static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveInfo: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveType: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let info: PluginLiveInfo = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getLiveLastestInfo",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("YoutubeParse.getLiveLastestInfo 使用 JS 插件成功")
                return LiveModel(
                    userName: info.userName,
                    roomTitle: info.roomTitle,
                    roomCover: info.roomCover,
                    userHeadImg: info.userHeadImg,
                    liveType: .youtube,
                    liveState: info.liveState,
                    userId: info.userId,
                    roomId: info.roomId,
                    liveWatchedCount: info.liveWatchedCount
                )
            } catch {
                logWarning("YoutubeParse.getLiveLastestInfo JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let youtube = YouTube(videoID: roomId)
        let metadata = try await youtube.metadata
        let streams = (try? await youtube.livestreams) ?? []

        let title = metadata?.title ?? roomId
        let thumbnail = metadata?.thumbnail?.url.absoluteString ?? ""
        let liveState = streams.isEmpty ? LiveState.close.rawValue : LiveState.live.rawValue

        return LiveModel(
            userName: title,
            roomTitle: title,
            roomCover: thumbnail,
            userHeadImg: thumbnail,
            liveType: .youtube,
            liveState: liveState,
            userId: "",
            roomId: roomId,
            liveWatchedCount: "-"
        )
    }
    
    public static func getLiveState(roomId: String, userId: String?) async throws -> LiveState {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveState: Decodable {
                let liveState: String
            }

            do {
                let result: PluginLiveState = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getLiveState",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )

                if let state = LiveState(rawValue: result.liveState) {
                    logInfo("YoutubeParse.getLiveState 使用 JS 插件成功")
                    return state
                }

                logWarning("YoutubeParse.getLiveState JS 插件返回无效状态：\(result.liveState)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw LiveParseError.liveStateParseError(
                        "Youtube 房间状态获取失败",
                        "插件返回未知状态值: \(result.liveState)"
                    )
                }
            } catch {
                logWarning("YoutubeParse.getLiveState JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        let rawState = try await getLiveLastestInfo(roomId: roomId, userId: nil).liveState ?? LiveState.close.rawValue
        return LiveState(rawValue: rawState) ?? .close
    }
    
    public static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel {
        if LiveParseConfig.enableJSPlugins {
            struct PluginLiveInfo: Decodable {
                let userName: String
                let roomTitle: String
                let roomCover: String
                let userHeadImg: String
                let liveType: String
                let liveState: String?
                let userId: String
                let roomId: String
                let liveWatchedCount: String?
            }

            do {
                let info: PluginLiveInfo = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getRoomInfoFromShareCode",
                    payload: [
                        "shareCode": shareCode
                    ]
                )
                logInfo("YoutubeParse.getRoomInfoFromShareCode 使用 JS 插件成功")
                return LiveModel(
                    userName: info.userName,
                    roomTitle: info.roomTitle,
                    roomCover: info.roomCover,
                    userHeadImg: info.userHeadImg,
                    liveType: .youtube,
                    liveState: info.liveState,
                    userId: info.userId,
                    roomId: info.roomId,
                    liveWatchedCount: info.liveWatchedCount
                )
            } catch {
                logWarning("YoutubeParse.getRoomInfoFromShareCode JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        var roomId = ""
        if shareCode.contains("youtube.com") && shareCode.contains("v=") { // 长链接
            let pattern = "v=([^/?&]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
            }
            let nsText = shareCode as NSString
            let matches = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsText.length))
            if let match = matches.first, match.numberOfRanges > 1 {
                let videoIDRange = match.range(at: 1)
                let videoID = nsText.substring(with: videoIDRange)
                roomId = videoID
            }
        } else if shareCode.contains("youtube.com") && shareCode.contains("live") { // 长链接 live
            let pattern = "live/([^/?&]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
            }
            let nsText = shareCode as NSString
            let matches = regex.matches(in: shareCode, options: [], range: NSRange(location: 0, length: nsText.length))
            if let match = matches.first, match.numberOfRanges > 1 {
                let videoIDRange = match.range(at: 1)
                let videoID = nsText.substring(with: videoIDRange)
                roomId = videoID
            }
        } else {
            roomId = shareCode
        }

        if roomId == "" {
            throw NSError(domain: "解析房间号失败，请检查分享码/分享链接是否正确", code: -10000, userInfo: ["desc": "解析房间号失败，请检查分享码/分享链接是否正确"])
        }

        return try await YoutubeParse.getLiveLastestInfo(roomId: roomId, userId: nil)
    }
    
    static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String : String], [String : String]?) {
        if LiveParseConfig.enableJSPlugins {
            struct PluginResult: Decodable {
                let args: [String: String]
                let headers: [String: String]?
            }

            do {
                let result: PluginResult = try await LiveParsePlugins.shared.callDecodable(
                    pluginId: "youtube",
                    function: "getDanmukuArgs",
                    payload: [
                        "roomId": roomId,
                        "userId": userId as Any
                    ]
                )
                logInfo("YoutubeParse.getDanmukuArgs 使用 JS 插件成功")
                return (result.args, result.headers)
            } catch {
                logWarning("YoutubeParse.getDanmukuArgs JS 插件失败：\(error)")
                if !LiveParseConfig.pluginFallbackToSwiftImplementation {
                    throw error
                }
            }
        }

        return ([:], [:])
    }
}
