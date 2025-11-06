//
//  Data+Extension.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/11/23.
//

import Foundation
import zlib

extension Data {
    func _4BytesToInt() -> Int {
        var value: UInt32 = 0
        let data = NSData(bytes: [UInt8](self), length: self.count)
        data.getBytes(&value, length: self.count) // 把data以字节方式拷贝给value？
        value = UInt32(bigEndian: value)
        return Int(value)
    }
    
    func _2BytesToInt() -> Int {
        var value: UInt16 = 0
        let data = NSData(bytes: [UInt8](self), length: self.count)
        data.getBytes(&value, length: self.count) // 把data以字节方式拷贝给value？
        value = UInt16(bigEndian: value)
        return Int(value)
    }
    
    static func decompressGzipData(data: Data) -> Data? {
        // Guard empty input
        if data.isEmpty { return Data() }

        var stream = z_stream()

        let outputData: Data? = data.withUnsafeBytes { inputRawBuffer in
            guard let inputBase = inputRawBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return nil
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBase)
            stream.avail_in = UInt32(inputRawBuffer.count)

            // Initialize for gzip (16 + MAX_WBITS)
            let initStatus = inflateInit2_(&stream, MAX_WBITS + 16, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            if initStatus != Z_OK {
                return nil
            }
            defer { inflateEnd(&stream) }

            var output = Data()
            output.reserveCapacity(Swift.max(1024, data.count * 2))

            let bufferSize = 32 * 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)

            while true {
                let loopResult: Int = buffer.withUnsafeMutableBytes { outRawBuffer in
                    guard let outBase = outRawBuffer.bindMemory(to: Bytef.self).baseAddress else {
                        return -3 // memory error
                    }

                    stream.next_out = outBase
                    stream.avail_out = UInt32(bufferSize)

                    let status = inflate(&stream, Z_NO_FLUSH)
                    let produced = bufferSize - Int(stream.avail_out)
                    switch status {
                    case Z_STREAM_END:
                        if produced > 0 {
                            output.append(outBase, count: produced)
                        }
                        return -1 // done
                    case Z_OK:
                        if produced > 0 {
                            output.append(outBase, count: produced)
                        }
                        return produced // continue
                    default:
                        return -2 // error
                    }
                }

                if loopResult == -1 { // finished
                    break
                } else if loopResult == -2 || loopResult == -3 { // error
                    return nil
                }
                // otherwise continue looping
            }

            return output
        }

        return outputData
    }

}
