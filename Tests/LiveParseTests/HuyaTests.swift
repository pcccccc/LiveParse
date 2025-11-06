import Foundation
import Testing
@testable import LiveParse

// MARK: - Huya Core Function Tests

@Test("获取虎牙分类列表")
func huyaGetCategoryList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 1: 分类列表")

    do {
        let categories = try await Huya.getCategoryList()
        #expect(!categories.isEmpty, "虎牙分类列表不应为空")
        print("✅ 成功获取虎牙分类: \(categories.count) 个")
    } catch let error as LiveParseError {
        print("❌ 获取虎牙分类失败")
        printEnhancedError(error, title: "虎牙分类错误")
        throw error
    }
}

@Test("获取虎牙房间列表")
func huyaGetRoomList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 2: 房间列表")

    let categories = try await Huya.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的虎牙分类")
        return
    }

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    #expect(!rooms.isEmpty, "虎牙房间列表不应为空")

    if let first = rooms.first {
        print("✅ 成功获取虎牙房间: \(first.userName) - 房间 \(first.roomId)")
    }
}

@Test("获取虎牙播放地址")
func huyaGetPlayArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 3: 播放地址")

    let categories = try await Huya.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的虎牙分类")
        return
    }

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的虎牙房间")
        return
    }

    let playArgs = try await Huya.getPlayArgs(roomId: room.roomId, userId: room.userId)

    #expect(!playArgs.isEmpty, "虎牙播放线路不应为空")
    #expect(playArgs.first?.qualitys.isEmpty == false, "虎牙播放清晰度不应为空")

    print("✅ 虎牙播放地址获取成功，线路: \(playArgs.count) 条")
}

@Test("获取虎牙房间状态")
func huyaGetLiveState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 4: 房间状态")

    let categories = try await Huya.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的虎牙分类")
        return
    }

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的虎牙房间")
        return
    }

    let state = try await Huya.getLiveState(roomId: room.roomId, userId: room.userId)

    #expect(state != .unknow, "虎牙房间状态不应为未知")
    print("✅ 虎牙房间状态: \(state)")
}

@Test("获取虎牙房间详情")
func huyaGetLiveLastestInfo() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 5: 房间详情")

    let categories = try await Huya.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的虎牙分类")
        return
    }

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的虎牙房间")
        return
    }

    let info = try await Huya.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)

    #expect(!info.userName.isEmpty, "虎牙主播名称不应为空")
    #expect(!info.roomId.isEmpty, "虎牙房间ID不应为空")

    print("✅ 虎牙房间详情: \(info.userName) - 房间 \(info.roomId)")
}

@Test("虎牙搜索房间")
func huyaSearchRooms() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 6: 搜索房间")

    let keyword = "王者"
    let results = try await Huya.searchRooms(keyword: keyword, page: 1)

    #expect(!results.isEmpty, "虎牙搜索结果不应为空")
    print("✅ 虎牙搜索结果: \(results.count) 条，关键词: \(keyword)")
}

@Test("虎牙分享码解析")
func huyaGetRoomInfoFromShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 7: 分享码解析")

    let categories = try await Huya.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的虎牙分类")
        return
    }

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的虎牙房间")
        return
    }

    let info = try await Huya.getRoomInfoFromShareCode(shareCode: room.roomId)

    #expect(!info.roomId.isEmpty, "虎牙分享码解析结果不应为空")
    print("✅ 虎牙分享码解析成功: 房间 \(info.roomId)")
}

@Test("获取虎牙弹幕参数")
func huyaGetDanmukuArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 8: 弹幕参数")

    let categories = try await Huya.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的虎牙分类")
        return
    }

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的虎牙房间")
        return
    }

    let danmuArgs = try await Huya.getDanmukuArgs(roomId: room.roomId, userId: room.userId)

    #expect(!danmuArgs.0.isEmpty, "虎牙弹幕参数不应为空")
    print("✅ 虎牙弹幕参数: \(danmuArgs.0)")
}

@Test("虎牙完整流程")
func huyaFullIntegration() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 9: 最小完整流程")

    let categories = try await Huya.getCategoryList()
    #expect(!categories.isEmpty, "虎牙分类不能为空")

    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("虎牙分类/子分类不可用")
        return
    }

    print("   ✅ 分类: \(category.title) -> 子分类: \(subCategory.title)")

    let rooms = try await Huya.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )
    #expect(!rooms.isEmpty, "虎牙房间列表不能为空")

    guard let room = rooms.first else {
        Issue.record("无可用虎牙房间")
        return
    }

    print("   ✅ 房间: \(room.userName) (\(room.roomId))")

    let info = try await Huya.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
    #expect(!info.roomId.isEmpty, "虎牙房间详情应返回房间ID")
    print("   ✅ 详情: 状态 \(info.liveState ?? "未知")")

    let playArgs = try await Huya.getPlayArgs(roomId: info.roomId, userId: info.userId)
    #expect(!playArgs.isEmpty, "虎牙播放线路不应为空")
    print("   ✅ 播放线路数: \(playArgs.count)")

    let danmuArgs = try await Huya.getDanmukuArgs(roomId: info.roomId, userId: info.userId)
    #expect(!danmuArgs.0.isEmpty, "虎牙弹幕参数不应为空")
    print("   ✅ 弹幕参数获取成功")

    print("✅ 虎牙最小完整流程测试通过")
}

// MARK: - Huya Error Handling Tests

@Test("虎牙错误处理 - 无效房间号")
func huyaErrorHandling_InvalidRoomId() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 10: 错误处理 (无效房间号)")

    do {
        _ = try await Huya.getLiveLastestInfo(roomId: "999999999", userId: nil)
        Issue.record("应该抛出错误")
    } catch let error as LiveParseError {
        print("✅ 正确捕获虎牙错误")
        printEnhancedError(error, title: "虎牙无效房间错误")

        #expect(!error.userFriendlyMessage.isEmpty, "虎牙错误提示不应为空")
        #expect(error.detail.contains("Huya.getLiveLastestInfo") || error.detail.contains("HNF_GLOBAL_INIT"),
                "错误详情应包含解析上下文信息")
    }
}

@Test("虎牙错误处理 - 无效分享码")
func huyaErrorHandling_InvalidShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 虎牙测试 11: 错误处理 (无效分享码)")

    let invalidShareCode = "https://invalid.example.com/share/foobar"

    do {
        _ = try await Huya.getRoomInfoFromShareCode(shareCode: invalidShareCode)
        Issue.record("应该抛出错误")
    } catch let error as LiveParseError {
        print("✅ 正确捕获虎牙分享码错误")
        printEnhancedError(error, title: "虎牙分享码解析错误")

        #expect(error.detail.contains(invalidShareCode), "错误详情应包含原始分享码")
    }
}
