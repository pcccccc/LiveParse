//
//  BilibiliSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
@preconcurrency import JavaScriptCore
import SWCompression

public final class BilibiliSocketDataParser: WebSocketDataParser {
    private static let codec = BilibiliDanmuJSCodec()

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

    func performHandshake(connection: WebSocketConnection) {
        let roomId = connection.parameters?["roomId"] ?? "0"
        let token = connection.parameters?["token"] ?? ""
        let buvid = connection.parameters?["buvid"] ?? ""
        let uid = BiliBiliCookie.uid

        if let authPacket = Self.codec.makeAuthPacket(
            uid: uid,
            roomId: roomId,
            token: token,
            buvid: buvid
        ) {
            connection.socket?.write(data: authPacket)
        }

        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(60), repeats: true) { _ in
            if let heartbeat = Self.codec.makeHeartbeatPacket() {
                connection.socket?.write(data: heartbeat)
            }
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }
}

private struct BilibiliDanmuMessage {
    let text: String
    let nickname: String
    let color: UInt32
}

private final class BilibiliDanmuJSCodec {
    private let queue = DispatchQueue(label: "liveparse.danmu.bilibili.js")
    private let context: JSContext

    init() {
        self.context = JSContext()!

        queue.sync {
            context.exceptionHandler = { _, exception in
                if let exception {
                    print("BilibiliDanmuJSCodec exception: \(exception)")
                }
            }

            let inflate: @convention(block) ([NSNumber]) -> [NSNumber] = { numbers in
                let input = Data(numbers.map { $0.uint8Value })
                guard let output = try? ZlibArchive.unarchive(archive: input) else {
                    return []
                }
                return output.map { NSNumber(value: $0) }
            }

            context.setObject(inflate, forKeyedSubscript: "__lp_bili_inflate_zlib" as NSString)
            context.evaluateScript(Self.script)
        }
    }

    func makeAuthPacket(uid: String, roomId: String, token: String, buvid: String) -> Data? {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("BilibiliDanmuCodec"),
                  let result = codec.invokeMethod("authPacket", withArguments: [uid, roomId, token, buvid]),
                  let bytes = result.toArray() as? [NSNumber] else {
                return nil
            }
            return Data(bytes.map { $0.uint8Value })
        }
    }

    func makeHeartbeatPacket() -> Data? {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("BilibiliDanmuCodec"),
                  let result = codec.invokeMethod("heartbeatPacket", withArguments: []),
                  let bytes = result.toArray() as? [NSNumber] else {
                return nil
            }
            return Data(bytes.map { $0.uint8Value })
        }
    }

    func parseMessages(from data: Data) -> [BilibiliDanmuMessage] {
        let bytes = Array(data)

        return queue.sync {
            guard let codec = context.objectForKeyedSubscript("BilibiliDanmuCodec"),
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
                return BilibiliDanmuMessage(text: text, nickname: nickname, color: colorValue)
            }
        }
    }
}

private extension BilibiliDanmuJSCodec {
    static let script = #"""
(function () {
  function u8(v) { return v & 0xff; }

  function readUInt16BE(bytes, offset) {
    return ((bytes[offset] & 0xff) << 8) | (bytes[offset + 1] & 0xff);
  }

  function readUInt32BE(bytes, offset) {
    return (((bytes[offset] & 0xff) << 24) >>> 0)
      | ((bytes[offset + 1] & 0xff) << 16)
      | ((bytes[offset + 2] & 0xff) << 8)
      | (bytes[offset + 3] & 0xff);
  }

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

  function makePacket(operation, bodyText) {
    var body = utf8Encode(String(bodyText || ""));
    var totalLen = body.length + 16;

    var out = [];
    out.push(u8(totalLen >> 24), u8(totalLen >> 16), u8(totalLen >> 8), u8(totalLen));
    out.push(0x00, 0x10);
    out.push(0x00, 0x01);
    out.push(u8(operation >> 24), u8(operation >> 16), u8(operation >> 8), u8(operation));
    out.push(0x00, 0x00, 0x00, 0x01);
    for (var i = 0; i < body.length; i++) out.push(body[i]);

    return out;
  }

  function splitJSONObjectCandidates(text) {
    var input = String(text || "");
    var parts = [];
    var depth = 0;
    var start = -1;
    var inString = false;
    var escaped = false;

    for (var i = 0; i < input.length; i++) {
      var ch = input.charAt(i);

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch === "\\") {
          escaped = true;
        } else if (ch === "\"") {
          inString = false;
        }
        continue;
      }

      if (ch === "\"") {
        inString = true;
        continue;
      }

      if (ch === "{") {
        if (depth === 0) start = i;
        depth += 1;
      } else if (ch === "}") {
        if (depth > 0) {
          depth -= 1;
          if (depth === 0 && start >= 0) {
            parts.push(input.slice(start, i + 1));
            start = -1;
          }
        }
      }
    }

    if (parts.length === 0 && input.trim().length > 0) {
      parts.push(input.trim());
    }

    return parts;
  }

  function get(obj, keys) {
    var current = obj;
    for (var i = 0; i < keys.length; i++) {
      if (current == null || typeof current !== "object") return undefined;
      current = current[keys[i]];
    }
    return current;
  }

  function normalizeColor(value, fallback) {
    var v = Number(value);
    if (!Number.isFinite(v) || v < 0) return fallback;
    return (v >>> 0);
  }

  function collectMessageFromJSON(payload, out) {
    if (!payload || typeof payload !== "object") return;

    var cmd = String(payload.cmd || "");
    if (cmd.indexOf("DANMU_MSG") === 0) {
      var text = get(payload, ["info", 1]);
      var nickname = get(payload, ["info", 2, 1]);
      var color = normalizeColor(get(payload, ["info", 0, 3]), 0xFFFFFF);

      if (typeof text === "string" && typeof nickname === "string") {
        out.push({
          nickname: nickname,
          text: text,
          color: color
        });
      }
      return;
    }

    if (cmd === "SUPER_CHAT_MESSAGE") {
      var scName = get(payload, ["data", "uinfo", "base", "origin_info", "name"]);
      var scText = get(payload, ["data", "message"]);
      var scColor = normalizeColor(get(payload, ["data", "background_bottom_color"]), 0xFFFFFF);
      if (typeof scName === "string" && typeof scText === "string") {
        out.push({
          nickname: scName,
          text: "醒目留言: " + scText,
          color: scColor
        });
      }
    }
  }

  function parseBodyToMessages(bodyBytes, out) {
    var text = utf8Decode(bodyBytes || []);
    var parts = splitJSONObjectCandidates(text);

    for (var i = 0; i < parts.length; i++) {
      var raw = parts[i];
      try {
        var payload = JSON.parse(raw);
        collectMessageFromJSON(payload, out);
      } catch (_) {
      }
    }
  }

  function parsePackets(bytes, out) {
    var data = bytes || [];
    var offset = 0;

    while (offset + 16 <= data.length) {
      var packetLen = readUInt32BE(data, offset);
      if (packetLen < 16 || offset + packetLen > data.length) {
        break;
      }

      var headerLen = readUInt16BE(data, offset + 4);
      var protocolVer = readUInt16BE(data, offset + 6);
      var operation = readUInt32BE(data, offset + 8);
      if (headerLen < 16 || headerLen > packetLen) {
        offset += packetLen;
        continue;
      }

      var body = data.slice(offset + headerLen, offset + packetLen);

      if (protocolVer === 2) {
        var inflated = __lp_bili_inflate_zlib(body);
        if (inflated && inflated.length > 0) {
          parsePackets(inflated, out);
        }
      } else if (operation === 5) {
        parseBodyToMessages(body, out);
      }

      offset += packetLen;
    }
  }

  globalThis.BilibiliDanmuCodec = {
    authPacket: function (uid, roomId, token, buvid) {
      var payload = {
        uid: Number(uid || 0),
        roomid: Number(roomId || 0),
        protover: 2,
        buvid: String(buvid || ""),
        platform: "web",
        type: 2,
        key: String(token || ""),
        clientver: "1.8.2"
      };
      return makePacket(7, JSON.stringify(payload));
    },
    heartbeatPacket: function () {
      return makePacket(2, "{}");
    },
    parseMessages: function (bytes) {
      var out = [];
      parsePackets(bytes || [], out);
      return out;
    }
  };
})();
"""#
}
