//
//  HuyaSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
import JavaScriptCore

public class HuyaSocketDataParser: WebSocketDataParser {
    
    let huyaJSContext: JSContext = {
        let huyaJSContext = JSContext()
        if let huyaFilePath = Bundle.module.path(forResource: "huya", ofType: "js") {
            huyaJSContext?.evaluateScript(try? String(contentsOfFile: huyaFilePath))
        }
        return huyaJSContext!
    }()
    
    func performHandshake(connection: WebSocketConnection) {
        if let huyaFilePath = Bundle.module.path(forResource: "huya", ofType: "js") {
            huyaJSContext.evaluateScript(try? String(contentsOfFile: huyaFilePath))
            huyaJSContext.evaluateScript("""
                            var wsUserInfo = new HUYA.WSUserInfo;
                            wsUserInfo.lUid = "\(connection.parameters?["lYyid"] ?? "")";
                            wsUserInfo.lTid = "\(connection.parameters?["lChannelId"] ?? "")";
                            wsUserInfo.lSid = "\(connection.parameters?["lSubChannelId"] ?? "")";
                            """)
            let result = huyaJSContext.evaluateScript("""
                new Uint8Array(sendRegister(wsUserInfo));
            """)
            let data = Data(result?.toArray() as? [UInt8] ?? [])
            connection.socket?.write(data: data) //加入房间
            connection.heartbeatTimer = Timer(timeInterval: TimeInterval(60), repeats: true) {_ in //心跳
                connection.socket?.write(data: "ABQdAAwsNgBM".data(using: .utf8)!)
            }
            RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
        }
    }
    
    func parse(data: Data, connection: WebSocketConnection) {
        deCodeData(data: data, connection: connection)
    }
    
    private func deCodeData(data: Data, connection: WebSocketConnection) {
        let bytes = [UInt8](data)
        if let re = huyaJSContext.evaluateScript("test(\(bytes));"), let json = try? JSONSerialization.jsonObject(with: Data((re.toString() ?? "").utf8), options: []) as? [String: Any] {
            guard let str = json["sContent"] as? String else {
                return
            }
            let tFormat = json["tFormat"] as? [String: Any]
            let col = tFormat?["iFontColor"] as? Int ?? -1
            guard str != "HUYA.EWebSocketCommandType.EWSCmd_RegisterRsp" else {
                print("huya websocket inited EWSCmd_RegisterRsp")
                return
            }
            guard str != "HUYA.EWebSocketCommandType.Default" else {
                print("huya websocket WebSocketCommandType.Default \(data)")
                return
            }
            guard !str.contains("分享了直播间，房间号"), !str.contains("录制并分享了小视频"), !str.contains("进入直播间"), !str.contains("刚刚在打赏君活动中") else { return }
            connection.delegate?.webSocketDidReceiveMessage(text: str, color: UInt32(getHuyaLiveColor(col: col)))
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
}
