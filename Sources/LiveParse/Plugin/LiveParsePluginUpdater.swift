import CryptoKit
import Foundation

public final class LiveParsePluginUpdater: @unchecked Sendable {
    public let storage: LiveParsePluginStorage
    public let session: URLSession

    public init(storage: LiveParsePluginStorage, session: URLSession = .shared) {
        self.storage = storage
        self.session = session
    }

    public func fetchIndex(url: URL) async throws -> LiveParseRemotePluginIndex {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(LiveParseRemotePluginIndex.self, from: data)
    }

    public func downloadZip(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }

    public func install(item: LiveParseRemotePluginItem) async throws -> LiveParsePluginManifest {
        guard let url = URL(string: item.zipURL) else {
            throw LiveParsePluginError.installFailed("Invalid zipURL: \(item.zipURL)")
        }
        let zipData = try await downloadZip(url: url)

        let actual = sha256Hex(zipData)
        let expected = item.sha256.lowercased()
        if actual != expected {
            throw LiveParsePluginError.checksumMismatch(expected: expected, actual: actual)
        }

        return try LiveParsePluginInstaller.install(zipData: zipData, storage: storage)
    }

    public func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

