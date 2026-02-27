//
//  YYSocketDataParser.swift
//
//
//  Created by Claude on 2026/02/27.
//

import Foundation

/// YY 弹幕 WebSocket 协议解析器（对齐 ws_danmaku.py）
public final class YYSocketDataParser: WebSocketDataParser {

    private enum URI {
        static let cliAPLoginAuthReq2: UInt32 = 779_268
        static let cliAPLoginAuthRes: UInt32 = 778_500
        static let cliAPLoginAuthRes2: UInt32 = 779_524
        static let anonymousLogin: UInt32 = 19_822
        static let anonymousLoginRes: UInt32 = 20_078
        static let loginAP: UInt32 = 775_684
        static let loginAPRes: UInt32 = 775_940
        static let pingAP: UInt32 = 794_116
        static let appPong: UInt32 = 794_372

        static let svcApRouterReq: UInt32 = 512_011
        static let svcApRouterRes: UInt32 = 512_267
        static let chlApRouterReq: UInt32 = 513_035
        static let chlApRouterRes: UInt32 = 513_291

        static let joinSvcUserGroupV2: UInt32 = 537_944
        static let leaveSvcUserGroupV2: UInt32 = 538_200
        static let subSvcTypesV2: UInt32 = 538_456
        static let dlUserGroupMsg: UInt32 = 533_080

        static let joinChannelReq: UInt32 = 2_048_258
        static let joinChannelRes: UInt32 = 2_048_514
        static let leaveChannelReq: UInt32 = 2_049_794
        static let channelInfoReq: UInt32 = 3_096_834
        static let chatCtrlReq: UInt32 = 3_143_682
        static let chatAuthReq: UInt32 = 3_655_682
        static let channelUserInfoReqA: UInt32 = 3_125_762
        static let channelUserInfoReqB: UInt32 = 3_126_274
        static let channelUserInfoReqC: UInt32 = 3_125_250
        static let channelMaixuReq: UInt32 = 3_854_338

        static let ulSvcMsgByUid: UInt32 = 79_960
        static let dlSvcMsgByUid: UInt32 = 80_216
        static let dlSvcMsgBySid: UInt32 = 28_760

        static let pHistoryChatReq: UInt32 = 3_117_144
        static let pHistoryChatRes: UInt32 = 3_117_400
        static let textChatMsgRes: UInt32 = 3_104_600
    }

    private enum AppID {
        static let apService: UInt32 = 259
        static let chatService: UInt16 = 31
        static let serviceAppids: [UInt32] = [15_068, 15_065, 15_067, 15_066]
    }

    struct ServiceGroup {
        let tLow: UInt32
        let tHigh: UInt32
        let idLow: UInt32
        let idHigh: UInt32
    }

    struct TextChatMessage {
        let fromUid: UInt32
        let topSid: UInt32
        let subSid: UInt32
        let nick: String
        let msg: String
    }

    private var uid: UInt32 = 0
    private var passport: String = ""
    private var password: String = ""
    private var cookie: Data = .init()
    private var wsUUID: String = ""
    private var topSid: UInt32 = 0
    private var subSid: UInt32 = 0
    private var tracePrefix: UInt32 = UInt32(Int.random(in: 10_000...99_999))
    private var traceCounter: UInt32 = UInt32(Int.random(in: 30...80))

    private var seenSet: Set<String> = []
    private var seenQueue: [String] = []
    private let seenLimit = 4_000

    func performHandshake(connection: WebSocketConnection) {
        resetRuntimeState(connection: connection)

        let roomId = connection.parameters?["roomId"] ?? ""
        topSid = UInt32(connection.parameters?["sid"] ?? roomId) ?? 0
        subSid = UInt32(connection.parameters?["ssid"] ?? roomId) ?? 0
        if subSid == 0 { subSid = topSid }

        wsUUID = connection.parameters?["ws_uuid"] ??
            connection.parameters?["uuid"] ??
            UUID().uuidString.replacingOccurrences(of: "-", with: "")

        guard topSid > 0, subSid > 0 else {
            print("❌ YY Danmaku: invalid sid/ssid roomId=\(roomId)")
            return
        }

        print("🔵 YY Danmaku: send anonymous login sid=\(topSid) ssid=\(subSid)")
        connection.socket?.write(data: buildAnonymousLoginRequest())
    }

    func parse(data: Data, connection: WebSocketConnection) {
        guard let (uri, payload) = YYBinaryProtocol.parseFrame(data) else { return }

        switch uri {
        case URI.cliAPLoginAuthRes, URI.cliAPLoginAuthRes2:
            handleLoginAuthResponse(payload, connection: connection)
        case URI.loginAPRes:
            handleAPLoginResponse(payload, connection: connection)
        case URI.appPong:
            return
        case URI.dlUserGroupMsg:
            handleDlUserGroupMsg(payload, connection: connection)
        case URI.dlSvcMsgByUid:
            handleDlSvcMsgByUid(payload, connection: connection)
        case URI.dlSvcMsgBySid:
            handleDlSvcMsgBySid(payload, connection: connection)
        case URI.svcApRouterReq, URI.svcApRouterRes, URI.chlApRouterReq, URI.chlApRouterRes:
            handleAPRouter(payload, connection: connection)
        default:
            break
        }
    }
}

private extension YYSocketDataParser {
    func resetRuntimeState(connection: WebSocketConnection) {
        uid = 0
        passport = ""
        password = ""
        cookie = .init()
        seenSet.removeAll(keepingCapacity: true)
        seenQueue.removeAll(keepingCapacity: true)

        connection.heartbeatTimer?.invalidate()
        connection.heartbeatTimer = nil
    }

    func nextTrace(uid: UInt32) -> String {
        traceCounter &+= 1
        return "F\(uid)_yymwebh5_\(tracePrefix)_\(traceCounter)"
    }

    func send(_ data: Data, connection: WebSocketConnection) {
        connection.socket?.write(data: data)
    }

    func startPingTimer(connection: WebSocketConnection) {
        connection.heartbeatTimer?.invalidate()
        connection.heartbeatTimer = Timer(timeInterval: 25, repeats: true) { [weak connection] _ in
            connection?.socket?.write(data: YYBinaryProtocol.buildFrame(uri: URI.pingAP, payload: YYBinaryProtocol.encodeUInt32LE(0)))
        }
        if let timer = connection.heartbeatTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

// MARK: - Login + Bootstrap
private extension YYSocketDataParser {
    func buildAnonymousLoginRequest() -> Data {
        var anonPayload = Data()
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16(""))
        anonPayload.append(YYBinaryProtocol.encodeUInt32LE(0))
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16("B8-97-5A-17-AD-4D"))
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16("B8-97-5A-17-AD-4D"))
        anonPayload.append(YYBinaryProtocol.encodeUInt32LE(0))
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16("yymwebh5"))

        var payload = Data()
        payload.append(YYBinaryProtocol.encodeASCIIString16(""))
        payload.append(YYBinaryProtocol.encodeUInt32LE(URI.anonymousLogin))
        payload.append(YYBinaryProtocol.encodeBytes32(anonPayload))
        return YYBinaryProtocol.buildFrame(uri: URI.cliAPLoginAuthReq2, payload: payload)
    }

    func buildPLoginAPRequest() -> Data {
        var authInfo = Data()
        authInfo.append(YYBinaryProtocol.encodeASCIIString16(passport))
        authInfo.append(YYBinaryProtocol.encodeASCIIString16(password))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeASCIIString16("yytianlaitv"))
        authInfo.append(YYBinaryProtocol.encodeASCIIString16("B8-97-5A-17-AD-4D"))
        authInfo.append(YYBinaryProtocol.encodeASCIIString16(""))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeUInt32LE(0))
        authInfo.append(YYBinaryProtocol.encodeASCIIString16(wsUUID))

        var payload = Data()
        payload.append(YYBinaryProtocol.encodeBytes32(authInfo))
        payload.append(YYBinaryProtocol.encodeUInt32LE(AppID.apService))
        payload.append(YYBinaryProtocol.encodeUInt32LE(uid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeUInt8(0))
        payload.append(YYBinaryProtocol.encodeBytes16(Data()))
        payload.append(YYBinaryProtocol.encodeBytes16(cookie))
        payload.append(YYBinaryProtocol.encodeASCIIString16("\(AppID.apService):0"))
        return YYBinaryProtocol.buildFrame(uri: URI.loginAP, payload: payload)
    }

    func handleLoginAuthResponse(_ payload: Data, connection: WebSocketConnection) {
        do {
            var reader = YYBinaryProtocol.Reader(data: payload)
            _ = try reader.readASCIIString16()
            _ = try reader.readUInt32LE()
            let ruri = try reader.readUInt32LE()
            let inner = try reader.readBytes32()
            guard ruri == URI.anonymousLoginRes else { return }

            var anon = YYBinaryProtocol.Reader(data: inner)
            _ = try anon.readASCIIString16()
            let resCode = try anon.readUInt32LE()
            guard resCode == 0 || resCode == 200 else {
                print("❌ YY Danmaku anonymous login failed: \(resCode)")
                return
            }

            uid = try anon.readUInt32LE()
            _ = try anon.readUInt32LE() // yyid
            passport = try anon.readASCIIString16()
            password = try anon.readASCIIString16()
            cookie = try anon.readBytes16()
            _ = try anon.readBytes16() // ticket

            print("✅ YY Danmaku anonymous login ok uid=\(uid), send PLoginAp")
            send(buildPLoginAPRequest(), connection: connection)
        } catch {
            print("❌ YY Danmaku parse anonymous login response failed: \(error)")
        }
    }

    func handleAPLoginResponse(_ payload: Data, connection: WebSocketConnection) {
        do {
            var reader = YYBinaryProtocol.Reader(data: payload)
            _ = try reader.readUInt32LE()
            let resCode = try reader.readUInt32LE()
            let context = try reader.readASCIIString16()
            _ = try reader.readUInt32LE()
            _ = try reader.readUInt16LE()
            _ = try reader.readUInt32LE()
            _ = try reader.readUInt32LE()

            guard resCode == 0 || resCode == 200 else {
                print("❌ YY Danmaku AP login failed resCode=\(resCode) context=\(context)")
                return
            }

            print("✅ YY Danmaku AP login ok context=\(context), bootstrap subscriptions")
            sendV2Sequence(connection: connection)
        } catch {
            print("❌ YY Danmaku parse AP login response failed: \(error)")
        }
    }

    func sendV2Sequence(connection: WebSocketConnection) {
        let fullGroups = defaultServiceGroups()
        let baseGroups = Array(fullGroups.prefix(2))

        send(buildSvcUserGroupV2(uri: URI.leaveSvcUserGroupV2, groups: fullGroups), connection: connection)
        send(buildSvcUserGroupV2(uri: URI.leaveSvcUserGroupV2, groups: baseGroups), connection: connection)

        for req in buildChannelBootstrapRequests() {
            send(req, connection: connection)
        }

        send(buildSvcUserGroupV2(uri: URI.joinSvcUserGroupV2, groups: fullGroups), connection: connection)
        send(buildSvcUserGroupV2(uri: URI.joinSvcUserGroupV2, groups: baseGroups), connection: connection)
        send(YYBinaryProtocol.buildSubServiceTypes(uri: URI.subSvcTypesV2, uid: uid, appids: AppID.serviceAppids), connection: connection)

        for group in type4ServiceGroups() {
            send(buildSvcUserGroupV2(uri: URI.joinSvcUserGroupV2, groups: [group]), connection: connection)
        }

        send(buildHistoryChatRouter(limit: 5), connection: connection)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) { [weak connection] in
            guard let connection else { return }
            connection.socket?.write(data: self.buildHistoryChatRouter(limit: 5))
        }

        startPingTimer(connection: connection)
    }

    func buildSvcUserGroupV2(uri: UInt32, groups: [ServiceGroup]) -> Data {
        var payload = Data()
        payload.append(YYBinaryProtocol.encodeUInt32LE(uid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeUInt32LE(UInt32(groups.count)))
        for group in groups {
            payload.append(YYBinaryProtocol.encodeUInt32LE(group.tLow))
            payload.append(YYBinaryProtocol.encodeUInt32LE(group.tHigh))
            payload.append(YYBinaryProtocol.encodeUInt32LE(group.idLow))
            payload.append(YYBinaryProtocol.encodeUInt32LE(group.idHigh))
        }
        payload.append(YYBinaryProtocol.encodeASCIIString16(""))
        return YYBinaryProtocol.buildFrame(uri: uri, payload: payload)
    }

    func buildChannelBootstrapRequests() -> [Data] {
        [
            buildChannelRouterReq(
                ruri: URI.leaveChannelReq,
                body: YYBinaryProtocol.encodeUInt32LE(uid) +
                    YYBinaryProtocol.encodeUInt32LE(topSid) +
                    YYBinaryProtocol.encodeUInt32LE(uid) +
                    YYBinaryProtocol.encodeUInt32LE(0),
                service: "channelAuther",
                withKey10000: true
            ),
            buildJoinChannelRouterReq(),
            buildChannelRouterReq(
                ruri: URI.channelInfoReq,
                body: Data([0, 0, 0]) + YYBinaryProtocol.encodeUInt32LE(topSid),
                service: "channelInfo",
                withKey10000: true
            ),
            buildChannelRouterReq(
                ruri: URI.chatCtrlReq,
                body: YYBinaryProtocol.encodeUInt32LE(topSid),
                service: "chatCtrl",
                withKey10000: true
            ),
            buildChannelRouterReq(
                ruri: URI.channelUserInfoReqA,
                body: YYBinaryProtocol.encodeUInt32LE(topSid) +
                    YYBinaryProtocol.encodeUInt32LE(1) +
                    YYBinaryProtocol.encodeUInt32LE(0) +
                    YYBinaryProtocol.encodeUInt32LE(0) +
                    YYBinaryProtocol.encodeUInt32LE(1) +
                    YYBinaryProtocol.encodeUInt32LE(0) +
                    YYBinaryProtocol.encodeUInt32LE(0),
                service: "channelUserInfo",
                withKey10000: true
            ),
            buildChannelRouterReq(
                ruri: URI.chatAuthReq,
                body: YYBinaryProtocol.encodeUInt32LE(topSid) +
                    YYBinaryProtocol.encodeUInt32LE(subSid) +
                    YYBinaryProtocol.encodeUInt32LE(uid) +
                    YYBinaryProtocol.encodeUInt32LE(uid) +
                    YYBinaryProtocol.encodeUInt32LE(0) +
                    YYBinaryProtocol.encodeUInt16LE(0),
                service: "chatCtrl",
                withKey10000: true
            ),
            buildChannelRouterReq(
                ruri: URI.channelUserInfoReqB,
                body: YYBinaryProtocol.encodeUInt32LE(topSid) +
                    YYBinaryProtocol.encodeUInt32LE(subSid) +
                    YYBinaryProtocol.encodeUInt32LE(2) +
                    YYBinaryProtocol.encodeUInt32LE(0),
                service: "channelUserInfo",
                withKey10000: true
            ),
            buildChannelRouterReq(
                ruri: URI.channelUserInfoReqC,
                body: YYBinaryProtocol.encodeUInt32LE(topSid) + YYBinaryProtocol.encodeUInt32LE(0),
                service: "channelUserInfo",
                withKey10000: true
            ),
            buildChannelRouterReq(
                ruri: URI.channelMaixuReq,
                body: YYBinaryProtocol.encodeUInt32LE(topSid) +
                    YYBinaryProtocol.encodeUInt32LE(subSid) +
                    YYBinaryProtocol.encodeUInt32LE(uid) +
                    YYBinaryProtocol.encodeUInt32LE(uid) +
                    YYBinaryProtocol.encodeUInt32LE(0),
                service: "channelMaixu",
                withKey10000: true
            )
        ]
    }

    func buildJoinChannelRouterReq() -> Data {
        let body = YYBinaryProtocol.encodeUInt32LE(uid) +
            YYBinaryProtocol.encodeUInt32LE(topSid) +
            YYBinaryProtocol.encodeUInt32LE(subSid) +
            YYBinaryProtocol.encodeUInt32LE(0) +
            YYBinaryProtocol.encodeUInt32LE(uid) +
            YYBinaryProtocol.encodeUInt32LE(0)

        let headers = YYBinaryProtocol.buildAPRouterHeaders(
            realUri: URI.joinChannelReq,
            appid: AppID.apService,
            uid: uid,
            serviceName: "channelAuther",
            extentProps: [
                1: YYBinaryProtocol.encodeUInt32LE(topSid),
                103: Data(nextTrace(uid: uid).utf8)
            ],
            clientCtx: ""
        )
        return YYBinaryProtocol.buildAPRouterFrame(
            outerURI: URI.chlApRouterReq,
            ruri: URI.joinChannelReq,
            body: body,
            headers: headers
        )
    }

    func buildChannelRouterReq(ruri: UInt32, body: Data, service: String, withKey10000: Bool) -> Data {
        var props: [UInt32: Data] = [
            1: YYBinaryProtocol.encodeUInt32LE(topSid),
            103: Data(nextTrace(uid: uid).utf8)
        ]
        if withKey10000 {
            props[10_000] = YYBinaryProtocol.encodeUInt32LE(topSid)
        }

        let headers = YYBinaryProtocol.buildAPRouterHeaders(
            realUri: ruri,
            appid: AppID.apService,
            uid: uid,
            serviceName: service,
            extentProps: props,
            clientCtx: ""
        )
        return YYBinaryProtocol.buildAPRouterFrame(
            outerURI: URI.chlApRouterReq,
            ruri: ruri,
            body: body,
            headers: headers
        )
    }

    func buildHistoryChatRouter(limit: UInt32) -> Data {
        let historyReq = buildHistoryChatRequest(limit: limit)
        let ulSvc = YYBinaryProtocol.buildUlSvcMsgByUid(
            appid: AppID.chatService,
            topSid: topSid,
            uid: uid,
            payload: historyReq,
            statType: UInt8(truncatingIfNeeded: AppID.chatService),
            subSid: subSid,
            ext: [7: ""],
            appendH5Tail: true
        )
        let headers = YYBinaryProtocol.buildAPRouterHeaders(
            realUri: URI.ulSvcMsgByUid,
            appid: AppID.apService,
            uid: uid,
            serviceName: "",
            extentProps: [103: Data(nextTrace(uid: uid).utf8)],
            clientCtx: ""
        )
        return YYBinaryProtocol.buildAPRouterFrame(
            outerURI: URI.svcApRouterReq,
            ruri: URI.ulSvcMsgByUid,
            body: ulSvc,
            headers: headers
        )
    }

    func buildHistoryChatRequest(limit: UInt32) -> Data {
        var payload = Data()
        payload.append(YYBinaryProtocol.encodeUInt32LE(topSid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(subSid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(uid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(uid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeUInt32LE(limit))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeASCIIString16(""))
        return YYBinaryProtocol.buildFrame(uri: URI.pHistoryChatReq, payload: payload)
    }

    func defaultServiceGroups() -> [ServiceGroup] {
        [
            ServiceGroup(tLow: 1, tHigh: 0, idLow: topSid, idHigh: 0),
            ServiceGroup(tLow: 2, tHigh: 0, idLow: subSid, idHigh: 0),
            ServiceGroup(tLow: 1_024, tHigh: AppID.apService, idLow: topSid, idHigh: subSid),
            ServiceGroup(tLow: 768, tHigh: AppID.apService, idLow: 0, idHigh: subSid),
            ServiceGroup(tLow: 256, tHigh: AppID.apService, idLow: 0, idHigh: subSid),
            ServiceGroup(tLow: 256, tHigh: AppID.apService, idLow: topSid, idHigh: subSid)
        ]
    }

    func type4ServiceGroups() -> [ServiceGroup] {
        let s1: UInt32 = 1 << 16
        let s19: UInt32 = 19 << 16
        return [
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 1, idHigh: s1),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 1, idHigh: s19),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 1, idHigh: s1 | 1),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 1, idHigh: s19 | 1),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 4, idHigh: s1),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 4, idHigh: s19),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 4, idHigh: s1 | 1),
            ServiceGroup(tLow: 4, tHigh: 0, idLow: 4, idHigh: s19 | 1)
        ]
    }
}

// MARK: - Message Parsing
private extension YYSocketDataParser {
    func handleAPRouter(_ payload: Data, connection: WebSocketConnection) {
        guard let router = YYBinaryProtocol.parseAPRouter(payload) else { return }
        switch router.ruri {
        case URI.dlSvcMsgByUid:
            handleDlSvcMsgByUid(router.body, connection: connection)
        case URI.dlSvcMsgBySid:
            handleDlSvcMsgBySid(router.body, connection: connection)
        case URI.pHistoryChatRes:
            emitHistoryChat(payload: router.body, connection: connection)
        case URI.joinChannelRes:
            print("✅ YY Danmaku JoinChannelRes received")
        default:
            handleServiceFrameBuffer(router.body, connection: connection)
        }
    }

    func handleDlUserGroupMsg(_ payload: Data, connection: WebSocketConnection) {
        if let group = YYBinaryProtocol.parseDlUsrGroupMsg(payload) {
            if group.ruri == URI.dlSvcMsgByUid {
                handleDlSvcMsgByUid(group.msg, connection: connection)
                return
            }
            if group.ruri == URI.dlSvcMsgBySid {
                handleDlSvcMsgBySid(group.msg, connection: connection)
                return
            }
            if let (_, framedPayload) = findFramedPacket(in: group.msg, targetURI: URI.textChatMsgRes),
               let chat = parseTextChatMsg(framedPayload)
            {
                emit(chat, connection: connection)
                return
            }
        }

        if let (_, framedPayload) = findFramedPacket(in: payload, targetURI: URI.textChatMsgRes),
           let chat = parseTextChatMsg(framedPayload)
        {
            emit(chat, connection: connection)
        }
    }

    func handleDlSvcMsgByUid(_ payload: Data, connection: WebSocketConnection) {
        guard let dl = YYBinaryProtocol.parseDlSvcMsgByUid(payload) else { return }
        handleServiceFrameBuffer(dl.payload, connection: connection)
    }

    func handleDlSvcMsgBySid(_ payload: Data, connection: WebSocketConnection) {
        guard let dl = YYBinaryProtocol.parseDlSvcMsgBySid(payload) else { return }
        handleServiceFrameBuffer(dl.payload, connection: connection)
    }

    func handleServiceFrameBuffer(_ buffer: Data, connection: WebSocketConnection) {
        if let (innerURI, innerPayload, _) = parseFrameHeaderAtStart(buffer) {
            handleInnerFrame(uri: innerURI, payload: innerPayload, connection: connection)
            return
        }

        if let (_, payload) = findFramedPacket(in: buffer, targetURI: URI.pHistoryChatRes) {
            emitHistoryChat(payload: payload, connection: connection)
            return
        }

        if let (_, payload) = findFramedPacket(in: buffer, targetURI: URI.textChatMsgRes),
           let chat = parseTextChatMsg(payload)
        {
            emit(chat, connection: connection)
        }
    }

    func handleInnerFrame(uri: UInt32, payload: Data, connection: WebSocketConnection) {
        switch uri {
        case URI.pHistoryChatRes:
            emitHistoryChat(payload: payload, connection: connection)
        case URI.textChatMsgRes:
            if let chat = parseTextChatMsg(payload) {
                emit(chat, connection: connection)
            }
        case URI.dlSvcMsgByUid:
            handleDlSvcMsgByUid(payload, connection: connection)
        case URI.dlSvcMsgBySid:
            handleDlSvcMsgBySid(payload, connection: connection)
        default:
            break
        }
    }

    func emitHistoryChat(payload: Data, connection: WebSocketConnection) {
        let items = parseHistoryChatResponse(payload)
        for item in items {
            emit(item, connection: connection)
        }
    }

    func emit(_ chat: TextChatMessage, connection: WebSocketConnection) {
        let content = extractChatText(from: chat.msg).trimmingCharacters(in: .whitespacesAndNewlines)
        let nick = chat.nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let key = "\(chat.fromUid)|\(chat.topSid)|\(chat.subSid)|\(nick)|\(content)"
        guard !seenSet.contains(key) else { return }
        seenSet.insert(key)
        seenQueue.append(key)
        if seenQueue.count > seenLimit {
            let stale = seenQueue.removeFirst()
            seenSet.remove(stale)
        }

        connection.delegate?.webSocketDidReceiveMessage(
            text: content,
            nickname: nick.isEmpty ? "YY用户" : nick,
            color: 0xFFFFFF
        )
    }
}

// MARK: - Binary Parsing Helpers
private extension YYSocketDataParser {
    func parseHistoryChatResponse(_ payload: Data) -> [TextChatMessage] {
        var reader = BinaryReader(data: payload)
        do {
            _ = try reader.readUInt32LE()
            _ = try reader.readUInt32LE()
            _ = try reader.readUInt32LE()
            let count = Int(try reader.readUInt32LE())

            var items: [TextChatMessage] = []
            items.reserveCapacity(max(count, 0))

            for _ in 0..<max(count, 0) {
                let entry = try reader.readBytes16()
                guard let (innerURI, innerPayload, _) = parseFrameHeaderAtStart(entry) else { continue }
                guard innerURI == URI.textChatMsgRes else { continue }
                if let chat = parseTextChatMsg(innerPayload) {
                    items.append(chat)
                }
            }
            return items
        } catch {
            return []
        }
    }

    func parseTextChatMsg(_ payload: Data) -> TextChatMessage? {
        var reader = BinaryReader(data: payload)
        do {
            let fromUid = try reader.readUInt32LE()
            let topSid = try reader.readUInt32LE()
            let subSid = try reader.readUInt32LE()
            _ = try reader.readUInt16LE()
            _ = try reader.readUInt32LE()
            _ = try reader.readUTF8String32()
            _ = try reader.readUInt32LE()
            _ = try reader.readUInt32LE()
            let msg = try reader.readUTF16LEString32()
            _ = try reader.readUInt32LE()
            _ = try reader.readASCIIString16()
            _ = try reader.readASCIIString16()
            let nick = try reader.readUTF8String16()

            let extraCount = Int(try reader.readUInt32LE())
            if extraCount > 0 {
                for _ in 0..<extraCount {
                    _ = try reader.readUInt16LE()
                    _ = try reader.readASCIIString16()
                }
            }

            return TextChatMessage(fromUid: fromUid, topSid: topSid, subSid: subSid, nick: nick, msg: msg)
        } catch {
            return nil
        }
    }

    func extractChatText(from raw: String) -> String {
        let ns = raw as NSString
        let range = NSRange(location: 0, length: ns.length)
        let pattern = #"data="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: raw, options: [], range: range),
              match.numberOfRanges > 1
        else {
            return raw
        }
        return ns.substring(with: match.range(at: 1))
    }

    func parseFrameHeaderAtStart(_ data: Data) -> (uri: UInt32, payload: Data, totalLen: Int)? {
        guard data.count >= 10 else { return nil }
        let totalLen = Int(readUInt32LE(data, offset: 0))
        guard totalLen >= 10, totalLen <= data.count else { return nil }
        let uri = readUInt32LE(data, offset: 4)
        let magic = readUInt16LE(data, offset: 8)
        guard magic == 200 else { return nil }
        return (uri, data.subdata(in: 10..<totalLen), totalLen)
    }

    func findFramedPacket(in data: Data, targetURI: UInt32 = 0) -> (uri: UInt32, payload: Data)? {
        guard data.count >= 10 else { return nil }
        for idx in 0...(data.count - 10) {
            let totalLen = Int(readUInt32LE(data, offset: idx))
            guard totalLen >= 10, idx + totalLen <= data.count else { continue }

            let uri = readUInt32LE(data, offset: idx + 4)
            let magic = readUInt16LE(data, offset: idx + 8)
            guard magic == 200 else { continue }
            if targetURI != 0, uri != targetURI { continue }

            let payloadStart = idx + 10
            let payloadEnd = idx + totalLen
            return (uri, data.subdata(in: payloadStart..<payloadEnd))
        }
        return nil
    }

    func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian }
    }

    func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
    }
}

private struct BinaryReader {
    enum ParseError: Error {
        case outOfRange
    }

    private let data: Data
    private(set) var offset: Int = 0

    init(data: Data) {
        self.data = data
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

    mutating func readBytes(count: Int) throws -> Data {
        guard count >= 0, offset + count <= data.count else { throw ParseError.outOfRange }
        let value = data.subdata(in: offset..<(offset + count))
        offset += count
        return value
    }

    mutating func readBytes16() throws -> Data {
        let length = Int(try readUInt16LE())
        return try readBytes(count: length)
    }

    mutating func readASCIIString16() throws -> String {
        let bytes = try readBytes16()
        return String(data: bytes, encoding: .ascii) ?? ""
    }

    mutating func readUTF8String16() throws -> String {
        let bytes = try readBytes16()
        return String(data: bytes, encoding: .utf8) ?? ""
    }

    mutating func readUTF8String32() throws -> String {
        let length = Int(try readUInt32LE())
        let bytes = try readBytes(count: length)
        return String(data: bytes, encoding: .utf8) ?? ""
    }

    mutating func readUTF16LEString32() throws -> String {
        let length = Int(try readUInt32LE())
        let bytes = try readBytes(count: length)
        return String(data: bytes, encoding: .utf16LittleEndian) ?? ""
    }
}
