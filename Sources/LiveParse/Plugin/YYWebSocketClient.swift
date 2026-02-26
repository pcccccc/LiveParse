import Foundation
import Starscream

/// YY 平台 WebSocket 客户端 - 用于获取直播流地址
final class YYWebSocketClient: NSObject, @unchecked Sendable {

    private var socket: WebSocket?
    private var continuation: CheckedContinuation<[String: Any], Error>?
    private let roomId: String
    private let queue: DispatchQueue

    // 状态机
    private enum State {
        case connecting
        case waitingLogin
        case waitingJoinChannel
        case waitingStreams
        case waitingGearLine
        case completed([String: Any])
        case failed(Error)
    }

    private var state: State = .connecting
    private var streamInfo: [String: Any] = [:]

    init(roomId: String) {
        self.roomId = roomId
        self.queue = DispatchQueue(label: "liveparse.yy.ws.\(UUID().uuidString)")
        super.init()
    }

    func getStreamInfo() async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            connect()
        }
    }

    private func connect() {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var request = URLRequest(url: URL(string: "wss://h5-sinchl.yy.com/websocket?appid=yymwebh5&version=3.2.10&uuid=\(uuid)&udbAppSign=a8d7eef2")!)
        request.timeoutInterval = 30

        socket = WebSocket(request: request)
        socket?.delegate = self
        queue.async { [weak self] in
            self?.socket?.connect()
        }
    }

    private func disconnect(error: Error? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            socket?.disconnect()
            socket = nil

            if let continuation = self.continuation {
                self.continuation = nil
                if case .completed(let info) = state {
                    continuation.resume(returning: info)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: LiveParsePluginError.jsException("YY WebSocket completed without result"))
                }
            }
        }
    }

    private func send(binary data: Data) {
        queue.async { [weak self] in
            self?.socket?.write(data: data)
        }
    }

    // MARK: - Protocol Handling

    private func handleConnected() {
        print("🔵 YY: Connection established, transitioning to waitingLogin state")
        state = .waitingLogin
        sendLogin()
    }

    private func sendLogin() {
        print("🔵 YY: Skipping login, scheduling sendQueryStreams in 0.5s")
        // PLoginAp: appid=259, 登录匿名用户
        // 简化版本：直接跳过登录，等待 joinChannel 事件
        // YY 的登录比较复杂，但对于获取流地址，可以尝试直接查询

        // 根据文档，连接后服务器会触发 joinChannel
        // 我们直接发送查询流信息的请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            print("🔵 YY: Transitioning to waitingStreams state")
            self.state = .waitingStreams
            self.sendQueryStreams()
        }
    }

    private func sendQueryStreams() {
        print("🔵 YY: Sending ChannelStreamsQueryRequest for roomId: \(roomId)")

        // ChannelStreamsQueryRequest (appid=259)
        // head (field 100)
        var headData = Data()
        headData.append(YYBinaryProtocol.encodeString(field: 1, value: roomId))  // cidstr
        headData.append(YYBinaryProtocol.encodeString(field: 2, value: roomId))  // sidstr
        headData.append(YYBinaryProtocol.encodeString(field: 3, value: "0"))     // appidstr
        headData.append(YYBinaryProtocol.encodeString(field: 4, value: "121"))   // bidstr
        headData.append(YYBinaryProtocol.encodeString(field: 5, value: "5.23.0")) // client_ver

        // client_attribute (field 7)
        var clientAttr = Data()
        clientAttr.append(YYBinaryProtocol.encodeInt(field: 1, value: 1))  // client_type = BROWSER

        // avp_parameter (field 8)
        var avpParam = Data()
        avpParam.append(YYBinaryProtocol.encodeInt(field: 1, value: 4))  // gear = 4
        avpParam.append(YYBinaryProtocol.encodeInt(field: 2, value: 1))  // ssl = 1
        avpParam.append(YYBinaryProtocol.encodeInt(field: 3, value: 0))  // stream_format = 0

        // 组装完整消息
        var requestData = Data()
        requestData.append(YYBinaryProtocol.encodeMessage(field: 100, value: headData))
        requestData.append(YYBinaryProtocol.encodeMessage(field: 7, value: clientAttr))
        requestData.append(YYBinaryProtocol.encodeMessage(field: 8, value: avpParam))

        print("🔵 YY: Request protobuf data (\(requestData.count) bytes): \(requestData.map { String(format: "%02x", $0) }.joined())")

        // 包装成 YYP 格式
        let yypData = YYBinaryProtocol.buildYYP(maxType: 1, minType: 1, data: requestData)
        print("🔵 YY: YYP wrapped data (\(yypData.count) bytes): \(yypData.map { String(format: "%02x", $0) }.joined())")

        // 包装成外层帧 (appid=259 的 URI)
        let frameData = YYBinaryProtocol.buildFrame(uri: 0x00000259, payload: yypData)
        print("🔵 YY: Final frame data (\(frameData.count) bytes): \(frameData.map { String(format: "%02x", $0) }.joined())")

        send(binary: frameData)
        print("🔵 YY: Message sent, waiting for response...")
    }

    private func sendQueryGearLine(streamKey: String, ver: String) {
        // ChannelGearLineInfoQueryRequest
        var headData = Data()
        headData.append(YYBinaryProtocol.encodeString(field: 1, value: roomId))
        headData.append(YYBinaryProtocol.encodeString(field: 2, value: roomId))
        headData.append(YYBinaryProtocol.encodeString(field: 3, value: "0"))
        headData.append(YYBinaryProtocol.encodeString(field: 4, value: "121"))
        headData.append(YYBinaryProtocol.encodeString(field: 5, value: "5.23.0"))

        var avpParam = Data()
        avpParam.append(YYBinaryProtocol.encodeInt(field: 1, value: 4))
        avpParam.append(YYBinaryProtocol.encodeInt(field: 2, value: 1))
        avpParam.append(YYBinaryProtocol.encodeInt(field: 3, value: 0))

        // need_url_gear_stream (field 2)
        var gearStreamKey = Data()
        gearStreamKey.append(YYBinaryProtocol.encodeString(field: 1, value: streamKey))
        gearStreamKey.append(YYBinaryProtocol.encodeString(field: 2, value: ver))

        var requestData = Data()
        requestData.append(YYBinaryProtocol.encodeMessage(field: 100, value: headData))
        requestData.append(YYBinaryProtocol.encodeMessage(field: 1, value: avpParam))
        requestData.append(YYBinaryProtocol.encodeMessage(field: 2, value: gearStreamKey))

        let yypData = YYBinaryProtocol.buildYYP(maxType: 1, minType: 2, data: requestData)
        let frameData = YYBinaryProtocol.buildFrame(uri: 0x00000259, payload: yypData)

        send(binary: frameData)
    }

    private func handleBinaryMessage(_ data: Data) {
        guard let (uri, payload) = YYBinaryProtocol.parseFrame(data) else {
            print("❌ YY: Failed to parse frame")
            return
        }

        // 解析 YYP 格式
        guard let (maxType, minType, protobufData) = YYBinaryProtocol.parseYYP(payload) else {
            print("❌ YY: Failed to parse YYP")
            return
        }

        print("✅ YY: Received message - URI: \(uri), maxType: \(maxType), minType: \(minType)")

        // 根据状态处理不同的响应
        if case .waitingStreams = state {
            handleStreamsResponse(protobufData)
        } else if case .waitingGearLine = state {
            handleGearLineResponse(protobufData)
        }
    }

    private func handleStreamsResponse(_ data: Data) {
        let fields = YYBinaryProtocol.parseProtobufFields(data)

        // 解析 channel_stream_info (field 2)
        guard let channelStreamInfo = fields[2] else {
            disconnect(error: LiveParsePluginError.jsException("Missing channel_stream_info"))
            return
        }

        let streamFields = YYBinaryProtocol.parseProtobufFields(channelStreamInfo)

        // 解析 streams (field 1) - 这是一个数组
        // 简化处理：取第一个 stream
        guard let firstStream = streamFields[1] else {
            disconnect(error: LiveParsePluginError.jsException("Missing streams"))
            return
        }

        let stream = YYBinaryProtocol.parseProtobufFields(firstStream)

        // 提取 stream_key (field 1) 和 ver (field 5)
        guard let streamKeyData = stream[1],
              let streamKey = YYBinaryProtocol.parseString(streamKeyData),
              let verData = stream[5],
              let ver = YYBinaryProtocol.parseString(verData) else {
            disconnect(error: LiveParsePluginError.jsException("Missing stream_key or ver"))
            return
        }

        print("✅ YY: Got stream_key=\(streamKey), ver=\(ver)")

        // 保存信息并查询 gear line
        streamInfo["stream_key"] = streamKey
        streamInfo["ver"] = ver

        state = .waitingGearLine
        sendQueryGearLine(streamKey: streamKey, ver: ver)
    }

    private func handleGearLineResponse(_ data: Data) {
        let fields = YYBinaryProtocol.parseProtobufFields(data)

        // 解析 avp_info_res (field 1)
        guard let avpInfo = fields[1] else {
            disconnect(error: LiveParsePluginError.jsException("Missing avp_info_res"))
            return
        }

        let avpFields = YYBinaryProtocol.parseProtobufFields(avpInfo)

        // 解析 stream_line_addr (field 3) - map
        guard let streamLineAddr = avpFields[3] else {
            disconnect(error: LiveParsePluginError.jsException("Missing stream_line_addr"))
            return
        }

        // stream_line_addr 是一个 map，需要遍历找到第一个有效的 URL
        // 简化：直接解析第一层
        let addrFields = YYBinaryProtocol.parseProtobufFields(streamLineAddr)

        // 尝试找到 cdn_info.url
        for (_, value) in addrFields {
            let streamInfo = YYBinaryProtocol.parseProtobufFields(value)
            if let cdnInfo = streamInfo[1] {
                let cdnFields = YYBinaryProtocol.parseProtobufFields(cdnInfo)
                if let urlData = cdnFields[1], let url = YYBinaryProtocol.parseString(urlData) {
                    print("✅ YY: Got play URL: \(url)")
                    self.streamInfo["url"] = url
                    state = .completed(self.streamInfo)
                    disconnect()
                    return
                }
            }
        }

        disconnect(error: LiveParsePluginError.jsException("No valid URL found in response"))
    }
}

// MARK: - WebSocketDelegate

extension YYWebSocketClient: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected:
            print("✅ YY WebSocket connected")
            handleConnected()

        case .disconnected(let reason, let code):
            print("❌ YY WebSocket disconnected: \(reason) (\(code))")
            if case .completed = state {
                disconnect()
            } else {
                disconnect(error: LiveParsePluginError.jsException("YY WebSocket disconnected: \(reason) (\(code))"))
            }

        case .binary(let data):
            print("📦 YY: Received binary data (\(data.count) bytes): \(data.prefix(50).map { String(format: "%02x", $0) }.joined())...")
            handleBinaryMessage(data)

        case .text(let text):
            print("📝 YY: Received text message: \(text)")

        case .ping:
            print("🏓 YY: Received ping")

        case .pong:
            print("🏓 YY: Received pong")

        case .viabilityChanged(let viable):
            print("🔄 YY: Viability changed: \(viable)")

        case .reconnectSuggested(let suggested):
            print("🔄 YY: Reconnect suggested: \(suggested)")

        case .error(let error):
            print("❌ YY WebSocket error: \(error?.localizedDescription ?? "unknown")")
            disconnect(error: error ?? LiveParsePluginError.jsException("YY WebSocket unknown error"))

        case .cancelled:
            disconnect(error: LiveParsePluginError.jsException("YY WebSocket cancelled"))

        case .peerClosed:
            print("❌ YY: Peer closed connection")
            disconnect(error: LiveParsePluginError.jsException("YY WebSocket peer closed"))
        }
    }
}
