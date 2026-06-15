import Foundation
import Observation

/// Source of truth for which servers Spinefin is signed into and which one is active.
/// Persists the server list (including access tokens) to the keychain.
@MainActor
@Observable
final class AuthStore {
    private(set) var servers: [ServerConnection] = []
    private(set) var activeServerID: String?

    var activeServer: ServerConnection? {
        servers.first { $0.id == activeServerID }
    }

    var isAuthenticated: Bool { activeServer != nil }

    private let keychain = KeychainStore(service: "com.spinefin.app")
    private let serversKey = "servers"
    private let activeKey = "spinefin.activeServerID"

    init() {
        load()
    }

    #if DEBUG
    /// In-memory store seeded with a stub server, for the screenshot preview harness.
    /// Does not touch the keychain.
    private init(previewServer: ServerConnection) {
        servers = [previewServer]
        activeServerID = previewServer.id
    }

    static func preview() -> AuthStore {
        AuthStore(previewServer: ServerConnection(
            serverName: "Demo",
            baseURLString: "https://demo.example.com",
            userId: "preview-user",
            username: "demo",
            accessToken: "preview",
            serverId: "preview"
        ))
    }

    static func preview(server: ServerConnection) -> AuthStore {
        AuthStore(previewServer: server)
    }
    #endif

    private func load() {
        if let data = keychain.read(key: serversKey),
           let decoded = try? JSONDecoder().decode([ServerConnection].self, from: data) {
            servers = decoded
        }
        let storedActive = UserDefaults.standard.string(forKey: activeKey)
        activeServerID = servers.contains { $0.id == storedActive } ? storedActive : servers.first?.id
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(servers) {
            keychain.write(data, key: serversKey)
        }
        UserDefaults.standard.set(activeServerID, forKey: activeKey)
    }

    func add(_ server: ServerConnection) {
        servers.removeAll { $0.id == server.id }
        servers.append(server)
        activeServerID = server.id
        persist()
    }

    func setActive(_ server: ServerConnection) {
        guard servers.contains(where: { $0.id == server.id }) else { return }
        activeServerID = server.id
        persist()
    }

    func signOut(_ server: ServerConnection) {
        servers.removeAll { $0.id == server.id }
        if activeServerID == server.id {
            activeServerID = servers.first?.id
        }
        persist()
    }

    func signOutActive() {
        guard let active = activeServer else { return }
        signOut(active)
    }
}
