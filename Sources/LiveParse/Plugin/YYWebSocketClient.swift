import Foundation
import Compression
import Starscream

/// YY 平台 WebSocket 客户端 - 获取播放地址（仅 WS，不回退 HTTP）
final class YYWebSocketClient: NSObject, @unchecked Sendable {

    private enum URI {
        static let cliAPLoginAuthReq2: UInt32 = 779_268
        static let cliAPLoginAuthRes: UInt32 = 778_500
        static let cliAPLoginAuthRes2: UInt32 = 779_524
        static let anonymousLoginRes: UInt32 = 20_078
        static let loginAP: UInt32 = 775_684
        static let loginAPRes: UInt32 = 775_940
        static let appPong: UInt32 = 794_372

        static let papRouterReq: UInt32 = 512_011
        static let papRouterRes: UInt32 = 512_267

        static let pSubServiceTypes: UInt32 = 538_456
        static let dlUsrGroupMsg: UInt32 = 533_080
        static let dlSvcMsgBySid: UInt32 = 28_760
        static let ulSvcMsgByUid: UInt32 = 79_960
        static let dlSvcMsgByUid: UInt32 = 80_216
    }

    private enum AppID {
        // h5-sinchl 通道下，AP 登录与 APRouter 头 appid 需使用 259
        static let apService: UInt32 = 259
        // 当前网页链路订阅 appids
        static let appidA: UInt32 = 15_068
        static let appidB: UInt32 = 15_065
        static let streamUpdateService: UInt16 = 15_066
        static let streamLineService: UInt16 = 15_067
        static let appidD: UInt32 = 15_066
        static let mediaAppidStr = "15013"
    }

    private enum State {
        case connecting
        case waitingLogin
        case waitingAPLogin
        case waitingStreams
        case waitingGearLine
        case completed([String: Any])
        case failed(Error)
    }

    private struct YYStreamCandidate {
        let index: Int
        let streamKey: String
        let ver: UInt64
        let lineSeq: Int
        let gear: Int
        let stage: String
        let mixToken: String
        let isVideo: Bool
        let isAudio: Bool
        let score: Int
    }

    private struct YYGearStreamKeyInfo {
        let streamKey: String
        let ver: UInt64
        let stage: String
        let mixToken: String
        let rStreamKey: String?
        let rVer: UInt64?
        let rStage: String?
        let rMixToken: String?
    }

    private var socket: WebSocket?
    private var continuation: CheckedContinuation<[String: Any], Error>?
    private let roomId: String
    private let requestedLineSeq: Int?
    private let requestedGear: Int?
    private let queue: DispatchQueue

    private var timeoutWorkItem: DispatchWorkItem?
    private let timeoutSeconds: TimeInterval = 15

    private var wsUUID: String = ""
    private var yyUID: UInt32 = 0
    private var yyPassport: String = ""
    private var yyPassword: String = ""
    private var yyCookie: Data = .init()

    private var seqCounter: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)
    private var tracePrefix: UInt32 = UInt32(Int.random(in: 10_000...99_999))
    private var traceCounter: UInt32 = UInt32(Int.random(in: 30...80))
    private var state: State = .connecting
    private var streamInfo: [String: Any] = [:]

    private var roomSid: UInt32 {
        UInt32(roomId) ?? 0
    }

    init(roomId: String, requestedLineSeq: Int? = nil, requestedGear: Int? = nil) {
        self.roomId = roomId
        self.requestedLineSeq = requestedLineSeq
        self.requestedGear = requestedGear
        self.queue = DispatchQueue(label: "liveparse.yy.ws.\(UUID().uuidString)")
        super.init()
    }

    func getStreamInfo() async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            connect()
        }
    }

    // MARK: - Connection

    private func connect() {
        wsUUID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var request = URLRequest(
            url: URL(string: "wss://h5-sinchl.yy.com/websocket?appid=yymwebh5&version=3.2.10&uuid=\(wsUUID)&sign=a8d7eef2")!
        )
        request.timeoutInterval = 30
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.yy.com", forHTTPHeaderField: "Origin")

        socket = WebSocket(request: request)
        socket?.delegate = self
        scheduleTimeout()

        queue.async { [weak self] in
            self?.socket?.connect()
        }
    }

    private func disconnect(error: Error? = nil) {
        queue.async { [weak self] in
            guard let self else { return }

            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil

            socket?.disconnect()
            socket = nil

            guard let continuation = continuation else { return }
            self.continuation = nil

            if case .completed(let info) = state {
                continuation.resume(returning: info)
                return
            }

            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(throwing: LiveParsePluginError.jsException("YY WebSocket completed without result"))
            }
        }
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if case .completed = self.state { return }
            let error = LiveParsePluginError.jsException("YY WebSocket timeout while waiting stream info")
            self.state = .failed(error)
            self.disconnect(error: error)
        }

        timeoutWorkItem = item
        queue.asyncAfter(deadline: .now() + timeoutSeconds, execute: item)
    }

    private func send(binary data: Data) {
        queue.async { [weak self] in
            self?.socket?.write(data: data)
        }
    }

    // MARK: - Login

    private func buildAnonymousLoginRequest() -> Data {
        var anonPayload = Data()
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16(""))
        anonPayload.append(YYBinaryProtocol.encodeUInt32LE(0))
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16("B8-97-5A-17-AD-4D"))
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16("B8-97-5A-17-AD-4D"))
        anonPayload.append(YYBinaryProtocol.encodeUInt32LE(0))
        anonPayload.append(YYBinaryProtocol.encodeASCIIString16("yymwebh5"))

        var payload = Data()
        payload.append(YYBinaryProtocol.encodeASCIIString16(""))
        payload.append(YYBinaryProtocol.encodeUInt32LE(19_822))
        payload.append(YYBinaryProtocol.encodeBytes32(anonPayload))

        return YYBinaryProtocol.buildFrame(uri: URI.cliAPLoginAuthReq2, payload: payload)
    }

    private func buildPLoginAPRequest(appid: UInt32) -> Data {
        var authInfo = Data()
        authInfo.append(YYBinaryProtocol.encodeASCIIString16(yyPassport))
        authInfo.append(YYBinaryProtocol.encodeASCIIString16(yyPassword))
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
        payload.append(YYBinaryProtocol.encodeUInt32LE(appid))
        payload.append(YYBinaryProtocol.encodeUInt32LE(yyUID))
        payload.append(YYBinaryProtocol.encodeUInt32LE(0))
        payload.append(YYBinaryProtocol.encodeUInt8(0))
        payload.append(YYBinaryProtocol.encodeBytes16(Data()))
        payload.append(YYBinaryProtocol.encodeBytes16(yyCookie))
        payload.append(YYBinaryProtocol.encodeASCIIString16("\(appid):0"))

        return YYBinaryProtocol.buildFrame(uri: URI.loginAP, payload: payload)
    }

    private func handleLoginAuthResponse(_ payload: Data) {
        do {
            var reader = YYBinaryProtocol.Reader(data: payload)
            _ = try reader.readASCIIString16()
            _ = try reader.readUInt32LE()
            let ruri = try reader.readUInt32LE()
            let inner = try reader.readBytes32()

            guard ruri == URI.anonymousLoginRes else {
                return
            }

            var anon = YYBinaryProtocol.Reader(data: inner)
            _ = try anon.readASCIIString16()
            let resCode = try anon.readUInt32LE()
            guard resCode == 0 || resCode == 200 else {
                let err = LiveParsePluginError.jsException("YY anonymous login failed: resCode=\(resCode)")
                state = .failed(err)
                disconnect(error: err)
                return
            }

            yyUID = try anon.readUInt32LE()
            _ = try anon.readUInt32LE() // yyid
            yyPassport = try anon.readASCIIString16()
            yyPassword = try anon.readASCIIString16()
            yyCookie = try anon.readBytes16()
            _ = try anon.readBytes16() // ticket

            let apAppID = AppID.apService
            print("🔵 YY: Anonymous login success uid=\(yyUID), sending PLoginAp(appid=\(apAppID))")
            state = .waitingAPLogin
            send(binary: buildPLoginAPRequest(appid: apAppID))
        } catch {
            let err = LiveParsePluginError.jsException("YY parse anonymous login response failed: \(error.localizedDescription)")
            state = .failed(err)
            disconnect(error: err)
        }
    }

    private func handleAPLoginResponse(_ payload: Data) {
        do {
            var reader = YYBinaryProtocol.Reader(data: payload)
            _ = try reader.readUInt32LE()
            let resCode = try reader.readUInt32LE()
            let context = try reader.readASCIIString16()
            _ = try reader.readUInt32LE() // client ip
            _ = try reader.readUInt16LE() // client port
            _ = try reader.readUInt32LE() // app key
            _ = try reader.readUInt32LE() // response uid (not used; keep anonymous uid)

            guard resCode == 0 || resCode == 200 else {
                let err = LiveParsePluginError.jsException("YY AP login failed: resCode=\(resCode), context=\(context)")
                state = .failed(err)
                disconnect(error: err)
                return
            }

            print("🔵 YY: AP login success context=\(context), uid=\(yyUID)")

            sendSubServiceTypes()

            state = .waitingStreams
            queue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.sendChannelStreamsUpdateRequest()
            }
        } catch {
            let err = LiveParsePluginError.jsException("YY parse AP login response failed: \(error.localizedDescription)")
            state = .failed(err)
            disconnect(error: err)
        }
    }

    // MARK: - Requests

    private func nextSequence() -> UInt64 {
        seqCounter += 1
        return seqCounter
    }

    private func buildHead(sequence: UInt64) -> Data {
        var head = Data()
        head.append(YYBinaryProtocol.encodeUInt64(field: 1, value: sequence))
        head.append(YYBinaryProtocol.encodeString(field: 2, value: AppID.mediaAppidStr))
        head.append(YYBinaryProtocol.encodeString(field: 3, value: "121"))
        head.append(YYBinaryProtocol.encodeString(field: 4, value: roomId))
        head.append(YYBinaryProtocol.encodeString(field: 5, value: roomId))
        head.append(YYBinaryProtocol.encodeUInt64(field: 6, value: UInt64(yyUID)))
        head.append(YYBinaryProtocol.encodeInt(field: 7, value: 108))
        head.append(YYBinaryProtocol.encodeString(field: 8, value: "5.23.0-beta.2"))
        head.append(YYBinaryProtocol.encodeInt(field: 9, value: 1))
        head.append(YYBinaryProtocol.encodeString(field: 10, value: "yylive_web"))
        head.append(YYBinaryProtocol.encodeString(field: 11, value: "5.23.0-beta.2"))
        head.append(YYBinaryProtocol.encodeString(field: 12, value: "0"))
        head.append(YYBinaryProtocol.encodeString(field: 13, value: "5.23.0-beta.2"))
        return head
    }

    private func buildClientAttribute() -> Data {
        var attr = Data()
        attr.append(YYBinaryProtocol.encodeString(field: 1, value: "web"))
        attr.append(YYBinaryProtocol.encodeString(field: 2, value: "web1"))
        attr.append(YYBinaryProtocol.encodeString(field: 3, value: ""))
        attr.append(YYBinaryProtocol.encodeString(field: 4, value: ""))
        attr.append(YYBinaryProtocol.encodeString(field: 5, value: "chrome"))
        attr.append(YYBinaryProtocol.encodeString(field: 6, value: "145.0.0.0"))
        attr.append(YYBinaryProtocol.encodeString(field: 7, value: ""))
        attr.append(YYBinaryProtocol.encodeString(field: 8, value: ""))
        attr.append(YYBinaryProtocol.encodeString(field: 9, value: ""))
        attr.append(YYBinaryProtocol.encodeString(field: 10, value: ""))
        attr.append(YYBinaryProtocol.encodeString(field: 11, value: "1920"))
        attr.append(YYBinaryProtocol.encodeString(field: 12, value: "1080"))
        attr.append(YYBinaryProtocol.encodeString(field: 13, value: ""))
        attr.append(YYBinaryProtocol.encodeInt(field: 14, value: 8))
        attr.append(YYBinaryProtocol.encodeInt(field: 15, value: 1))
        return attr
    }

    private func buildAvpParameter(lineSeq: Int = 0, gear: Int = 4) -> Data {
        var avp = Data()
        avp.append(YYBinaryProtocol.encodeInt(field: 1, value: 1)) // version
        avp.append(YYBinaryProtocol.encodeInt(field: 4, value: 8)) // client_type
        avp.append(YYBinaryProtocol.encodeInt(field: 5, value: 0)) // service_type
        avp.append(YYBinaryProtocol.encodeInt(field: 6, value: 0)) // imsi
        avp.append(YYBinaryProtocol.encodeInt(field: 7, value: Int(Date().timeIntervalSince1970))) // send_time
        avp.append(YYBinaryProtocol.encodeInt(field: 11, value: lineSeq))
        avp.append(YYBinaryProtocol.encodeInt(field: 12, value: gear))
        avp.append(YYBinaryProtocol.encodeInt(field: 14, value: 1)) // ssl
        avp.append(YYBinaryProtocol.encodeInt(field: 16, value: 0)) // stream_format
        return avp
    }

    private func sendSubServiceTypes() {
        let appids: [UInt32] = [
            AppID.appidA,
            AppID.appidB,
            UInt32(AppID.streamLineService),
            AppID.appidD
        ]
        let frame = YYBinaryProtocol.buildSubServiceTypes(uri: URI.pSubServiceTypes, uid: yyUID, appids: appids)
        print("🔵 YY: SubServiceTypes appids=\(appids)")
        send(binary: frame)
    }

    private func sendServiceAppData(
        appid: UInt16,
        maxType: UInt16,
        minType: UInt16,
        protobuf: Data,
        routerAppid: UInt32 = AppID.apService
    ) {
        let trace = nextTrace()
        let yyp = YYBinaryProtocol.buildYYP(maxType: maxType, minType: minType, data: protobuf)
        let ul = YYBinaryProtocol.buildUlSvcMsgByUid(
            appid: appid,
            topSid: roomSid,
            uid: yyUID,
            payload: yyp,
            statType: UInt8(truncatingIfNeeded: appid),
            subSid: roomSid,
            ext: [:],
            appendH5Tail: true
        )

        let headers = YYBinaryProtocol.buildAPRouterHeaders(
            realUri: URI.ulSvcMsgByUid,
            appid: routerAppid,
            uid: yyUID,
            serviceName: "",
            extentProps: [103: Data(trace.utf8)],
            clientCtx: ""
        )

        let frame = YYBinaryProtocol.buildAPRouterFrame(
            outerURI: URI.papRouterReq,
            ruri: URI.ulSvcMsgByUid,
            body: ul,
            headers: headers
        )

        print("🔵 YY: sendAppData routerAppid=\(routerAppid) appid=\(appid) max/min=\(maxType)/\(minType) yyp=\(yyp.count) frame=\(frame.count) trace=\(trace)")
        send(binary: frame)
    }

    private func nextTrace() -> String {
        traceCounter &+= 1
        return "F\(yyUID)_yymwebh5_\(tracePrefix)_\(traceCounter)"
    }

    private func sendChannelStreamsUpdateRequest() {
        let seq = UInt64(Date().timeIntervalSince1970 * 1000)
        seqCounter = max(seqCounter, seq)

        var request = Data()
        // 对齐网页 9701/5 请求：field 8=timestamp(ms), field 9=client_attribute, field 100=head
        request.append(YYBinaryProtocol.encodeUInt64(field: 8, value: seq))
        request.append(YYBinaryProtocol.encodeMessage(field: 9, value: buildClientAttribute()))
        request.append(YYBinaryProtocol.encodeMessage(field: 100, value: buildHead(sequence: seq)))

        print("🔵 YY: Sending ChannelStreamsUpdateRequest roomId=\(roomId) seq=\(seq)")
        sendServiceAppData(appid: AppID.streamUpdateService, maxType: 9701, minType: 5, protobuf: request)
    }

    private func sendChannelGearLineInfoRequest(
        primary: YYGearStreamKeyInfo,
        lineCandidates: [YYGearStreamKeyInfo],
        lineSeq: Int,
        gear: Int
    ) {
        let seq = nextSequence()

        let primaryData = encodeGearStreamKeyInfo(primary)

        var request = Data()
        request.append(YYBinaryProtocol.encodeMessage(field: 1, value: buildAvpParameter(lineSeq: lineSeq, gear: gear)))
        request.append(YYBinaryProtocol.encodeMessage(field: 2, value: primaryData))
        for item in lineCandidates {
            request.append(YYBinaryProtocol.encodeMessage(field: 3, value: encodeGearStreamKeyInfo(item)))
        }
        request.append(YYBinaryProtocol.encodeMessage(field: 100, value: buildHead(sequence: seq)))

        print(
            "🔵 YY: Sending ChannelGearLineInfoQueryRequest streamKey=\(primary.streamKey) ver=\(primary.ver) lineSeq=\(lineSeq) gear=\(gear) seq=\(seq) appid=\(AppID.streamLineService) router=\(AppID.apService) payloadLen=\(primaryData.count) lineCandidates=\(lineCandidates.count)"
        )
        sendServiceAppData(
            appid: AppID.streamLineService,
            maxType: 9701,
            minType: 7,
            protobuf: request,
            routerAppid: AppID.apService
        )
    }

    // MARK: - Responses

    private func handleConnected() {
        print("🔵 YY: Connection established, sending anonymous login")
        state = .waitingLogin
        send(binary: buildAnonymousLoginRequest())
    }

    private func handleRouterMessage(_ frameURI: UInt32, _ payload: Data) {
        guard let router = YYBinaryProtocol.parseAPRouter(payload) else {
            print("❌ YY: parse PAPRouter failed frameURI=\(frameURI)")
            return
        }

        switch router.ruri {
        case URI.dlSvcMsgByUid:
            handleDlSvcMsgByUid(router.body)
        case URI.dlSvcMsgBySid:
            handleDlSvcMsgBySid(router.body)
        case URI.dlUsrGroupMsg:
            guard let groupMsg = YYBinaryProtocol.parseDlUsrGroupMsg(router.body) else {
                print("⚠️ YY: parse DlUsrGroupMsg failed")
                return
            }
            if groupMsg.ruri == URI.dlSvcMsgByUid {
                handleDlSvcMsgByUid(groupMsg.msg)
            } else if groupMsg.ruri == URI.dlSvcMsgBySid {
                handleDlSvcMsgBySid(groupMsg.msg)
            }
        default:
            print("ℹ️ YY: router ruri=\(router.ruri) ignored")
        }
    }

    private func handleDlSvcMsgByUid(_ payload: Data) {
        guard let dl = YYBinaryProtocol.parseDlSvcMsgByUid(payload) else {
            print("❌ YY: parse DlSvcMsgByUid failed")
            return
        }

        guard let yyp = YYBinaryProtocol.parseYYP(dl.payload) else {
            print("❌ YY: parse YYP from DlSvcMsgByUid failed appid=\(dl.appid)")
            return
        }

        print("✅ YY: recv appid=\(dl.appid) max/min=\(yyp.maxType)/\(yyp.minType) len=\(yyp.data.count)")

        if dl.appid == AppID.streamUpdateService, yyp.maxType == 9701, yyp.minType == 6 {
            handleStreamsUpdateResponse(yyp.data)
            return
        }

        if dl.appid == AppID.streamLineService, yyp.maxType == 9701, yyp.minType == 8 {
            handleGearLineResponse(yyp.data)
            return
        }
    }

    private func handleDlSvcMsgBySid(_ payload: Data) {
        guard let dl = YYBinaryProtocol.parseDlSvcMsgBySid(payload) else {
            print("❌ YY: parse DlSvcMsgBySid failed")
            return
        }

        guard let yyp = YYBinaryProtocol.parseYYP(dl.payload) else {
            print("ℹ️ YY: DlSvcMsgBySid appid=\(dl.appid) topSid=\(dl.topSid) is not YYP")
            return
        }

        print("✅ YY: recv(bySid) appid=\(dl.appid) max/min=\(yyp.maxType)/\(yyp.minType) len=\(yyp.data.count)")

        if dl.appid == AppID.streamLineService, yyp.maxType == 9701, yyp.minType == 8 {
            handleGearLineResponse(yyp.data)
            return
        }

        if dl.appid == AppID.streamUpdateService, yyp.maxType == 9701, yyp.minType == 6 {
            handleStreamsUpdateResponse(yyp.data)
            return
        }
    }

    private func handleStreamsUpdateResponse(_ data: Data) {
        let root = YYBinaryProtocol.protobufFieldMap(data)
        if let result = root[1]?.first?.varintValue, result != 0 {
            let msg = YYBinaryProtocol.firstStringField(data, number: 9) ?? ""
            let error = LiveParsePluginError.jsException("YY ChannelStreamsUpdateResponse result=\(result) msg=\(msg)")
            state = .failed(error)
            disconnect(error: error)
            return
        }

        guard let channelStreamInfo = root[8]?.first?.rawValue else {
            let error = LiveParsePluginError.jsException("YY ChannelStreamsUpdateResponse missing channel_stream_info")
            state = .failed(error)
            disconnect(error: error)
            return
        }

        let channelMap = YYBinaryProtocol.protobufFieldMap(channelStreamInfo)
        if let version = channelMap[1]?.first?.varintValue {
            streamInfo["current_version"] = String(version)
        }

        guard let streams = channelMap[2], !streams.isEmpty else {
            let error = LiveParsePluginError.jsException("YY ChannelStreamsUpdateResponse streams is empty")
            state = .failed(error)
            disconnect(error: error)
            return
        }

        var candidates: [YYStreamCandidate] = []

        for (index, streamField) in streams.enumerated() {
            let streamMap = YYBinaryProtocol.protobufFieldMap(streamField.rawValue)
            guard let rawStreamKey = streamMap[26]?.first.flatMap({ String(data: $0.rawValue, encoding: .utf8) }) else {
                continue
            }

            let streamKey = rawStreamKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !streamKey.isEmpty, let ver = streamMap[15]?.first?.varintValue else {
                continue
            }

            var lineSeq = 0
            if let lineList = streamMap[28]?.first?.rawValue {
                let lineListMap = YYBinaryProtocol.protobufFieldMap(lineList)
                if let lineInfo = lineListMap[1]?.first?.rawValue {
                    let lineInfoMap = YYBinaryProtocol.protobufFieldMap(lineInfo)
                    if let seqValue = lineInfoMap[1]?.first?.varintValue {
                        lineSeq = Int(seqValue)
                    }
                }
            }

            var gear = 1
            var stage = ""
            var mixToken = ""
            if let jsonObject = parseJSONObjectField(streamMap[8]?.first?.rawValue) {
                if let gearInfo = jsonObject["gear_info"] as? [String: Any] {
                    if let gearNumber = gearInfo["gear"] as? NSNumber {
                        gear = gearNumber.intValue
                    } else if let gearString = gearInfo["gear"] as? String, let gearInt = Int(gearString) {
                        gear = gearInt
                    }
                }
                if let attr = jsonObject["attr"] as? [String: Any] {
                    stage = stringValue(attr["stage"])
                    mixToken = stringValue(attr["mixToken"])
                    if mixToken.isEmpty {
                        mixToken = stringValue(attr["mix_token"])
                    }
                }
                if stage.isEmpty {
                    stage = stringValue(jsonObject["stage"])
                }
                if mixToken.isEmpty {
                    mixToken = stringValue(jsonObject["mixToken"])
                }
                if mixToken.isEmpty {
                    mixToken = stringValue(jsonObject["mix_token"])
                }
            }
            if (stage.isEmpty || mixToken.isEmpty),
               let metadataObject = parseJSONObjectField(streamMap[10]?.first?.rawValue)
            {
                if stage.isEmpty {
                    stage = stringValue(metadataObject["stage"])
                }
                if mixToken.isEmpty {
                    mixToken = stringValue(metadataObject["mixToken"])
                }
                if mixToken.isEmpty {
                    mixToken = stringValue(metadataObject["mix_token"])
                }
            }

            let isVideo = streamKey.contains("_xv_")
            let isAudio = streamKey.contains("_xa_")
            var score = 0
            if isVideo { score += 1_000 } // 优先视频流
            if isAudio { score -= 200 }   // 避免选到纯音频
            if streamKey.hasSuffix("_0_0_0") { score += 50 } // 与网页常见可播 key 对齐
            score += max(0, min(gear, 20)) * 10             // 优先更高清档位
            if lineSeq > 0 { score += 5 }

            let candidate = YYStreamCandidate(
                index: index,
                streamKey: streamKey,
                ver: ver,
                lineSeq: lineSeq,
                gear: gear,
                stage: stage,
                mixToken: mixToken,
                isVideo: isVideo,
                isAudio: isAudio,
                score: score
            )
            candidates.append(candidate)
            print(
                "🔹 YY: Stream candidate index=\(index) score=\(score) ver=\(ver) stream_key=\(streamKey) lineSeq=\(lineSeq) gear=\(gear) stageLen=\(stage.count) mixLen=\(mixToken.count)"
            )
        }

        let videoCandidates = candidates.filter(\.isVideo)
        guard let picked = selectRequestedCandidate(from: videoCandidates) ?? bestVideoCandidate(from: videoCandidates) else {
            let error = LiveParsePluginError.jsException("YY ChannelStreamsUpdateResponse missing valid stream_key/ver in \(streams.count) streams")
            state = .failed(error)
            disconnect(error: error)
            return
        }

        let streamKey = picked.streamKey
        let ver = picked.ver
        let pickedLineSeq = picked.lineSeq
        let pickedGear = picked.gear
        print("🔵 YY: Selected stream index=\(picked.index) score=\(picked.score) ver=\(ver) stream_key=\(streamKey) lineSeq=\(pickedLineSeq) gear=\(pickedGear)")

        streamInfo["stream_key"] = streamKey
        streamInfo["ver"] = String(ver)
        streamInfo["line_seq"] = String(pickedLineSeq)
        streamInfo["gear"] = String(pickedGear)

        let pairedAudio = findPairedAudio(for: picked, from: candidates)
        let primaryInfo = makeGearStreamKeyInfo(video: picked, audio: pairedAudio)

        var lineCandidates: [YYGearStreamKeyInfo] = []
        var seen = Set<String>()
        let sameGearVideos = candidates.filter { $0.isVideo && $0.gear == picked.gear }
        for video in sameGearVideos {
            let audio = findPairedAudio(for: video, from: candidates)
            let info = makeGearStreamKeyInfo(video: video, audio: audio)
            if seen.insert(info.streamKey).inserted {
                lineCandidates.append(info)
            }
        }
        if lineCandidates.isEmpty {
            lineCandidates = [primaryInfo]
        }

        state = .waitingGearLine
        sendChannelGearLineInfoRequest(
            primary: primaryInfo,
            lineCandidates: lineCandidates,
            lineSeq: pickedLineSeq,
            gear: pickedGear
        )
    }

    private func bestVideoCandidate(from candidates: [YYStreamCandidate]) -> YYStreamCandidate? {
        candidates.max(by: { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhs.gear != rhs.gear { return lhs.gear < rhs.gear }
            return lhs.index > rhs.index
        })
    }

    private func selectRequestedCandidate(from candidates: [YYStreamCandidate]) -> YYStreamCandidate? {
        guard !candidates.isEmpty else { return nil }
        guard requestedLineSeq != nil || requestedGear != nil else { return nil }

        if let requestedGear {
            print("🔵 YY: Requested quality gear=\(requestedGear), lineSeq=\(requestedLineSeq ?? -1)")
        } else if let requestedLineSeq {
            print("🔵 YY: Requested lineSeq=\(requestedLineSeq)")
        }

        if let requestedLineSeq, let requestedGear {
            let exact = candidates.filter { $0.lineSeq == requestedLineSeq && $0.gear == requestedGear }
            if let picked = bestVideoCandidate(from: exact) { return picked }
        }

        if let requestedGear {
            let exactGear = candidates.filter { $0.gear == requestedGear }
            if let picked = bestVideoCandidate(from: exactGear) { return picked }

            let nearestGear = candidates.min { lhs, rhs in
                let left = abs(lhs.gear - requestedGear)
                let right = abs(rhs.gear - requestedGear)
                if left != right { return left < right }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.index < rhs.index
            }
            if let nearestGear { return nearestGear }
        }

        if let requestedLineSeq {
            let exactLine = candidates.filter { $0.lineSeq == requestedLineSeq }
            if let picked = bestVideoCandidate(from: exactLine) { return picked }
        }

        return nil
    }

    private func makeGearStreamKeyInfo(video: YYStreamCandidate, audio: YYStreamCandidate?) -> YYGearStreamKeyInfo {
        YYGearStreamKeyInfo(
            streamKey: video.streamKey,
            ver: video.ver,
            stage: video.stage,
            mixToken: video.mixToken,
            rStreamKey: audio?.streamKey,
            rVer: audio?.ver,
            rStage: audio?.stage,
            rMixToken: audio?.mixToken
        )
    }

    private func findPairedAudio(for video: YYStreamCandidate, from all: [YYStreamCandidate]) -> YYStreamCandidate? {
        let directKey = video.streamKey.replacingOccurrences(of: "_xv_", with: "_xa_")
        if let hit = all.first(where: { $0.isAudio && $0.streamKey == directKey }) {
            return hit
        }

        let targetTail = streamTail(video.streamKey)
        return all.first(where: { candidate in
            candidate.isAudio && streamTail(candidate.streamKey) == targetTail
        })
    }

    private func streamTail(_ streamKey: String) -> String {
        if let range = streamKey.range(of: "_xv_") {
            return String(streamKey[range.upperBound...])
        }
        if let range = streamKey.range(of: "_xa_") {
            return String(streamKey[range.upperBound...])
        }
        return streamKey
    }

    private func encodeGearStreamKeyInfo(_ info: YYGearStreamKeyInfo) -> Data {
        var data = Data()
        data.append(YYBinaryProtocol.encodeString(field: 1, value: info.streamKey))
        if let rStreamKey = info.rStreamKey, !rStreamKey.isEmpty {
            data.append(YYBinaryProtocol.encodeString(field: 2, value: rStreamKey))
        }
        data.append(YYBinaryProtocol.encodeUInt64(field: 4, value: info.ver))
        if let rVer = info.rVer {
            data.append(YYBinaryProtocol.encodeUInt64(field: 5, value: rVer))
        }
        if !info.stage.isEmpty {
            data.append(YYBinaryProtocol.encodeString(field: 6, value: info.stage))
        }
        if let rStage = info.rStage, !rStage.isEmpty {
            data.append(YYBinaryProtocol.encodeString(field: 7, value: rStage))
        }
        if !info.mixToken.isEmpty {
            data.append(YYBinaryProtocol.encodeString(field: 8, value: info.mixToken))
        }
        if let rMixToken = info.rMixToken, !rMixToken.isEmpty {
            data.append(YYBinaryProtocol.encodeString(field: 9, value: rMixToken))
        }
        return data
    }

    private func parseJSONObjectField(_ raw: Data?) -> [String: Any]? {
        guard let raw, !raw.isEmpty,
              let text = String(data: raw, encoding: .utf8),
              let jsonData = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            return nil
        }
        return object
    }

    private func stringValue(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private func handleGearLineResponse(_ data: Data) {
        var payload = data
        var root = YYBinaryProtocol.protobufFieldMap(payload)
        if root.isEmpty, let inflated = inflateZlib(payload), !inflated.isEmpty {
            print("🔍 YY 9701/8 inflate zlib \(payload.count) -> \(inflated.count)")
            payload = inflated
            root = YYBinaryProtocol.protobufFieldMap(payload)
        }

        // 兼容不同返回布局：优先标准 field=3，其次尝试 field=2/4 以及首个 length-delimited 字段。
        var avpCandidates: [Data] = []
        if let value = root[3]?.first?.rawValue { avpCandidates.append(value) }
        if let value = root[2]?.first?.rawValue { avpCandidates.append(value) }
        if let value = root[4]?.first?.rawValue { avpCandidates.append(value) }
        for fields in root.values {
            if let raw = fields.first?.rawValue, !avpCandidates.contains(raw) {
                avpCandidates.append(raw)
            }
        }
        logGearLineDebug(data: payload, root: root, avpCandidates: avpCandidates)

        if let result = root[1]?.first?.varintValue, result != 0 {
            let msg = YYBinaryProtocol.firstStringField(payload, number: 2) ?? ""
            print("⚠️ YY 9701/8 result=\(result) msg=\(msg) (continue parsing url)")
        }

        var foundURL: String?
        var foundLineSeq: UInt64?

        for candidate in avpCandidates {
            if let parsed = extractURLFromAvpInfoRes(candidate) {
                foundURL = parsed.url
                foundLineSeq = parsed.lineSeq
                break
            }
        }

        if foundURL == nil, let fallback = extractURLByRecursiveScan(payload) {
            foundURL = fallback
        }

        guard let url = foundURL else {
            let keys = root.keys.sorted()
            let error = LiveParsePluginError.jsException("YY no valid cdn url found in 9701/8 (root fields=\(keys))")
            state = .failed(error)
            disconnect(error: error)
            return
        }

        streamInfo["url"] = url
        if let lineSeq = foundLineSeq {
            streamInfo["line_seq"] = String(lineSeq)
        }

        print("✅ YY: Got play URL: \(url)")

        state = .completed(streamInfo)
        disconnect()
    }

    private func extractURLFromAvpInfoRes(_ avpInfoRes: Data) -> (url: String, lineSeq: UInt64?)? {
        let avpMap = YYBinaryProtocol.protobufFieldMap(avpInfoRes)
        guard let streamLineAddrEntries = avpMap[1], !streamLineAddrEntries.isEmpty else {
            return nil
        }

        var foundURL: String?
        var foundLineSeq: UInt64?
        for entryField in streamLineAddrEntries {
            let entry = YYBinaryProtocol.protobufFieldMap(entryField.rawValue)
            guard let lineAddressInfo = entry[2]?.first?.rawValue else { continue }

            let lineAddressMap = YYBinaryProtocol.protobufFieldMap(lineAddressInfo)
            if let lineSeq = lineAddressMap[1]?.first?.varintValue {
                foundLineSeq = lineSeq
            }

            guard let cdnInfo = lineAddressMap[3]?.first?.rawValue else { continue }
            let cdnMap = YYBinaryProtocol.protobufFieldMap(cdnInfo)
            if let url = cdnMap[4]?.first.flatMap({ String(data: $0.rawValue, encoding: .utf8) }),
               url.contains("://"),
               !url.isEmpty
            {
                foundURL = url
                break
            }
        }

        guard let url = foundURL else { return nil }
        return (url, foundLineSeq)
    }

    private func extractURLByRecursiveScan(_ data: Data, depth: Int = 0) -> String? {
        if depth > 5 || data.isEmpty { return nil }

        if let s = String(data: data, encoding: .utf8),
           let url = firstYYURL(in: s)
        {
            return url
        }

        for field in YYBinaryProtocol.parseProtobuf(data) where field.wireType == 2 {
            if let s = String(data: field.rawValue, encoding: .utf8),
               let url = firstYYURL(in: s)
            {
                return url
            }
            if let nested = extractURLByRecursiveScan(field.rawValue, depth: depth + 1) {
                return nested
            }
        }

        return nil
    }

    private func logGearLineDebug(data: Data, root: [Int: [YYBinaryProtocol.ProtoField]], avpCandidates: [Data]) {
        let headHex = data.prefix(24).map { String(format: "%02x", $0) }.joined()
        let rootSummary = root.keys.sorted().map { key in
            guard let first = root[key]?.first else { return "\(key):empty" }
            if let v = first.varintValue {
                return "\(key):v=\(v)"
            }
            return "\(key):len=\(first.rawValue.count)"
        }.joined(separator: ",")
        print("🔍 YY 9701/8 root(len=\(data.count),hex=\(headHex)) => \(rootSummary)")

        for (idx, candidate) in avpCandidates.prefix(3).enumerated() {
            let map = YYBinaryProtocol.protobufFieldMap(candidate)
            let fieldSummary = map.keys.sorted().map { key in
                let count = map[key]?.count ?? 0
                let firstLen = map[key]?.first?.rawValue.count ?? 0
                return "\(key)x\(count)(\(firstLen))"
            }.joined(separator: ",")
            let prefixHex = candidate.prefix(24).map { String(format: "%02x", $0) }.joined()
            print("🔍 YY 9701/8 cand[\(idx)] len=\(candidate.count) fields=\(fieldSummary) hex=\(prefixHex)")
        }

        let urls = collectDebugURLs(in: data, maxCount: 8)
        if urls.isEmpty {
            print("🔍 YY 9701/8 urls: none")
        } else {
            print("🔍 YY 9701/8 urls: \(urls.joined(separator: " | "))")
        }
    }

    private func inflateZlib(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        var capacity = max(data.count * 4, 2048)

        return data.withUnsafeBytes { raw -> Data? in
            guard let src = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            for _ in 0..<6 {
                let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
                defer { dst.deallocate() }
                let decoded = compression_decode_buffer(
                    dst,
                    capacity,
                    src,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
                if decoded > 0 {
                    return Data(bytes: dst, count: decoded)
                }
                capacity *= 2
            }
            return nil
        }
    }

    private func collectDebugURLs(in data: Data, maxCount: Int) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        collectDebugURLsRecursive(in: data, depth: 0, maxDepth: 6, maxCount: maxCount, result: &result, seen: &seen)
        return result
    }

    private func collectDebugURLsRecursive(
        in data: Data,
        depth: Int,
        maxDepth: Int,
        maxCount: Int,
        result: inout [String],
        seen: inout Set<String>
    ) {
        if depth > maxDepth || result.count >= maxCount || data.isEmpty { return }

        if let text = String(data: data, encoding: .utf8) {
            for url in allYYURLs(in: text) where !seen.contains(url) {
                seen.insert(url)
                result.append(url)
                if result.count >= maxCount { return }
            }
        }

        for field in YYBinaryProtocol.parseProtobuf(data) where field.wireType == 2 {
            collectDebugURLsRecursive(
                in: field.rawValue,
                depth: depth + 1,
                maxDepth: maxDepth,
                maxCount: maxCount,
                result: &result,
                seen: &seen
            )
            if result.count >= maxCount { return }
        }
    }

    private func allYYURLs(in text: String) -> [String] {
        let pattern = #"https?://[^\s"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var result: [String] = []
        let matches = regex.matches(in: text, options: [], range: range)
        for match in matches {
            let url = ns.substring(with: match.range)
            if url.contains("yy.com/live/") || url.contains("flv") {
                result.append(url)
            }
        }
        return result
    }

    private func firstYYURL(in text: String) -> String? {
        allYYURLs(in: text).first
    }

    private func handleBinaryMessage(_ data: Data) {
        guard let (uri, payload) = YYBinaryProtocol.parseFrame(data) else {
            print("❌ YY: Failed to parse frame")
            return
        }

        switch uri {
        case URI.cliAPLoginAuthRes, URI.cliAPLoginAuthRes2:
            handleLoginAuthResponse(payload)
        case URI.loginAPRes:
            handleAPLoginResponse(payload)
        case URI.appPong:
            return
        case URI.papRouterReq, URI.papRouterRes:
            handleRouterMessage(uri, payload)
        default:
            // 其他消息不影响主流程
            print("ℹ️ YY: frame uri=\(uri) ignored")
        }
    }
}

// MARK: - WebSocketDelegate

extension YYWebSocketClient: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected:
            print("✅ YY WebSocket connected")
            handleConnected()

        case .disconnected(let reason, let code):
            if case .completed = state {
                print("ℹ️ YY WebSocket closed after success: \(reason) (\(code))")
                disconnect()
            } else {
                print("❌ YY WebSocket disconnected: \(reason) (\(code))")
                disconnect(error: LiveParsePluginError.jsException("YY WebSocket disconnected: \(reason) (\(code))"))
            }

        case .binary(let data):
            print("📦 YY: Received binary data (\(data.count) bytes)")
            handleBinaryMessage(data)

        case .text(let text):
            print("📝 YY: Received text message: \(text)")

        case .ping:
            break

        case .pong:
            break

        case .viabilityChanged(let viable):
            print("🔄 YY: Viability changed: \(viable)")

        case .reconnectSuggested(let suggested):
            print("🔄 YY: Reconnect suggested: \(suggested)")

        case .error(let error):
            if case .completed = state {
                print("ℹ️ YY WebSocket ignored error after success: \(error?.localizedDescription ?? "unknown")")
                disconnect()
            } else {
                print("❌ YY WebSocket error: \(error?.localizedDescription ?? "unknown")")
                disconnect(error: error ?? LiveParsePluginError.jsException("YY WebSocket unknown error"))
            }

        case .cancelled:
            if case .completed = state {
                print("ℹ️ YY WebSocket cancelled after success")
                disconnect()
            } else {
                disconnect(error: LiveParsePluginError.jsException("YY WebSocket cancelled"))
            }

        case .peerClosed:
            if case .completed = state {
                print("ℹ️ YY: Peer closed after success")
                disconnect()
            } else {
                print("❌ YY: Peer closed connection")
                disconnect(error: LiveParsePluginError.jsException("YY WebSocket peer closed"))
            }
        }
    }
}
