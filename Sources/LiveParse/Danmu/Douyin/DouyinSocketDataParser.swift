//
//  DouyinSocketDataParser.swift
//
//
//  Created by pc on 2023/12/28.
//

import Foundation
@preconcurrency import JavaScriptCore

public final class DouyinSocketDataParser: WebSocketDataParser {
    private static let codec = DouyinDanmuJSCodec()

    func performHandshake(connection: WebSocketConnection) {
        guard let heartbeat = Self.codec.makeHeartbeatPacket() else {
            connection.delegate?.webSocketDidDisconnect(error: nil)
            return
        }

        connection.socket?.write(data: heartbeat)
        connection.heartbeatTimer = Timer(timeInterval: TimeInterval(10), repeats: true) { _ in
            guard let data = Self.codec.makeHeartbeatPacket() else {
                connection.delegate?.webSocketDidDisconnect(error: nil)
                return
            }
            connection.socket?.write(data: data)
        }
        RunLoop.current.add(connection.heartbeatTimer!, forMode: .common)
    }

    func parse(data: Data, connection: WebSocketConnection) {
        let result = Self.codec.parseFrame(from: data)

        if let ackPacket = result.ackPacket {
            connection.socket?.write(data: ackPacket)
        }

        for message in result.messages {
            connection.delegate?.webSocketDidReceiveMessage(
                text: message.text,
                nickname: message.nickname,
                color: message.color
            )
        }
    }
}

private struct DouyinDanmuMessage {
    let text: String
    let nickname: String
    let color: UInt32
}

private struct DouyinDanmuDecodeResult {
    let messages: [DouyinDanmuMessage]
    let ackPacket: Data?
}

private final class DouyinDanmuJSCodec {
    private let queue = DispatchQueue(label: "liveparse.danmu.douyin.js")
    private let context: JSContext

    init() {
        self.context = JSContext()!

        queue.sync {
            context.exceptionHandler = { _, exception in
                if let exception {
                    print("DouyinDanmuJSCodec exception: \(exception)")
                }
            }

            let inflate: @convention(block) ([NSNumber]) -> [NSNumber] = { numbers in
                let input = Data(numbers.map { $0.uint8Value })
                guard let output = Data.decompressGzipData(data: input) else {
                    return []
                }
                return output.map { NSNumber(value: $0) }
            }

            context.setObject(inflate, forKeyedSubscript: "__lp_douyin_gzip_inflate" as NSString)
            context.evaluateScript(Self.script)
        }
    }

    func makeHeartbeatPacket() -> Data? {
        queue.sync {
            guard let codec = context.objectForKeyedSubscript("DouyinDanmuCodec"),
                  let result = codec.invokeMethod("heartbeatPacket", withArguments: []),
                  let bytes = result.toArray() as? [NSNumber] else {
                return nil
            }
            return Data(bytes.map { $0.uint8Value })
        }
    }

    func parseFrame(from data: Data) -> DouyinDanmuDecodeResult {
        let bytes = Array(data)

        return queue.sync {
            guard let codec = context.objectForKeyedSubscript("DouyinDanmuCodec"),
                  let result = codec.invokeMethod("parseFrame", withArguments: [bytes]) else {
                return DouyinDanmuDecodeResult(messages: [], ackPacket: nil)
            }

            let messageItems = result.forProperty("messages")?.toArray() as? [[String: Any]] ?? []
            let messages = messageItems.compactMap { item -> DouyinDanmuMessage? in
                guard let text = item["text"] as? String,
                      let nickname = item["nickname"] as? String else {
                    return nil
                }
                let colorValue = (item["color"] as? NSNumber)?.uint32Value ?? 0xFFFFFF
                return DouyinDanmuMessage(text: text, nickname: nickname, color: colorValue)
            }

            let ackBytes = result.forProperty("ackPacket")?.toArray() as? [NSNumber]
            let ackPacket = ackBytes.flatMap { bytes -> Data? in
                guard !bytes.isEmpty else { return nil }
                return Data(bytes.map { $0.uint8Value })
            }

            return DouyinDanmuDecodeResult(messages: messages, ackPacket: ackPacket)
        }
    }
}

private extension DouyinDanmuJSCodec {
    static let script = #"""
(function () {
  function readVarint(bytes, offset) {
    var value = 0;
    var shift = 0;
    var idx = offset;

    while (idx < bytes.length && shift <= 63) {
      var b = bytes[idx++] & 0xff;
      value += (b & 0x7f) * Math.pow(2, shift);
      if ((b & 0x80) === 0) {
        return { value: value, offset: idx };
      }
      shift += 7;
    }

    return null;
  }

  function writeVarint(value) {
    var out = [];
    var v = Math.max(0, Number(value || 0));

    while (v >= 0x80) {
      out.push((v % 128) | 0x80);
      v = Math.floor(v / 128);
    }
    out.push(v & 0x7f);

    return out;
  }

  function readLengthDelimited(bytes, offset) {
    var lengthInfo = readVarint(bytes, offset);
    if (!lengthInfo) return null;

    var length = Number(lengthInfo.value || 0);
    var start = lengthInfo.offset;
    var end = start + length;
    if (end > bytes.length) return null;

    return {
      bytes: bytes.slice(start, end),
      offset: end
    };
  }

  function skipField(bytes, offset, wireType) {
    if (wireType === 0) {
      var v = readVarint(bytes, offset);
      return v ? v.offset : -1;
    }
    if (wireType === 1) {
      return offset + 8 <= bytes.length ? offset + 8 : -1;
    }
    if (wireType === 2) {
      var ld = readLengthDelimited(bytes, offset);
      return ld ? ld.offset : -1;
    }
    if (wireType === 5) {
      return offset + 4 <= bytes.length ? offset + 4 : -1;
    }
    return -1;
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

  function appendFieldVarint(out, fieldNumber, value) {
    var key = (fieldNumber << 3) | 0;
    var k = writeVarint(key);
    for (var i = 0; i < k.length; i++) out.push(k[i]);
    var v = writeVarint(value);
    for (var j = 0; j < v.length; j++) out.push(v[j]);
  }

  function appendFieldBytes(out, fieldNumber, dataBytes) {
    var key = (fieldNumber << 3) | 2;
    var k = writeVarint(key);
    for (var i = 0; i < k.length; i++) out.push(k[i]);

    var bytes = dataBytes || [];
    var len = writeVarint(bytes.length);
    for (var j = 0; j < len.length; j++) out.push(len[j]);
    for (var x = 0; x < bytes.length; x++) out.push(bytes[x]);
  }

  function appendFieldString(out, fieldNumber, text) {
    appendFieldBytes(out, fieldNumber, utf8Encode(String(text || "")));
  }

  function parsePushFrame(bytes) {
    var frame = {
      logId: 0,
      payloadType: "",
      payload: []
    };

    var offset = 0;
    while (offset < bytes.length) {
      var keyInfo = readVarint(bytes, offset);
      if (!keyInfo) break;
      offset = keyInfo.offset;

      var fieldNumber = Math.floor(keyInfo.value / 8);
      var wireType = keyInfo.value & 0x07;

      if (fieldNumber === 2 && wireType === 0) {
        var logId = readVarint(bytes, offset);
        if (!logId) break;
        frame.logId = Number(logId.value || 0);
        offset = logId.offset;
      } else if (fieldNumber === 7 && wireType === 2) {
        var payloadType = readLengthDelimited(bytes, offset);
        if (!payloadType) break;
        frame.payloadType = utf8Decode(payloadType.bytes);
        offset = payloadType.offset;
      } else if (fieldNumber === 8 && wireType === 2) {
        var payload = readLengthDelimited(bytes, offset);
        if (!payload) break;
        frame.payload = payload.bytes;
        offset = payload.offset;
      } else {
        var skipped = skipField(bytes, offset, wireType);
        if (skipped < 0) break;
        offset = skipped;
      }
    }

    return frame;
  }

  function parseResponseMessage(bytes) {
    var msg = {
      method: "",
      payload: []
    };

    var offset = 0;
    while (offset < bytes.length) {
      var keyInfo = readVarint(bytes, offset);
      if (!keyInfo) break;
      offset = keyInfo.offset;

      var fieldNumber = Math.floor(keyInfo.value / 8);
      var wireType = keyInfo.value & 0x07;

      if (fieldNumber === 1 && wireType === 2) {
        var method = readLengthDelimited(bytes, offset);
        if (!method) break;
        msg.method = utf8Decode(method.bytes);
        offset = method.offset;
      } else if (fieldNumber === 2 && wireType === 2) {
        var payload = readLengthDelimited(bytes, offset);
        if (!payload) break;
        msg.payload = payload.bytes;
        offset = payload.offset;
      } else {
        var skipped = skipField(bytes, offset, wireType);
        if (skipped < 0) break;
        offset = skipped;
      }
    }

    return msg;
  }

  function parseResponse(bytes) {
    var response = {
      messages: [],
      internalExt: "",
      needAck: false
    };

    var offset = 0;
    while (offset < bytes.length) {
      var keyInfo = readVarint(bytes, offset);
      if (!keyInfo) break;
      offset = keyInfo.offset;

      var fieldNumber = Math.floor(keyInfo.value / 8);
      var wireType = keyInfo.value & 0x07;

      if (fieldNumber === 1 && wireType === 2) {
        var messageField = readLengthDelimited(bytes, offset);
        if (!messageField) break;
        response.messages.push(parseResponseMessage(messageField.bytes));
        offset = messageField.offset;
      } else if (fieldNumber === 5 && wireType === 2) {
        var extField = readLengthDelimited(bytes, offset);
        if (!extField) break;
        response.internalExt = utf8Decode(extField.bytes);
        offset = extField.offset;
      } else if (fieldNumber === 9 && wireType === 0) {
        var ackField = readVarint(bytes, offset);
        if (!ackField) break;
        response.needAck = Number(ackField.value || 0) !== 0;
        offset = ackField.offset;
      } else {
        var skipped = skipField(bytes, offset, wireType);
        if (skipped < 0) break;
        offset = skipped;
      }
    }

    return response;
  }

  function parseUser(bytes) {
    var user = { nickname: "" };

    var offset = 0;
    while (offset < bytes.length) {
      var keyInfo = readVarint(bytes, offset);
      if (!keyInfo) break;
      offset = keyInfo.offset;

      var fieldNumber = Math.floor(keyInfo.value / 8);
      var wireType = keyInfo.value & 0x07;

      if (fieldNumber === 3 && wireType === 2) {
        var nickField = readLengthDelimited(bytes, offset);
        if (!nickField) break;
        user.nickname = utf8Decode(nickField.bytes);
        offset = nickField.offset;
      } else {
        var skipped = skipField(bytes, offset, wireType);
        if (skipped < 0) break;
        offset = skipped;
      }
    }

    return user;
  }

  function parseChatMessage(bytes) {
    var chat = {
      content: "",
      nickname: ""
    };

    var offset = 0;
    while (offset < bytes.length) {
      var keyInfo = readVarint(bytes, offset);
      if (!keyInfo) break;
      offset = keyInfo.offset;

      var fieldNumber = Math.floor(keyInfo.value / 8);
      var wireType = keyInfo.value & 0x07;

      if (fieldNumber === 2 && wireType === 2) {
        var userField = readLengthDelimited(bytes, offset);
        if (!userField) break;
        chat.nickname = parseUser(userField.bytes).nickname;
        offset = userField.offset;
      } else if (fieldNumber === 3 && wireType === 2) {
        var contentField = readLengthDelimited(bytes, offset);
        if (!contentField) break;
        chat.content = utf8Decode(contentField.bytes);
        offset = contentField.offset;
      } else {
        var skipped = skipField(bytes, offset, wireType);
        if (skipped < 0) break;
        offset = skipped;
      }
    }

    return chat;
  }

  function encodePushFrame(logId, payloadType) {
    var out = [];

    if (Number(logId || 0) > 0) {
      appendFieldVarint(out, 2, Number(logId || 0));
    }

    appendFieldString(out, 7, String(payloadType || ""));
    return out;
  }

  function parseFrame(bytes) {
    var frame = parsePushFrame(bytes || []);
    var messages = [];
    var ackPacket = null;

    var payload = frame.payload || [];
    if (payload.length === 0) {
      return { messages: messages, ackPacket: ackPacket };
    }

    var decompressed = __lp_douyin_gzip_inflate(payload);
    if (!decompressed || decompressed.length === 0) {
      return { messages: messages, ackPacket: ackPacket };
    }

    var response = parseResponse(decompressed);
    if (response.needAck) {
      ackPacket = encodePushFrame(frame.logId, response.internalExt || "");
    }

    for (var i = 0; i < response.messages.length; i++) {
      var item = response.messages[i];
      if (item.method === "WebcastChatMessage") {
        var chat = parseChatMessage(item.payload || []);
        messages.push({
          nickname: chat.nickname || "",
          text: chat.content || "",
          color: 0xFFFFFF
        });
      }
    }

    return {
      messages: messages,
      ackPacket: ackPacket
    };
  }

  globalThis.DouyinDanmuCodec = {
    heartbeatPacket: function () {
      return encodePushFrame(0, "hb");
    },
    parseFrame: function (bytes) {
      return parseFrame(bytes || []);
    }
  };
})();
"""#
}
