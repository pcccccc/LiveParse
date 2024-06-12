//
//  HuyaSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
import JavaScriptCore
import zlib

public class CCSocketDataParser: WebSocketDataParser {
    
    func performHandshake(connection: WebSocketConnection) {
        connection.socket?.write(data: getJoin(dataCid: connection.parameters?["cid"] ?? "", dataGameType: connection.parameters?["gametype"] ?? "", dataRoomId: connection.parameters?["room_id"] ?? "")) //加入房间
        connection.socket?.write(data: getReg())
        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(30), repeats: true) {_ in //心跳
            connection.socket?.write(data: self.getBeat())
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }
    
    func parse(data: Data, connection: WebSocketConnection) {
        print(data)
        deCodeData(data: data, connection: connection)
    }
    
    private func deCodeData(data: Data, connection: WebSocketConnection) {

    }
        
    func encodeDict(_ dict: [String: Any]) -> Data {
        var encoded = Data([222]) // Assuming all dictionaries are less than 65536 elements
        for (key, value) in dict {
            encoded.append(encodeStr(key))
            if let num = value as? Int {
                encoded.append(encodeNum(num))
            } else if let str = value as? String {
                encoded.append(encodeStr(str))
            } else if let subDict = value as? [String: Any] {
                encoded.append(encodeDict(subDict))
            }
        }
        return encoded
    }
    
    func encodeStr(_ str: String) -> Data {
        let length = str.utf8.count
        var encoded = Data()
        if length < 32 {
            encoded.append(UInt8(160 + length))
        } else if length <= 255 {
            encoded.append(contentsOf: [215, UInt8(length)])
        } else if length <= 65535 {
            encoded.append(contentsOf: [216])
            encoded.append(contentsOf: withUnsafeBytes(of: UInt16(length).bigEndian, Array.init))
        }
        encoded.append(contentsOf: str.utf8)
        return encoded
    }

    func encodeNum(_ num: Int) -> Data {
        var encoded = Data()
        if num < 256 {
            encoded.append(contentsOf: [204, UInt8(num)])
        } else if num < 65536 {
            encoded.append(205)
            encoded.append(contentsOf: withUnsafeBytes(of: UInt16(num).bigEndian, Array.init))
        } else {
            encoded.append(206)
            encoded.append(contentsOf: withUnsafeBytes(of: UInt64(num).bigEndian, Array.init))
        }
        return encoded
    }
    
    private func getJoin(dataCid: String, dataGameType: String, dataRoomId: String) -> Data {
        let sid: UInt16 = 6144
        let cid: UInt16 = 2
        let data: [String: Any] = [
            "cid": dataCid,
            "gametype":dataGameType,
            "roomId": dataRoomId
        ]
        var joinData = Data()
        joinData.appendUInt16(sid)
        joinData.appendUInt16(cid)
        joinData.appendUInt32(0) // Placeholder for future use
        joinData.append(encodeDict(data))
        return joinData
    }
    
    func getReg() -> Data {
        let sid: UInt16 = 6144
        let cid: UInt16 = 2
        let update_req_info: [String: Any] = [
            "22": 640,
            "23": 360,
            "24": "web",
            "25": "Linux",
            "29": "163_cc",
            "30": "",
            "31": "Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Mobile Safari/537.36"
        ]
        let device_token = UUID().uuidString + "@web.cc.163.com"
        let macAdd = device_token
        let data: [String: Any] = [
            "web-cc": Int(Date().timeIntervalSince1970 * 1000),
            "macAdd": macAdd,
            "device_token": device_token,
            "page_uuid": UUID().uuidString,
            "update_req_info": update_req_info,
            "system": "win",
            "memory": 1,
            "version": 1,
            "webccType": 4253
        ]
        var regData = Data()
        regData.appendUInt16(sid)
        regData.appendUInt16(cid)
        regData.appendUInt32(0) // Placeholder for future use
        regData.append(encodeDict(data))
        return regData
    }

    private func getBeat() -> Data {
        let sid: UInt16 = 6144
        let cid: UInt16 = 5
        let data: [String: Any] = [:] // 空字典表示心跳包通常不包含额外数据
        var beatData = Data()
        beatData.appendUInt16(sid)
        beatData.appendUInt16(cid)
        beatData.appendUInt32(0) // Placeholder for future use
        beatData.append(encodeDict(data))
        return beatData
    }
    
}
    
extension Data {
    mutating func appendUInt8(_ value: UInt8) {
        var val = value
        self.append(UnsafeBufferPointer(start: &val, count: 1))
    }

    mutating func appendUInt16(_ value: UInt16) {
        var val = value.bigEndian
        self.append(UnsafeBufferPointer(start: &val, count: 1))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var val = value.bigEndian
        self.append(UnsafeBufferPointer(start: &val, count: 1))
    }
    
    func unpackUInt16(fromOffset offset: Int) -> UInt16 {
        let subdata = self.subdata(in: offset..<offset+2)
        return UInt16(bigEndian: subdata.withUnsafeBytes { $0.load(as: UInt16.self) })
    }

    func unpackUInt32(fromOffset offset: Int) -> UInt32 {
        let subdata = self.subdata(in: offset..<offset+4)
        return UInt32(bigEndian: subdata.withUnsafeBytes { $0.load(as: UInt32.self) })
    }

}
