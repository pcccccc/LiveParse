//
//  GetCdnTokenReq.swift
//  LiveParse
//
//  Created by pc on 2024/12/9.
//

import Foundation
import TarsKit

public class GetCdnTokenReq: TarsStruct {
    
    public var url = ""
    public var cdnType = ""
    public var streamName = ""
    public var presenterUid = 0

    public func readFrom(_ inputStream: TarsInputStream) throws {
        url = try inputStream.read(&url, tag: 0, required: false)
        cdnType = try inputStream.read(&cdnType, tag: 1, required: false)
        streamName = try inputStream.read(&streamName, tag: 2, required: false)
        presenterUid = try inputStream.read(&presenterUid, tag: 3, required: false)
    }
    
    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(url, tag: 0)
        try os.write(cdnType, tag: 1)
        try os.write(streamName, tag: 2)
        try os.write(presenterUid, tag: 3)
    }
    
    public func deepCopy() -> Self {
        var copy = self
        copy.url = url
        copy.cdnType = cdnType
        copy.streamName = streamName
        copy.presenterUid = presenterUid
        return copy
    }
    
    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayString("url", url)
        ds.displayString("cdnType", cdnType)
        ds.displayString("streamName", streamName)
        ds.displayInt(presenterUid, "presenterUid")
    }
}
