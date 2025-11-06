import Foundation
import Testing
@testable import LiveParse

// MARK: - Bilibili Core Functions Tests

@Test("获取B站分类列表")
func bilibiliGetCategoryList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 1: 获取分类列表")

    do {
        let categories = try await Bilibili.getCategoryList()

        #expect(!categories.isEmpty, "分类列表不应为空")
        #expect(categories.first != nil, "应该至少有一个分类")

        print("✅ 成功获取 \(categories.count) 个分类")
        if let firstCategory = categories.first {
            print("   第一个分类: \(firstCategory.title)")
            print("   子分类数量: \(firstCategory.subList.count)")
        }
    } catch let error as LiveParseError {
        print("❌ 获取分类列表失败")
        printEnhancedError(error, title: "获取分类列表错误")
        throw error
    }
}

@Test("获取B站房间列表")
func bilibiliGetRoomList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 2: 获取房间列表")

    let categories = try await Bilibili.getCategoryList()
    guard let firstCategory = categories.first,
          let firstSubCategory = firstCategory.subList.first else {
        Issue.record("没有可用的分类")
        return
    }

    let rooms = try await Bilibili.getRoomList(
        id: firstSubCategory.id,
        parentId: firstCategory.id,
        page: 1
    )

    #expect(!rooms.isEmpty, "房间列表不应为空")

    if let firstRoom = rooms.first {
        print("✅ 成功获取 \(rooms.count) 个房间")
        print("   第一个房间:")
        print("   - 主播: \(firstRoom.userName)")
        print("   - 标题: \(firstRoom.roomTitle)")
        print("   - 房间ID: \(firstRoom.roomId)")
    }
}

@Test("获取B站直播状态")
func bilibiliGetLiveState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 3: 获取直播状态")

    let testRoomId = "6"

    do {
        let liveState = try await Bilibili.getLiveState(roomId: testRoomId, userId: nil)

        #expect(liveState != .unknow, "应该能正确获取直播状态")
        print("✅ 直播状态: \(liveState)")
    } catch let error as LiveParseError {
        print("❌ 获取直播状态失败")
        printEnhancedError(error, title: "获取直播状态错误")
        throw error
    }
}

@Test("获取B站直播间详细信息")
func bilibiliGetLiveLastestInfo() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 4: 获取直播间详细信息")

    let testRoomId = "6"
    let roomInfo = try await Bilibili.getLiveLastestInfo(roomId: testRoomId, userId: nil)

    #expect(!roomInfo.userName.isEmpty, "主播名称不应为空")
    #expect(!roomInfo.roomId.isEmpty, "房间ID不应为空")

    print("✅ 房间信息:")
    print("   主播: \(roomInfo.userName)")
    print("   标题: \(roomInfo.roomTitle)")
    print("   房间ID: \(roomInfo.roomId)")
    print("   用户ID: \(roomInfo.userId)")
    print("   状态: \(roomInfo.liveState ?? "未知")")
}

@Test("从分享码获取房间信息")
func bilibiliGetRoomInfoFromShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 5: 从分享码获取房间信息")

    let testCases = [
        ("房间号", "6")
    ]

    for (type, shareCode) in testCases {
        print("   测试 \(type): \(shareCode)")

        let roomInfo = try await Bilibili.getRoomInfoFromShareCode(shareCode: shareCode)

        #expect(!roomInfo.userName.isEmpty, "\(type) - 主播名称不应为空")
        #expect(!roomInfo.roomId.isEmpty, "\(type) - 房间ID不应为空")

        print("   ✅ 解析成功: \(roomInfo.userName) - 房间\(roomInfo.roomId)")
    }
}

@Test("获取B站弹幕参数")
func bilibiliGetDanmukuArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 6: 获取弹幕参数")

    let testRoomId = "6"
    let danmuArgs = try await Bilibili.getDanmukuArgs(roomId: testRoomId, userId: nil)

    #expect(danmuArgs.0["ws_url"] != nil, "WebSocket URL不应为空")
    #expect(danmuArgs.0["token"] != nil, "Token不应为空")
    #expect(danmuArgs.0["buvid"] != nil, "Buvid不应为空")

    print("✅ 弹幕参数:")
    print("   WebSocket URL: \(danmuArgs.0["ws_url"] ?? "无")")
    print("   Token: \(danmuArgs.0["token"]?.prefix(20) ?? "无")...")
    print("   Buvid: \(danmuArgs.0["buvid"]?.prefix(20) ?? "无")...")
    print("   房间ID: \(danmuArgs.0["roomId"] ?? "无")")
}

@Test("获取B站播放地址")
func bilibiliGetPlayArgs() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 7: 获取播放地址 ⭐")

    let testRoomId = "6"

    do {
        let playUrls = try await Bilibili.getPlayArgs(roomId: testRoomId, userId: nil)

        #expect(!playUrls.isEmpty, "播放地址列表不应为空")

        print("✅ 播放地址:")
        print("   共 \(playUrls.count) 条线路")

        for (index, quality) in playUrls.enumerated() {
            print("   线路\(index + 1): \(quality.cdn) - \(quality.qualitys.count)个清晰度")
            #expect(!quality.qualitys.isEmpty, "线路\(index + 1)的清晰度列表不应为空")

            for q in quality.qualitys.prefix(3) {
                print("      - \(q.title): \(q.url.prefix(50))...")
                #expect(!q.url.isEmpty, "播放URL不应为空")
            }
        }
    } catch let error as LiveParseError {
        print("❌ 获取播放地址失败")
        printEnhancedError(error, title: "获取播放地址错误")
        throw error
    }
}

@Test("搜索B站直播间")
func bilibiliSearchRooms() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 8: 搜索直播间 ⭐")

    let testKeyword = "英雄联盟"

    do {
        let searchResults = try await Bilibili.searchRooms(keyword: testKeyword, page: 1)

        #expect(!searchResults.isEmpty, "搜索结果不应为空")

        print("✅ 搜索 '\(testKeyword)' 结果: \(searchResults.count) 个房间")
        for (index, room) in searchResults.prefix(5).enumerated() {
            print("   \(index + 1). \(room.userName) - \(room.roomTitle)")
            print("      房间ID: \(room.roomId), 观看: \(room.liveWatchedCount ?? "未知")")

            #expect(!room.userName.isEmpty, "主播名称不应为空")
            #expect(!room.roomId.isEmpty, "房间ID不应为空")
        }
    } catch let error as LiveParseError {
        print("❌ 搜索直播间失败")
        printEnhancedError(error, title: "搜索直播间错误")
        throw error
    }
}

@Test("获取B站登录二维码")
func bilibiliGetQRCodeUrl() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 9: 获取登录二维码")

    let qrCode = try await Bilibili.getQRCodeUrl()

    #expect(!(qrCode.data.url ?? "").isEmpty, "二维码URL不应为空")
    #expect(!(qrCode.data.qrcode_key ?? "").isEmpty, "二维码Key不应为空")

    print("✅ 二维码信息:")
    print("   URL: \(qrCode.data.url?.prefix(50))...")
    print("   Key: \(qrCode.data.qrcode_key?.prefix(30))...")
}

@Test("检查B站二维码扫描状态")
func bilibiliGetQRCodeState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 10: 检查二维码扫描状态")

    let qrCode = try await Bilibili.getQRCodeUrl()
    let qrState = try await Bilibili.getQRCodeState(qrcode_key: qrCode.data.qrcode_key ?? "")

    print("✅ 二维码状态:")
    print("   状态码: \(qrState.0.data.code ?? 0)")
    print("   消息: \(qrState.0.data.message ?? "")")
}

// MARK: - Integration / Error / Performance

@Test("Bilibili完整集成测试")
func bilibiliFullIntegration() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 完整集成测试：用户使用流程")

    print("\n1️⃣ 获取分类...")
    let categories = try await Bilibili.getCategoryList()
    #expect(!categories.isEmpty)
    print("   ✅ \(categories.count) 个分类")

    print("\n2️⃣ 获取房间列表...")
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的分类")
        return
    }

    let rooms = try await Bilibili.getRoomList(
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )
    #expect(!rooms.isEmpty)
    print("   ✅ \(rooms.count) 个房间")

    print("\n3️⃣ 获取房间详情...")
    guard let room = rooms.first else {
        Issue.record("没有可用的房间")
        return
    }

    let roomInfo = try await Bilibili.getLiveLastestInfo(
        roomId: room.roomId,
        userId: room.userId
    )
    print("   ✅ \(roomInfo.userName) - \(roomInfo.roomTitle)")

    print("\n4️⃣ 获取播放地址...")
    let playUrls = try await Bilibili.getPlayArgs(
        roomId: roomInfo.roomId,
        userId: roomInfo.userId
    )
    #expect(!playUrls.isEmpty)
    print("   ✅ \(playUrls.count) 条线路")

    print("\n5️⃣ 获取弹幕参数...")
    let danmuArgs = try await Bilibili.getDanmukuArgs(
        roomId: roomInfo.roomId,
        userId: roomInfo.userId
    )
    #expect(danmuArgs.0["ws_url"] != nil)
    print("   ✅ WebSocket: \(danmuArgs.0["ws_url"]?.prefix(40) ?? "")...")

    print("\n6️⃣ 测试搜索...")
    let searchResults = try await Bilibili.searchRooms(keyword: "LOL", page: 1)
    #expect(!searchResults.isEmpty)
    print("   ✅ \(searchResults.count) 个搜索结果")

    print("\n✅ 完整流程测试成功！")
}

@Test("错误处理-无效房间号")
func bilibiliErrorHandling_InvalidRoomId() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误处理：无效房间号")

    do {
        _ = try await Bilibili.getLiveLastestInfo(roomId: "99999999999", userId: nil)
        Issue.record("应该抛出错误")
    } catch let error as LiveParseError {
        print("✅ 正确捕获错误")
        printEnhancedError(error, title: "无效房间号错误")
        #expect(!error.userFriendlyMessage.isEmpty, "错误提示不应为空")
        #expect(
            error.detail.contains("https://api.live.bilibili.com/xlive/web-room/v1/index/getH5InfoByRoom"),
            "错误详情应包含请求的接口地址"
        )
    }
}

@Test("错误处理-无效分享码")
func bilibiliErrorHandling_InvalidShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误处理：无效分享码")

    do {
        _ = try await Bilibili.getRoomInfoFromShareCode(shareCode: "https://invalid.url.com/test")
    } catch let error as LiveParseError {
        print("✅ 正确捕获错误")
        printEnhancedError(error, title: "无效分享码错误")
        #expect(!error.userFriendlyMessage.isEmpty, "错误提示不应为空")
    }
}

@Test("错误处理-网络请求详情")
func bilibiliErrorHandling_NetworkDetails() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误处理：检查网络请求详情")

    do {
        _ = try await Bilibili.getLiveState(roomId: "invalid_room_123", userId: nil)
    } catch let error as LiveParseError {
        print("✅ 正确捕获错误，包含详细的网络请求信息")
        printEnhancedError(error, title: "网络请求详情示例")

        let errorDescription = error.description
        if errorDescription.contains("网络请求") {
            #expect(
                errorDescription.contains("URL") || errorDescription.contains("请求"),
                "网络错误应包含请求信息"
            )
        }
    }
}

@Test("错误类型展示-LiveParseError+Enhanced功能")
func bilibiliErrorHandling_EnhancedErrorDemo() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误类型展示：LiveParseError+Enhanced 的各项功能")

    let testCases: [(name: String, roomId: String)] = [
        ("不存在的房间", "99999999999"),
        ("无效格式的房间ID", "invalid_room_id"),
        ("空房间ID", "")
    ]

    for (index, testCase) in testCases.enumerated() {
        print("\n" + String(repeating: "─", count: 60))
        print("测试场景 \(index + 1): \(testCase.name)")
        print(String(repeating: "─", count: 60))

        do {
            _ = try await Bilibili.getLiveLastestInfo(roomId: testCase.roomId, userId: nil)
            print("⚠️  意外成功，预期应该失败")
        } catch let error as LiveParseError {
            printEnhancedError(error, title: "\(testCase.name) - 完整错误信息")
            print("\n🔍 错误属性分析:")
            print("   • 错误类型: \(type(of: error))")
            print("   • 用户友好消息: \(error.userFriendlyMessage)")
            print("   • 可重试: \(error.isRetryable ? "✅" : "❌")")
            print("   • 有恢复建议: \(error.recoverySuggestion != nil ? "✅" : "❌")")
        } catch {
            print("❌ 捕获到非 LiveParseError 类型的错误: \(error)")
        }
    }

    print("\n" + String(repeating: "═", count: 60))
    print("✅ 错误类型展示测试完成")
    print(String(repeating: "═", count: 60))
}

@Test("性能测试-批量请求")
func bilibiliPerformance_BatchRequests() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 性能测试：批量请求")

    let startTime = Date()
    let roomIds = ["6", "7", "8"]

    try await withThrowingTaskGroup(of: LiveModel.self) { group in
        for roomId in roomIds {
            group.addTask {
                try await Bilibili.getLiveLastestInfo(roomId: roomId, userId: nil)
            }
        }

        var count = 0
        for try await _ in group {
            count += 1
        }

        #expect(count == roomIds.count, "应该成功获取所有房间信息")
    }

    let duration = Date().timeIntervalSince(startTime)
    print("   ✅ 完成 \(roomIds.count) 个并发请求，耗时: \(String(format: "%.2f", duration))秒")

    #expect(duration < 10.0, "并发请求应该在10秒内完成")
}
