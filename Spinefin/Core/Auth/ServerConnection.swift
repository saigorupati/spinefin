import Foundation

/// A persisted, authenticated connection to one Jellyfin server for one user.
/// Spinefin supports several of these at once (multi-server).
struct ServerConnection: Codable, Identifiable, Hashable, Sendable {
    /// Composite of user + server so the same person on two servers stays distinct.
    let id: String
    var serverName: String
    var baseURLString: String
    var userId: String
    var username: String
    var accessToken: String

    var baseURL: URL? { URL(string: baseURLString) }

    init(
        serverName: String,
        baseURLString: String,
        userId: String,
        username: String,
        accessToken: String,
        serverId: String?
    ) {
        self.id = "\(userId)@\(serverId ?? baseURLString)"
        self.serverName = serverName
        self.baseURLString = baseURLString
        self.userId = userId
        self.username = username
        self.accessToken = accessToken
    }
}
