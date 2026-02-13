//
//  LiveParseError+Enhanced.swift
//  LiveParse
//
//  Created by pc on 2025/11/03.
//  Enhanced error handling system with detailed network request/response information
//

import Foundation
import Alamofire

// MARK: - 网络请求详情

/// 网络请求的详细信息，用于错误追踪和调试
public struct NetworkRequestDetail {
    public let url: String
    public let method: String
    public let headers: [String: String]?
    public let parameters: [String: Any]?
    public let body: String?
    public let timestamp: Date

    public init(
        url: String,
        method: String,
        headers: [String: String]? = nil,
        parameters: [String: Any]? = nil,
        body: String? = nil,
        timestamp: Date = Date()
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.parameters = parameters
        self.body = body
        self.timestamp = timestamp
    }

    /// 生成 curl 命令，方便用户复现请求
    public var curlCommand: String {
        var curl = "curl -X \(method.uppercased())"

        // 添加 headers
        if let headers = headers {
            for (key, value) in headers {
                // 隐藏敏感信息
                let displayValue: String
                if key.lowercased().contains("cookie") || key.lowercased().contains("authorization") {
                    displayValue = "[已隐藏]"
                } else {
                    displayValue = value
                }
                curl += " \\\n  -H '\(key): \(displayValue)'"
            }
        }

        // 添加请求体
        if let body = body {
            let escapedBody = body.replacingOccurrences(of: "'", with: "'\\''")
            curl += " \\\n  -d '\(escapedBody)'"
        }

        // 添加 URL（如果有 parameters 且是 GET 请求，parameters 已经在 URL 中）
        curl += " \\\n  '\(url)'"

        return curl
    }

    /// 格式化的请求详情字符串，用于日志输出
    public var formattedString: String {
        var result = """

        ==================== 请求详情 ====================
        CURL 命令（可直接复制使用）:
        \(curlCommand)
        ==================================================
        """
        return result
    }
}

/// 网络响应的详细信息
public struct NetworkResponseDetail {
    public let statusCode: Int
    public let headers: [String: String]?
    public let body: String?
    public let timestamp: Date

    public init(
        statusCode: Int,
        headers: [String: String]? = nil,
        body: String? = nil,
        timestamp: Date = Date()
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.timestamp = timestamp
    }

    /// 格式化的响应详情字符串
    public var formattedString: String {
        var result = """

        ==================== 服务器返回 ====================
        HTTP 状态码: \(statusCode)
        """

        if let body = body {
            let truncatedBody = body.count > 2000 ? "\(body.prefix(2000))...\n[已截断，总长度: \(body.count) 字符]" : body
            result += "\n原始返回内容:\n\(truncatedBody)\n"
        } else {
            result += "\n原始返回内容: [空]\n"
        }

        result += "==================================================\n"
        return result
    }
}

// MARK: - 细分的错误类型

/// 网络相关错误
public enum NetworkError: Error {
    case timeout(request: NetworkRequestDetail)
    case noConnection
    case invalidURL(String)
    case serverError(statusCode: Int, message: String, request: NetworkRequestDetail, response: NetworkResponseDetail)
    case invalidResponse(request: NetworkRequestDetail, response: NetworkResponseDetail?)
    case requestFailed(request: NetworkRequestDetail, response: NetworkResponseDetail?, underlyingError: Error)

    /// 获取关联的 curl 命令
    public var curl: String? {
        switch self {
        case .timeout(let request),
             .serverError(_, _, let request, _),
             .invalidResponse(let request, _),
             .requestFailed(let request, _, _):
            return request.curlCommand
        case .noConnection, .invalidURL:
            return nil
        }
    }

    var description: String {
        switch self {
        case .timeout(let request):
            return "网络请求超时\(request.formattedString)"
        case .noConnection:
            return "无网络连接"
        case .invalidURL(let url):
            return "无效的URL: \(url)"
        case .serverError(let statusCode, let message, let request, let response):
            return "服务器错误 (\(statusCode)): \(message)\(request.formattedString)\(response.formattedString)"
        case .invalidResponse(let request, let response):
            var result = "无效的响应数据\(request.formattedString)"
            if let response = response {
                result += response.formattedString
            }
            return result
        case .requestFailed(let request, let response, let error):
            var result = "网络请求失败: \(error.localizedDescription)\(request.formattedString)"
            if let response = response {
                result += response.formattedString
            }
            return result
        }
    }
}

/// 解析相关错误
public enum ParseError: Error {
    case invalidJSON(location: String, request: NetworkRequestDetail?, response: NetworkResponseDetail?)
    case missingRequiredField(field: String, location: String, response: NetworkResponseDetail?)
    case invalidDataFormat(expected: String, actual: String, location: String)
    case decodingFailed(type: String, location: String, response: NetworkResponseDetail?, underlyingError: Error)
    case regexMatchFailed(pattern: String, location: String, rawData: String?)

    /// 获取关联的 curl 命令
    public var curl: String? {
        switch self {
        case .invalidJSON(_, let request, _):
            return request?.curlCommand
        case .missingRequiredField, .invalidDataFormat, .decodingFailed, .regexMatchFailed:
            return nil
        }
    }

    var description: String {
        switch self {
        case .invalidJSON(let location, let request, let response):
            var result = "JSON解析失败 [\(formatLocation(location))]"
            if let request = request {
                result += request.formattedString
            }
            if let response = response {
                result += response.formattedString
            }
            return result
        case .missingRequiredField(let field, let location, let response):
            var result = "缺少必需字段: \(field) [\(formatLocation(location))]"
            if let response = response {
                result += response.formattedString
            }
            return result
        case .invalidDataFormat(let expected, let actual, let location):
            return "数据格式不正确 [\(formatLocation(location))]: 期望 \(expected), 实际 \(actual)"
        case .decodingFailed(let type, let location, let response, let error):
            var result = "解码失败: \(type) [\(formatLocation(location))]\n原因: \(error.localizedDescription)"
            if let response = response {
                result += response.formattedString
            }
            return result
        case .regexMatchFailed(let pattern, let location, let rawData):
            var result = "正则匹配失败 [\(formatLocation(location))]\n模式: \(pattern)"
            if let rawData = rawData {
                let truncated = rawData.count > 500 ? "\(rawData.prefix(500))...[已截断]" : rawData
                result += "\n原始数据: \(truncated)"
            }
            return result
        }
    }
}

/// 业务逻辑错误
public enum BusinessError: Error {
    case roomNotFound(roomId: String)
    case liveNotStarted(roomId: String)
    case permissionDenied(reason: String)
    case cookieExpired(platform: LiveType)
    case rateLimit(platform: LiveType, retryAfter: TimeInterval?)
    case platformMaintenance(platform: LiveType)
    case emptyResult(location: String, request: NetworkRequestDetail?)
    case apiError(code: Int, message: String, platform: String, location: String, request: NetworkRequestDetail?, response: NetworkResponseDetail?)

    /// 获取关联的 curl 命令
    public var curl: String? {
        switch self {
        case .emptyResult(_, let request):
            return request?.curlCommand
        case .apiError(_, _, _, _, let request, _):
            return request?.curlCommand
        case .roomNotFound, .liveNotStarted, .permissionDenied, .cookieExpired, .rateLimit, .platformMaintenance:
            return nil
        }
    }

    var description: String {
        switch self {
        case .roomNotFound(let roomId):
            return "直播间不存在: \(roomId)"
        case .liveNotStarted(let roomId):
            return "直播未开始: \(roomId)"
        case .permissionDenied(let reason):
            return "权限不足: \(reason)"
        case .cookieExpired(let platform):
            return "\(LiveParseTools.getLivePlatformName(platform))登录凭证已过期"
        case .rateLimit(let platform, let retryAfter):
            if let retryAfter = retryAfter {
                return "\(LiveParseTools.getLivePlatformName(platform))请求频率限制，请在 \(Int(retryAfter)) 秒后重试"
            }
            return "\(LiveParseTools.getLivePlatformName(platform))请求频率限制"
        case .platformMaintenance(let platform):
            return "\(LiveParseTools.getLivePlatformName(platform))正在维护中"
        case .emptyResult(let location, let request):
            var result = "返回结果为空 [\(formatLocation(location))]"
            if let request = request {
                result += request.formattedString
            }
            return result
        case .apiError(let code, let message, let platform, let location, let request, let response):
            var result = "\(platform) API 错误 [\(formatLocation(location))]\n"
            result += "错误代码: \(code)\n"
            result += "错误信息: \(message)"

            // 特殊错误码提示
            if platform.contains("Bilibili") || platform.contains("哔哩") {
                switch code {
                case 352:
                    result += "\n\n⚠️ 风控验证失败，请登录 B站 账号后重试"
                case 412:
                    result += "\n\n⚠️ 请求被拦截，可能需要人机验证"
                case -101:
                    result += "\n\n⚠️ 账号未登录"
                case -400:
                    result += "\n\n⚠️ 请求错误"
                case -404:
                    result += "\n\n⚠️ 无此项"
                default:
                    break
                }
            }

            if let request = request {
                result += request.formattedString
            }

            if let response = response {
                result += response.formattedString
            }

            return result
        }
    }
}

/// WebSocket 错误
public enum WebSocketError: Error {
    case connectionFailed(reason: String, platform: LiveType)
    case authenticationFailed(platform: LiveType, request: NetworkRequestDetail?)
    case messageDecodingFailed(platform: LiveType, rawData: Data?)
    case heartbeatTimeout(platform: LiveType)
    case reconnectExceeded(attempts: Int, platform: LiveType)

    /// 获取关联的 curl 命令
    public var curl: String? {
        switch self {
        case .authenticationFailed(_, let request):
            return request?.curlCommand
        case .connectionFailed, .messageDecodingFailed, .heartbeatTimeout, .reconnectExceeded:
            return nil
        }
    }

    var description: String {
        switch self {
        case .connectionFailed(let reason, let platform):
            return "\(LiveParseTools.getLivePlatformName(platform))弹幕连接失败: \(reason)"
        case .authenticationFailed(let platform, let request):
            var result = "\(LiveParseTools.getLivePlatformName(platform))弹幕认证失败"
            if let request = request {
                result += request.formattedString
            }
            return result
        case .messageDecodingFailed(let platform, let rawData):
            var result = "\(LiveParseTools.getLivePlatformName(platform))弹幕消息解析失败"
            if let rawData = rawData {
                result += "\n原始数据 (前100字节): \(rawData.prefix(100).map { String(format: "%02x", $0) }.joined(separator: " "))"
            }
            return result
        case .heartbeatTimeout(let platform):
            return "\(LiveParseTools.getLivePlatformName(platform))弹幕心跳超时"
        case .reconnectExceeded(let attempts, let platform):
            return "\(LiveParseTools.getLivePlatformName(platform))弹幕重连失败，已尝试 \(attempts) 次"
        }
    }
}

// MARK: - 增强的 LiveParseError

/// 扩展原有的 LiveParseError，添加新的错误类型
extension LiveParseError {
    // 从新的错误类型创建 LiveParseError
    public static func network(_ error: NetworkError) -> LiveParseError {
        return .liveParseError("网络错误", error.description)
    }

    public static func parse(_ error: ParseError) -> LiveParseError {
        return .liveParseError("解析错误", error.description)
    }

    public static func business(_ error: BusinessError) -> LiveParseError {
        return .liveParseError("业务错误", error.description)
    }

    public static func websocket(_ error: WebSocketError) -> LiveParseError {
        return .danmuArgsParseError("WebSocket错误", error.description)
    }

    /// 从错误详情中提取 curl 命令
    public var curl: String? {
        let detail = self.detail

        // 查找 "CURL 命令（可直接复制使用）:" 标记
        guard let curlStart = detail.range(of: "CURL 命令（可直接复制使用）:\n") else {
            return nil
        }

        let startIndex = curlStart.upperBound

        // 查找结束标记
        guard let endRange = detail[startIndex...].range(of: "\n====================") else {
            // 如果没有找到结束标记，取到字符串末尾
            return String(detail[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(detail[startIndex..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 用户友好的错误提示
    public var userFriendlyMessage: String {
        switch self {
        case .liveParseError:
            let detail = self.detail
            // 尝试提取简洁的错误信息
            if detail.contains("网络请求超时") {
                return "网络请求超时，请检查网络连接"
            } else if detail.contains("无网络连接") {
                return "网络连接失败，请检查网络设置"
            } else if detail.contains("服务器错误") {
                return "服务器响应异常，请稍后重试"
            } else if detail.contains("直播间不存在") {
                return "直播间不存在或已关闭"
            } else if detail.contains("登录凭证已过期") {
                return "登录已过期，请重新登录"
            } else if detail.contains("请求频率限制") {
                return "请求过于频繁，请稍后重试"
            } else {
                return "操作失败，请稍后重试"
            }
        case .shareCodeParseError:
            return "分享码解析失败，请检查分享码是否正确"
        case .liveStateParseError:
            return "获取直播状态失败"
        case .danmuArgsParseError:
            return "弹幕连接失败"
        }
    }

    // 恢复建议
    public var recoverySuggestion: String? {
        switch self {
        case .liveParseError:
            let detail = self.detail
            if detail.contains("网络请求超时") || detail.contains("无网络连接") {
                return "1. 检查WiFi或移动网络是否正常\n2. 尝试切换网络\n3. 检查是否需要代理"
            } else if detail.contains("登录凭证已过期") {
                return "请前往设置重新扫码登录"
            } else if detail.contains("请求频率限制") {
                return "请稍等片刻后再试"
            } else if detail.contains("服务器错误") {
                return "服务器可能正在维护，请稍后重试"
            }
            return nil
        case .shareCodeParseError:
            return "请确认分享码/链接是否完整和正确"
        case .danmuArgsParseError:
            return "请检查网络连接后重新打开直播间"
        default:
            return nil
        }
    }

    // 是否可以重试
    public var isRetryable: Bool {
        switch self {
        case .liveParseError:
            let detail = self.detail
            return detail.contains("网络请求超时") ||
                   detail.contains("请求频率限制") ||
                   detail.contains("服务器错误") ||
                   detail.contains("连接失败")
        case .liveStateParseError, .danmuArgsParseError:
            return true
        case .shareCodeParseError:
            return false
        }
    }
}

// MARK: - 日志系统

/// 日志级别
public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// 日志记录协议
public protocol LiveParseLogger {
    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int)
}

/// 默认日志实现
public class DefaultLiveParseLogger: LiveParseLogger {
    public init() {}

    public func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("\(level.emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    }
}

/// 全局日志配置
public class LiveParseConfig {
    /// 日志记录器
    public static var logger: LiveParseLogger = DefaultLiveParseLogger()

    /// 最小日志级别，低于此级别的日志不会被记录
    public static var logLevel: LogLevel = .debug

    /// 是否在错误日志中包含详细的请求/响应信息
    public static var includeDetailedNetworkInfo: Bool = true

    /// 是否在控制台打印日志
    public static var enableConsoleLog: Bool = true

    /// 自定义日志处理器（例如写入文件）
    public static var customLogHandler: ((LogLevel, String) -> Void)?

    /// 是否启用 JS 插件系统（JavaScriptCore）
    public static let enableJSPlugins: Bool = true

    /// 当插件执行失败时，是否回退到 Swift 内置实现
    public static let pluginFallbackToSwiftImplementation: Bool = false
}

// MARK: - 日志辅助函数

/// 记录调试日志
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    guard LiveParseConfig.logLevel <= .debug else { return }
    LiveParseConfig.logger.log(.debug, message: message, file: file, function: function, line: line)
    LiveParseConfig.customLogHandler?(.debug, message)
}

/// 记录信息日志
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    guard LiveParseConfig.logLevel <= .info else { return }
    LiveParseConfig.logger.log(.info, message: message, file: file, function: function, line: line)
    LiveParseConfig.customLogHandler?(.info, message)
}

/// 记录警告日志
func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    guard LiveParseConfig.logLevel <= .warning else { return }
    LiveParseConfig.logger.log(.warning, message: message, file: file, function: function, line: line)
    LiveParseConfig.customLogHandler?(.warning, message)
}

/// 记录错误日志
func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    guard LiveParseConfig.logLevel <= .error else { return }
    LiveParseConfig.logger.log(.error, message: message, file: file, function: function, line: line)
    LiveParseConfig.customLogHandler?(.error, message)
}

// MARK: - 辅助函数

/// 格式化位置信息，去掉文件路径和行号，只保留平台和函数名
/// - Parameter location: 原始位置信息，可能包含文件路径和行号（如 "/path/to/file.swift:123"）或函数名（如 "Platform.functionName"）
/// - Returns: 格式化后的位置信息（如 "Platform.functionName"）
private func formatLocation(_ location: String) -> String {
    // 如果已经是 "Platform.functionName" 格式，直接返回
    if !location.contains("/") && !location.contains(":") {
        return location
    }

    // 如果包含文件路径（如 "/path/to/Bilibili.swift:123"），提取文件名（去掉路径和行号）
    if location.contains("/") {
        // 提取文件名（去掉路径）
        let fileName = (location as NSString).lastPathComponent
        // 去掉 .swift 扩展名和行号
        if let dotIndex = fileName.firstIndex(of: ".") {
            return String(fileName[..<dotIndex])
        }
        // 去掉可能的行号
        if let colonIndex = fileName.firstIndex(of: ":") {
            return String(fileName[..<colonIndex])
        }
        return fileName
    }

    // 其他情况保持原样
    return location
}
