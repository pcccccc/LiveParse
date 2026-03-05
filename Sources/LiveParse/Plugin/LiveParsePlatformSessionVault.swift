import Foundation

struct LiveParsePlatformSession: Sendable {
    let cookie: String
    let uid: String?
    let updatedAt: Date
}

enum LiveParsePlatformSessionVault {
    private static let lock = NSLock()
    private static var sessions: [String: LiveParsePlatformSession] = [:]

    static func update(platformId: String, cookie: String, uid: String?) {
        let normalizedId = canonicalPlatformId(platformId)
        guard !normalizedId.isEmpty else { return }

        let normalizedCookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        if normalizedCookie.isEmpty {
            sessions.removeValue(forKey: normalizedId)
        } else {
            sessions[normalizedId] = LiveParsePlatformSession(
                cookie: normalizedCookie,
                uid: uid?.trimmingCharacters(in: .whitespacesAndNewlines),
                updatedAt: Date()
            )
        }
        lock.unlock()
    }

    static func clear(platformId: String) {
        let normalizedId = canonicalPlatformId(platformId)
        guard !normalizedId.isEmpty else { return }
        lock.lock()
        sessions.removeValue(forKey: normalizedId)
        lock.unlock()
    }

    static func mergedCookieHeader(for platformId: String) -> String? {
        let normalizedId = canonicalPlatformId(platformId)
        guard !normalizedId.isEmpty else { return nil }

        var parts: [String] = []
        if let defaultCookie = defaultCookie(for: normalizedId), !defaultCookie.isEmpty {
            parts.append(defaultCookie)
        }

        lock.lock()
        let sessionCookie = sessions[normalizedId]?.cookie
        lock.unlock()

        if let sessionCookie, !sessionCookie.isEmpty {
            parts.append(sessionCookie)
        }

        let merged = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")

        return merged.isEmpty ? nil : merged
    }

    static func canonicalPlatformId(_ platformId: String) -> String {
        let raw = platformId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "kuaishou":
            return "ks"
        default:
            return raw
        }
    }

    private static func defaultCookie(for platformId: String) -> String? {
        switch platformId {
        case "soop":
            return "AbroadChk=OK"
        default:
            return nil
        }
    }
}
