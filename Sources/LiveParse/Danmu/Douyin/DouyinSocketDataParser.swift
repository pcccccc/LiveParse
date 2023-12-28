//
//  DouyinSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation

public class DouyinSocketDataParser: WebSocketDataParser {
    
    func performHandshake(connection: WebSocketConnection) {
        do {
            var obj = Douyin_PushFrame()
            obj.payloadType = "hb"
            let data = try obj.serializedData()
            connection.socket?.write(data: data) //发送握手包
            connection.heartbeatTimer = Timer(timeInterval: TimeInterval(10), repeats: true) { _ in
                do {
                    var obj = Douyin_PushFrame()
                    obj.payloadType = "hb"
                    let data = try obj.serializedData()
                    connection.socket?.write(data: data)
                }catch {
                    connection.delegate?.webSocketDidDisconnect(error: nil)
                }
            }
            RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
        }catch {
            connection.delegate?.webSocketDidDisconnect(error: nil)
        }
    }
    
    func parse(data: Data, connection: WebSocketConnection) {
        decodeDouyinData(data: data, connection: connection)
    }

    private func decodeDouyinData(data: Data, connection: WebSocketConnection) {
        do {
            let wssPackage = try Douyin_PushFrame(serializedData: data)
            let logID = wssPackage.logID
            let decompressed = Data.decompressGzipData(data: wssPackage.payload)
            let payloadPackage = try Douyin_Response(serializedData: decompressed ?? Data())
            if payloadPackage.needAck {
                douyinSendAck(logID, payloadPackage.internalExt, connection)
            }
            for msg in payloadPackage.messagesList {
                if msg.method == "WebcastChatMessage" {
                    dyUnPackWebcastChatMessage(msg.payload, connection)
                }else if msg.method == "WebcastRoomUserSeqMessage" {//暂时不知道干嘛用的
//                    dyUnPackWebcastRoomUserSeqMessage(msg.payload)
                }
            }
        }catch {
            print(error)
        }
    }
    
    private func douyinSendAck(_ logId: UInt64, _ internalExt: String, _ connection: WebSocketConnection) {
        do {
            var obj = Douyin_PushFrame()
            obj.payloadType = "ack"
            obj.logID = logId
            obj.payloadType = internalExt
            let data = try obj.serializedData()
            connection.socket?.write(data: data)
        }catch {
            
        }
    }
    
    private func dyUnPackWebcastChatMessage(_ payload: Data, _ connection: WebSocketConnection) {
        do {
            let chatMessage = try Douyin_ChatMessage(serializedData: payload)
            connection.delegate?.webSocketDidReceiveMessage(text: chatMessage.content, color: 0xFFFFFF)
        }catch {
            
        }
    }
}
