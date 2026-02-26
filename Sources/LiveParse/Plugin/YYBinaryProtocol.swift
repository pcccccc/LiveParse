import Foundation

/// YY 平台二进制协议工具类
struct YYBinaryProtocol {

    // MARK: - 外层帧格式 (Little-Endian)

    /// 构建外层帧：[4字节总长度][4字节URI][2字节0x00C8][N字节payload]
    static func buildFrame(uri: UInt32, payload: Data) -> Data {
        var data = Data()
        let totalLen = UInt32(4 + 4 + 2 + payload.count)

        // 4 bytes: total length (LE)
        data.append(contentsOf: withUnsafeBytes(of: totalLen.littleEndian) { Data($0) })

        // 4 bytes: URI (LE)
        data.append(contentsOf: withUnsafeBytes(of: uri.littleEndian) { Data($0) })

        // 2 bytes: 0x00C8 (LE)
        let magic: UInt16 = 0x00C8
        data.append(contentsOf: withUnsafeBytes(of: magic.littleEndian) { Data($0) })

        // Payload
        data.append(payload)

        return data
    }

    /// 解析外层帧
    static func parseFrame(_ data: Data) -> (uri: UInt32, payload: Data)? {
        guard data.count >= 10 else { return nil }

        let totalLen = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let uri = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self).littleEndian }
        let magic = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt16.self).littleEndian }

        guard magic == 0x00C8, data.count >= Int(totalLen) else { return nil }

        let payload = data.subdata(in: 10..<Int(totalLen))
        return (uri, payload)
    }

    // MARK: - YYP 应用层格式

    /// 构建 YYP 格式数据：[2字节maxType][2字节minType][4字节extCount][2字节dataLen][N字节data]
    static func buildYYP(maxType: UInt16, minType: UInt16, data: Data) -> Data {
        var result = Data()

        // maxType (LE)
        result.append(contentsOf: withUnsafeBytes(of: maxType.littleEndian) { Data($0) })

        // minType (LE)
        result.append(contentsOf: withUnsafeBytes(of: minType.littleEndian) { Data($0) })

        // extCount = 0 (LE)
        let extCount: UInt32 = 0
        result.append(contentsOf: withUnsafeBytes(of: extCount.littleEndian) { Data($0) })

        // dataLen (LE)
        let dataLen = UInt16(data.count)
        result.append(contentsOf: withUnsafeBytes(of: dataLen.littleEndian) { Data($0) })

        // data
        result.append(data)

        return result
    }

    /// 解析 YYP 格式
    static func parseYYP(_ data: Data) -> (maxType: UInt16, minType: UInt16, payload: Data)? {
        guard data.count >= 10 else { return nil }

        let maxType = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt16.self).littleEndian }
        let minType = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 2, as: UInt16.self).littleEndian }
        let extCount = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self).littleEndian }

        var offset = 8 + Int(extCount) * 4 // Skip extensions
        guard data.count >= offset + 2 else { return nil }

        let dataLen = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian }
        offset += 2

        guard data.count >= offset + Int(dataLen) else { return nil }
        let payload = data.subdata(in: offset..<(offset + Int(dataLen)))

        return (maxType, minType, payload)
    }

    // MARK: - 简化 Protobuf 编码（仅支持 YY 需要的字段）

    /// 编码 Varint
    static func encodeVarint(_ value: UInt64) -> Data {
        var data = Data()
        var val = value
        while val > 0x7F {
            data.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        data.append(UInt8(val & 0x7F))
        return data
    }

    /// 编码字符串字段：tag + length + utf8bytes
    static func encodeString(field: Int, value: String) -> Data {
        var data = Data()
        let tag = (field << 3) | 2  // wire type = 2 (length-delimited)
        data.append(contentsOf: encodeVarint(UInt64(tag)))

        let utf8 = Data(value.utf8)
        data.append(contentsOf: encodeVarint(UInt64(utf8.count)))
        data.append(utf8)

        return data
    }

    /// 编码整数字段：tag + varint
    static func encodeInt(field: Int, value: Int) -> Data {
        var data = Data()
        let tag = (field << 3) | 0  // wire type = 0 (varint)
        data.append(contentsOf: encodeVarint(UInt64(tag)))
        data.append(contentsOf: encodeVarint(UInt64(value)))
        return data
    }

    /// 编码嵌套消息：tag + length + message
    static func encodeMessage(field: Int, value: Data) -> Data {
        var data = Data()
        let tag = (field << 3) | 2  // wire type = 2
        data.append(contentsOf: encodeVarint(UInt64(tag)))
        data.append(contentsOf: encodeVarint(UInt64(value.count)))
        data.append(value)
        return data
    }

    // MARK: - Protobuf 解析

    /// 解析 Protobuf 字段
    static func parseProtobufFields(_ data: Data) -> [Int: Data] {
        var result = [Int: Data]()
        var offset = 0

        while offset < data.count {
            guard let (tag, wireType, fieldNumber, newOffset) = readTag(data, offset: offset) else { break }
            offset = newOffset

            switch wireType {
            case 0: // Varint
                guard let (_, newOffset) = readVarint(data, offset: offset) else { break }
                offset = newOffset

            case 2: // Length-delimited
                guard let (length, newOffset) = readVarint(data, offset: offset) else { break }
                offset = newOffset
                guard offset + Int(length) <= data.count else { break }
                let fieldData = data.subdata(in: offset..<(offset + Int(length)))
                result[fieldNumber] = fieldData
                offset += Int(length)

            default:
                return result
            }
        }

        return result
    }

    private static func readTag(_ data: Data, offset: Int) -> (tag: UInt64, wireType: Int, fieldNumber: Int, newOffset: Int)? {
        guard let (tag, newOffset) = readVarint(data, offset: offset) else { return nil }
        let wireType = Int(tag & 0x7)
        let fieldNumber = Int(tag >> 3)
        return (tag, wireType, fieldNumber, newOffset)
    }

    private static func readVarint(_ data: Data, offset: Int) -> (value: UInt64, newOffset: Int)? {
        var result: UInt64 = 0
        var shift = 0
        var currentOffset = offset

        while currentOffset < data.count {
            let byte = data[currentOffset]
            result |= UInt64(byte & 0x7F) << shift
            currentOffset += 1

            if (byte & 0x80) == 0 {
                return (result, currentOffset)
            }
            shift += 7
            if shift >= 64 { return nil }
        }

        return nil
    }

    /// 解析字符串字段
    static func parseString(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }
}
