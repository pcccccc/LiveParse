//
//  HuyaSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
import SwiftyJSON
import TarsKit

public class HuyaSocketDataParser: WebSocketDataParser {
    
    
    func performHandshake(connection: WebSocketConnection) {
        let data = HuyaSocketDataParser.getJoinData(ayyuid: Int(connection.parameters?["lYyid"] ?? "0") ?? 0, tid: Int(connection.parameters?["lChannelId"] ?? "0") ?? 0, sid: Int(connection.parameters?["lSubChannelId"] ?? "0") ?? 0)
        connection.socket?.write(data: Data(bytes: data, count: data.count))
        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(60), repeats: true) {_ in
            connection.socket?.write(data: "ABQdAAwsNgBM".data(using: .utf8)!)
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }
    
    func parse(data: Data, connection: WebSocketConnection) {
        deCodeData(data: data, connection: connection)
    }
    
    private func deCodeData(data: Data, connection: WebSocketConnection) {
        let bytes = [UInt8](data)
        var stream = TarsInputStream(bytes)
        var type = 0
        do {
            type = try stream.read(&type, tag: 0, required: false)
            if type == 7 {
                stream = TarsInputStream(try stream.readBytes(1, required: false))
                let wSPushMessage = HYPushMessage()
                try wSPushMessage.readFrom(stream)
                if wSPushMessage.uri == 1400 {
                    var messageNotice = HYMessage()
                    try messageNotice.readFrom(TarsInputStream(wSPushMessage.msg))
                    var uname = messageNotice.userInfo.nickName
                    var content = messageNotice.content
                    var color = messageNotice.bulletFormat.fontColor
                    connection.delegate?.webSocketDidReceiveMessage(text: content, color: UInt32(color))
                }else if type == 8006 {
                    var online = 0
                    var s = TarsInputStream(wSPushMessage.msg)
                    online = try s.read(&online, tag: 0, required: false)
                    print(online)
                }
            }
        }catch {
            print("Error reading type: \(error)")
        }
    }
    
    private func getHuyaLiveColor(col: Int) -> Int {
        switch col {
        case 1:
            return 0xccff
        case 2:
            return 0xccff
        case 3:
            return 0x9AFF02
        case 4:
            return 0xFFFF00
        case 5:
            return 0xBF3EFF
        case 6:
            return 0xFF60AF
        default:
            return 0xFFFFFF
        }
    }
    
    // 将Dart的getJoinData函数转换为Swift
    static func getJoinData(ayyuid: Int, tid: Int, sid: Int) -> [UInt8] {
       do {
           let oos = TarsOutputStream()
           try oos.write(ayyuid, tag: 0)
           try oos.write(true, tag: 1)
           try oos.write("", tag: 2)
           try oos.write("", tag: 3)
           try oos.write(tid, tag: 4)
           try oos.write(sid, tag: 5)
           try oos.write(0, tag: 6)
           try oos.write(0, tag: 7)
           let q = oos.writer.buffer as [UInt8]
           let wscmd = TarsOutputStream()
           try wscmd.write(1, tag: 0)
           try wscmd.write(q, tag: 1)
           
           return wscmd.toUint8List()
       } catch {
           print("Error in getJoinData: \(error)")
           return []
       }
    }
}
