// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


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
        case .soop:
            return "SOOP"
        }
    }

    public class func getAllSupportPlatform() -> [LiveParsePlatformInfo] {
        let descriptions: [LiveType: String] = [
            .bilibili: "超清直播须在设置扫码",
            .huya: "竞技由我，玩在虎牙",
            .douyin: "无法使用请在PC浏览器扫码登录",
            .douyu: "每个人的直播平台",
            .cc: "网易游戏直播",
            .ks: "无法播放请手动打开任意直播间通过滑块验证码",
            .yy: "全民娱乐的互动直播平台(暂无弹幕)",
            .soop: "韩国直播平台(原AfreecaTV)"
        ]

        return LiveParseJSPlatformManager.availablePlatforms.map { platform in
            let liveType = platform.liveType
            return LiveParsePlatformInfo(
                liveType: liveType,
                livePlatformName: getLivePlatformName(liveType),
                description: descriptions[liveType] ?? ""
            )
        }
    }
}


public enum LiveParseError: Error, CustomStringConvertible, LocalizedError {

    case shareCodeParseError(String, String)
    case liveParseError(String, String)
    case liveStateParseError(String, String)
    case danmuArgsParseError(String, String)

    /// 错误标题（用于展示给用户或日志分类）
    public var title: String {
        switch self {
        case .shareCodeParseError(let title, _),
             .liveParseError(let title, _),
             .liveStateParseError(let title, _),
             .danmuArgsParseError(let title, _):
            return title
        }
    }

    /// 详细错误信息（包含网络请求详情等调试信息）
    public var detail: String {
        switch self {
        case .shareCodeParseError(_, let detail),
             .liveParseError(_, let detail),
             .liveStateParseError(_, let detail),
             .danmuArgsParseError(_, let detail):
            return detail
        }
    }

    /// 完整描述，用于打印或展示
    public var description: String {
        if detail.isEmpty {
            return title
        }
        if detail.contains(title) {
            return detail
        }
        return "\(title)\n\(detail)"
    }

    // MARK: - LocalizedError 协议实现

    /// 错误描述（用于 localizedDescription）
    public var errorDescription: String? {
        return title
    }

    /// 失败原因
    public var failureReason: String? {
        return detail.isEmpty ? nil : detail
    }
}
