import Foundation

/// Static identity Spinefin reports to Jellyfin on every request.
///
/// Jellyfin uses these values to show the session on the server dashboard and to
/// tie a Quick Connect handshake to a specific device, so `deviceId` must stay
/// stable across launches (we persist a generated UUID).
enum DeviceInfo {
    static let client = "Spinefin"
    static let version = "0.1.0"
    static let deviceName = "iPhone"

    static var deviceId: String {
        let key = "spinefin.deviceId"
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }

    /// Builds the `Authorization` header value Jellyfin expects, e.g.
    /// `MediaBrowser Client="Spinefin", Device="iPhone", DeviceId="…", Version="0.1.0", Token="…"`.
    static func authorizationHeader(token: String?) -> String {
        var parts = [
            "Client=\"\(client)\"",
            "Device=\"\(deviceName)\"",
            "DeviceId=\"\(deviceId)\"",
            "Version=\"\(version)\"",
        ]
        if let token {
            parts.append("Token=\"\(token)\"")
        }
        return "MediaBrowser " + parts.joined(separator: ", ")
    }
}
