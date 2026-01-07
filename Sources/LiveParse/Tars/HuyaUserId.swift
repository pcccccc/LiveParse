//
//  HuyaUserId.swift
//  LiveParse
//
//  Created by pc on 2025/1/7.
//

import Foundation
import TarsKit

public final class HuyaUserId: TarsStruct {

    public var lUid: Int = 0
    public var sGuid: String = ""
    public var sToken: String = ""
    public var sHuYaUA: String = ""
    public var sCookie: String = ""
    public var iTokenType: Int = 0
    public var sDeviceInfo: String = ""
    public var sQIMEI: String = ""

    public func readFrom(_ inputStream: TarsInputStream) throws {
        lUid = try inputStream.read(&lUid, tag: 0, required: false)
        sGuid = try inputStream.read(&sGuid, tag: 1, required: false)
        sToken = try inputStream.read(&sToken, tag: 2, required: false)
        sHuYaUA = try inputStream.read(&sHuYaUA, tag: 3, required: false)
        sCookie = try inputStream.read(&sCookie, tag: 4, required: false)
        iTokenType = try inputStream.read(&iTokenType, tag: 5, required: false)
        sDeviceInfo = try inputStream.read(&sDeviceInfo, tag: 6, required: false)
        sQIMEI = try inputStream.read(&sQIMEI, tag: 7, required: false)
    }

    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(lUid, tag: 0)
        try os.write(sGuid, tag: 1)
        try os.write(sToken, tag: 2)
        try os.write(sHuYaUA, tag: 3)
        try os.write(sCookie, tag: 4)
        try os.write(iTokenType, tag: 5)
        try os.write(sDeviceInfo, tag: 6)
        try os.write(sQIMEI, tag: 7)
    }

    public func deepCopy() -> HuyaUserId {
        let copy = HuyaUserId()
        copy.lUid = lUid
        copy.sGuid = sGuid
        copy.sToken = sToken
        copy.sHuYaUA = sHuYaUA
        copy.sCookie = sCookie
        copy.iTokenType = iTokenType
        copy.sDeviceInfo = sDeviceInfo
        copy.sQIMEI = sQIMEI
        return copy
    }

    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayInt(lUid, "lUid")
        ds.displayString(sGuid, "sGuid")
        ds.displayString(sToken, "sToken")
        ds.displayString(sHuYaUA, "sHuYaUA")
        ds.displayString(sCookie, "sCookie")
        ds.displayInt(iTokenType, "iTokenType")
        ds.displayString(sDeviceInfo, "sDeviceInfo")
        ds.displayString(sQIMEI, "sQIMEI")
    }
}
