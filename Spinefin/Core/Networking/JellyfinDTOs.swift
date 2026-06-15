import Foundation

/// Minimal Jellyfin response models for the auth + onboarding surface.
/// Jellyfin returns PascalCase JSON keys, mapped explicitly below.

struct PublicSystemInfo: Decodable, Sendable {
    let serverName: String?
    let version: String?
    let id: String?
    let productName: String?

    enum CodingKeys: String, CodingKey {
        case serverName = "ServerName"
        case version = "Version"
        case id = "Id"
        case productName = "ProductName"
    }
}

struct UserDto: Decodable, Sendable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct AuthenticationResult: Decodable, Sendable {
    let accessToken: String
    let serverId: String?
    let user: UserDto

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case serverId = "ServerId"
        case user = "User"
    }
}

struct QuickConnectResult: Decodable, Sendable {
    let authenticated: Bool
    let secret: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case authenticated = "Authenticated"
        case secret = "Secret"
        case code = "Code"
    }
}
