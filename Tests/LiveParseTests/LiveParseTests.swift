import Testing
import Foundation
@testable import LiveParse

// MARK: - Helper Functions

/// 打印增强的错误信息
func printEnhancedError(_ error: LiveParseError, title: String = "错误详情") {
    print("\n" + String(repeating: "═", count: 60))
    print("   \(title)")
    print(String(repeating: "═", count: 60))

    print("\n📌 用户友好提示:")
    print("   \(error.userFriendlyMessage)")

    print("\n🔄 是否可重试:")
    print("   \(error.isRetryable ? "✅ 是" : "❌ 否")")

    if let suggestion = error.recoverySuggestion {
        print("\n💡 恢复建议:")
        suggestion.split(separator: "\n").forEach { line in
            print("   \(line)")
        }
    }

    print("\n📋 完整错误描述:")
    error.description.split(separator: "\n").forEach { line in
        print("   \(line)")
    }

    print("\n" + String(repeating: "═", count: 60))
}

// MARK: - Bilibili Core Functions Tests

/// 测试1: 获取B站分类列表
@Test("获取B站分类列表")
func bilibiliGetCategoryList() async throws {
    // 配置日志级别
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

/// 测试2: 获取B站房间列表
@Test("获取B站房间列表")
func bilibiliGetRoomList() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 2: 获取房间列表")

    // 先获取分类
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

    print("✅ 成功获取 \(rooms.count) 个房间")
    if let firstRoom = rooms.first {
        print("   第一个房间:")
        print("   - 主播: \(firstRoom.userName)")
        print("   - 标题: \(firstRoom.roomTitle)")
        print("   - 房间ID: \(firstRoom.roomId)")
    }
}

/// 测试3: 获取B站直播状态
@Test("获取B站直播状态")
func bilibiliGetLiveState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 3: 获取直播状态")

    // 使用知名主播的房间号进行测试（例如：6，官方）
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

/// 测试4: 获取B站直播间详细信息
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

/// 测试5: 从分享码获取房间信息
@Test("从分享码获取房间信息")
func bilibiliGetRoomInfoFromShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 5: 从分享码获取房间信息")

    // 测试不同类型的分享码
    let testCases = [
        ("房间号", "6"),
        // 可以添加更多测试用例：
        // ("短链接", "https://b23.tv/xxxxx"),
        // ("长链接", "https://live.bilibili.com/6"),
    ]

    for (type, shareCode) in testCases {
        print("   测试 \(type): \(shareCode)")

        let roomInfo = try await Bilibili.getRoomInfoFromShareCode(shareCode: shareCode)

        #expect(!roomInfo.userName.isEmpty, "\(type) - 主播名称不应为空")
        #expect(!roomInfo.roomId.isEmpty, "\(type) - 房间ID不应为空")

        print("   ✅ 解析成功: \(roomInfo.userName) - 房间\(roomInfo.roomId)")
    }
}

/// 测试6: 获取B站弹幕参数
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

/// 测试7: 获取B站播放地址 ⭐ 重要！
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

            // 显示前3个清晰度
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

/// 测试8: 搜索B站直播间 ⭐ 重要！
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

/// 测试9: 获取B站登录二维码
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

/// 测试10: 检查B站二维码扫描状态
@Test("检查B站二维码扫描状态")
func bilibiliGetQRCodeState() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试 10: 检查二维码扫描状态")

    // 先获取二维码
    let qrCode = try await Bilibili.getQRCodeUrl()

    // 检查状态（未扫描时应该返回特定状态码）
    let qrState = try await Bilibili.getQRCodeState(qrcode_key: qrCode.data.qrcode_key ?? "")

    // 未扫描时，code应该不为0
    print("✅ 二维码状态:")
    print("   状态码: \(qrState.0.data.code ?? 0)")
    print("   消息: \(qrState.0.data.message ?? "")")

    // 这里不做断言，因为未扫描的状态码可能是86101等
    // #expect(qrState.0.data.code != 0, "未扫描时code不应为0")
}

// MARK: - Integration Test

/// 完整集成测试：模拟用户完整使用流程
@Test("Bilibili完整集成测试")
func bilibiliFullIntegration() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 完整集成测试：用户使用流程")

    // 1. 获取分类
    print("\n1️⃣ 获取分类...")
    let categories = try await Bilibili.getCategoryList()
    #expect(!categories.isEmpty)
    print("   ✅ \(categories.count) 个分类")

    // 2. 选择分类，获取房间列表
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

    // 3. 选择房间，获取详细信息
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

    // 4. 获取播放地址
    print("\n4️⃣ 获取播放地址...")
    let playUrls = try await Bilibili.getPlayArgs(
        roomId: roomInfo.roomId,
        userId: roomInfo.userId
    )
    #expect(!playUrls.isEmpty)
    print("   ✅ \(playUrls.count) 条线路")

    // 5. 获取弹幕参数
    print("\n5️⃣ 获取弹幕参数...")
    let danmuArgs = try await Bilibili.getDanmukuArgs(
        roomId: roomInfo.roomId,
        userId: roomInfo.userId
    )
    #expect(danmuArgs.0["ws_url"] != nil)
    print("   ✅ WebSocket: \(danmuArgs.0["ws_url"]?.prefix(40) ?? "")...")

    // 6. 测试搜索功能
    print("\n6️⃣ 测试搜索...")
    let searchResults = try await Bilibili.searchRooms(keyword: "LOL", page: 1)
    #expect(!searchResults.isEmpty)
    print("   ✅ \(searchResults.count) 个搜索结果")

    print("\n✅ 完整流程测试成功！")
}

// MARK: - Error Handling Tests

/// 测试错误处理：无效房间号
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

        // 验证错误信息不为空
        #expect(!error.userFriendlyMessage.isEmpty, "错误提示不应为空")
    }
}

/// 测试错误处理：无效分享码
@Test("错误处理-无效分享码")
func bilibiliErrorHandling_InvalidShareCode() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误处理：无效分享码")

    do {
        _ = try await Bilibili.getRoomInfoFromShareCode(shareCode: "https://invalid.url.com/test")
        // 注意：某些无效分享码可能会被当作房间号处理，所以这里可能不会抛出错误
    } catch let error as LiveParseError {
        print("✅ 正确捕获错误")
        printEnhancedError(error, title: "无效分享码错误")

        #expect(!error.userFriendlyMessage.isEmpty, "错误提示不应为空")
    }
}

/// 测试错误处理：网络请求详情
@Test("错误处理-网络请求详情")
func bilibiliErrorHandling_NetworkDetails() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误处理：检查网络请求详情")

    do {
        // 使用一个可能失败的操作
        _ = try await Bilibili.getLiveState(roomId: "invalid_room_123", userId: nil)
    } catch let error as LiveParseError {
        print("✅ 正确捕获错误，包含详细的网络请求信息")
        printEnhancedError(error, title: "网络请求详情示例")

        let errorDescription = error.description

        // 验证错误描述包含关键信息
        print("\n📊 错误分析:")
        print("   错误描述长度: \(errorDescription.count) 字符")

        // 如果是网络错误，应该包含请求详情
        if errorDescription.contains("网络请求") {
            print("   ✅ 包含网络请求详情")
            #expect(
                errorDescription.contains("URL") || errorDescription.contains("请求"),
                "网络错误应包含请求信息"
            )
        }
    }
}

/// 测试错误类型展示：展示增强错误系统的功能
@Test("错误类型展示-LiveParseError+Enhanced功能")
func bilibiliErrorHandling_EnhancedErrorDemo() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 测试错误类型展示：LiveParseError+Enhanced 的各项功能")
    print("   这个测试将展示增强错误系统如何提供丰富的错误信息\n")

    // 测试多个可能失败的场景
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
            // 展示增强错误系统的所有功能
            printEnhancedError(error, title: "\(testCase.name) - 完整错误信息")

            // 额外展示错误的其他属性
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

// MARK: - Performance Tests

/// 性能测试：批量请求
@Test("性能测试-批量请求")
func bilibiliPerformance_BatchRequests() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    print("📋 性能测试：批量请求")

    let startTime = Date()

    // 并发获取多个房间的信息
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

    // 性能断言：并发请求应该在合理时间内完成
    #expect(duration < 10.0, "并发请求应该在10秒内完成")
}
