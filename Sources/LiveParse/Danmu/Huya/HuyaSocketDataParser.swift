//
//  HuyaSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
@preconcurrency import JavaScriptCore

public final class HuyaSocketDataParser: WebSocketDataParser {
    private static let codec = HuyaDanmuJSCodec()

    func performHandshake(connection: WebSocketConnection) {
        let uid = Int(connection.parameters?["lYyid"] ?? "0") ?? 0
        let tid = Int(connection.parameters?["lChannelId"] ?? "0") ?? 0
        let sid = Int(connection.parameters?["lSubChannelId"] ?? "0") ?? 0

        if let joinPacket = Self.codec.makeJoinPacket(uid: uid, tid: tid, sid: sid) {
            connection.socket?.write(data: joinPacket)
        }

        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(60), repeats: true) { _ in
            if let heartbeat = Self.codec.makeHeartbeatPacket() {
                connection.socket?.write(data: heartbeat)
            }
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }

    func parse(data: Data, connection: WebSocketConnection) {
        let messages = Self.codec.parseMessages(from: data)
        for message in messages {
            connection.delegate?.webSocketDidReceiveMessage(
                text: message.text,
                nickname: message.nickname,
                color: message.color
            )
        }
    }
}

private struct HuyaDanmuMessage {
    let text: String
    let nickname: String
    let color: UInt32
}

private final class HuyaDanmuJSCodec {
    private let queue = DispatchQueue(label: "liveparse.danmu.huya.js")
    private let context: JSContext

    init() {
        self.context = JSContext()!

        queue.sync {
            context.exceptionHandler = { _, exception in
                if let exception {
                    print("HuyaDanmuJSCodec exception: \(exception)")
                }
            }

            if let huyaScriptURL = Bundle.module.url(forResource: "huya", withExtension: "js"),
               let huyaScript = try? String(contentsOf: huyaScriptURL, encoding: .utf8) {
                context.evaluateScript(huyaScript, withSourceURL: huyaScriptURL)
            } else {
                print("HuyaDanmuJSCodec: missing huya.js resource")
            }

            context.evaluateScript(Self.bridgeScript)
        }
    }

    func makeJoinPacket(uid: Int, tid: Int, sid: Int) -> Data? {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("HuyaDanmuCodec"),
                  let result = codec.invokeMethod("joinPacket", withArguments: [uid, tid, sid]),
                  let bytes = result.toArray() as? [NSNumber] else {
                return nil
            }
            return Data(bytes.map { $0.uint8Value })
        }
    }

    func makeHeartbeatPacket() -> Data? {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("HuyaDanmuCodec"),
                  let result = codec.invokeMethod("heartbeatPacket", withArguments: []),
                  let bytes = result.toArray() as? [NSNumber] else {
                return nil
            }
            return Data(bytes.map { $0.uint8Value })
        }
    }

    func parseMessages(from data: Data) -> [HuyaDanmuMessage] {
        let bytes = Array(data)

        return queue.sync {
            guard let codec = context.objectForKeyedSubscript("HuyaDanmuCodec"),
                  let result = codec.invokeMethod("parseMessages", withArguments: [bytes]),
                  let items = result.toArray() as? [[String: Any]] else {
                return []
            }

            return items.compactMap { item in
                guard let text = item["text"] as? String,
                      let nickname = item["nickname"] as? String else {
                    return nil
                }
                let colorValue = (item["color"] as? NSNumber)?.uint32Value ?? 0xFFFFFF
                return HuyaDanmuMessage(text: text, nickname: nickname, color: colorValue)
            }
        }
    }
}

private extension HuyaDanmuJSCodec {
    static let bridgeScript = #"""
(function () {
  function asByteArray(buffer) {
    return Array.from(new Uint8Array(buffer));
  }

  function buildJoinPacket(uid, tid, sid) {
    if (typeof sendRegister !== "function" || !globalThis.HUYA || !globalThis.Taf) {
      return [];
    }

    var userInfo = new HUYA.WSUserInfo();
    userInfo.lUid = Number(uid || 0);
    userInfo.bAnonymous = true;
    userInfo.sGuid = "";
    userInfo.sToken = "";
    userInfo.lTid = Number(tid || 0);
    userInfo.lSid = Number(sid || 0);
    userInfo.lGroupId = 0;
    userInfo.lGroupType = 0;

    return asByteArray(sendRegister(userInfo));
  }

  function buildHeartbeatPacket() {
    var raw = "ABQdAAwsNgBM";
    var out = [];
    for (var i = 0; i < raw.length; i++) {
      out.push(raw.charCodeAt(i) & 0xff);
    }
    return out;
  }

  function parseMessages(bytes) {
    var out = [];

    if (!globalThis.HUYA || !globalThis.Taf) {
      return out;
    }

    try {
      var commandInput = new Taf.JceInputStream(new Uint8Array(bytes || []).buffer);
      var command = new HUYA.WebSocketCommand();
      command.readFrom(commandInput);

      if (Number(command.iCmdType) !== HUYA.EWebSocketCommandType.EWSCmdS2C_MsgPushReq) {
        return out;
      }

      var pushInput = new Taf.JceInputStream(command.vData.buffer);
      var pushMessage = new HUYA.WSPushMessage();
      pushMessage.readFrom(pushInput);

      if (Number(pushMessage.iUri) !== 1400) {
        return out;
      }

      var noticeInput = new Taf.JceInputStream(pushMessage.sMsg.buffer);
      var messageNotice = new HUYA.MessageNotice();
      messageNotice.readFrom(noticeInput);

      var nickname = messageNotice.tUserInfo && messageNotice.tUserInfo.sNickName
        ? String(messageNotice.tUserInfo.sNickName)
        : "";
      var text = String(messageNotice.sContent || "");
      var fontColor = messageNotice.tBulletFormat
        ? Number(messageNotice.tBulletFormat.iFontColor)
        : -1;
      var color = (fontColor === 255 || !Number.isFinite(fontColor) || fontColor < 0)
        ? 0xFFFFFF
        : (fontColor >>> 0);

      out.push({
        nickname: nickname,
        text: text,
        color: color
      });
    } catch (_) {
    }

    return out;
  }

  globalThis.HuyaDanmuCodec = {
    joinPacket: function (uid, tid, sid) {
      return buildJoinPacket(uid, tid, sid);
    },
    heartbeatPacket: function () {
      return buildHeartbeatPacket();
    },
    parseMessages: function (bytes) {
      return parseMessages(bytes || []);
    }
  };
})();
"""#
}
