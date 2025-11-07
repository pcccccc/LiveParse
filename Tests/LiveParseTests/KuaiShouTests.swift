import Foundation
import Testing
@testable import LiveParse

// MARK: - KuaiShou Helper

private func fetchKuaiShouCategoryContext() async throws -> (LiveMainListModel, LiveCategoryModel) {
    let categories = try await KuaiShou.getCategoryList()
    guard let category = categories.first(where: { !$0.subList.isEmpty }),
          let subCategory = category.subList.first else {
        Issue.record("没有可用的快手分类")
        throw CancellationError()
    }
    return (category, subCategory)
}

@discardableResult
private func fetchKuaiShouRoom() async throws -> LiveModel {
    let (_, subCategory) = try await fetchKuaiShouCategoryContext()
    let rooms = try await KuaiShou.getRoomList(id: subCategory.id, parentId: nil, page: 1)
    guard let room = rooms.first else {
        Issue.record("快手房间列表为空")
        throw CancellationError()
    }
    return room
}

// MARK: - KuaiShou Tests

@Test("获取快手分类列表")
func kuaishouGetCategoryList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 1: 获取分类列表")

    do {
        let categories = try await KuaiShou.getCategoryList()
        #expect(!categories.isEmpty, "快手分类列表不应为空")

        if let first = categories.first {
            print("✅ 快手分类数量: \(categories.count)，首个分类 \(first.title) 含 \(first.subList.count) 个子分类")
        }
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手分类获取失败")
        throw error
    }
}

@Test("获取快手房间列表")
func kuaishouGetRoomList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 2: 获取房间列表")

    do {
        let (_, subCategory) = try await fetchKuaiShouCategoryContext()
        let rooms = try await KuaiShou.getRoomList(id: subCategory.id, parentId: nil, page: 1)

        #expect(!rooms.isEmpty, "快手房间列表不应为空")

        if let first = rooms.first {
            print("✅ 快手房间样例: \(first.userName) - 房间 \(first.roomId)")
        }
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手房间列表获取失败")
        throw error
    } catch is CancellationError {
        // Issue 已记录，直接返回
        return
    }
}

@Test("获取快手房间详情")
func kuaishouGetLiveLastestInfo() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 3: 获取房间详情")

    do {
        let room = try await fetchKuaiShouRoom()
        let info = try await KuaiShou.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)

        #expect(!info.userName.isEmpty, "快手房间详情 - 主播名不应为空")
        #expect(!info.roomId.isEmpty, "快手房间详情 - 房间ID不应为空")

        print("✅ 快手房间详情: \(info.userName) - \(info.roomTitle)")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手房间详情获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("获取快手直播状态")
func kuaishouGetLiveState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 4: 获取直播状态")

    do {
        let room = try await fetchKuaiShouRoom()
        let state = try await KuaiShou.getLiveState(roomId: room.roomId, userId: room.userId)

        #expect(state != .unknow, "快手直播状态不应为未知")
        print("✅ 快手直播状态: \(state)")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手直播状态获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("获取快手播放参数")
func kuaishouGetPlayArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 5: 获取播放参数")

    do {
        let room = try await fetchKuaiShouRoom()
        let playArgs = try await KuaiShou.getPlayArgs(roomId: room.roomId, userId: room.userId)

        #expect(!playArgs.isEmpty, "快手播放线路不应为空")
        #expect(playArgs.first?.qualitys.isEmpty == false, "快手播放清晰度不应为空")

        if let first = playArgs.first {
            print("✅ 快手播放线路: \(first.cdn) - 清晰度数量 \(first.qualitys.count)")
        }
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手播放参数获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("快手分享码解析")
func kuaishouShareCodeParse() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 6: 分享码解析")

    do {
        let room = try await fetchKuaiShouRoom()
        let info = try await KuaiShou.getRoomInfoFromShareCode(shareCode: room.roomId)

        #expect(info.roomId == room.roomId, "快手分享码解析后的房间ID应匹配输入")
        print("✅ 快手分享码解析成功: \(info.roomId)")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手分享码解析失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("快手弹幕参数提示")
func kuaishouDanmukuArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 7: 弹幕参数")

    do {
        let room = try await fetchKuaiShouRoom()
        let args = try await KuaiShou.getDanmukuArgs(roomId: room.roomId, userId: room.userId)

        #expect(args.0.isEmpty, "快手弹幕参数应为空（暂未开放）")
        #expect(args.1 == nil, "快手弹幕 Header 应为 nil")
        print("✅ 快手弹幕参数返回空，符合预期")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手弹幕参数获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("快手搜索占位")
func kuaishouSearchPlaceholder() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 8: 搜索占位")

    let keyword = "游戏"
    let results = try await KuaiShou.searchRooms(keyword: keyword, page: 1)

    #expect(results.isEmpty, "快手搜索暂未实现，应该返回空数组")
    print("✅ 快手搜索接口暂未开放，返回空数组符合预期")
}

@Test("快手最小完整流程")
func kuaishouFullIntegration() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 快手测试 9: 最小完整流程")

    do {
        let (category, subCategory) = try await fetchKuaiShouCategoryContext()
        print("   ✅ 分类: \(category.title) -> 子分类: \(subCategory.title)")

        let rooms = try await KuaiShou.getRoomList(id: subCategory.id, parentId: nil, page: 1)
        #expect(!rooms.isEmpty, "快手房间列表不应为空")

        guard let room = rooms.first else {
            Issue.record("快手房间列表为空，无法执行完整流程")
            return
        }

        print("   ✅ 房间: \(room.userName) - \(room.roomId)")

        let info = try await KuaiShou.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
        print("   ✅ 房间详情状态: \(info.liveState ?? "未知")")

        let state = try await KuaiShou.getLiveState(roomId: room.roomId, userId: room.userId)
        #expect(state != .unknow, "快手完整流程 - 直播状态不应为未知")

        let playArgs = try await KuaiShou.getPlayArgs(roomId: room.roomId, userId: room.userId)
        #expect(!playArgs.isEmpty, "快手完整流程 - 播放线路不应为空")
        print("   ✅ 播放线路数: \(playArgs.count)")

        let shareInfo = try await KuaiShou.getRoomInfoFromShareCode(shareCode: room.roomId)
        #expect(shareInfo.roomId == room.roomId, "快手完整流程 - 分享码解析应返回同一房间")

        let danmuArgs = try await KuaiShou.getDanmukuArgs(roomId: room.roomId, userId: room.userId)
        #expect(danmuArgs.0.isEmpty, "快手弹幕参数应为空（暂未开放）")

        let searchResults = try await KuaiShou.searchRooms(keyword: room.userName, page: 1)
        #expect(searchResults.isEmpty, "快手搜索暂未开放，应返回空数组")

        print("✅ 快手最小完整流程验证完成")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "快手完整流程失败")
        throw error
    } catch is CancellationError {
        return
    }
}
