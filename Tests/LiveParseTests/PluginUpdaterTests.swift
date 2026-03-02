import Foundation
import Testing
@testable import LiveParse

private final class MockURLProtocol: URLProtocol {
    struct Stub {
        let data: Data?
        let statusCode: Int
        let error: Error?
    }

    private static let lock = NSLock()
    private static var stubs: [String: Stub] = [:]

    static func reset() {
        lock.lock()
        stubs = [:]
        lock.unlock()
    }

    static func register(url: String, data: Data? = nil, statusCode: Int = 200, error: Error? = nil) {
        lock.lock()
        stubs[url] = Stub(data: data, statusCode: statusCode, error: error)
        lock.unlock()
    }

    private static func stub(for url: URL) -> Stub? {
        lock.lock()
        defer { lock.unlock() }
        return stubs[url.absoluteString]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        guard let stub = Self.stub(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/zip"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

struct PluginUpdaterTests {
    @Test
    func remoteItemSupportsLegacySingleURL() throws {
        let json = """
        {
          "apiVersion": 1,
          "plugins": [
            {
              "pluginId": "huya",
              "version": "1.0.0",
              "platform": "huya",
              "platformName": "虎牙",
              "icon": "https://cdn.example.com/icons/huya.png",
              "iosIcon": "pad_live_card_huya",
              "macosIcon": "mini_live_card_huya",
              "tvosIcon": "live_card_huya",
              "tvosBigIcon": "tv_huya_big",
              "tvosSmallIcon": "tv_huya_small",
              "tvosBigIconDark": "tv_huya_big_dark",
              "tvosSmallIconDark": "tv_huya_small_dark",
              "zipURL": "https://example.com/huya.zip",
              "sha256": "abc123"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let index = try JSONDecoder().decode(LiveParseRemotePluginIndex.self, from: data)

        #expect(index.plugins.count == 1)
        #expect(index.plugins[0].downloadURLs == ["https://example.com/huya.zip"])
        #expect(index.plugins[0].platform == "huya")
        #expect(index.plugins[0].platformName == "虎牙")
        #expect(index.plugins[0].iosIcon == "pad_live_card_huya")
        #expect(index.plugins[0].macosIcon == "mini_live_card_huya")
        #expect(index.plugins[0].tvosIcon == "live_card_huya")
        #expect(index.plugins[0].tvosBigIcon == "tv_huya_big")
        #expect(index.plugins[0].tvosSmallIcon == "tv_huya_small")
        #expect(index.plugins[0].tvosBigIconDark == "tv_huya_big_dark")
        #expect(index.plugins[0].tvosSmallIconDark == "tv_huya_small_dark")
    }

    @Test
    func remoteItemPrefersMirrorListAndDeduplicates() throws {
        let json = """
        {
          "apiVersion": 1,
          "plugins": [
            {
              "pluginId": "huya",
              "version": "1.0.0",
              "zipURLs": [
                "https://mirror-cn.example.com/huya.zip",
                "https://github.com/org/repo/releases/download/v1/huya.zip"
              ],
              "zipURL": "https://mirror-cn.example.com/huya.zip",
              "sha256": "abc123"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let index = try JSONDecoder().decode(LiveParseRemotePluginIndex.self, from: data)
        let urls = index.plugins[0].downloadURLs

        #expect(urls == [
            "https://mirror-cn.example.com/huya.zip",
            "https://github.com/org/repo/releases/download/v1/huya.zip"
        ])
    }

    @Test
    func remoteItemRequiresAtLeastOneDownloadURL() {
        let json = """
        {
          "apiVersion": 1,
          "plugins": [
            {
              "pluginId": "huya",
              "version": "1.0.0",
              "sha256": "abc123"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        var didThrow = false
        do {
            _ = try JSONDecoder().decode(LiveParseRemotePluginIndex.self, from: data)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test
    func updaterFallsBackToNextMirrorWhenPrimaryFails() async throws {
        MockURLProtocol.reset()

        let primary = "https://primary.example.com/plugin.zip"
        let mirror = "https://mirror.example.com/plugin.zip"
        let expectedData = Data("valid-plugin-zip".utf8)

        MockURLProtocol.register(url: primary, error: URLError(.cannotConnectToHost))
        MockURLProtocol.register(url: mirror, data: expectedData)

        let updater = try makeUpdater()
        let item = LiveParseRemotePluginItem(
            pluginId: "huya",
            version: "1.0.0",
            zipURLs: [primary, mirror],
            sha256: updater.sha256Hex(expectedData)
        )

        let downloaded = try await updater.downloadVerifiedZip(item: item)
        #expect(downloaded == expectedData)
    }

    @Test
    func updaterFallsBackOnChecksumMismatch() async throws {
        MockURLProtocol.reset()

        let primary = "https://primary.example.com/plugin.zip"
        let mirror = "https://mirror.example.com/plugin.zip"
        let badData = Data("bad-data".utf8)
        let goodData = Data("good-data".utf8)

        MockURLProtocol.register(url: primary, data: badData)
        MockURLProtocol.register(url: mirror, data: goodData)

        let updater = try makeUpdater()
        let item = LiveParseRemotePluginItem(
            pluginId: "huya",
            version: "1.0.0",
            zipURLs: [primary, mirror],
            sha256: updater.sha256Hex(goodData)
        )

        let downloaded = try await updater.downloadVerifiedZip(item: item)
        #expect(downloaded == goodData)
    }

    @Test
    func updaterFailsWhenNoDownloadURLAvailable() async throws {
        let updater = try makeUpdater()
        let item = LiveParseRemotePluginItem(
            pluginId: "huya",
            version: "1.0.0",
            sha256: "abc123"
        )

        var installError: LiveParsePluginError?
        do {
            _ = try await updater.downloadVerifiedZip(item: item)
        } catch let error as LiveParsePluginError {
            installError = error
        } catch {
            // ignore other types
        }

        if case .installFailed = installError {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func updaterPersistsLastGoodVersion() throws {
        let updater = try makeUpdater()
        try updater.persistLastGoodVersion(pluginId: "huya", version: "1.2.3")

        let state = updater.storage.loadState()
        #expect(state.plugins["huya"]?.lastGoodVersion == "1.2.3")
    }

    @Test
    func updaterRemovesInstalledVersionDirectory() throws {
        let updater = try makeUpdater()
        let dir = updater.storage.pluginVersionDirectory(pluginId: "huya", version: "9.9.9")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #expect(FileManager.default.fileExists(atPath: dir.path))

        try updater.removeInstalledVersion(pluginId: "huya", version: "9.9.9")
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test
    func smokeTestInstalledPluginRunsPing() async throws {
        let updater = try makeUpdater()
        let manifest = try createTestPluginFiles(updater: updater, pluginId: "demo", version: "1.0.0")

        try await updater.smokeTestInstalledPlugin(
            manifest: manifest,
            function: "ping",
            payload: ["value": 1],
            session: makeSession()
        )
        #expect(Bool(true))
    }
}

private extension PluginUpdaterTests {
    func makeUpdater() throws -> LiveParsePluginUpdater {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveParsePluginUpdaterTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = try LiveParsePluginStorage(baseDirectory: base)
        return LiveParsePluginUpdater(storage: storage, session: makeSession())
    }

    func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func createTestPluginFiles(
        updater: LiveParsePluginUpdater,
        pluginId: String,
        version: String
    ) throws -> LiveParsePluginManifest {
        let root = updater.storage.pluginVersionDirectory(pluginId: pluginId, version: version)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let entryURL = root.appendingPathComponent("index.js", isDirectory: false)
        let script = """
        globalThis.LiveParsePlugin = {
          apiVersion: 1,
          ping(payload) { return { ok: true, echo: payload }; }
        };
        """
        try script.write(to: entryURL, atomically: true, encoding: .utf8)

        return LiveParsePluginManifest(
            pluginId: pluginId,
            version: version,
            apiVersion: 1,
            liveTypes: ["1"],
            entry: "index.js"
        )
    }
}
