// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


public final class LiveParsePlatformInfo: Codable {
    public let pluginId: String
    public let liveType: LiveType
    public let livePlatformName: String
    public let description: String

    init(pluginId: String, liveType: LiveType, livePlatformName: String, description: String) {
        self.pluginId = pluginId
        self.liveType = liveType
        self.livePlatformName = livePlatformName
        self.description = description
    }
}

public final class LiveParseTools {
    private static let builtInNames: [String: String] = [
        LiveType.bilibili.rawValue: "哔哩哔哩",
        LiveType.huya.rawValue: "虎牙",
        LiveType.douyin.rawValue: "抖音",
        LiveType.douyu.rawValue: "斗鱼",
        LiveType.cc.rawValue: "网易CC",
        LiveType.ks.rawValue: "快手",
        LiveType.yy.rawValue: "YY直播",
        LiveType.youtube.rawValue: "YouTube",
        LiveType.soop.rawValue: "SOOP"
    ]

    private static let builtInDescriptions: [String: String] = [
        LiveType.bilibili.rawValue: "超清直播须在设置扫码",
        LiveType.huya.rawValue: "竞技由我，玩在虎牙",
        LiveType.douyin.rawValue: "无法使用请在PC浏览器扫码登录",
        LiveType.douyu.rawValue: "每个人的直播平台",
        LiveType.cc.rawValue: "网易游戏直播(暂无弹幕)",
        LiveType.ks.rawValue: "无法播放请手动打开任意直播间通过滑块验证码(暂无弹幕)",
        LiveType.yy.rawValue: "全民娱乐的互动直播平台",
        LiveType.youtube.rawValue: "全球视频平台直播(已支持直播弹幕轮询)",
        LiveType.soop.rawValue: "韩国直播平台(原AfreecaTV)"
    ]

    public class func getLivePlatformName(_ liveType: LiveType) -> String {
        if let name = builtInNames[liveType.rawValue] {
            return name
        }
        if let platform = LiveParseJSPlatformManager.platform(for: liveType) {
            return platform.displayName
        }
        return "平台\(liveType.rawValue)"
    }

    public class func getAllSupportPlatform() -> [LiveParsePlatformInfo] {
        return LiveParseJSPlatformManager.availablePlatforms.map { platform in
            let liveType = platform.liveType
            return LiveParsePlatformInfo(
                pluginId: platform.pluginId,
                liveType: liveType,
                livePlatformName: getLivePlatformName(liveType),
                description: builtInDescriptions[liveType.rawValue] ?? ""
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
