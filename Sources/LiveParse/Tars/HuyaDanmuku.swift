//
//  HuyaDanmuku.swift
//  LiveParse
//
//  Created by pc on 2025/5/12.
//

import Foundation
import TarsKit

public class HYPushMessage: TarsStruct {
    public var pushType = 0
    public var uri = 0
    public var msg = [UInt8]()
    public var protocolType = 0
    
    public func readFrom(_ inputStream: TarsInputStream) throws {
        pushType = try inputStream.read(&pushType, tag: 0, required: false)
        uri = try inputStream.read(&uri, tag: 1, required: false)
        msg = try inputStream.read(&msg, tag: 2, required: false)
        protocolType = try inputStream.read(&protocolType, tag: 3, required: false)
    }
    
    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(pushType, tag: 0)
        try os.write(uri, tag: 1)
        try os.write(msg, tag: 2)
        try os.write(protocolType, tag: 3)
    }
    
    public func deepCopy() -> Self {
        let copy = self
        copy.pushType = pushType
        copy.uri = uri
        copy.msg = msg
        copy.protocolType = protocolType
        return copy
    }
    
    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayInt(pushType, "pushType")
        ds.displayInt(uri, "uri")
        ds.displayString("\(msg)", "msg")
        ds.displayInt(protocolType, "protocolType")
    }
}

public class HYSender: TarsStruct {
    public var uid = 0
    public var lMid = 0
    public var nickName = ""
    public var gender = 0
    
    public func readFrom(_ inputStream: TarsInputStream) throws {
        uid = try inputStream.read(&uid, tag: 0, required: false)
        lMid = try inputStream.read(&lMid, tag: 1, required: false)
        nickName = try inputStream.read(&nickName, tag: 2, required: false)
        gender = try inputStream.read(&gender, tag: 3, required: false)
    }
    
    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(uid, tag: 0)
        try os.write(lMid, tag: 1)
        try os.write(nickName, tag: 2)
        try os.write(gender, tag: 3)
    }
    
    public func deepCopy() -> Self {
        let copy = self
        copy.uid = uid
        copy.lMid = lMid
        copy.nickName = nickName
        copy.gender = gender
        return copy
    }
    
    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayInt(uid, "uid")
        ds.displayInt(lMid, "lMid")
        ds.displayString(nickName, "nickName")
        ds.displayInt(gender, "gender")
    }
}
    
public class HYMessage: TarsStruct {
    public var userInfo = HYSender()
    public var content = ""
    public var bulletFormat = HYBulletFormat()
    
    public func readFrom(_ inputStream: TarsInputStream) throws {
        userInfo = try inputStream.read(&userInfo, tag: 0, required: false)
        content = try inputStream.read(&content, tag: 3, required: false)
        bulletFormat = try inputStream.read(&bulletFormat, tag: 6, required: false)
    }
    
    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(userInfo, tag: 0)
        try os.write(content, tag: 3)
        try os.write(bulletFormat, tag: 6)
    }
    
    public func deepCopy() -> Self {
        let copy = self
        copy.userInfo = userInfo
        copy.content = content
        copy.bulletFormat = bulletFormat
        return copy
    }
    
    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayString("\(userInfo)", "userInfo")
        ds.displayString(content, "content")
        ds.displayString("\(bulletFormat)", "bulletFormat")
    }
}

public class HYBulletFormat: TarsStruct {
    public var fontColor = 0
    public var fontSize = 4
    public var textSpeed = 0
    public var transitionType = 1
    
    public func readFrom(_ inputStream: TarsInputStream) throws {
        fontColor = try inputStream.read(&fontColor, tag: 0, required: false)
        fontSize = try inputStream.read(&fontSize, tag: 1, required: false)
        textSpeed = try inputStream.read(&textSpeed, tag: 2, required: false)
        transitionType = try inputStream.read(&transitionType, tag: 3, required: false)
    }
    
    public func writeTo(_ os: TarsOutputStream) throws {
        try os.write(fontColor, tag: 0)
        try os.write(fontSize, tag: 1)
        try os.write(textSpeed, tag: 2)
        try os.write(transitionType, tag: 3)
    }
    
    public func deepCopy() -> Self {
        let copy = self
        copy.fontColor = fontColor
        copy.fontSize = fontSize
        copy.textSpeed = textSpeed
        copy.transitionType = transitionType
        return copy
    }
    
    public func displayAsString(_ buffer: inout String, level: Int) {
        let ds = TarsDisplayer(buffer, level: level)
        ds.displayInt(fontColor, "fontColor")
        ds.displayInt(fontSize, "fontSize")
        ds.displayInt(textSpeed, "textSpeed")
        ds.displayInt(transitionType, "transitionType")
    }
}
