//
//  DouyuSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation

public class DouyuSocketDataParser: WebSocketDataParser {
    
    func performHandshake(connection: WebSocketConnection) {
        connection.socket?.write(data: encodeDouyuData(msg: "type@=loginreq/roomid@=\(connection.parameters?["roomId"] ?? "")/"))//加入房间
        connection.socket?.write(data: self.encodeDouyuData(msg: "type@=joingroup/rid@=\(connection.parameters?["roomId"] ?? "")/gid@=-9999/"))//加入房间步骤2?
        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(45), repeats: true) {_ in //心跳
            let timestamp = Int(Date().timeIntervalSince1970)
            connection.socket?.write(data: self.encodeDouyuData(msg: "type@=keeplive/tick@=\(timestamp)/"))
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }
    
    func parse(data: Data, connection: WebSocketConnection) {
        decodeDouyuData(data, isAuthData: true, connection: connection)
    }
    
    private func encodeDouyuData(msg: String) -> Data {
        var data = Data()
        // 头部8字节，尾部1字节，与字符串长度相加即数据长度
        let dataLen = msg.utf8.count + 9
        let lenByte = Data(bytes: withUnsafeBytes(of: UInt32(dataLen).littleEndian) { Data($0) })
        // 前两个字节按照小端顺序拼接为0x02b1，转化为十进制即689（《协议》中规定的客户端发送消息类型）
        // 后两个字节即《协议》中规定的加密字段与保留字段，置0
        var sendByte = Data([0xb1, 0x02, 0x00, 0x00])
        
        // 将字符串转化为字节流
        if let msgByte = msg.data(using: .utf8) {
            sendByte.append(msgByte)
        }
        // 尾部以"\0"结束
        let endByte = Data([0x00])
        // 按顺序拼接在一起
        data.append(contentsOf: lenByte)
        data.append(contentsOf: lenByte)
        data.append(contentsOf: sendByte)
        data.append(contentsOf: endByte)
        return data
    }
    
    private func decodeDouyuData(_ data: Data, isAuthData yesOrNo: Bool, connection: WebSocketConnection) {
        var contents: [String] = []
        var subData = data
        var _loction: Int = 0
        var _length: Int = 0
        
        repeat {
            // 获取数据长度
            if subData.count < 12 {
                break
            }
            
            _length = Int(subData.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: 0, as: Int32.self)
            }) - 12
            
            if _length + 12 >= data.count {
                break
            }
            
            // 截取相应的数据
            let contentData = subData.subdata(in: 12..<_length + 12)
            if let content = String(data: contentData, encoding: .utf8) {
                contents.append(content)
            }
            
            // 截取余下的数据
            _loction += 12
            if _length + _loction > data.count {
                break
            }
            subData = data.subdata(in: _length + _loction..<data.count)
            _loction += _length
        } while _loction < data.count
        
        if contents.count > 0 {
            let str = contents.first!
            if NSString(string: str).contains("chatmsg") == true {
                let barrageDict = formatBarrageDict(msg: str)
                connection.delegate?.webSocketDidReceiveMessage(text: barrageDict["content"] as? String ?? "", color: UInt32(getDouyinLiveColor(col: barrageDict["col"] as? Int ?? 0)))
            }
        }
    }
    
    private func formatBarrageDict(msg: String) -> [String: Any] {
       do {
           let keys = ["rid", "uid", "nn", "level", "bnn", "bl", "brid", "diaf", "txt", "col"]
           var values: [Any] = []
           
           for key in keys {
               let regex = try NSRegularExpression(pattern: #"\#(key)@=(.*?)/"#)
               if let match = regex.firstMatch(in: msg, range: NSRange(msg.startIndex..., in: msg)) {
                   let matchedString = String(msg[Range(match.range(at: 1), in: msg)!])
                   values.append(matchedString)
               }else {
                   values.append("")
               }
           }
           
           let barrageDict: [String: Any] = [
               "rid": Int(values[0] as? String ?? "") ?? 0,
               "uid": Int(values[1] as? String ?? "") ?? 0,
               "nickname": values[2] as? String ?? "",
               "level": Int(values[3] as? String ?? "") ?? 0,
               "bnn": values[4] as? String ?? "",
               "bnn_level": Int(values[5] as? String ?? "") ?? 0,
               "brid": Int(values[6] as? String ?? "") ?? 0,
               "is_diaf": Int(values[7] as? String ?? "") ?? 0,
               "content": values[8] as? String ?? "",
               "col": Int(values[9] as? String ?? "") ?? 0
           ]
           return barrageDict
       } catch {
           // Handle error
           print("Error: \(error)")
           return [:]
       }
    }
    
    private func getDouyinLiveColor(col: Int) -> Int {
        switch col {
        case 1:
            return 0xFF0000
        case 2:
            return 0x1E7DF0
        case 3:
            return 0x7AC84B
        case 4:
            return 0xFF7F00
        case 5:
            return 0x9B39F4
        case 6:
            return 0xFF69B4
        default:
            return 0xffffff
        }
    }
}
