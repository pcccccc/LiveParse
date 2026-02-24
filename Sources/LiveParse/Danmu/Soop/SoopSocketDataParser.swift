//
//  SoopSocketDataParser.swift
//
//
//  Created by pc on 2025/2/24.
//

import Foundation

/// SOOP (formerly AfreecaTV) 弹幕 WebSocket 协议解析器
///
/// 协议要点：
/// - 包头: ESC TAB (`\x1b\t`)
/// - 字段分隔: Form Feed (`\x0c`)
/// - CONNECT: `\x1b\t000100000600\x0c\x0c\x0c16\x0c`
/// - JOIN:    `\x1b\t0002{size:06}00\x0c{chatNo}\x0c\x0c\x0c\x0c\x0c`
/// - PING:    `\x1b\t000000000100\x0c`
/// - 心跳间隔: 60 秒
public final class SoopSocketDataParser: WebSocketDataParser {

    private static let ESC = "\u{1b}\u{09}"   // \x1b\t
    private static let F   = "\u{0c}"          // \x0c  form-feed

    func performHandshake(connection: WebSocketConnection) {
        let chatNo = connection.parameters?["chatNo"] ?? ""
        let ftk    = connection.parameters?["ftk"] ?? ""

        // Step 1: CONNECT 包
        let connectPacket = Self.makeConnectPacket(ftk: ftk)
        connection.socket?.write(string: connectPacket)

        // 延迟 2 秒后发送 JOIN 包（遵循协议时序）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let joinPacket = Self.makeJoinPacket(chatNo: chatNo)
            connection.socket?.write(string: joinPacket)
        }

        // 心跳 60 秒
        connection.heartbeatTimer = Timer(timeInterval: 60, repeats: true) { _ in
            let ping = Self.makePingPacket()
            connection.socket?.write(string: ping)
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }

    func parse(data: Data, connection: WebSocketConnection) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        parseText(text: text, connection: connection)
    }

    /// SOOP 弹幕走 text frame，也处理一下
    func parseText(text: String, connection: WebSocketConnection) {
        let messages = Self.extractMessages(from: text)
        for msg in messages {
            connection.delegate?.webSocketDidReceiveMessage(
                text: msg.text,
                nickname: msg.nickname,
                color: msg.color
            )
        }
    }

    // MARK: - 包构造

    /// CONNECT 包: `ESC 0001 000006 00 F F F 16 F`
    static func makeConnectPacket(ftk: String) -> String {
        // 标准连接包，带 FTK（如果有的话）
        if ftk.isEmpty {
            return "\(ESC)000100000600\(F)\(F)\(F)16\(F)"
        }
        // 带 FTK 的连接包
        let body = "\(F)\(F)\(F)16\(F)"
        let size = String(format: "%06d", body.utf8.count)
        return "\(ESC)0001\(size)00\(body)"
    }

    /// JOIN 包: `ESC 0002 {size:06} 00 F {chatNo} F F F F F`
    static func makeJoinPacket(chatNo: String) -> String {
        let body = "\(F)\(chatNo)\(F)\(F)\(F)\(F)\(F)"
        let size = String(format: "%06d", body.utf8.count)
        return "\(ESC)0002\(size)00\(body)"
    }

    /// PING 包: `ESC 0000 000001 00 F`
    static func makePingPacket() -> String {
        return "\(ESC)000000000100\(F)"
    }

    // MARK: - 消息解析

    private struct DanmuMessage {
        let text: String
        let nickname: String
        let color: UInt32
    }

    /// 从服务器返回的文本中提取弹幕消息
    static func extractMessages(from raw: String) -> [(text: String, nickname: String, color: UInt32)] {
        // SOOP 的消息以 \x0c 分隔字段
        // 弹幕消息的字段索引 (根据公开资料):
        //   fields[1] = 弹幕内容 (comment)
        //   fields[2] = 用户 ID
        //   fields[6] = 用户昵称 (nickname)
        // 当 fields 数量 > 5 且包含有效弹幕内容时为聊天消息

        var results: [(text: String, nickname: String, color: UInt32)] = []

        // 可能一次收到多条消息，按 ESC 分割
        let packets = raw.components(separatedBy: "\u{1b}\u{09}")

        for packet in packets {
            guard !packet.isEmpty else { continue }

            let fields = packet.components(separatedBy: "\u{0c}")

            // 聊天消息至少需要 7 个字段
            guard fields.count > 6 else { continue }

            // 前 4 个字符通常是命令 ID，跳过 header 部分
            // 包格式: {cmd:4}{size:6}{flag:2}{F}{content}{F}{userId}{F}...{F}{nickname}{F}...
            // 第一个 field 包含 header: "0005000032XX" 之类
            let headerField = fields[0]

            // 提取命令类型 — 聊天消息对应 cmd = "0005"
            // headerField 可能是 "0005XXXXXXXX" 或为空（已被ESC分割掉）
            let cmd: String
            if headerField.count >= 4 {
                cmd = String(headerField.prefix(4))
            } else {
                continue
            }

            // cmd "0005" 为聊天消息
            guard cmd == "0005" else { continue }

            let comment = fields[1]
            let nickname = fields.count > 6 ? fields[6] : fields[2]

            guard !comment.isEmpty else { continue }

            results.append((
                text: comment,
                nickname: nickname.isEmpty ? fields[2] : nickname,
                color: 0xFFFFFF
            ))
        }

        return results
    }
}
