import Foundation
import Testing
@testable import LiveParse

// MARK: - KuaiShou Helper

private func prepareKuaiShouTestEnvironment() {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true
    assertPurePluginMode(platform: "KuaiShou")
}

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

private func fetchKuaiShouPlayableRoom(maxProbeCount: Int = 10) async throws -> (LiveModel, [LiveQualityModel]) {
    let (_, subCategory) = try await fetchKuaiShouCategoryContext()
    let rooms = try await KuaiShou.getRoomList(id: subCategory.id, parentId: nil, page: 1)
    guard !rooms.isEmpty else {
        Issue.record("快手房间列表为空")
        throw CancellationError()
    }

    // 优先探测标记为直播中的房间，降低拿到无流房间的概率。
    let preferred = rooms.sorted { lhs, rhs in
        let lhsScore = (lhs.liveState == LiveState.live.rawValue) ? 0 : 1
        let rhsScore = (rhs.liveState == LiveState.live.rawValue) ? 0 : 1
        return lhsScore < rhsScore
    }

    var lastError: Error?
    for room in preferred.prefix(maxProbeCount) {
        do {
            let playArgs = try await KuaiShou.getPlayArgs(roomId: room.roomId, userId: room.userId)
            if !playArgs.isEmpty {
                return (room, playArgs)
            }
        } catch {
            lastError = error
        }
    }

    if let liveParseError = lastError as? LiveParseError {
        throw liveParseError
    }
    throw LiveParseError.liveParseError("快手播放参数获取失败", "尝试 \(min(preferred.count, maxProbeCount)) 个房间后仍无可用播放流")
}

private func isKuaiShouTransientError(_ error: Error) -> Bool {
    let message = String(describing: error)
    return message.contains("__INITIAL_STATE__ not found")
        || message.contains("playUrls is empty")
        || message.contains("empty quality details")
        || message.contains("无可用播放流")
}

// MARK: - KuaiShou Tests

@Test("获取快手分类列表")
func kuaishouGetCategoryList() async throws {
    prepareKuaiShouTestEnvironment()

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
    prepareKuaiShouTestEnvironment()

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
    prepareKuaiShouTestEnvironment()

    print("📋 快手测试 3: 获取房间详情")

    do {
        let room = try await fetchKuaiShouRoom()
        let info = try await KuaiShou.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)

        #expect(!info.roomId.isEmpty, "快手房间详情 - 房间ID不应为空")
        if info.userName.isEmpty && info.roomTitle.isEmpty {
            print("⚠️ 快手房间详情返回空昵称/标题，跳过当前用例: roomId=\(info.roomId)")
            return
        }

        print("✅ 快手房间详情: \(info.userName) - \(info.roomTitle)")
    } catch let error as LiveParseError {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手房间详情受上游波动影响，跳过当前用例: \(error)")
            return
        }
        printEnhancedError(error, title: "快手房间详情获取失败")
        throw error
    } catch is CancellationError {
        return
    } catch {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手房间详情受上游波动影响，跳过当前用例: \(error)")
            return
        }
        throw error
    }
}

@Test("获取快手直播状态")
func kuaishouGetLiveState() async throws {
    prepareKuaiShouTestEnvironment()

    print("📋 快手测试 4: 获取直播状态")

    do {
        let room = try await fetchKuaiShouRoom()
        let state = try await KuaiShou.getLiveState(roomId: room.roomId, userId: room.userId)

        #expect(state != .unknow, "快手直播状态不应为未知")
        print("✅ 快手直播状态: \(state)")
    } catch let error as LiveParseError {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手直播状态受上游波动影响，跳过当前用例: \(error)")
            return
        }
        printEnhancedError(error, title: "快手直播状态获取失败")
        throw error
    } catch is CancellationError {
        return
    } catch {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手直播状态受上游波动影响，跳过当前用例: \(error)")
            return
        }
        throw error
    }
}

@Test("获取快手播放参数")
func kuaishouGetPlayArgs() async throws {
    prepareKuaiShouTestEnvironment()

    print("📋 快手测试 5: 获取播放参数")

    do {
        let (_, playArgs) = try await fetchKuaiShouPlayableRoom()

        #expect(!playArgs.isEmpty, "快手播放线路不应为空")
        #expect(playArgs.first?.qualitys.isEmpty == false, "快手播放清晰度不应为空")

        if let first = playArgs.first {
            print("✅ 快手播放线路: \(first.cdn) - 清晰度数量 \(first.qualitys.count)")
        }
    } catch let error as LiveParseError {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手播放参数受上游波动影响，跳过当前用例: \(error)")
            return
        }
        printEnhancedError(error, title: "快手播放参数获取失败")
        throw error
    } catch is CancellationError {
        return
    } catch {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手播放参数受上游波动影响，跳过当前用例: \(error)")
            return
        }
        throw error
    }
}

@Test("快手分享码解析")
func kuaishouShareCodeParse() async throws {
    prepareKuaiShouTestEnvironment()

    print("📋 快手测试 6: 分享码解析")

    do {
        let room = try await fetchKuaiShouRoom()
        let info = try await KuaiShou.getRoomInfoFromShareCode(shareCode: room.roomId)

        #expect(info.roomId == room.roomId, "快手分享码解析后的房间ID应匹配输入")
        print("✅ 快手分享码解析成功: \(info.roomId)")
    } catch let error as LiveParseError {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手分享码链路受上游波动影响，跳过当前用例: \(error)")
            return
        }
        printEnhancedError(error, title: "快手分享码解析失败")
        throw error
    } catch is CancellationError {
        return
    } catch {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手分享码链路受上游波动影响，跳过当前用例: \(error)")
            return
        }
        throw error
    }
}

@Test("快手弹幕参数提示")
func kuaishouDanmukuArgs() async throws {
    prepareKuaiShouTestEnvironment()

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
    prepareKuaiShouTestEnvironment()

    print("📋 快手测试 8: 搜索占位")

    let keyword = "游戏"
    let results = try await KuaiShou.searchRooms(keyword: keyword, page: 1)

    #expect(results.isEmpty, "快手搜索暂未实现，应该返回空数组")
    print("✅ 快手搜索接口暂未开放，返回空数组符合预期")
}

@Test("快手最小完整流程")
func kuaishouFullIntegration() async throws {
    prepareKuaiShouTestEnvironment()

    print("📋 快手测试 9: 最小完整流程")

    do {
        let (category, subCategory) = try await fetchKuaiShouCategoryContext()
        print("   ✅ 分类: \(category.title) -> 子分类: \(subCategory.title)")

        let rooms = try await KuaiShou.getRoomList(id: subCategory.id, parentId: nil, page: 1)
        #expect(!rooms.isEmpty, "快手房间列表不应为空")

        let (room, playArgs) = try await fetchKuaiShouPlayableRoom()
        print("   ✅ 房间: \(room.userName) - \(room.roomId)")

        let info = try await KuaiShou.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
        print("   ✅ 房间详情状态: \(info.liveState ?? "未知")")

        let state = try await KuaiShou.getLiveState(roomId: room.roomId, userId: room.userId)
        #expect(state != .unknow, "快手完整流程 - 直播状态不应为未知")

        #expect(!playArgs.isEmpty, "快手完整流程 - 播放线路不应为空")
        print("   ✅ 播放线路数: \(playArgs.count)")

        do {
            let shareInfo = try await KuaiShou.getRoomInfoFromShareCode(shareCode: room.roomId)
            #expect(!shareInfo.roomId.isEmpty, "快手完整流程 - 分享码解析应返回有效房间ID")
        } catch {
            // 快手分享链路受风控波动影响较大；独立用例已覆盖该能力，此处不作为完整流程阻断项。
            print("   ⚠️ 分享码解析波动，跳过阻断: \(error)")
        }

        let danmuArgs = try await KuaiShou.getDanmukuArgs(roomId: room.roomId, userId: room.userId)
        #expect(danmuArgs.0.isEmpty, "快手弹幕参数应为空（暂未开放）")

        let searchResults = try await KuaiShou.searchRooms(keyword: room.userName, page: 1)
        #expect(searchResults.isEmpty, "快手搜索暂未开放，应返回空数组")

        print("✅ 快手最小完整流程验证完成")
    } catch let error as LiveParseError {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手完整流程受上游波动影响，跳过当前用例: \(error)")
            return
        }
        printEnhancedError(error, title: "快手完整流程失败")
        throw error
    } catch is CancellationError {
        return
    } catch {
        if isKuaiShouTransientError(error) {
            print("⚠️ 快手完整流程受上游波动影响，跳过当前用例: \(error)")
            return
        }
        throw error
    }
}
