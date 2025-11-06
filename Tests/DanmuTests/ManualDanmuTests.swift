import Foundation
import LiveParse

/// 手动验证直播弹幕连接的辅助工具。
///
/// 使用方式（以虎牙为例）：
/// ```bash
/// swift test --filter DanmuManualRunner.runHuya
/// ```
/// 或者在 Playground / 脚本中调用 `await DanmuManualRunner.runHuya()`。
/// 该工具不会自动在 CI 中运行，需手动触发。
enum DanmuManualRunner {

    /// 连接虎牙弹幕。
    /// - Parameters:
    ///   - roomId: 指定房间号，默认为 `nil` 时会自动挑选一个热门房间。
    ///   - duration: 监听弹幕的时长（秒）。
    static func runHuya(roomId: String? = nil, duration: TimeInterval = 30) async {
        await run(
            platform: .huya,
            roomId: roomId,
            duration: duration,
            roomSelector: autoHuyaRoom,
            danmuFetcher: Huya.getDanmukuArgs
        )
    }

    /// 连接哔哩哔哩弹幕。
    static func runBilibili(roomId: String? = nil, duration: TimeInterval = 30) async {
        await run(
            platform: .bilibili,
            roomId: roomId,
            duration: duration,
            roomSelector: autoBilibiliRoom,
            danmuFetcher: Bilibili.getDanmukuArgs
        )
    }

    /// 连接抖音弹幕。
    static func runDouyin(roomId: String? = nil, duration: TimeInterval = 30) async {
        await run(
            platform: .douyin,
            roomId: roomId,
            duration: duration,
            roomSelector: autoDouyinRoom,
            danmuFetcher: Douyin.getDanmukuArgs
        )
    }

    // MARK: - Core Runner

    private static func run(
        platform: LiveType,
        roomId: String?,
        duration: TimeInterval,
        roomSelector: () async throws -> AutoRoomResult,
        danmuFetcher: (String, String?) async throws -> ([String: String], [String: String]?)
    ) async {
        LiveParseConfig.logLevel = .debug
        LiveParseConfig.includeDetailedNetworkInfo = true

        do {
            let selection: AutoRoomResult
            if let roomId, !roomId.isEmpty {
                selection = AutoRoomResult(roomId: roomId, userId: nil, description: roomId)
            } else {
                selection = try await roomSelector()
            }

            print("🎯 平台: \(platform) 房间: \(selection.description) (\(selection.roomId))")

            let danmakuArgs = try await danmuFetcher(selection.roomId, selection.userId)
            let delegate = PrintDanmuDelegate()
            let connection = WebSocketConnection(parameters: danmakuArgs.0, headers: danmakuArgs.1, liveType: platform)
            connection.delegate = delegate

            print("🔌 开始连接弹幕 WebSocket，持续 \(Int(duration)) 秒…")
            connection.connect()

            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            print("🔌 准备断开连接…")
            connection.disconnect()
            delegate.finish()
        } catch {
            print("❌ DanmuManualRunner 失败: \(error)")
        }
    }

    // MARK: - 房间选择

    private static func autoHuyaRoom() async throws -> AutoRoomResult {
        let categories = try await Huya.getCategoryList()
        guard let category = categories.first,
              let sub = category.subList.first else {
            throw ManualDanmuError.noRoomAvailable("Huya 分类")
        }

        let rooms = try await Huya.getRoomList(id: sub.id, parentId: category.id, page: 1)
        guard let room = rooms.first else {
            throw ManualDanmuError.noRoomAvailable("Huya 房间列表")
        }
        return AutoRoomResult(roomId: room.roomId, userId: room.userId, description: room.userName)
    }

    private static func autoBilibiliRoom() async throws -> AutoRoomResult {
        let categories = try await Bilibili.getCategoryList()
        guard let category = categories.first,
              let sub = category.subList.first else {
            throw ManualDanmuError.noRoomAvailable("Bilibili 分类")
        }

        let rooms = try await Bilibili.getRoomList(id: sub.id, parentId: category.id, page: 1)
        guard let room = rooms.first else {
            throw ManualDanmuError.noRoomAvailable("Bilibili 房间列表")
        }
        return AutoRoomResult(roomId: room.roomId, userId: room.userId, description: room.userName)
    }

    private static func autoDouyinRoom() async throws -> AutoRoomResult {
        let categories = try await Douyin.getCategoryList()
        guard let category = categories.first,
              let sub = category.subList.first else {
            throw ManualDanmuError.noRoomAvailable("Douyin 分类")
        }

        let rooms = try await Douyin.getRoomList(id: sub.id, parentId: category.id, page: 1)
        guard let room = rooms.first else {
            throw ManualDanmuError.noRoomAvailable("Douyin 房间列表")
        }
        return AutoRoomResult(roomId: room.roomId, userId: room.userId, description: room.userName)
    }
}

// MARK: - Helpers

private struct AutoRoomResult {
    let roomId: String
    let userId: String?
    let description: String
}

private enum ManualDanmuError: Error {
    case noRoomAvailable(String)
}

private final class PrintDanmuDelegate: WebSocketConnectionDelegate {
    private var startTime = Date()

    func webSocketDidConnect() {
        startTime = Date()
        print("✅ 弹幕 WebSocket 已连接，开始接收…")
    }

    func webSocketDidDisconnect(error: Error?) {
        if let error {
            print("⚠️ 弹幕连接断开: \(error.localizedDescription)")
        } else {
            print("ℹ️ 弹幕连接正常关闭")
        }
    }

    func webSocketDidReceiveMessage(text: String, nickname: String, color: UInt32) {
        let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
        let hex = String(color, radix: 16, uppercase: true)
        print("[+\(elapsed)s] 💬 (0x\(hex)) \(nickname): \(text)")
    }

    func finish() {
        print("✅ 弹幕手动测试结束")
    }
}
