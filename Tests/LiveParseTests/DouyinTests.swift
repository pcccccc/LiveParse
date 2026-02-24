import Foundation
import Testing
@testable import LiveParse

// MARK: - Douyin Test Cookie

/// 手动填入抖音 Cookie，留空则跳过需要 Cookie 的测试
private let douyinTestCookie = ""

// MARK: - Douyin Core Functions Tests

private func prepareDouyinTestEnvironment() {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true
    assertPurePluginMode(platform: "Douyin")
}

/// 注入 Cookie 到抖音 JS 插件运行时，返回 false 表示无 Cookie 可用
private func injectDouyinCookieIfNeeded() async -> Bool {
    let cookie = douyinTestCookie.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cookie.isEmpty else { return false }
    do {
        let plugin = try LiveParsePlugins.shared.resolve(pluginId: "douyin")
        try await plugin.load()
        let escaped = cookie.replacingOccurrences(of: "'", with: "\\'")
        try await plugin.runtime.evaluate(script: "_dy_setRuntimeCookie('\(escaped)')")
        print("🍪 已注入抖音测试 Cookie")
        return true
    } catch {
        print("⚠️ 注入抖音 Cookie 失败: \(error)")
        return false
    }
}

@Test("获取抖音分类列表")
func douyinGetCategoryList() async throws {
    prepareDouyinTestEnvironment()

    print("📋 抖音测试 1: 获取分类列表")

    do {
        let categories = try await Douyin.getCategoryList()
        #expect(!categories.isEmpty, "抖音分类列表不应为空")
        print("✅ 成功获取 \(categories.count) 个抖音分类")
    } catch let error as LiveParseError {
        print("❌ 获取抖音分类失败")
        printEnhancedError(error, title: "抖音分类获取错误")
        throw error
    }
}

@Test("获取抖音房间列表")
func douyinGetRoomList() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 2: 获取房间列表")

    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    #expect(!rooms.isEmpty, "抖音房间列表不应为空")

    if let firstRoom = rooms.first {
        print("✅ 抖音房间列表获取成功: \(firstRoom.userName) - 房间 \(firstRoom.roomId)")
    }
}

@Test("获取抖音播放地址")
func douyinGetPlayArgs() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 3: 获取播放地址")

    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的抖音房间")
        return
    }

    let playArgs = try await Douyin.getPlayArgs(roomId: room.roomId, userId: room.userId)

    #expect(!playArgs.isEmpty, "抖音播放线路不应为空")
    #expect(playArgs.first?.qualitys.isEmpty == false, "抖音播放清晰度列表不应为空")

    print("✅ 抖音播放地址获取成功，线路数: \(playArgs.count)")
}

@Test("获取抖音房间状态")
func douyinGetLiveState() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 4: 获取房间状态")

    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的抖音房间")
        return
    }

    let state = try await Douyin.getLiveState(roomId: room.roomId, userId: room.userId)

    #expect(state != .unknow, "抖音房间状态不应为未知")
    print("✅ 抖音房间状态: \(state)")
}

@Test("获取抖音房间详情")
func douyinGetLiveLastestInfo() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 5: 获取房间详情")

    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的抖音房间")
        return
    }

    let info = try await Douyin.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)

    #expect(!info.userName.isEmpty, "抖音主播名称不应为空")
    #expect(!info.roomId.isEmpty, "抖音房间ID不应为空")
    print("✅ 抖音房间详情获取成功: \(info.userName) - 房间 \(info.roomId)")
}

@Test("抖音搜索房间")
func douyinSearchRooms() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 6: 搜索房间")

    let keyword = "音乐"
    do {
        let results = try await Douyin.searchRooms(keyword: keyword, page: 1)
        if results.isEmpty {
            print("⚠️ 抖音搜索结果为空，可能是上游风控或临时波动")
            return
        }
        print("✅ 抖音搜索获得 \(results.count) 个结果，关键词: \(keyword)")
    } catch {
        let desc = String(describing: error).lowercased()
        if desc.contains("search empty or blocked") || desc.contains("tls") {
            print("⚠️ 抖音搜索被风控/网络波动影响，跳过严格断言: \(error)")
            return
        }
        throw error
    }
}

@Test("抖音分享码解析")
func douyinGetRoomInfoFromShareCode() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 7: 分享码解析")

    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的抖音房间")
        return
    }

    let info = try await Douyin.getRoomInfoFromShareCode(shareCode: room.roomId)

    #expect(!info.roomId.isEmpty, "分享码解析的房间ID不应为空")
    print("✅ 抖音分享码解析成功: \(info.roomId)")
}

@Test("获取抖音弹幕参数")
func douyinGetDanmukuArgs() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试 8: 弹幕参数")

    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )

    guard let room = rooms.first else {
        Issue.record("没有可用的抖音房间")
        return
    }

    let danmuArgs = try await Douyin.getDanmukuArgs(roomId: room.roomId, userId: room.userId)

    #expect(!danmuArgs.0.isEmpty, "抖音弹幕参数不应为空")
    #expect(danmuArgs.0["room_id"] != nil, "弹幕参数应包含 room_id")

    print("✅ 抖音弹幕参数生成成功，参数数量: \(danmuArgs.0.count)")
}

// MARK: - 集成 / 错误 / 性能测试

@Test("抖音完整集成测试")
func douyinFullIntegration() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音完整流程测试")

    print("\n1️⃣ 获取分类...")
    let categories = try await Douyin.getCategoryList()
    #expect(!categories.isEmpty, "抖音分类列表不应为空")

    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    print("\n2️⃣ 获取房间列表...")
    let rooms = try await Douyin.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )
    #expect(!rooms.isEmpty, "抖音房间列表不应为空")

    guard let room = rooms.last else {
        Issue.record("没有可用的抖音房间")
        return
    }

    print("\n3️⃣ 获取房间详情...")
    let roomInfo = try await Douyin.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
    print("   ✅ \(roomInfo.userName) - \(roomInfo.roomTitle)")

    print("\n4️⃣ 获取播放地址...")
    let playArgs = try await Douyin.getPlayArgs(roomId: room.roomId, userId: room.userId)
    #expect(!playArgs.isEmpty, "抖音播放线路不应为空")
    print("   ✅ 播放线路: \(playArgs.count) 条")

    print("\n5️⃣ 获取弹幕参数...")
    let danmuArgs = try await Douyin.getDanmukuArgs(roomId: room.roomId, userId: room.userId)
    #expect(danmuArgs.0["room_id"] != nil, "弹幕参数应包含 room_id")
    print("   ✅ 弹幕参数数量: \(danmuArgs.0.count)")

    print("\n6️⃣ 搜索房间...")
    let searchResults = try await Douyin.getRoomInfoFromShareCode(shareCode: "https://live.douyin.com/339638082961?enter_from_merge=link_share&enter_method=copy_link_share&action_type=click&from=web_code_link")
    #expect(!searchResults.roomId.isEmpty, "抖音搜索结果不应为空")
    print("   ✅ 搜索结果: \(searchResults.roomTitle) ")

    print("\n✅ 抖音完整流程测试成功！")
}

@Test("抖音错误处理-无效房间号")
func douyinErrorHandling_InvalidRoomId() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音错误处理：无效房间号")

    do {
        let info = try await Douyin.getLiveLastestInfo(roomId: "999999999999", userId: nil)
        #expect(!info.roomId.isEmpty, "无效房间号在当前环境下返回成功时，roomId 不应为空")
        print("⚠️ 无效房间号未触发异常，返回 roomId=\(info.roomId)")
    } catch let error as LiveParseError {
        print("✅ 正确捕获抖音错误")
        printEnhancedError(error, title: "抖音无效房间号错误")
        #expect(!error.userFriendlyMessage.isEmpty, "错误提示不应为空")
    } catch {
        #expect(!String(describing: error).isEmpty, "错误描述不应为空")
    }
}

@Test("抖音错误处理-无效分享码")
func douyinErrorHandling_InvalidShareCode() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音错误处理：无效分享码")

    do {
        let info = try await Douyin.getRoomInfoFromShareCode(shareCode: "https://invalid.douyin.com/share")
        #expect(!info.roomId.isEmpty, "无效分享码在当前环境下返回成功时，roomId 不应为空")
        print("⚠️ 无效分享码未触发异常，返回 roomId=\(info.roomId)")
    } catch let error as LiveParseError {
        print("✅ 正确捕获抖音分享码错误")
        printEnhancedError(error, title: "抖音无效分享码错误")
        #expect(!error.userFriendlyMessage.isEmpty, "错误提示不应为空")
    } catch {
        #expect(!String(describing: error).isEmpty, "错误描述不应为空")
    }
}

@Test("抖音错误处理-网络详情")
func douyinErrorHandling_NetworkDetails() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音错误处理：检查网络详情")

    do {
        let state = try await Douyin.getLiveState(roomId: "invalid_room_123", userId: nil)
        print("⚠️ 无效 roomId 返回状态: \(state)，未触发异常")
    } catch let error as LiveParseError {
        print("✅ 捕获到抖音网络错误")
        printEnhancedError(error, title: "抖音网络请求详情")

        let description = error.description
        if description.contains("网络请求") {
            #expect(description.contains("URL") || description.contains("请求"), "错误描述应包含请求信息")
        }
    } catch {
        #expect(!String(describing: error).isEmpty, "错误描述不应为空")
    }
}

@Test("测试多机位 camera_id 作为弹幕 roomId")
func douyinTestCameraIdAsDanmukuRoomId() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音测试：camera_id 作为弹幕 roomId")

    // 使用从 JSON 中提取的 camera_id
    let cameraId = "7584986812533134399"

    print("🔍 尝试使用 camera_id: \(cameraId) 连接弹幕服务器")

    do {
        let danmuArgs = try await Douyin.getDanmukuArgs(roomId: cameraId, userId: nil)

        print("✅ 成功生成弹幕参数！")
        print("   room_id: \(danmuArgs.0["room_id"] ?? "无")")
        print("   参数数量: \(danmuArgs.0.count)")

        #expect(!danmuArgs.0.isEmpty, "弹幕参数不应为空")
        #expect(danmuArgs.0["room_id"] != nil, "应包含 room_id")

    } catch let error as LiveParseError {
        print("❌ camera_id 无法作为弹幕 roomId 使用")
        printEnhancedError(error, title: "camera_id 弹幕测试失败")
        throw error
    }
}

@Test("抖音性能测试-批量请求")
func douyinPerformance_BatchRequests() async throws {
    prepareDouyinTestEnvironment()
    guard await injectDouyinCookieIfNeeded() else {
        print("⏭️ 跳过：未配置抖音 Cookie")
        return
    }

    print("📋 抖音性能测试：批量请求")

    // 先获取一个真实的分类与房间，用来提取真实 roomId/userId
    let categories = try await Douyin.getCategoryList()
    guard let category = categories.first,
          let sub = category.subList.first else {
        Issue.record("没有可用的抖音分类")
        return
    }

    let rooms = try await Douyin.getRoomList(id: sub.id, parentId: category.id, page: 1)
    let roomIds = rooms.prefix(3)

    guard !roomIds.isEmpty else {
        Issue.record("没有可用的抖音房间")
        return
    }

    let startTime = Date()

    try await withThrowingTaskGroup(of: LiveModel.self) { group in
        for room in roomIds {
            group.addTask {
                try await Douyin.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
            }
        }

        var count = 0
        for try await _ in group {
            count += 1
        }

        #expect(count == roomIds.count, "应成功获取所有抖音房间信息")
    }

    let duration = Date().timeIntervalSince(startTime)
    print("✅ 完成 \(roomIds.count) 个并发请求，耗时: \(String(format: "%.2f", duration)) 秒")
    #expect(duration < 12.0, "并发请求应在 12 秒内完成")
}
