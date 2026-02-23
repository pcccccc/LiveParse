import Foundation
import Testing
@testable import LiveParse

struct PluginSystemTests {
    @Test
    func jsRuntimeSyncCall() async throws {
        let runtime = JSRuntime()
        try await runtime.evaluate(script: """
        globalThis.LiveParsePlugin = {
          apiVersion: 1,
          ping(payload) { return { ok: true, echo: payload }; }
        };
        """)

        let result = try await runtime.callPluginFunction(name: "ping", payload: ["a": 1])
        let dict = try #require(result as? [String: Any])
        #expect((dict["ok"] as? Bool) == true)
        let echo = try #require(dict["echo"] as? [String: Any])
        #expect((echo["a"] as? Int) == 1)
    }

    @Test
    func jsRuntimePromiseCall() async throws {
        let runtime = JSRuntime()
        try await runtime.evaluate(script: """
        globalThis.LiveParsePlugin = {
          apiVersion: 1,
          pingAsync(payload) { return Promise.resolve({ ok: true, echo: payload, async: true }); }
        };
        """)

        let result = try await runtime.callPluginFunction(name: "pingAsync", payload: ["b": "x"]) 
        let dict = try #require(result as? [String: Any])
        #expect((dict["async"] as? Bool) == true)
        let echo = try #require(dict["echo"] as? [String: Any])
        #expect((echo["b"] as? String) == "x")
    }

    @Test
    func builtInExamplePluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "example")
        #expect(plugin.manifest.pluginId == "example")
        try await plugin.load()
    }

    @Test
    func builtInDouyuPluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "douyu")
        #expect(plugin.manifest.pluginId == "douyu")
        try await plugin.load()
    }

    @Test
    func builtInCCPluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "cc")
        #expect(plugin.manifest.pluginId == "cc")
        try await plugin.load()
    }

    @Test
    func builtInYYPluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "yy")
        #expect(plugin.manifest.pluginId == "yy")
        try await plugin.load()
    }

    @Test
    func builtInKuaiShouPluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "ks")
        #expect(plugin.manifest.pluginId == "ks")
        try await plugin.load()
    }

    @Test
    func builtInBilibiliPluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "bilibili")
        #expect(plugin.manifest.pluginId == "bilibili")
        try await plugin.load()
    }

    @Test
    func builtInDouyinPluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "douyin")
        #expect(plugin.manifest.pluginId == "douyin")
        try await plugin.load()
    }

    @Test
    func builtInDouyinPluginCategoryCatalogNotTruncated() async throws {
        let manager = try LiveParsePluginManager()
        let categories: [LiveMainListModel] = try await manager.callDecodable(
            pluginId: "douyin",
            function: "getCategoryList",
            payload: [:]
        )

        #expect(categories.count >= 10)
        let ids = Set(categories.map(\.id))
        #expect(ids.contains("1"))   // 游戏子分类（射击游戏）
        #expect(ids.contains("108")) // 运动
    }
    @Test
    func builtInYoutubePluginResolvable() async throws {
        let manager = try LiveParsePluginManager()
        let plugin = try manager.resolve(pluginId: "youtube")
        #expect(plugin.manifest.pluginId == "youtube")
        try await plugin.load()
    }

    @Test
    func jsPlatformManagerMarksEightPlatforms() async throws {
        let infos = LiveParseJSPlatformManager.availablePlatformInfos()
        #expect(infos.count == 8)

        let pluginIds = Set(infos.map(\.pluginId))
        #expect(pluginIds == Set(["bilibili", "huya", "douyin", "douyu", "cc", "ks", "yy", "youtube"]))
    }
}
