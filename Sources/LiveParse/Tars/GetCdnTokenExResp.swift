//
//  GetCdnTokenExResp.swift
//  LiveParse
//
//  Created by pc on 2025/1/7.
//

import Foundation
import TarsKit

public final class GetCdnTokenExResp: TarsStruct {

    public var sFlvToken: String = ""
    public var iExpireTime: Int = 0

    public func readFrom(_ inputStream: TarsInputStream) throws {
        sFlvToken = try inputStream.read(&sFlvToken, tag: 0, required: false)
        iExpireTime = try inputStream.read(&iExpireTime, tag: 1, required: false)
    }

    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(sFlvToken, tag: 0)
        try os.write(iExpireTime, tag: 1)
    }

    public func deepCopy() -> GetCdnTokenExResp {
        let copy = GetCdnTokenExResp()
        copy.sFlvToken = sFlvToken
        copy.iExpireTime = iExpireTime
        return copy
    }

    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayString(sFlvToken, "sFlvToken")
        ds.displayInt(iExpireTime, "iExpireTime")
    }
}
