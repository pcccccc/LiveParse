//
//  GetCdnTokenResp.swift
//  LiveParse
//
//  Created by pc on 2024/12/9.
//

import Foundation
import TarsKit

class GetCdnTokenResp: TarsStruct {

    var url = ""
    var cdnType = ""
    var streamName = ""
    var presenterUid = 0
    var antiCode = ""
    var sTime = ""
    var flvAntiCode = ""
    var hlsAntiCode = ""
    
    func readFrom(_ inputStream: TarsInputStream) throws {
        url = try inputStream.read(&url, tag: 0, required: false);
        cdnType = try inputStream.read(&cdnType, tag: 1, required: false);
        streamName = try inputStream.read(&streamName, tag: 2, required: false);
        presenterUid = try inputStream.read(&presenterUid, tag: 3, required: false);
        antiCode = try inputStream.read(&antiCode, tag: 4, required: false);
        sTime = try inputStream.read(&sTime, tag: 5, required: false);
        flvAntiCode = try inputStream.read(&flvAntiCode, tag: 6, required: false);
        hlsAntiCode = try inputStream.read(&hlsAntiCode, tag: 7, required: false);
    }
    
    func writeTo(_ os: TarsOutputStream) throws {
        try os.write(url, tag: 0)
        try os.write(cdnType, tag: 1)
        try os.write(streamName, tag: 2)
        try os.write(presenterUid, tag: 3)
        try os.write(antiCode, tag: 4)
        try os.write(sTime, tag: 5)
        try os.write(flvAntiCode, tag: 6)
        try os.write(hlsAntiCode, tag: 7)
    }
    
    func deepCopy() -> Self {
        var copy = self
        copy.url = url
        copy.cdnType = cdnType
        copy.streamName = streamName
        copy.presenterUid = presenterUid
        copy.antiCode = antiCode
        copy.sTime = sTime
        copy.flvAntiCode = flvAntiCode
        copy.hlsAntiCode = hlsAntiCode
        return copy
    }
    
    func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayString(url, "url")
        ds.displayString(cdnType, "cdnType")
        ds.displayString(streamName, "streamName")
        ds.displayInt(presenterUid, "presenterUid")
        ds.displayString(antiCode, "antiCode")
        ds.displayString(sTime, "sTime")
        ds.displayString(flvAntiCode, "flvAntiCode")
        ds.displayString(hlsAntiCode, "hlsAntiCode")
    }
}
