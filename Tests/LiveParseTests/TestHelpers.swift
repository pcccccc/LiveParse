import Foundation
import Testing
@testable import LiveParse

/// 打印增强后的 LiveParseError 详情，便于调试测试失败。
func printEnhancedError(_ error: LiveParseError, title: String = "错误详情") {
    print("\n" + String(repeating: "═", count: 60))
    print("   \(title)")
    print(String(repeating: "═", count: 60))

    print("\n🏷️ 错误标题:")
    print("   \(error.title)")

    print("\n📌 用户友好提示:")
    print("   \(error.userFriendlyMessage)")

    print("\n🔄 是否可重试:")
    print("   \(error.isRetryable ? "✅ 是" : "❌ 否")")

    if let suggestion = error.recoverySuggestion {
        print("\n💡 恢复建议:")
        suggestion.split(separator: "\n").forEach { line in
            print("   \(line)")
        }
    }

    print("\n📋 完整错误描述:")
    error.description.split(separator: "\n").forEach { line in
        print("   \(line)")
    }

    print("\n📄 错误详情内容:")
    error.detail.split(separator: "\n").forEach { line in
        print("   \(line)")
    }

    print("\n" + String(repeating: "═", count: 60))
}

/// 断言当前测试运行在“纯插件模式”，禁止走原生 fallback。
func assertPurePluginMode(platform: String) {
    #expect(LiveParseConfig.enableJSPlugins, "\(platform) 测试要求开启 JS 插件")
    #expect(!LiveParseConfig.pluginFallbackToSwiftImplementation, "\(platform) 测试要求关闭原生 fallback")
}
