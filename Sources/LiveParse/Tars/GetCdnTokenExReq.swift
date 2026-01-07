//
//  GetCdnTokenExReq.swift
//  LiveParse
//
//  Created by pc on 2025/1/7.
//

import Foundation
import TarsKit

public final class GetCdnTokenExReq: TarsStruct {

    public var sFlvUrl: String = ""
    public var sStreamName: String = ""
    public var iLoopTime: Int = 0
    public var tId: HuyaUserId = HuyaUserId()
    public var iAppId: Int = 66

    public func readFrom(_ inputStream: TarsInputStream) throws {
        sFlvUrl = try inputStream.read(&sFlvUrl, tag: 0, required: false)
        sStreamName = try inputStream.read(&sStreamName, tag: 1, required: false)
        iLoopTime = try inputStream.read(&iLoopTime, tag: 2, required: false)
        tId = try inputStream.read(&tId, tag: 3, required: false)
        iAppId = try inputStream.read(&iAppId, tag: 4, required: false)
    }

    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(sFlvUrl, tag: 0)
        try os.write(sStreamName, tag: 1)
        try os.write(iLoopTime, tag: 2)
        try os.write(tId, tag: 3)
        try os.write(iAppId, tag: 4)
    }

    public func deepCopy() -> GetCdnTokenExReq {
        let copy = GetCdnTokenExReq()
        copy.sFlvUrl = sFlvUrl
        copy.sStreamName = sStreamName
        copy.iLoopTime = iLoopTime
        copy.tId = tId.deepCopy()
        copy.iAppId = iAppId
        return copy
    }

    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayString(sFlvUrl, "sFlvUrl")
        ds.displayString(sStreamName, "sStreamName")
        ds.displayInt(iLoopTime, "iLoopTime")
        ds.displayInt(iAppId, "iAppId")
    }
}
