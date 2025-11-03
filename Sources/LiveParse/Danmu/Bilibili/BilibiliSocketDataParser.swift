//
//  BilibiliSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
import SwiftyJSON
import SWCompression

public class BilibiliSocketDataParser: WebSocketDataParser {
    
    func parse(data: Data, connection: WebSocketConnection) {
        unpack(data: data, connectionDelegate: connection.delegate)
    }
    
    
    func performHandshake(connection: WebSocketConnection) {
        connection.socket?.write(data: self.sendPacket(connection: connection, type: 7)) //发送握手包
        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(60), repeats: true) {_ in
            connection.socket?.write(data: self.sendPacket(connection: connection, type: 2)) //发送心跳包
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }
    
    private func sendPacket(connection: WebSocketConnection ,type: Int) -> Data {
        // 该函数修改自https://github.com/komeiji-koishi-ww/bilibili_danmakuhime_swiftUI/
        //数据包
        var bodyDatas = Data()
        
        switch type {
        case 7: //认证包
                let str = "{\"uid\": \(BiliBiliCookie.uid),\"roomid\": \(connection.parameters?["roomId"] ?? ""),\"protover\": 2,\"buvid\":\"\(connection.parameters?["buvid"] ?? "")\",\"platform\":\"web\",\"type\": 2,\"key\": \"\(connection.parameters?["token"] ?? "")\",\"clientver\":\"1.8.2\"}"
            bodyDatas = str.data(using: String.Encoding.utf8)!
            
        default: //心跳包
            bodyDatas = "{}".data(using: String.Encoding.utf8)!
        }
        
        //header总长度,  body长度+header长度
        var len: UInt32 = CFSwapInt32HostToBig(UInt32(bodyDatas.count + 16))
        let lengthData = Data(bytes: &len, count: 4)
        
        //header长度, 固定16
        var headerLen: UInt16 = CFSwapInt16HostToBig(UInt16(16))
        let headerLenghData = Data(bytes: &headerLen, count: 2)
        
        //协议版本
        var versionLen: UInt16 = CFSwapInt16HostToBig(UInt16(1))
        let versionLenData = Data(bytes: &versionLen, count: 2)
        
        //操作码
        var optionCode: UInt32 = CFSwapInt32HostToBig(UInt32(type))
        let optionCodeData = Data(bytes: &optionCode, count: 4)
        
        //数据包头部长度（固定为 1）
        var bodyHeaderLength: UInt32 = CFSwapInt32HostToBig(UInt32(1))
        let bodyHeaderLengthData = Data(bytes: &bodyHeaderLength, count: 4)
        
        //按顺序添加到数据包中
        var packData = Data()
        packData.append(lengthData)
        packData.append(headerLenghData)
        packData.append(versionLenData)
        packData.append(optionCodeData)
        packData.append(bodyHeaderLengthData)
        packData.append(bodyDatas)
        return packData
    }
    
    private func unpack(data: Data, connectionDelegate: WebSocketConnectionDelegate?) {
        let header = data.subdata(in: Range(NSRange(location: 0, length: 16))!)
        let protocolVer = header.subdata(in: Range(NSRange(location: 6, length: 2))!)
        _ = header.subdata(in: Range(NSRange(location: 8, length: 4))!)
        let body = data.subdata(in: Range(NSRange(location: 16, length: data.count-16))!)
        switch protocolVer._2BytesToInt() {
        case 0: // JSON
//             var result = try! JSON(data: body).rawString()!
                break
        case 1: // 人气值
            break
        case 2: // zlib JSON
            guard let unzipData = try? ZlibArchive.unarchive(archive: body) else {
                break
            }
            unpackUnzipData(data: unzipData, connectionDelegate: connectionDelegate)
        case 3: // brotli JSON
            break
        default:
            break
        }
    }
    
    func unpackUnzipData(data: Data, connectionDelegate: WebSocketConnectionDelegate?) {
        let bodyLen = data.subdata(in: Range(NSRange(location: 0, length: 4))!)._4BytesToInt()
        //print("[BodyLen] \(bodyLen)")
        if bodyLen > 16 {
            let cur = data.subdata(in: Range(NSRange(location: 16, length: bodyLen-16))!)
            parseJSON(json: JSON(cur), connectionDelegate: connectionDelegate)
            if data.count > bodyLen {
                let res = data.subdata(in: Range(NSRange(location: bodyLen, length: data.count-bodyLen))!)
                unpackUnzipData(data: res, connectionDelegate: connectionDelegate)
            }
        }
    }
    
    private func parseJSON(json: JSON, connectionDelegate: WebSocketConnectionDelegate?) {
        switch json["cmd"].stringValue {
        case message.dm.rawValue:
            if json["info"].arrayValue[3].count <= 0 {
                print("昵称：\(json["info"].arrayValue[2].arrayValue[1].stringValue)")
                print("弹幕：\(json["info"].arrayValue[1].stringValue)")
                connectionDelegate?.webSocketDidReceiveMessage(text: json["info"].arrayValue[1].stringValue, nickname: json["info"].arrayValue[2].arrayValue[1].stringValue, color: json["info"].arrayValue[0].arrayValue[3].uInt32Value)
            } else {
                print("昵称：\(json["info"].arrayValue[2].arrayValue[1].stringValue)")
                print("弹幕：\(json["info"].arrayValue[1].stringValue)")
                connectionDelegate?.webSocketDidReceiveMessage(text: json["info"].arrayValue[1].stringValue, nickname: json["info"].arrayValue[2].arrayValue[1].stringValue, color: json["info"].arrayValue[0].arrayValue[3].uInt32Value)
            }
        case message.sc.rawValue:
                print("昵称：\(json["data"]["uinfo"]["base"]["origin_info"]["name"].stringValue)")
                print("醒目留言: \(json["data"]["message"].stringValue)")
                connectionDelegate?.webSocketDidReceiveMessage(text: "醒目留言: \(json["data"]["message"].stringValue)", nickname: json["data"]["uinfo"]["base"]["origin_info"]["name"].stringValue, color: json["data"]["background_bottom_color"].uInt32Value)
        default:
            break
        }
    }
}


enum message: String {
    case dm = "DANMU_MSG" //弹幕消息
    case gift = "SEND_GIFT" //投喂礼物
    //case comboGift = "COMBO_SEND" //连击礼物
    //LIVE_INTERACTIVE_GAME
    case entry = "INTERACT_WORD" //进入房间
    //case ENTRY_EFFECT //欢迎舰长进入房间
    case sc = "SUPER_CHAT_MESSAGE"
}
