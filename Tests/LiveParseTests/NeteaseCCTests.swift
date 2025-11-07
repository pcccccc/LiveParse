import Foundation
import Testing
@testable import LiveParse

// MARK: - Helpers

private func fetchCCRoomContext() async throws -> LiveModel {
    let categories = try await NeteaseCC.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的 CC 分类")
        throw CancellationError()
    }

    let rooms = try await NeteaseCC.getRoomList(id: subCategory.id, parentId: category.id, page: 1)
    guard let room = rooms.first else {
        Issue.record("CC 房间列表为空")
        throw CancellationError()
    }
    return room
}

// MARK: - Tests

@Test("获取 CC 分类列表")
func ccGetCategoryList() async throws {
    LiveParseConfig.logLevel = .debug
    let categories = try await NeteaseCC.getCategoryList()
    #expect(!categories.isEmpty, "CC 分类列表不应为空")
}

@Test("获取 CC 子分类")
func ccGetCategorySubList() async throws {
    let categories = try await NeteaseCC.getCategoryList()
    guard let first = categories.first else {
        Issue.record("没有可用的 CC 分类")
        return
    }
    let subList = try await NeteaseCC.getCategorySubList(id: first.id)
    #expect(!subList.isEmpty, "CC 子分类不应为空")
}

@Test("获取 CC 房间列表")
func ccGetRoomList() async throws {
    LiveParseConfig.logLevel = .debug
    let categories = try await NeteaseCC.getCategoryList()
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("没有可用的 CC 分类")
        return
    }
    let rooms = try await NeteaseCC.getRoomList(id: subCategory.id, parentId: category.id, page: 1)
    #expect(!rooms.isEmpty, "CC 房间列表不应为空")
}

@Test("获取 CC 房间详情")
func ccGetLiveInfo() async throws {
    LiveParseConfig.logLevel = .debug
    do {
        let room = try await fetchCCRoomContext()
        let info = try await NeteaseCC.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
        #expect(!info.userName.isEmpty, "CC 房间详情 - 主播名称不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("获取 CC 播放参数")
func ccGetPlayArgs() async throws {
    LiveParseConfig.logLevel = .debug
    do {
        let room = try await fetchCCRoomContext()
        let playArgs = try await NeteaseCC.getPlayArgs(roomId: room.roomId, userId: room.userId)
        #expect(!playArgs.isEmpty, "CC 播放线路不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("获取 CC 直播状态")
func ccGetLiveState() async throws {
    LiveParseConfig.logLevel = .debug
    do {
        let room = try await fetchCCRoomContext()
        let state = try await NeteaseCC.getLiveState(roomId: room.roomId, userId: room.userId)
        #expect(state != .unknow, "CC 直播状态不应为未知")
    } catch is CancellationError {
        return
    }
}

@Test("CC 搜索房间")
func ccSearchRooms() async throws {
    LiveParseConfig.logLevel = .debug
    let rooms = try await NeteaseCC.searchRooms(keyword: "游戏", page: 1)
    #expect(!rooms.isEmpty, "CC 搜索结果不应为空")
}

@Test("CC 分享码解析")
func ccShareCodeParse() async throws {
    LiveParseConfig.logLevel = .debug
    do {
        let room = try await fetchCCRoomContext()
        let info = try await NeteaseCC.getRoomInfoFromShareCode(shareCode: room.roomId)
        #expect(!info.roomId.isEmpty, "CC 分享码解析房间ID不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("CC 弹幕参数")
func ccDanmakuArgs() async throws {
    LiveParseConfig.logLevel = .debug
    do {
        let room = try await fetchCCRoomContext()
        let args = try await NeteaseCC.getDanmukuArgs(roomId: room.roomId, userId: room.userId)
        #expect(!args.0.isEmpty, "CC 弹幕参数不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("CC 最小完整流程")
func ccFullIntegration() async throws {
    LiveParseConfig.logLevel = .debug
    LiveParseConfig.includeDetailedNetworkInfo = true

    let categories = try await NeteaseCC.getCategoryList()
    #expect(!categories.isEmpty, "CC 分类列表不应为空")

    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("CC 分类/子分类为空")
        return
    }

    let rooms = try await NeteaseCC.getRoomList(id: subCategory.id, parentId: category.id, page: 1)
    guard let room = rooms.first else {
        Issue.record("CC 房间列表为空")
        return
    }

    let info = try await NeteaseCC.getLiveLastestInfo(roomId: room.roomId, userId: room.userId)
    let state = try await NeteaseCC.getLiveState(roomId: room.roomId, userId: room.userId)
    let playArgs = try await NeteaseCC.getPlayArgs(roomId: room.roomId, userId: room.userId)
    let shareInfo = try await NeteaseCC.getRoomInfoFromShareCode(shareCode: "https://cc.163.com/163917/")

    #expect(!info.userName.isEmpty, "CC 完整流程 - 主播名称不应为空")
    #expect(state != .unknow, "CC 完整流程 - 状态不应未知")
    #expect(!playArgs.isEmpty, "CC 完整流程 - 播放线路不应为空")
    #expect(!shareInfo.roomId.isEmpty && !shareInfo.roomTitle.isEmpty, "CC 完整流程 - 分享码解析失败")
}
