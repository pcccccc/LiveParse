import Foundation

/// 全局插件系统入口。
///
/// 说明：`LiveParsePluginManager` 自带插件缓存（JSContext 等），但如果每次调用都重新创建 manager，会导致缓存失效。
/// 因此提供一个共享实例给各平台调用。
public enum LiveParsePlugins {
    public static let shared: LiveParsePluginManager = {
        // 使用独立的 URLSession，禁用自动 cookie 管理，
        // 避免 HTTPCookieStorage 干扰插件手动设置的 Cookie header。
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config)

        return try! LiveParsePluginManager(session: session, logHandler: { msg in
            print("[LiveParse:JS] \(msg)")
        })
    }()
}

