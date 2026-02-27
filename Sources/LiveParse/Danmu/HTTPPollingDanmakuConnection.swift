//
//  HTTPPollingDanmakuConnection.swift
//  LiveParse
//
//  Created by Claude on 2026/02/26.
//

import Foundation
import Alamofire

/// HTTP 轮询弹幕连接协议
/// 用于支持不使用 WebSocket 而是通过 HTTP 轮询获取弹幕的平台（如快手、YouTube 等）
public class HTTPPollingDanmakuConnection {

    // MARK: - Properties

    /// 参数字典（包含轮询配置和业务参数）
    public var parameters: [String: String]?

    /// HTTP 请求头
    var headers: [String: String]?

    /// 代理协议
    public weak var delegate: WebSocketConnectionDelegate?

    /// 平台类型
    let liveType: LiveType

    /// 轮询定时器
    private var pollingTimer: Timer?

    /// 轮询间隔（秒）
    private var pollingInterval: TimeInterval = 3.0

    /// 轮询 URL
    private var pollingURL: String = ""

    /// HTTP 方法
    private var pollingMethod: HTTPMethod = .post

    /// 游标/分页参数（用于去重和增量拉取）
    private var cursors: [String: Any] = [:]

    /// 是否已连接
    private var isConnected: Bool = false

    /// 轮询任务计数器（用于调试）
    private var pollCount: UInt64 = 0

    /// 快手弹幕去重：已发送过的消息 key
    private var seenCommentKeys: Set<String> = []

    /// 快手弹幕去重：记录插入顺序，用于裁剪内存
    private var seenCommentOrder: [String] = []

    /// 是否已输出首批历史窗口
    private var didEmitInitialHistory: Bool = false

    // MARK: - Initialization

    public init(parameters: [String: String]?, headers: [String: String]?, liveType: LiveType) {
        self.parameters = parameters
        self.headers = headers
        self.liveType = liveType

        // 解析轮询配置
        parsePollingConfig()
    }

    deinit {
        self.disconnect()
    }

    // MARK: - Configuration Parsing

    /// 解析轮询配置参数
    private func parsePollingConfig() {
        guard let params = parameters else { return }

        // 解析轮询 URL
        if let url = params["_polling_url"] {
            self.pollingURL = url
        }

        // 解析轮询方法
        if let method = params["_polling_method"] {
            self.pollingMethod = HTTPMethod(rawValue: method.uppercased())
        }

        // 解析轮询间隔（毫秒转秒）
        if let intervalStr = params["_polling_interval"], let intervalMs = Double(intervalStr) {
            self.pollingInterval = intervalMs / 1000.0
        }

        // 初始化游标参数（从 parameters 中提取非下划线开头的字段作为业务参数）
        for (key, value) in params where !key.hasPrefix("_") {
            self.cursors[key] = value
        }
    }

    // MARK: - Connection Control

    /// 开始连接（启动轮询）
    public func connect() {
        guard !pollingURL.isEmpty else {
            let error = NSError(
                domain: "HTTPPollingDanmakuConnection",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "轮询 URL 未配置"]
            )
            delegate?.webSocketDidDisconnect(error: error)
            return
        }

        resetRuntimeState()
        isConnected = true
        delegate?.webSocketDidConnect()

        // 立即执行第一次轮询
        performPolling()

        // 启动定时器
        startPollingTimer()
    }

    /// 断开连接（停止轮询）
    public func disconnect() {
        stopPollingTimer()
        isConnected = false
    }

    /// 启动轮询定时器
    private func startPollingTimer() {
        stopPollingTimer()

        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performPolling()
        }

        // 添加到 RunLoop 以确保后台也能运行
        if let timer = pollingTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// 停止轮询定时器
    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Polling Logic

    /// 执行一次轮询请求
    private func performPolling() {
        guard isConnected else { return }

        pollCount += 1

        // 根据平台类型选择解析器
        switch liveType {
        case .ks:
            performKuaishouPolling()
        default:
            print("⚠️ HTTP 轮询暂不支持平台: \(liveType)")
        }
    }

    // MARK: - Platform-Specific Polling

    /// 快手平台 HTTP 轮询
    private func performKuaishouPolling() {
        guard let liveStreamId = cursors["liveStreamId"] as? String else {
            print("❌ 快手轮询缺少 liveStreamId")
            return
        }

        // 固定请求“当前最新窗口”，避免 cursor 回翻到更旧历史。
        let requestParams: [String: Any] = [
            "liveStreamId": liveStreamId,
            "feedTypeCursorMap": ["1": 0, "2": 0]
        ]

        // 发起请求
        AF.request(
            pollingURL,
            method: pollingMethod,
            parameters: requestParams,
            encoding: JSONEncoding.default,
            headers: headers.map { HTTPHeaders($0) }
        )
        .validate()
        .responseData { [weak self] response in
            guard let self = self else { return }

            switch response.result {
            case .success(let data):
                self.parseKuaishouResponse(data: data)
            case .failure(let error):
                print("❌ 快手轮询请求失败: \(error.localizedDescription)")
                // 不触发 disconnect，继续下一次轮询
            }
        }
    }

    /// 解析快手轮询响应
    private func parseKuaishouResponse(data: Data) {
        do {
            // 解析 JSON 响应
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObject = json["data"] as? [String: Any] else {
                print("❌ 快手响应格式错误")
                return
            }

            // 解析弹幕列表
            if let backTraceFeedMap = dataObject["backTraceFeedMap"] as? [String: Any],
               let commentFeedData = backTraceFeedMap["1"] as? [String: Any],
               let historyFeedList = commentFeedData["historyFeedList"] as? [String] {
                var entries: [KuaishouCommentEntry] = []
                entries.reserveCapacity(historyFeedList.count)

                for (index, base64String) in historyFeedList.enumerated() {
                    // Base64 解码
                    guard let protobufData = Data(base64Encoded: base64String) else {
                        continue
                    }

                    // Protobuf 解码
                    do {
                        let commentFeed = try Kuaishou_WebCommentFeed(serializedData: protobufData)

                        // 提取弹幕内容
                        let userName = commentFeed.user?.userName ?? ""
                        let content = commentFeed.content
                        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            continue
                        }

                        // 解析颜色（十六进制字符串转 UInt32）
                        var color: UInt32 = 0xFFFFFF // 默认白色
                        if !commentFeed.color.isEmpty {
                            let colorStr = commentFeed.color.hasPrefix("#") ?
                                String(commentFeed.color.dropFirst()) : commentFeed.color
                            if let colorValue = UInt32(colorStr, radix: 16) {
                                color = colorValue
                            }
                        }
                        let key: String
                        if !commentFeed.id.isEmpty {
                            key = commentFeed.id
                        } else {
                            key = "\(commentFeed.time)|\(userName)|\(content)"
                        }

                        entries.append(
                            KuaishouCommentEntry(
                                key: key,
                                time: commentFeed.time,
                                sequence: index,
                                nickname: userName,
                                content: content,
                                color: color
                            )
                        )
                    } catch {
                        print("❌ Protobuf 解析失败: \(error.localizedDescription)")
                    }
                }

                // 旧 -> 新，确保“最新在最后”
                entries.sort { lhs, rhs in
                    if lhs.time != rhs.time { return lhs.time < rhs.time }
                    return lhs.sequence < rhs.sequence
                }

                if !didEmitInitialHistory {
                    for entry in entries {
                        rememberSeenKey(entry.key)
                        delegate?.webSocketDidReceiveMessage(
                            text: entry.content,
                            nickname: entry.nickname,
                            color: entry.color
                        )
                    }
                    didEmitInitialHistory = true
                    return
                }

                for entry in entries where !seenCommentKeys.contains(entry.key) {
                    rememberSeenKey(entry.key)
                    delegate?.webSocketDidReceiveMessage(
                        text: entry.content,
                        nickname: entry.nickname,
                        color: entry.color
                    )
                }
            }
        } catch {
            print("❌ 解析快手响应失败: \(error.localizedDescription)")
        }
    }
}

private extension HTTPPollingDanmakuConnection {
    struct KuaishouCommentEntry {
        let key: String
        let time: UInt64
        let sequence: Int
        let nickname: String
        let content: String
        let color: UInt32
    }

    func resetRuntimeState() {
        pollCount = 0
        seenCommentKeys.removeAll(keepingCapacity: true)
        seenCommentOrder.removeAll(keepingCapacity: true)
        didEmitInitialHistory = false
    }

    func rememberSeenKey(_ key: String) {
        guard !key.isEmpty else { return }
        if seenCommentKeys.insert(key).inserted {
            seenCommentOrder.append(key)
        }

        let maxCount = 8_000
        let keepCount = 4_000
        if seenCommentOrder.count > maxCount {
            let removeCount = seenCommentOrder.count - keepCount
            let removed = seenCommentOrder.prefix(removeCount)
            seenCommentOrder.removeFirst(removeCount)
            for key in removed {
                seenCommentKeys.remove(key)
            }
        }
    }
}
