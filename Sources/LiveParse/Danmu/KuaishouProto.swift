//
//  KuaishouProto.swift
//  LiveParse
//
//  Created by Claude on 2026/02/26.
//

import Foundation
import SwiftProtobuf

/// 快手直播弹幕 Protobuf 消息定义
/// 参考：kuaishou_analysis/README.md

// MARK: - 用户信息
struct Kuaishou_SimpleUserInfo: SwiftProtobuf.Message, Equatable {
    static let protoMessageName: String = "kuaishou.SimpleUserInfo"

    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "principalId"),
        2: .same(proto: "userName"),
        3: .same(proto: "headUrl"),
        4: .same(proto: "mystery"),
        5: .same(proto: "desc"),
    ]

    var principalId: String = ""  // 用户ID
    var userName: String = ""     // 用户名
    var headUrl: String = ""      // 头像
    var mystery: Bool = false
    var desc: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.principalId)
            case 2: try decoder.decodeSingularStringField(value: &self.userName)
            case 3: try decoder.decodeSingularStringField(value: &self.headUrl)
            case 4: try decoder.decodeSingularBoolField(value: &self.mystery)
            case 5: try decoder.decodeSingularStringField(value: &self.desc)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.principalId.isEmpty {
            try visitor.visitSingularStringField(value: self.principalId, fieldNumber: 1)
        }
        if !self.userName.isEmpty {
            try visitor.visitSingularStringField(value: self.userName, fieldNumber: 2)
        }
        if !self.headUrl.isEmpty {
            try visitor.visitSingularStringField(value: self.headUrl, fieldNumber: 3)
        }
        if self.mystery {
            try visitor.visitSingularBoolField(value: self.mystery, fieldNumber: 4)
        }
        if !self.desc.isEmpty {
            try visitor.visitSingularStringField(value: self.desc, fieldNumber: 5)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? Kuaishou_SimpleUserInfo else { return false }
        return self == other
    }

    static func ==(lhs: Kuaishou_SimpleUserInfo, rhs: Kuaishou_SimpleUserInfo) -> Bool {
        if lhs.principalId != rhs.principalId { return false }
        if lhs.userName != rhs.userName { return false }
        if lhs.headUrl != rhs.headUrl { return false }
        if lhs.mystery != rhs.mystery { return false }
        if lhs.desc != rhs.desc { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

// MARK: - 弹幕评论
struct Kuaishou_WebCommentFeed: SwiftProtobuf.Message, Equatable {
    static let protoMessageName: String = "kuaishou.WebCommentFeed"

    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "id"),
        2: .same(proto: "user"),
        3: .same(proto: "content"),
        4: .same(proto: "deviceHash"),
        5: .same(proto: "sortRank"),
        6: .same(proto: "color"),
        7: .same(proto: "showType"),
        8: .same(proto: "senderState"),
        9: .same(proto: "time"),
    ]

    var id: String = ""
    var user: Kuaishou_SimpleUserInfo?
    var content: String = ""      // 弹幕内容
    var deviceHash: String = ""
    var sortRank: UInt64 = 0
    var color: String = ""        // 弹幕颜色
    var showType: UInt32 = 0
    var senderState: UInt32 = 0
    var time: UInt64 = 0          // 发送时间（毫秒时间戳）
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.id)
            case 2: try decoder.decodeSingularMessageField(value: &self.user)
            case 3: try decoder.decodeSingularStringField(value: &self.content)
            case 4: try decoder.decodeSingularStringField(value: &self.deviceHash)
            case 5: try decoder.decodeSingularUInt64Field(value: &self.sortRank)
            case 6: try decoder.decodeSingularStringField(value: &self.color)
            case 7: try decoder.decodeSingularUInt32Field(value: &self.showType)
            case 8: try decoder.decodeSingularUInt32Field(value: &self.senderState)
            case 9: try decoder.decodeSingularUInt64Field(value: &self.time)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.id.isEmpty {
            try visitor.visitSingularStringField(value: self.id, fieldNumber: 1)
        }
        if let user = self.user {
            try visitor.visitSingularMessageField(value: user, fieldNumber: 2)
        }
        if !self.content.isEmpty {
            try visitor.visitSingularStringField(value: self.content, fieldNumber: 3)
        }
        if !self.deviceHash.isEmpty {
            try visitor.visitSingularStringField(value: self.deviceHash, fieldNumber: 4)
        }
        if self.sortRank != 0 {
            try visitor.visitSingularUInt64Field(value: self.sortRank, fieldNumber: 5)
        }
        if !self.color.isEmpty {
            try visitor.visitSingularStringField(value: self.color, fieldNumber: 6)
        }
        if self.showType != 0 {
            try visitor.visitSingularUInt32Field(value: self.showType, fieldNumber: 7)
        }
        if self.senderState != 0 {
            try visitor.visitSingularUInt32Field(value: self.senderState, fieldNumber: 8)
        }
        if self.time != 0 {
            try visitor.visitSingularUInt64Field(value: self.time, fieldNumber: 9)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    func isEqualTo(message: any SwiftProtobuf.Message) -> Bool {
        guard let other = message as? Kuaishou_WebCommentFeed else { return false }
        return self == other
    }

    static func ==(lhs: Kuaishou_WebCommentFeed, rhs: Kuaishou_WebCommentFeed) -> Bool {
        if lhs.id != rhs.id { return false }
        if lhs.user != rhs.user { return false }
        if lhs.content != rhs.content { return false }
        if lhs.deviceHash != rhs.deviceHash { return false }
        if lhs.sortRank != rhs.sortRank { return false }
        if lhs.color != rhs.color { return false }
        if lhs.showType != rhs.showType { return false }
        if lhs.senderState != rhs.senderState { return false }
        if lhs.time != rhs.time { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
