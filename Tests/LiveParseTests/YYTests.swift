import Foundation
import Testing
@testable import LiveParse

// MARK: - Helpers

private func prepareYYTestEnvironment() {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true
    assertPurePluginMode(platform: "YY")
}

private func fetchYYCategoryContext() async throws -> (LiveMainListModel, LiveCategoryModel) {
    let categories = try await YY.getCategoryList()
    guard let category = categories.first(where: { !$0.subList.isEmpty }),
          let subCategory = category.subList.first else {
        print("⚠️ 没有可用的 YY 分类，跳过当前用例")
        throw CancellationError()
    }
    return (category, subCategory)
}

@discardableResult
private func fetchYYRoom() async throws -> LiveModel {
    let (category, subCategory) = try await fetchYYCategoryContext()
    let rooms = try await YY.getRoomList(id: subCategory.id, parentId: category.id, page: 1)
    guard let room = rooms.first else {
        print("⚠️ YY 房间列表为空，跳过当前用例")
        throw CancellationError()
    }
    return room
}

// MARK: - Tests

@Test("获取 YY 分类列表")
func yyGetCategoryList() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 1: 分类列表")

    do {
        let categories = try await YY.getCategoryList()
        #expect(!categories.isEmpty, "YY 分类列表不应为空")

        if let first = categories.first {
            print("✅ YY 分类数量: \(categories.count)，首个分类 \(first.title) 子分类数 \(first.subList.count)")
        }
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 分类获取失败")
        throw error
    }
}

@Test("获取 YY 房间列表")
func yyGetRoomList() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 2: 房间列表")

    do {
        let (category, subCategory) = try await fetchYYCategoryContext()
        let rooms = try await YY.getRoomList(id: category.biz ?? "", parentId: subCategory.biz, page: 1)

        #expect(!rooms.isEmpty, "YY 房间列表不应为空")
        if let first = rooms.first {
            print("✅ YY 房间样例: \(first.userName) - 房间 \(first.roomId)")
        }
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 房间列表获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("获取 YY 房间详情")
func yyGetLiveLastestInfo() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 3: 房间详情")

    do {
        let room = try await fetchYYRoom()
        let info = try await YY.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)

        #expect(!info.userName.isEmpty, "YY 房间详情 - 主播名称不应为空")
        #expect(!info.roomId.isEmpty, "YY 房间详情 - 房间ID不应为空")
        print("✅ YY 房间详情: \(info.userName) - \(info.roomTitle)")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 房间详情获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("获取 YY 播放参数")
func yyGetPlayArgs() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 4: 播放参数")

    do {
        let room = try await fetchYYRoom()
        let playArgs = try await YY.getPlayArgs(roomId: room.roomId, userId: room.userId)

        #expect(!playArgs.isEmpty, "YY 播放线路不应为空")
        #expect(playArgs.first?.qualitys.isEmpty == false, "YY 播放清晰度不应为空")
        print("✅ YY 播放线路: \(playArgs.count) 条")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 播放参数获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("获取 YY 直播状态")
func yyGetLiveState() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 5: 直播状态")

    do {
        let room = try await fetchYYRoom()
        let state = try await YY.getLiveState(roomId: room.roomId, userId: room.userId)

        #expect(state != .unknow, "YY 直播状态不应为未知")
        print("✅ YY 直播状态: \(state)")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 直播状态获取失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("YY 搜索房间")
func yySearchRooms() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 6: 搜索房间")

    let keyword = "音乐"
    let results = try await YY.searchRooms(keyword: keyword, page: 1)

    if results.isEmpty {
        print("⚠️ YY 搜索结果为空，关键词: \(keyword)")
    } else {
        print("✅ YY 搜索结果: \(results.count) 条，关键词: \(keyword)")
    }
}

@Test("YY 分享码解析")
func yyShareCodeParse() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 7: 分享码解析")

    do {
        let room = try await fetchYYRoom()
        let info = try await YY.getRoomInfoFromShareCode(shareCode: room.roomId)

        #expect(info.roomId == room.roomId, "YY 分享码解析后的房间ID应匹配输入")
        print("✅ YY 分享码解析成功: 房间 \(info.roomId)")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 分享码解析失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("YY 弹幕参数占位")
func yyDanmukuArgs() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 8: 弹幕参数")

    do {
        let room = try await fetchYYRoom()
        let args = try await YY.getDanmukuArgs(roomId: room.roomId, userId: room.userId)

        #expect(args.0.isEmpty, "YY 弹幕参数应为空（暂未开放）")
        #expect(args.1 == nil, "YY 弹幕 Header 应为 nil")
        print("✅ YY 弹幕参数返回空，符合预期")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 弹幕参数提示失败")
        throw error
    } catch is CancellationError {
        return
    }
}

@Test("YY 最小完整流程")
func yyFullIntegration() async throws {
    prepareYYTestEnvironment()

    print("📋 YY 测试 9: 最小完整流程")

    do {
        let (category, subCategory) = try await fetchYYCategoryContext()
        print("   ✅ 分类: \(category.title) -> 子分类: \(subCategory.title)")

        let rooms = try await YY.getRoomList(id: category.biz ?? "", parentId: subCategory.biz ?? "", page: 1)
        guard let room = rooms.first else {
            print("⚠️ YY 房间列表为空，跳过最小完整流程")
            return
        }

        print("   ✅ 房间: \(room.userName) - \(room.roomId)")

        let info = try await YY.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
        let state = try await YY.getLiveState(roomId: room.roomId, userId: room.userId)
        let playArgs = try await YY.getPlayArgs(roomId: room.roomId, userId: room.userId)
        let shareInfo = try await YY.getRoomInfoFromShareCode(shareCode: room.roomId)
        let danmuArgs = try await YY.getDanmukuArgs(roomId: room.roomId, userId: room.userId)

        #expect(!info.userName.isEmpty, "YY 完整流程 - 房间详情不应为空")
        #expect(state != .unknow, "YY 完整流程 - 直播状态不应未知")
        #expect(!playArgs.isEmpty, "YY 完整流程 - 播放线路不应为空")
        #expect(shareInfo.roomId == room.roomId, "YY 完整流程 - 分享解析应返回同一房间")
        #expect(danmuArgs.0.isEmpty, "YY 完整流程 - 弹幕参数应为空")

        print("✅ YY 最小完整流程验证完成")
    } catch let error as LiveParseError {
        printEnhancedError(error, title: "YY 完整流程失败")
        throw error
    } catch is CancellationError {
        return
    }
}
