import Foundation
import Testing
@testable import LiveParse

// MARK: - Douyu Core Function Tests

@Test("获取斗鱼分类列表")
func douyuGetCategoryList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 1: 获取分类列表")

    do {
        let categories = try await Douyu.getCategoryList()
        #expect(!categories.isEmpty, "斗鱼分类列表不应为空")
        print("✅ 成功获取斗鱼分类: \(categories.count) 个")
    } catch let error as LiveParseError {
        print("❌ 获取斗鱼分类失败")
        printEnhancedError(error, title: "斗鱼分类错误")
        throw error
    }
}

@Test("获取斗鱼房间列表")
func douyuGetRoomList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 2: 获取房间列表")

    let categories = try await Douyu.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的斗鱼分类")
        return
    }

    let rooms = try await Douyu.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    #expect(!rooms.isEmpty, "斗鱼房间列表不应为空")

    if let first = rooms.first {
        print("✅ 斗鱼房间列表获取成功: \(first.userName) - 房间 \(first.roomId)")
    }
}

@Test("获取斗鱼播放地址")
func douyuGetPlayArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 3: 获取播放地址")

    let categories = try await Douyu.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的斗鱼分类")
        return
    }

    let rooms = try await Douyu.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的斗鱼房间")
        return
    }

    let playArgs = try await Douyu.getPlayArgs(roomId: room.roomId, userId: room.userId)

    #expect(!playArgs.isEmpty, "斗鱼播放线路不应为空")
    #expect(playArgs.first?.qualitys.isEmpty == false, "斗鱼播放清晰度不应为空")

    print("✅ 斗鱼播放地址获取成功，线路数: \(playArgs.count)")
}

@Test("获取斗鱼房间状态")
func douyuGetLiveState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 4: 获取房间状态")

    let categories = try await Douyu.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的斗鱼分类")
        return
    }

    let rooms = try await Douyu.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的斗鱼房间")
        return
    }

    let state = try await Douyu.getLiveState(roomId: room.roomId, userId: room.userId)

    #expect(state != .unknow, "斗鱼房间状态不应为未知")
    print("✅ 斗鱼房间状态: \(state)")
}

@Test("获取斗鱼房间详情")
func douyuGetLiveLastestInfo() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 5: 获取房间详情")

    let categories = try await Douyu.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的斗鱼分类")
        return
    }

    let rooms = try await Douyu.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的斗鱼房间")
        return
    }

    let info = try await Douyu.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)

    #expect(!info.roomId.isEmpty, "斗鱼房间ID不应为空")
    #expect(!info.userName.isEmpty, "斗鱼主播昵称不应为空")

    print("✅ 斗鱼房间详情获取成功: \(info.userName) - 房间 \(info.roomId)")
}

@Test("斗鱼直播搜索")
func douyuSearchRooms() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 6: 搜索房间")

    let keyword = "LOL"
    let results = try await Douyu.searchRooms(keyword: keyword, page: 1)

    #expect(!results.isEmpty, "斗鱼搜索结果不应为空")
    print("✅ 斗鱼搜索结果: \(results.count) 条，关键词: \(keyword)")
}

@Test("斗鱼分享码解析")
func douyuGetRoomInfoFromShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 7: 分享码解析")

    let categories = try await Douyu.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的斗鱼分类")
        return
    }

    let rooms = try await Douyu.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的斗鱼房间")
        return
    }

    let info = try await Douyu.getRoomInfoFromShareCode(shareCode: room.roomId)

    #expect(info.roomId == room.roomId, "斗鱼分享码解析结果应匹配房间ID")
    print("✅ 斗鱼分享码解析成功: 房间 \(info.roomId)")
}

@Test("获取斗鱼弹幕参数")
func douyuGetDanmukuArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼测试 8: 获取弹幕参数")

    let roomId = "9999"
    let (args, _) = try await Douyu.getDanmukuArgs(roomId: roomId, userId: nil)

    #expect(args["roomId"] == roomId, "斗鱼弹幕参数应包含房间ID")
    print("✅ 斗鱼弹幕参数获取成功: \(args)")
}

@Test("斗鱼完整集成测试")
func douyuFullIntegration() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 斗鱼完整流程测试")

    print("\n1️⃣ 获取分类...")
    let categories = try await Douyu.getCategoryList()
    #expect(!categories.isEmpty, "斗鱼分类列表不应为空")

    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的斗鱼分类")
        return
    }

    print("\n2️⃣ 获取房间列表...")
    let rooms = try await Douyu.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )
    #expect(!rooms.isEmpty, "斗鱼房间列表不应为空")

    guard let room = rooms.first else {
        Issue.record("没有可用的斗鱼房间")
        return
    }

    print("\n3️⃣ 获取房间详情...")
    let info = try await Douyu.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
    print("   ✅ \(info.userName) - \(info.roomTitle)")

    print("\n4️⃣ 获取播放地址...")
    let playArgs = try await Douyu.getPlayArgs(roomId: room.roomId, userId: room.userId)
    #expect(!playArgs.isEmpty, "斗鱼播放线路不应为空")
    print("   ✅ 播放线路: \(playArgs.count) 条")

    print("\n5️⃣ 获取弹幕参数...")
    let danmuArgs = try await Douyu.getDanmukuArgs(roomId: room.roomId, userId: room.userId)
    #expect(danmuArgs.0["roomId"] == room.roomId, "斗鱼弹幕参数应包含 roomId")
    print("   ✅ 弹幕参数: \(danmuArgs.0)")

    print("\n6️⃣ 分享码解析验证...")
    let shareInfo = try await Douyu.getRoomInfoFromShareCode(shareCode: room.roomId)
    #expect(shareInfo.roomId == room.roomId, "斗鱼分享码解析结果应匹配房间ID")
    print("   ✅ 分享码解析成功: \(shareInfo.roomId)")

    print("\n✅ 斗鱼完整流程测试成功！")
}
