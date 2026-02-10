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
}
