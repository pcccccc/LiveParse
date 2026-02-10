import Foundation

public enum LiveParsePluginError: Error, LocalizedError, CustomStringConvertible {
    case invalidManifest(String)
    case incompatibleAPIVersion(expected: Int, actual: Int)
    case missingEntryFile(String)
    case pluginNotFound(String)
    case jsException(String)
    case invalidReturnValue(String)
    case checksumMismatch(expected: String, actual: String)
    case zipSlipDetected(String)
    case installFailed(String)

    public var errorDescription: String? { description }

    public var description: String {
        switch self {
        case .invalidManifest(let reason):
            return "Invalid manifest: \(reason)"
        case .incompatibleAPIVersion(let expected, let actual):
            return "Incompatible apiVersion. Expected \(expected), got \(actual)."
        case .missingEntryFile(let name):
            return "Missing entry file: \(name)"
        case .pluginNotFound(let pluginId):
            return "Plugin not found: \(pluginId)"
        case .jsException(let message):
            return "JS exception: \(message)"
        case .invalidReturnValue(let message):
            return "Invalid JS return value: \(message)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch. Expected \(expected), got \(actual)."
        case .zipSlipDetected(let path):
            return "Zip Slip detected for path: \(path)"
        case .installFailed(let reason):
            return "Install failed: \(reason)"
        }
    }
}

