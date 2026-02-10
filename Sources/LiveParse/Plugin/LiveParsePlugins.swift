import Foundation

/// 全局插件系统入口。
///
/// 说明：`LiveParsePluginManager` 自带插件缓存（JSContext 等），但如果每次调用都重新创建 manager，会导致缓存失效。
/// 因此提供一个共享实例给各平台调用。
public enum LiveParsePlugins {
    public static let shared: LiveParsePluginManager = {
        // applicationSupportDirectory 创建失败的概率极低；如果确实失败，说明运行环境异常。
        // 这里用 try! 简化上层调用。
        return try! LiveParsePluginManager()
    }()
}

