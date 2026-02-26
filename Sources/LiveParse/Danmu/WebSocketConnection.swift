//
//  WebSocketConnection.swift
//
//
//  Created by pc on 2023/12/26.
//

import Foundation
import Starscream
import Alamofire

protocol WebSocketDataParser {
    func performHandshake(connection: WebSocketConnection)
    func parse(data: Data, connection: WebSocketConnection)
}

public protocol WebSocketConnectionDelegate: AnyObject {
    /// 建立连接成功通知
    func webSocketDidConnect()
    /// 断开链接通知,参数 `isReconnecting` 表示是否处于等待重新连接状态。
    func webSocketDidDisconnect(error: Error?)
    /// 接收到消息后的回调(String)
    func webSocketDidReceiveMessage(text: String, nickname: String, color: UInt32)
}

public class WebSocketConnection {
    
    var socket: WebSocket?
    public var parameters: [String:String]?
    var headers: [String: String]?
    public var delegate: WebSocketConnectionDelegate?
    let liveType: LiveType
    var heartbeatTimer: Timer?
    var reConnectTimer: Timer?
    var receiveCounter: UInt64 = 0
    var lastReceiveCounts: UInt64 = 0
    var tryCount: Int = 0
    
    var url: URL {
        switch liveType {
            case .bilibili:
                URL(string: "wss://broadcastlv.chat.bilibili.com:443/sub")!
            case .huya:
                URL(string: "wss://cdnws.api.huya.com")!
            case .douyin:
                URL(string: "wss://webcast5-ws-web-lf.douyin.com/webcast/im/push/v2/")!
            case .douyu:
                URL(string: "wss://danmuproxy.douyu.com:8506/")!
            case .cc:
                URL(string: parameters?["url"] ?? "wss://wslink.cc.163.com/conn")!
            case .soop:
                URL(string: parameters?["ws_url"] ?? "wss://chat.sooplive.co.kr:8001/Websocket")!
            default:
                URL(string: "wss://broadcastlv.chat.bilibili.com:443/sub")!
        }
    }
    var parser: WebSocketDataParser {
        switch liveType {
            case .bilibili:
                BilibiliSocketDataParser()
            case .huya:
                HuyaSocketDataParser()
            case .douyin:
                DouyinSocketDataParser()
            case .douyu:
                DouyuSocketDataParser()
            case .cc:
                CCSocketDataParser()
            case .soop:
                SoopSocketDataParser()
            default:
                BilibiliSocketDataParser()
        }
    }

    public init(parameters: [String: String]?, headers: [String: String]?, liveType: LiveType) {
        self.parameters = parameters
        self.headers = headers
        self.liveType = liveType
    }

    deinit {
        self.disconnect()
    }

    public func connect() {
        var request = URLRequest(url: url)
        if liveType == .douyin { //抖音需要把parameters拼到url上
            print(formatDouyinFinalUrl(url: url, parameters: self.parameters!))
            request = URLRequest(url: formatDouyinFinalUrl(url: url, parameters: self.parameters!))
        }else if liveType == .bilibili {
            request = URLRequest(url: URL(string: parameters?["ws_url"] ?? "")!)
            request.headers = ["user-agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"]
        }else if liveType == .soop {
            request = URLRequest(url: URL(string: parameters?["ws_url"] ?? "")!)
            request.headers = ["user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"]
        }
        
        socket = WebSocket(request: request)
        if self.headers != nil {
            if let keys = self.headers?.keys {
                var headers = HTTPHeaders()
                for key in keys {
                    let value = self.headers![key]!
                    headers.add(name: key, value: value)
                }
                request.headers = headers
            }
        }
        socket?.delegate = self
        socket?.connect()
    }

    public func disconnect() {
        socket?.disconnect()
        socket?.forceDisconnect()
    }
    
    func reConnect() {
        if reConnectTimer == nil {
            reConnectTimer = Timer(timeInterval: TimeInterval(10), repeats: true) {_ in
                self.socket?.connect()
                self.tryCount += 1
            }
            RunLoop.current.add(reConnectTimer!, forMode: .common)
        }
        if tryCount > 10 {
            reConnectTimer?.invalidate()
        }
    }
}

extension WebSocketConnection: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        receiveCounter += 1
        switch event {
            case .connected(let headers):
                print("WebSocket connected: \(headers)")
                tryCount = 0

                // CC 平台使用 SockJS 协议，需要订阅
                if liveType == .cc {
                    subscribeCCDanmaku()
                    startCCHeartbeat()
                } else {
                    parser.performHandshake(connection: self)
                }

                delegate?.webSocketDidConnect()
            case .disconnected(let reason, let code):
                let error = NSError(domain: reason, code: Int(code), userInfo: ["reason" : reason])
                delegate?.webSocketDidDisconnect(error: error)
                reConnect()
            case .text(let string):
                if liveType == .soop, let soopParser = parser as? SoopSocketDataParser {
                    soopParser.parseText(text: string, connection: self)
                } else if liveType == .cc {
                    parseCCMessage(text: string)
                }
            case .binary(let data):
                parser.parse(data: data, connection: self)
            case .error(let error):
                reConnect()
                delegate?.webSocketDidDisconnect(error: error)
            case .peerClosed:
                reConnect()
                delegate?.webSocketDidDisconnect(error: nil)
        default:
            break
        }
    }
}

extension WebSocketConnection {
    func formatDouyinFinalUrl(url: URL, parameters: [String: String]) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            fatalError("Invalid URL")
        }
        components.scheme = "wss"
        var items: [URLQueryItem] = []
        for key in parameters.keys {
            items.append(URLQueryItem(name: key, value: parameters[key]))
        }
        components.queryItems = items
        return components.url!
    }

    // MARK: - CC Platform SockJS Methods

    /// 订阅 CC 平台弹幕
    private func subscribeCCDanmaku() {
        guard let subscriptionGroup = parameters?["subscription_group"] else {
            print("⚠️ CC 订阅 group 为空")
            return
        }

        let subscribeMessage: [String: Any] = [
            "cmd": "sub",
            "data": [
                "groups": [subscriptionGroup]
            ]
        ]
        sendCCJSON(subscribeMessage)
        print("✅ CC 已订阅: \(subscriptionGroup)")
    }

    /// 开始 CC 平台心跳
    private func startCCHeartbeat() {
        let interval = Double(parameters?["heartbeat_interval"] ?? "60000")! / 1000.0

        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendCCHeartbeat()
        }
        if let timer = heartbeatTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// 发送 CC 心跳
    private func sendCCHeartbeat() {
        let heartbeatMessage: [String: Any] = ["cmd": "heartbeat"]
        sendCCJSON(heartbeatMessage)
    }

    /// 发送 CC JSON 消息
    private func sendCCJSON(_ message: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            socket?.write(string: jsonString)
        } catch {
            print("❌ CC JSON 序列化失败: \(error.localizedDescription)")
        }
    }

    /// 解析 CC 平台消息
    private func parseCCMessage(text: String) {
        guard let jsonData = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }

        let cmd = json["cmd"] as? String ?? ""

        // 处理弹幕推送
        if cmd == "pub" {
            guard let data = json["data"] as? [String: Any],
                  let list = data["list"] as? [[String: Any]] else {
                return
            }

            for item in list {
                let msgBody = item["msg_body"] as? String ?? ""
                let nick = item["nick"] as? String ?? ""

                // 过滤 BBCode 标签
                let cleanedMsg = filterBBCode(msgBody)

                if !cleanedMsg.isEmpty {
                    delegate?.webSocketDidReceiveMessage(
                        text: cleanedMsg,
                        nickname: nick,
                        color: 0xFFFFFF
                    )
                }
            }
        }
    }

    /// 过滤 BBCode 标签
    private func filterBBCode(_ text: String) -> String {
        var result = text

        let bbCodeTags = [
            "emts", "wmp", "pic", "giftpic", "flash", "link", "roomlink",
            "grouplink", "taillamp", "img", "comic", "font", "userCard", "jumplink"
        ]

        for tag in bbCodeTags {
            let pattern = "\\[\(tag)\\].*?\\[/\(tag)\\]"
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
