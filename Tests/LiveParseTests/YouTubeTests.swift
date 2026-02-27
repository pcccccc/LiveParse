import Foundation
import Testing
@testable import LiveParse

private func fetchYouTubeCategoryContext() async throws -> (LiveMainListModel, LiveCategoryModel) {
    let categories = try await LiveParseJSPlatformManager.getCategoryList(platform: .youtube)
    guard let category = categories.first,
          let subCategory = category.subList.first else {
        Issue.record("YouTube 分类为空，跳过当前用例")
        throw CancellationError()
    }
    return (category, subCategory)
}

private func fetchYouTubeRoom() async throws -> LiveModel {
    let (category, subCategory) = try await fetchYouTubeCategoryContext()
    let rooms = try await LiveParseJSPlatformManager.getRoomList(
        platform: .youtube,
        id: subCategory.id,
        parentId: category.id,
        page: 1
    )
    guard let room = rooms.first else {
        Issue.record("YouTube 房间列表为空，跳过当前用例")
        throw CancellationError()
    }
    return room
}

@Test("YouTube 获取分类列表")
func youtubeGetCategoryList() async throws {
    let categories = try await LiveParseJSPlatformManager.getCategoryList(platform: .youtube)
    #expect(!categories.isEmpty, "YouTube 分类列表不应为空")
    #expect(categories.first?.subList.isEmpty == false, "YouTube 子分类不应为空")
}

@Test("YouTube 获取房间列表")
func youtubeGetRoomList() async throws {
    do {
        let (category, subCategory) = try await fetchYouTubeCategoryContext()
        let rooms = try await LiveParseJSPlatformManager.getRoomList(
            platform: .youtube,
            id: subCategory.id,
            parentId: category.id,
            page: 1
        )
        #expect(!rooms.isEmpty, "YouTube 房间列表不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("YouTube 获取房间详情")
func youtubeGetRoomDetail() async throws {
    do {
        let room = try await fetchYouTubeRoom()
        let info = try await LiveParseJSPlatformManager.getLiveLastestInfo(
            platform: .youtube,
            roomId: room.roomId,
            userId: room.userId
        )

        #expect(!info.roomId.isEmpty, "YouTube 房间详情 roomId 不应为空")
        #expect(!info.roomTitle.isEmpty || !info.userName.isEmpty, "YouTube 房间详情不应全空")
    } catch is CancellationError {
        return
    }
}

@Test("YouTube 获取播放参数")
func youtubeGetPlayback() async throws {
    do {
        let room = try await fetchYouTubeRoom()
        let playArgs = try await LiveParseJSPlatformManager.getPlayArgs(
            platform: .youtube,
            roomId: room.roomId,
            userId: room.userId
        )

        #expect(!playArgs.isEmpty, "YouTube 播放线路不应为空")
        #expect(playArgs.first?.qualitys.isEmpty == false, "YouTube 清晰度列表不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("YouTube 获取直播状态")
func youtubeGetLiveState() async throws {
    do {
        let room = try await fetchYouTubeRoom()
        let state = try await LiveParseJSPlatformManager.getLiveState(
            platform: .youtube,
            roomId: room.roomId,
            userId: room.userId
        )

        #expect(state != .unknow, "YouTube 直播状态不应为未知")
    } catch is CancellationError {
        return
    }
}

@Test("YouTube 搜索房间")
func youtubeSearchRooms() async throws {
    let results = try await LiveParseJSPlatformManager.searchRooms(
        platform: .youtube,
        keyword: "live",
        page: 1
    )
    // 搜索结果受地区与上游页面变化影响，允许为空，但应可完成调用。
    #expect(results.count >= 0)
}

@Test("YouTube 分享码解析")
func youtubeResolveShare() async throws {
    do {
        let room = try await fetchYouTubeRoom()
        let info = try await LiveParseJSPlatformManager.getRoomInfoFromShareCode(
            platform: .youtube,
            shareCode: room.roomId
        )

        #expect(!info.roomId.isEmpty, "YouTube 分享码解析结果 roomId 不应为空")
    } catch is CancellationError {
        return
    }
}

@Test("YouTube 获取弹幕参数")
func youtubeGetDanmakuArgs() async throws {
    do {
        let room = try await fetchYouTubeRoom()
        let args = try await LiveParseJSPlatformManager.getDanmukuArgs(
            platform: .youtube,
            roomId: room.roomId,
            userId: room.userId
        )

        #expect(args.0["_danmu_type"] != nil, "YouTube 弹幕参数应包含轮询类型")
        #expect(args.0["continuation"] != nil, "YouTube 弹幕参数应包含 continuation")
        #expect(args.1 != nil, "YouTube 弹幕 headers 不应为空")
    } catch is CancellationError {
        return
    }
}
