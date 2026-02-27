import Foundation
import zlib

/// YY 平台二进制协议工具类
struct YYBinaryProtocol {

    // MARK: - Outer frame [len:u32][uri:u32][magic:u16=200][payload]

    static func buildFrame(uri: UInt32, payload: Data) -> Data {
        var data = Data()
        let totalLen = UInt32(10 + payload.count)
        data.append(contentsOf: withUnsafeBytes(of: totalLen.littleEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: uri.littleEndian) { Data($0) })
        let magic: UInt16 = 0x00C8
        data.append(contentsOf: withUnsafeBytes(of: magic.littleEndian) { Data($0) })
        data.append(payload)
        return data
    }

    static func parseFrame(_ data: Data) -> (uri: UInt32, payload: Data)? {
        guard data.count >= 10 else { return nil }
        let totalLen = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let uri = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self).littleEndian }
        let magic = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt16.self).littleEndian }
        guard magic == 0x00C8, totalLen >= 10, data.count >= Int(totalLen) else { return nil }
        return (uri, data.subdata(in: 10..<Int(totalLen)))
    }

    // MARK: - YYP

    struct YYP {
        let maxType: UInt16
        let minType: UInt16
        let ext: [UInt16: String]
        let data: Data
    }

    static func buildYYP(
        maxType: UInt16,
        minType: UInt16,
        data: Data,
        ext: [UInt16: String] = [:],
        usePackV2: Bool = true
    ) -> Data {
        var result = Data()
        result.append(encodeUInt16LE(maxType))
        result.append(encodeUInt16LE(minType))
        result.append(encodeUInt32LE(UInt32(ext.count)))
        for (key, value) in ext {
            let bytes = Data(value.utf8)
            result.append(encodeUInt16LE(key))
            result.append(encodeUInt16LE(UInt16(bytes.count)))
            result.append(bytes)
        }
        if usePackV2 {
            // 对齐网页 H5Service encodeYYP(v2):
            // [u16 0][u32 0][u32 dataLen][u32 dataLen][data]
            result.append(encodeUInt16LE(0))
            result.append(encodeUInt32LE(0))
            result.append(encodeUInt32LE(UInt32(data.count)))
            result.append(encodeUInt32LE(UInt32(data.count)))
            result.append(data)
        } else {
            // 旧格式:
            // [u16 dataLen][data]
            result.append(encodeUInt16LE(UInt16(data.count)))
            result.append(data)
        }
        return result
    }

    static func parseYYP(_ data: Data) -> YYP? {
        var reader = Reader(data: data)
        do {
            let maxType = try reader.readUInt16LE()
            let minType = try reader.readUInt16LE()
            let extCount = Int(try reader.readUInt32LE())
            var ext: [UInt16: String] = [:]
            if extCount > 0 {
                for _ in 0..<extCount {
                    let key = try reader.readUInt16LE()
                    let length = Int(try reader.readUInt16LE())
                    let valueData = try reader.readBytes(count: length)
                    ext[key] = String(data: valueData, encoding: .utf8) ?? ""
                }
            }
            guard !reader.isAtEnd else { return YYP(maxType: maxType, minType: minType, ext: ext, data: Data()) }

            let legacyLen = Int(try reader.readUInt16LE())
            let payload: Data

            if legacyLen > 0 {
                // 旧格式
                payload = try reader.readBytes(count: legacyLen)
            } else {
                // 尝试按 packV2 解析
                // [u16 0][u32 compressType][u32 lenA][u32 lenB][data]
                // 进入此分支时，u16 0 已读取，余下至少需要 12 字节
                guard reader.offset + 12 <= data.count else {
                    payload = Data()
                    return YYP(maxType: maxType, minType: minType, ext: ext, data: payload)
                }
                let compressType = try reader.readUInt32LE()
                let lenA = Int(try reader.readUInt32LE())
                let lenB = Int(try reader.readUInt32LE())
                let remaining = data.count - reader.offset
                let packedLen: Int
                if lenB > 0, lenB <= remaining {
                    packedLen = lenB
                } else if lenA > 0, lenA <= remaining {
                    packedLen = lenA
                } else {
                    packedLen = remaining
                }
                let packed = try reader.readBytes(count: packedLen)

                if compressType == 1 {
                    // 网页端同款: compressType=1 时，body 为 deflate 压缩数据
                    let expectedSize = max(lenA, lenB, remaining)
                    let decoded = decompressDeflate(packed, expectedSize: expectedSize)
                    payload = decoded ?? packed
                    if maxType == 9701, minType == 8 {
                        print("🔍 YY YYP 9701/8 comp=\(compressType) lenA=\(lenA) lenB=\(lenB) packed=\(packed.count) decoded=\(decoded?.count ?? -1)")
                    }
                } else {
                    // compressType=0: 未压缩。lenA/lenB 在不同链路下语义可能互换，优先与剩余长度匹配。
                    let candidateLen: Int
                    if lenA > 0, lenA <= remaining, (lenA == remaining || lenB > remaining) {
                        candidateLen = lenA
                    } else if lenB > 0, lenB <= remaining {
                        candidateLen = lenB
                    } else {
                        candidateLen = remaining
                    }
                    payload = packed.prefix(candidateLen)
                }
            }
            return YYP(maxType: maxType, minType: minType, ext: ext, data: payload)
        } catch {
            return nil
        }
    }

    private static func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
        guard !data.isEmpty else { return Data() }
        return inflate(data, windowBits: 15, expectedSize: expectedSize)
            ?? inflate(data, windowBits: -15, expectedSize: expectedSize) // raw deflate fallback
    }

    private static func inflate(_ data: Data, windowBits: Int32, expectedSize: Int) -> Data? {
        var stream = z_stream()
        let initCode = inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initCode == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        var output = Data()
        output.reserveCapacity(max(expectedSize, data.count * 2))
        let chunkSize = 64 * 1024
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        var input = [UInt8](data)
        let inputCount = input.count

        return input.withUnsafeMutableBytes { inputBytes -> Data? in
            guard let inPtr = inputBytes.bindMemory(to: Bytef.self).baseAddress else { return nil }
            stream.next_in = inPtr
            stream.avail_in = uInt(inputCount)

            while true {
                let ret: Int32 = chunk.withUnsafeMutableBytes { outBytes in
                    stream.next_out = outBytes.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(chunkSize)
                    return zlib.inflate(&stream, Z_NO_FLUSH)
                }

                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(chunk, count: produced)
                }

                if ret == Z_STREAM_END {
                    break
                }
                if ret != Z_OK {
                    return nil
                }
                if stream.avail_in == 0, produced == 0 {
                    break
                }
            }

            return output.isEmpty ? nil : output
        }
    }

    // MARK: - AP Router

    struct APRouter {
        let from: String
        let ruri: UInt32
        let resCode: UInt16
        let body: Data
        let headers: Data
    }

    struct APRouterHeaders {
        let realUri: UInt32
        let appid: UInt32
        let uid: UInt32
        let serviceName: String
        let extentProps: [UInt32: Data]
        let clientCtx: String
    }

    static func buildAPRouterFrame(outerURI: UInt32, ruri: UInt32, body: Data, headers: Data, from: String = "", resCode: UInt16 = 0) -> Data {
        var payload = Data()
        payload.append(encodeASCIIString16(from))
        payload.append(encodeUInt32LE(ruri))
        payload.append(encodeUInt16LE(resCode))
        payload.append(encodeBytes32(body))
        payload.append(encodeBytes32(headers))
        return buildFrame(uri: outerURI, payload: payload)
    }

    static func parseAPRouter(_ payload: Data) -> APRouter? {
        var reader = Reader(data: payload)
        do {
            let from = try reader.readASCIIString16()
            let ruri = try reader.readUInt32LE()
            let resCode = try reader.readUInt16LE()
            let body = try reader.readBytes32()
            let headers = try reader.readBytes32()
            return APRouter(from: from, ruri: ruri, resCode: resCode, body: body, headers: headers)
        } catch {
            return nil
        }
    }

    static func buildAPRouterHeaders(realUri: UInt32, appid: UInt32, uid: UInt32, serviceName: String, extentProps: [UInt32: Data] = [:], clientCtx: String = "") -> Data {
        var result = Data()

        func appendChunk(field: UInt32, value: Data) {
            let chunkLen = UInt32(4 + value.count) // YY Router chunk length includes descriptor itself
            let descriptor = (field << 24) | (chunkLen & 0x00FF_FFFF)
            result.append(encodeUInt32LE(descriptor))
            result.append(value)
        }

        // field 1: real uri
        appendChunk(field: 1, value: encodeUInt32LE(realUri))

        // field 2: appid + uid + reserved
        var field2 = Data()
        field2.append(encodeUInt32LE(appid))
        field2.append(encodeUInt32LE(uid))
        field2.append(encodeUInt32LE(0))
        appendChunk(field: 2, value: field2)

        // field 4: vecProxyId + vecS2SId
        var field4 = Data()
        field4.append(encodeUInt32LE(0)) // proxy count
        field4.append(encodeUInt32LE(0)) // s2s count
        appendChunk(field: 4, value: field4)

        // field 5: codec
        appendChunk(field: 5, value: encodeUInt32LE(0))

        // field 6: client meta
        // 对齐网页实现: u32 + u32 + u16 + str16(service) + u16 + u32
        var field6 = Data()
        field6.append(encodeUInt32LE(0))
        field6.append(encodeUInt32LE(0))
        field6.append(encodeUInt16LE(0))
        field6.append(encodeASCIIString16(serviceName))
        field6.append(encodeUInt16LE(0))
        field6.append(encodeUInt32LE(0))
        appendChunk(field: 6, value: field6)

        // field 7: extent props
        var field7 = Data()
        let sortedProps = extentProps.keys.sorted()
        field7.append(encodeUInt32LE(UInt32(sortedProps.count)))
        for key in sortedProps {
            guard let value = extentProps[key] else { continue }
            field7.append(encodeUInt32LE(key))
            field7.append(encodeBytes16(value))
        }
        appendChunk(field: 7, value: field7)

        // field 8: client ctx
        appendChunk(field: 8, value: encodeASCIIString16(clientCtx))

        // trailer 0xFF787878 (LE)
        result.append(encodeUInt32LE(0xFF78_7878))
        return result
    }

    static func parseAPRouterHeaders(_ data: Data) -> APRouterHeaders? {
        var reader = Reader(data: data)
        var realUri: UInt32 = 0
        var appid: UInt32 = 0
        var uid: UInt32 = 0
        var serviceName = ""
        var extent: [UInt32: Data] = [:]
        var clientCtx = ""

        do {
            var guardCounter = 0
            while !reader.isAtEnd {
                let descriptor = try reader.readUInt32LE()
                let field = UInt8((descriptor >> 24) & 0xFF)
                if field == 0xFF { break }
                guardCounter += 1
                if guardCounter > 20 { break }

                switch field {
                case 1:
                    realUri = try reader.readUInt32LE()
                case 2:
                    appid = try reader.readUInt32LE()
                    uid = try reader.readUInt32LE()
                    _ = try reader.readUInt32LE()
                case 4:
                    // vecProxyId + vecS2SId
                    let proxyCount = Int(try reader.readUInt32LE())
                    if proxyCount > 0 {
                        _ = try reader.readBytes(count: proxyCount * 8)
                    }
                    let s2sCount = Int(try reader.readUInt32LE())
                    if s2sCount > 0 {
                        _ = try reader.readBytes(count: s2sCount * 8)
                    }
                case 5:
                    _ = try reader.readUInt32LE()
                case 6:
                    _ = try reader.readUInt32LE()
                    _ = try reader.readUInt32LE()
                    _ = try reader.readUInt16LE()
                    serviceName = try reader.readASCIIString16()
                    _ = try reader.readUInt16LE()
                    _ = try reader.readUInt32LE()
                case 7:
                    let count = Int(try reader.readUInt32LE())
                    for _ in 0..<count {
                        let key = try reader.readUInt32LE()
                        let value = try reader.readBytes16()
                        extent[key] = value
                    }
                case 8:
                    clientCtx = try reader.readASCIIString16()
                default:
                    let fieldLen = Int(descriptor & 0x00FF_FFFF)
                    if fieldLen > 4 {
                        _ = try reader.readBytes(count: fieldLen - 4)
                    }
                }
            }
        } catch {
            return nil
        }

        return APRouterHeaders(
            realUri: realUri,
            appid: appid,
            uid: uid,
            serviceName: serviceName,
            extentProps: extent,
            clientCtx: clientCtx
        )
    }

    // MARK: - Service messages

    struct DlSvcMsgByUid {
        let appid: UInt16
        let uid: UInt32
        let payload: Data
        let suid: UInt32
        let seqId: UInt32
    }

    struct DlSvcMsgBySid {
        let appid: UInt16
        let topSid: UInt32
        let payload: Data
    }

    static func buildUlSvcMsgByUid(
        appid: UInt16,
        topSid: UInt32,
        uid: UInt32,
        payload: Data,
        clientIp: UInt32 = 0,
        termType: UInt8 = 0,
        statType: UInt8,
        subSid: UInt32,
        ext: [UInt32: String] = [:],
        appendH5Tail: Bool = true
    ) -> Data {
        var data = Data()
        data.append(encodeUInt16LE(appid))
        data.append(encodeUInt32LE(topSid))
        data.append(encodeUInt32LE(uid))
        data.append(encodeBytes32(payload))
        data.append(encodeUInt32LE(clientIp))
        data.append(encodeUInt8(termType))
        data.append(encodeUInt8(statType))
        data.append(encodeUInt32LE(subSid))
        data.append(encodeUInt32LE(0))
        data.append(encodeUInt32LE(0))
        data.append(encodeUInt32LE(UInt32(ext.count)))
        for (key, value) in ext {
            data.append(encodeUInt32LE(key))
            data.append(encodeASCIIString16(value))
        }
        if appendH5Tail {
            // 对齐网页 h5_g_svcH5.buildUlSvcMsgByUidV2 末尾 22 字节
            data.append(encodeUInt16LE(0))
            data.append(encodeUInt32LE(0))
            data.append(encodeUInt32LE(uid))
            data.append(encodeUInt32LE(0))
            data.append(encodeUInt32LE(0))
            data.append(encodeUInt32LE(0))
        }
        return data
    }

    static func parseDlSvcMsgByUid(_ data: Data) -> DlSvcMsgByUid? {
        var reader = Reader(data: data)
        do {
            let appid = try reader.readUInt16LE()
            let uid = try reader.readUInt32LE()
            let payload = try reader.readBytes32()
            let suid = try reader.readUInt32LE()
            _ = try reader.readUInt32LE()
            let seqId = try reader.readUInt32LE()
            _ = try reader.readUInt32LE()
            return DlSvcMsgByUid(appid: appid, uid: uid, payload: payload, suid: suid, seqId: seqId)
        } catch {
            return nil
        }
    }

    /// DlSvcMsgBySid: appid(u16)+topSid(u32)+msg(bytes16)
    static func parseDlSvcMsgBySid(_ data: Data) -> DlSvcMsgBySid? {
        var reader = Reader(data: data)
        do {
            let appid = try reader.readUInt16LE()
            let topSid = try reader.readUInt32LE()
            let payload = try reader.readBytes16()
            return DlSvcMsgBySid(appid: appid, topSid: topSid, payload: payload)
        } catch {
            return nil
        }
    }

    /// DlUsrGroupMsg: grpType(u64)+grpId(u64)+appid(u32)+msg(bytes32)+seqNum(u64)+srvId(u64)+ruri(u32)+subSvcName(str16)
    struct DlUsrGroupMsg {
        let appid: UInt32
        let msg: Data
        let ruri: UInt32
    }

    static func parseDlUsrGroupMsg(_ data: Data) -> DlUsrGroupMsg? {
        var reader = Reader(data: data)
        do {
            _ = try reader.readUInt64LE() // grpType
            _ = try reader.readUInt64LE() // grpId
            let appid = try reader.readUInt32LE()
            let msg = try reader.readBytes32()
            _ = try reader.readUInt64LE() // seqNum
            _ = try reader.readUInt64LE() // srvId
            let ruri = try reader.readUInt32LE()
            _ = try reader.readASCIIString16() // subSvcName
            return DlUsrGroupMsg(appid: appid, msg: msg, ruri: ruri)
        } catch {
            return nil
        }
    }

    static func buildSubServiceTypes(uri: UInt32, uid: UInt32, appids: [UInt32]) -> Data {
        var payload = Data()
        payload.append(encodeUInt32LE(uid))
        payload.append(encodeUInt32LE(0))
        payload.append(encodeUInt32LE(UInt32(appids.count)))
        for appid in appids {
            payload.append(encodeUInt32LE(appid))
        }
        return buildFrame(uri: uri, payload: payload)
    }

    // MARK: - Protobuf helpers

    struct ProtoField {
        let number: Int
        let wireType: Int
        let rawValue: Data
        let varintValue: UInt64?
    }

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

    static func encodeString(field: Int, value: String) -> Data {
        var data = Data()
        data.append(contentsOf: encodeVarint(UInt64((field << 3) | 2)))
        let utf8 = Data(value.utf8)
        data.append(contentsOf: encodeVarint(UInt64(utf8.count)))
        data.append(utf8)
        return data
    }

    static func encodeInt(field: Int, value: Int) -> Data {
        var data = Data()
        data.append(contentsOf: encodeVarint(UInt64((field << 3) | 0)))
        if value >= 0 {
            data.append(contentsOf: encodeVarint(UInt64(value)))
        } else {
            // protobuf int32/int64 negative values are encoded as two's-complement varint.
            data.append(contentsOf: encodeVarint(UInt64(bitPattern: Int64(value))))
        }
        return data
    }

    static func encodeUInt64(field: Int, value: UInt64) -> Data {
        var data = Data()
        data.append(contentsOf: encodeVarint(UInt64((field << 3) | 0)))
        data.append(contentsOf: encodeVarint(value))
        return data
    }

    static func encodeMessage(field: Int, value: Data) -> Data {
        var data = Data()
        data.append(contentsOf: encodeVarint(UInt64((field << 3) | 2)))
        data.append(contentsOf: encodeVarint(UInt64(value.count)))
        data.append(value)
        return data
    }

    static func parseProtobuf(_ data: Data) -> [ProtoField] {
        var fields: [ProtoField] = []
        var offset = 0

        while offset < data.count {
            guard let (tag, afterTag) = readVarint(data, offset: offset) else { break }
            offset = afterTag

            let wireType = Int(tag & 0x7)
            let fieldNumber = Int(tag >> 3)

            switch wireType {
            case 0:
                guard let (value, afterValue) = readVarint(data, offset: offset) else { return fields }
                let raw = data.subdata(in: offset..<afterValue)
                fields.append(ProtoField(number: fieldNumber, wireType: wireType, rawValue: raw, varintValue: value))
                offset = afterValue
            case 2:
                guard let (length, afterLength) = readVarint(data, offset: offset) else { return fields }
                offset = afterLength
                let intLength = Int(length)
                guard intLength >= 0, offset + intLength <= data.count else { return fields }
                let raw = data.subdata(in: offset..<(offset + intLength))
                fields.append(ProtoField(number: fieldNumber, wireType: wireType, rawValue: raw, varintValue: nil))
                offset += intLength
            case 5:
                guard offset + 4 <= data.count else { return fields }
                let raw = data.subdata(in: offset..<(offset + 4))
                fields.append(ProtoField(number: fieldNumber, wireType: wireType, rawValue: raw, varintValue: nil))
                offset += 4
            case 1:
                guard offset + 8 <= data.count else { return fields }
                let raw = data.subdata(in: offset..<(offset + 8))
                fields.append(ProtoField(number: fieldNumber, wireType: wireType, rawValue: raw, varintValue: nil))
                offset += 8
            default:
                return fields
            }
        }

        return fields
    }

    static func protobufFieldMap(_ data: Data) -> [Int: [ProtoField]] {
        var map: [Int: [ProtoField]] = [:]
        for field in parseProtobuf(data) {
            map[field.number, default: []].append(field)
        }
        return map
    }

    static func firstMessageField(_ data: Data, number: Int) -> Data? {
        protobufFieldMap(data)[number]?.first?.rawValue
    }

    static func firstStringField(_ data: Data, number: Int) -> String? {
        guard let raw = firstMessageField(data, number: number) else { return nil }
        return String(data: raw, encoding: .utf8)
    }

    static func firstVarintField(_ data: Data, number: Int) -> UInt64? {
        protobufFieldMap(data)[number]?.first?.varintValue
    }

    // backward-compatible helper (old callers)
    static func parseProtobufFields(_ data: Data) -> [Int: Data] {
        var result: [Int: Data] = [:]
        for (key, values) in protobufFieldMap(data) {
            if let first = values.first {
                result[key] = first.rawValue
            }
        }
        return result
    }

    static func parseString(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    // MARK: - Primitive encoding helpers

    static func encodeUInt8(_ value: UInt8) -> Data { Data([value]) }

    static func encodeUInt16LE(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func encodeUInt32LE(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func encodeUInt64LE(_ value: UInt64) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func encodeASCIIString16(_ value: String) -> Data {
        let bytes = Data(value.utf8)
        return encodeUInt16LE(UInt16(bytes.count)) + bytes
    }

    static func encodeBytes16(_ value: Data) -> Data {
        encodeUInt16LE(UInt16(value.count)) + value
    }

    static func encodeBytes32(_ value: Data) -> Data {
        encodeUInt32LE(UInt32(value.count)) + value
    }

    // MARK: - Raw reader

    struct Reader {
        private let data: Data
        private(set) var offset: Int = 0

        init(data: Data) {
            self.data = data
        }

        var isAtEnd: Bool { offset >= data.count }

        mutating func readUInt8() throws -> UInt8 {
            guard offset + 1 <= data.count else { throw ParseError.outOfRange }
            let value = data[offset]
            offset += 1
            return value
        }

        mutating func readUInt16LE() throws -> UInt16 {
            guard offset + 2 <= data.count else { throw ParseError.outOfRange }
            let value = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
            }
            offset += 2
            return value
        }

        mutating func readUInt32LE() throws -> UInt32 {
            guard offset + 4 <= data.count else { throw ParseError.outOfRange }
            let value = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
            }
            offset += 4
            return value
        }

        mutating func readUInt64LE() throws -> UInt64 {
            guard offset + 8 <= data.count else { throw ParseError.outOfRange }
            let value = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self).littleEndian
            }
            offset += 8
            return value
        }

        mutating func readBytes(count: Int) throws -> Data {
            guard count >= 0, offset + count <= data.count else { throw ParseError.outOfRange }
            let result = data.subdata(in: offset..<(offset + count))
            offset += count
            return result
        }

        mutating func readASCIIString16() throws -> String {
            let count = Int(try readUInt16LE())
            let bytes = try readBytes(count: count)
            return String(data: bytes, encoding: .ascii) ?? ""
        }

        mutating func readBytes16() throws -> Data {
            let count = Int(try readUInt16LE())
            return try readBytes(count: count)
        }

        mutating func readBytes32() throws -> Data {
            let count = Int(try readUInt32LE())
            return try readBytes(count: count)
        }
    }

    enum ParseError: Error {
        case outOfRange
    }

    // MARK: - Internal protobuf varint reader

    private static func readVarint(_ data: Data, offset: Int) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift = 0
        var cursor = offset

        while cursor < data.count {
            let byte = data[cursor]
            result |= UInt64(byte & 0x7F) << shift
            cursor += 1

            if (byte & 0x80) == 0 {
                return (result, cursor)
            }

            shift += 7
            if shift >= 64 { return nil }
        }

        return nil
    }
}
