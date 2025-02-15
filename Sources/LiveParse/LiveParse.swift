// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


protocol LiveParse {
    
    /**
     获取平台直播分类。
     
     - Returns: 平台直播分类（包含子分类）。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getCategoryList() async throws -> [LiveMainListModel]
    
    
    /**
     获取直播分类下的房间信息。
     
     - Parameters:
     - id: 对应平台分类id, 抖音原始字段为:id_str。
     - parentId: 对应平台id, b站抖音必填（抖音对应原始字段为: type），斗鱼虎牙不需要。
     
     - Returns: 主播和直播间信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getRoomList(id: String, parentId: String?, page: Int) async throws -> [LiveModel]
    
    
    /**
     获取直播源。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str）。
     
     - Warning: 斗鱼流程可能有些不同，需要首先调用本方法，如需要切换cdn/清晰度，需要再次调用getRealPlayArgs(roomId: String, rate: Int, cdn: String?),并且目前相当于只返回一个清晰度和CDN的链接
     
     - Warning: YY流程可能有些不同，需要首先调用本方法，如需要切换cdn/清晰度，需要再次调用getRealPlayArgs(roomId: String, lineSeq: Int? = -1, gear: Int? = 4),并且目前相当于只返回一个清晰度和CDN的链接
     
     - Returns: 直播真实地址和与相关清晰度字段。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getPlayArgs(roomId: String, userId: String?) async throws -> [LiveQualityModel]
    
    
    /**
     根据关键字搜索主播。
     
     - Parameters:
     - keyword: 关键词。
     - page: 分页。
     
     - Returns: 对应平台主播信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func searchRooms(keyword: String, page: Int) async throws -> [LiveModel]
    
    
    /**
     刷新用户信息（如用户进行收藏，需要单独更新主播直播标题封面等信息）。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid， cc对应字段为cuteid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str， cc对应字段为channel_id **必填**）。
     
     - Returns: 对应平台主播信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getLiveLastestInfo(roomId: String, userId: String?) async throws -> LiveModel
    
    
    /**
     获取对应主播直播状态。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str）。
     
     - Returns: 对应平台主播直播状态。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getLiveState(roomId: String, userId: String?) async throws -> LiveState
    
    /**
     通过分享链接/房间号/分享码/短链接等方式获取用户信息。
     
     - Parameters:
     - shareCode: shareCode
        B站：【暖雪玩玩-哔哩哔哩直播】 https://b23.tv/jeBazlm || https://live.bilibili.com/404 || 404
     
        Douyu: https://www.douyu.com/7180846 || 7180846 || https://www.douyu.com/lpl
     
        Huya: 霸哥(房间号189201)正在直播"冠军园区！大师局9999目前3170" 分享自 @虎牙直播https://m.huya.com/189201?shareid=16890536033617446582&shareUid=13794774&source=ios&pid=1724691&liveid=7312248923907638255&platform=7&from=cpy&invite_code=HY76QLTk || https://www.huya.com/7180846 || 7180846 || https://www.huya.com/lpl
     
        Douyin: 2- #在抖音，记录美好生活#【交个朋友直播间】正在直播，来和我一起支持Ta吧。复制下方链接，打开【抖音】，直接观看直播！ https://v.douyin.com/i8rhQQ2t/ 2@4.com 12/18 || https://live.douyin.com/168465302284 || 168465302284
     
        网易CC: https://cc.163.com/364038534/ || 364038534
     
        快手：https://live.kuaishou.com/u/Boy333ks1203 || Boy333ks1203
     
        YY: 1雪儿7156正在YY直播【她正在唱歌】，上YY 陪你一起唱！ 丫 https://www.yy.com/share/i/v2?platform=5&config_id=55&edition=1&sharedOid=5e9b07f01bcb028e927bf7932f74bc1b&userUid=a5a06fc73370b2af419dbe7f81ca540a&sid=87208093&ssid=87208093&timestamp=1718161221&version=8.40.0 丫，复制此消息，打开【YY直播】，直接观看！| https://www.yy.com/54880976/54880976?tempId=16777217 | 54880976
     
        Youtube: https://www.youtube.com/watch?v=DD-jLdHEh3c | DD-jLdHEh3c
     
     - Returns: 对应平台主播信息。
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getRoomInfoFromShareCode(shareCode: String) async throws -> LiveModel
    
    /**
     获取对应平台主播弹幕链接重要参数。
     
     - Parameters:
     - roomId: 对应平台主播房间号（并不一定url中出现的房间号， 抖音对应原始字段为webrid）。
     - userId: 对应平台用户id（抖音对应原始字段为room_id_str）。
     
     - Returns: 对应平台主播连接WebSocket重要参数, B站 虎牙 斗鱼链接WebSocket后第一次验证身份时需要，抖音则为url params和header (元组)
     
         B站：0: roomId(ws参数名:roomid) & token(ws参数名:key) & buvid; 1: nil
         Douyu: 0: roomid; 1: nil
         Huya: 0: lYyid & lChannelId & lSubChannelId; 1: nil
         Douyin: 0: URL Params; 1: Cookie: ttwid, ac_nonce
     
     - Throws: 如果无法完成请求或解析数据，将抛出错误。
     */
    static func getDanmukuArgs(roomId: String, userId: String?) async throws -> ([String: String], [String: String]?)
}

public final class LiveParsePlatformInfo: Codable {
    public let liveType: LiveType
    public let livePlatformName: String
    public let description: String
    
    init(liveType: LiveType, livePlatformName: String, description: String) {
        self.liveType = liveType
        self.livePlatformName = livePlatformName
        self.description = description
    }
}

public final class LiveParseTools {
    public class func getLivePlatformName(_ liveType: LiveType) -> String {
        switch liveType {
        case .bilibili:
            return "哔哩哔哩"
        case .huya:
            return "虎牙"
        case .douyin:
            return "抖音"
        case .douyu:
            return "斗鱼"
        case .cc:
            return "网易CC"
        case .ks:
            return "快手"
        case .yy:
            return "YY直播"
        case .youtube:
            return "Youtube"
        }
    }

    public class func getAllSupportPlatform() -> [LiveParsePlatformInfo] {
        return [
            LiveParsePlatformInfo(liveType: .bilibili, livePlatformName: getLivePlatformName(.bilibili), description: "超清直播须在设置扫码"),
            LiveParsePlatformInfo(liveType: .huya, livePlatformName: getLivePlatformName(.huya), description: "竞技由我，玩在虎牙"),
            LiveParsePlatformInfo(liveType: .douyin, livePlatformName: getLivePlatformName(.douyin), description: "无法使用请在PC浏览器扫码登录"),
            LiveParsePlatformInfo(liveType: .douyu, livePlatformName: getLivePlatformName(.douyu), description: "每个人的直播平台"),
            LiveParsePlatformInfo(liveType: .cc, livePlatformName: getLivePlatformName(.cc), description: "网易游戏直播(暂无弹幕)"),
            LiveParsePlatformInfo(liveType: .ks, livePlatformName: getLivePlatformName(.ks), description: "无法播放请手动打开任意直播间通过滑块验证码(暂无弹幕)"),
            LiveParsePlatformInfo(liveType: .yy, livePlatformName: getLivePlatformName(.yy), description: "全民娱乐的互动直播平台(暂无弹幕)"),
            LiveParsePlatformInfo(liveType: .youtube, livePlatformName: getLivePlatformName(.youtube), description: "需要自行解决代理问题，仅支持搜索观看(暂无弹幕)"),
        ]
    }
}


enum LiveParseError: Error, CustomStringConvertible {

    var description: String {
        switch self {
        case let .liveParseError(_, _):
            return "平台解析错误"
        case let .liveStateParseError(_, _):
            return "直播状态解析错误"
        case let .danmuArgsParseError(_, _):
            return "弹幕参数解析错误"
        case let .shareCodeParseError(_, _):
            return "分享码解析错误"
        }
    }
    
    case shareCodeParseError(String, String)
    case liveParseError(String, String)
    case liveStateParseError(String, String)
    case danmuArgsParseError(String, String)
}
