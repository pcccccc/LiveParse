import Foundation
import SWCompression

public enum LiveParsePluginInstaller {
    public static func install(zipData: Data, storage: LiveParsePluginStorage) throws -> LiveParsePluginManifest {
        try storage.ensureDirectories()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveParsePluginInstall", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try extract(zipData: zipData, to: tempRoot)

        let manifestURL = tempRoot.appendingPathComponent("manifest.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw LiveParsePluginError.invalidManifest("manifest.json not found")
        }
        let manifest = try LiveParsePluginManifest.load(from: manifestURL)

        let destination = storage.pluginVersionDirectory(pluginId: manifest.pluginId, version: manifest.version)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempRoot, to: destination)
        return manifest
    }

    public static func extract(zipData: Data, to destinationDirectory: URL) throws {
        let entries = try ZipContainer.open(container: zipData)

        for entry in entries {
            let relativePath = try sanitize(relativePath: entry.info.name)
            let targetURL = destinationDirectory.appendingPathComponent(relativePath, isDirectory: entry.info.type == .directory)

            if entry.info.type == .directory {
                try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
                continue
            }

            guard let data = entry.data else {
                continue
            }
            try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: targetURL, options: [.atomic])
        }
    }

    private static func sanitize(relativePath: String) throws -> String {
        if relativePath.hasPrefix("/") {
            throw LiveParsePluginError.zipSlipDetected(relativePath)
        }
        let components = relativePath.split(separator: "/").map(String.init)
        if components.contains("..") {
            throw LiveParsePluginError.zipSlipDetected(relativePath)
        }
        return components.joined(separator: "/")
    }
}

