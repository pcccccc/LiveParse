//
//  DouyuSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
@preconcurrency import JavaScriptCore

public final class DouyuSocketDataParser: WebSocketDataParser {
    private static let codec = DouyuDanmuJSCodec()

    func performHandshake(connection: WebSocketConnection) {
        guard let roomId = connection.parameters?["roomId"], !roomId.isEmpty else { return }

        for packet in Self.codec.makeHandshakePackets(roomId: roomId) {
            connection.socket?.write(data: packet)
        }

        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(45), repeats: true) { _ in
            let timestamp = Int(Date().timeIntervalSince1970)
            if let heartbeat = Self.codec.makeHeartbeatPacket(timestamp: timestamp) {
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

private struct DouyuDanmuMessage {
    let text: String
    let nickname: String
    let color: UInt32
}

private final class DouyuDanmuJSCodec {
    private let queue = DispatchQueue(label: "liveparse.danmu.douyu.js")
    private let context: JSContext

    init() {
        self.context = JSContext()!
        queue.sync {
            self.context.exceptionHandler = { _, exception in
                if let exception {
                    print("DouyuDanmuJSCodec exception: \(exception)")
                }
            }
            self.context.evaluateScript(Self.script)
        }
    }

    func makeHandshakePackets(roomId: String) -> [Data] {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("DouyuDanmuCodec"),
                  let result = codec.invokeMethod("handshakePackets", withArguments: [roomId]),
                  let packets = result.toArray() as? [[NSNumber]] else {
                return []
            }
            return packets.map { Data($0.map { $0.uint8Value }) }
        }
    }

    func makeHeartbeatPacket(timestamp: Int) -> Data? {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("DouyuDanmuCodec"),
                  let result = codec.invokeMethod("heartbeatPacket", withArguments: [timestamp]),
                  let bytes = result.toArray() as? [NSNumber] else {
                return nil
            }
            return Data(bytes.map { $0.uint8Value })
        }
    }

    func parseMessages(from data: Data) -> [DouyuDanmuMessage] {
        let bytes = Array(data)

        return queue.sync {
            guard let codec = context.objectForKeyedSubscript("DouyuDanmuCodec"),
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
                return DouyuDanmuMessage(text: text, nickname: nickname, color: colorValue)
            }
        }
    }
}

private extension DouyuDanmuJSCodec {
    static let script = #"""
(function () {
  function u8(v) { return v & 0xff; }

  function utf8Encode(str) {
    var out = [];
    for (var i = 0; i < str.length; i++) {
      var c = str.charCodeAt(i);
      if (c < 0x80) {
        out.push(c);
      } else if (c < 0x800) {
        out.push(0xc0 | (c >> 6));
        out.push(0x80 | (c & 0x3f));
      } else if (c >= 0xd800 && c <= 0xdbff) {
        i += 1;
        if (i >= str.length) break;
        var c2 = str.charCodeAt(i);
        var u = 0x10000 + ((c & 0x3ff) << 10) + (c2 & 0x3ff);
        out.push(0xf0 | (u >> 18));
        out.push(0x80 | ((u >> 12) & 0x3f));
        out.push(0x80 | ((u >> 6) & 0x3f));
        out.push(0x80 | (u & 0x3f));
      } else {
        out.push(0xe0 | (c >> 12));
        out.push(0x80 | ((c >> 6) & 0x3f));
        out.push(0x80 | (c & 0x3f));
      }
    }
    return out;
  }

  function utf8Decode(bytes) {
    var out = "";
    var i = 0;
    while (i < bytes.length) {
      var c = bytes[i++] & 0xff;
      if ((c & 0x80) === 0) {
        out += String.fromCharCode(c);
      } else if ((c & 0xe0) === 0xc0) {
        if (i >= bytes.length) break;
        var c2 = bytes[i++] & 0x3f;
        out += String.fromCharCode(((c & 0x1f) << 6) | c2);
      } else if ((c & 0xf0) === 0xe0) {
        if (i + 1 >= bytes.length) break;
        var c21 = bytes[i++] & 0x3f;
        var c22 = bytes[i++] & 0x3f;
        out += String.fromCharCode(((c & 0x0f) << 12) | (c21 << 6) | c22);
      } else {
        if (i + 2 >= bytes.length) break;
        var c31 = bytes[i++] & 0x3f;
        var c32 = bytes[i++] & 0x3f;
        var c33 = bytes[i++] & 0x3f;
        var u = ((c & 0x07) << 18) | (c31 << 12) | (c32 << 6) | c33;
        u -= 0x10000;
        out += String.fromCharCode(0xd800 + ((u >> 10) & 0x3ff));
        out += String.fromCharCode(0xdc00 + (u & 0x3ff));
      }
    }
    return out;
  }

  function encodePacket(msg) {
    var msgBytes = utf8Encode(String(msg || ""));
    var dataLen = msgBytes.length + 9;

    var out = [];
    out.push(u8(dataLen));
    out.push(u8(dataLen >> 8));
    out.push(u8(dataLen >> 16));
    out.push(u8(dataLen >> 24));
    out.push(u8(dataLen));
    out.push(u8(dataLen >> 8));
    out.push(u8(dataLen >> 16));
    out.push(u8(dataLen >> 24));

    out.push(0xb1, 0x02, 0x00, 0x00);
    for (var i = 0; i < msgBytes.length; i++) out.push(msgBytes[i]);
    out.push(0x00);
    return out;
  }

  function readInt32LE(bytes, idx) {
    return (bytes[idx] & 0xff)
      | ((bytes[idx + 1] & 0xff) << 8)
      | ((bytes[idx + 2] & 0xff) << 16)
      | ((bytes[idx + 3] & 0xff) << 24);
  }

  function pick(msg, key) {
    var re = new RegExp(key + "@=(.*?)/");
    var m = re.exec(msg);
    return m && m[1] ? m[1] : "";
  }

  function mapColor(col) {
    switch (col) {
      case 1: return 0xFF0000;
      case 2: return 0x1E7DF0;
      case 3: return 0x7AC84B;
      case 4: return 0xFF7F00;
      case 5: return 0x9B39F4;
      case 6: return 0xFF69B4;
      default: return 0xFFFFFF;
    }
  }

  function parseMessages(bytes) {
    var data = bytes || [];
    var messages = [];
    var offset = 0;

    while (offset + 12 <= data.length) {
      var bodyLen = readInt32LE(data, offset) - 12;
      if (bodyLen <= 0 || offset + 12 + bodyLen > data.length) break;

      var body = data.slice(offset + 12, offset + 12 + bodyLen);
      var text = utf8Decode(body);

      if (text.indexOf("chatmsg") >= 0) {
        var dms = parseInt(pick(text, "dms"), 10);
        if (!isNaN(dms) && dms > -1) {
          var nickname = pick(text, "nn");
          var content = pick(text, "txt");
          var col = parseInt(pick(text, "col"), 10);
          if (isNaN(col)) col = 0;
          messages.push({
            nickname: nickname || "",
            text: content || "",
            color: mapColor(col)
          });
        }
      }

      offset += 12 + bodyLen;
    }

    return messages;
  }

  globalThis.DouyuDanmuCodec = {
    handshakePackets: function (roomId) {
      var rid = String(roomId || "");
      return [
        encodePacket("type@=loginreq/roomid@=" + rid + "/"),
        encodePacket("type@=joingroup/rid@=" + rid + "/gid@=-9999/")
      ];
    },
    heartbeatPacket: function (timestamp) {
      var tick = Number(timestamp || 0);
      return encodePacket("type@=keeplive/tick@=" + tick + "/");
    },
    parseMessages: function (bytes) {
      return parseMessages(bytes || []);
    }
  };
})();
"""#
}
