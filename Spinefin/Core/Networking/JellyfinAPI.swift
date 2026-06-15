import Foundation

enum JellyfinError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(status: Int)
    case decoding(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "That doesn't look like a valid server address."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .http(let status) where status == 401:
            return "Incorrect username or password."
        case .http(let status):
            return "The server returned an error (HTTP \(status))."
        case .decoding:
            return "Couldn't read the server's response. Is this a Jellyfin server?"
        }
    }
}

/// A small, focused Jellyfin REST client covering the auth + onboarding surface.
/// Stateless and `Sendable`; pass a `token` once authenticated for signed requests.
struct JellyfinAPI: Sendable {
    let baseURL: URL
    var token: String?

    private let session: URLSession

    init(baseURL: URL, token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    // MARK: - Public endpoints

    /// Validates that the address points at a Jellyfin server.
    func publicSystemInfo() async throws -> PublicSystemInfo {
        try await get("System/Info/Public")
    }

    func authenticate(username: String, password: String) async throws -> AuthenticationResult {
        let body = try JSONSerialization.data(withJSONObject: ["Username": username, "Pw": password])
        return try await send("Users/AuthenticateByName", method: "POST", body: body)
    }

    // MARK: - Quick Connect

    func quickConnectEnabled() async throws -> Bool {
        let data = try await rawData(for: "QuickConnect/Enabled", method: "GET")
        return (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
    }

    func quickConnectInitiate() async throws -> QuickConnectResult {
        try await get("QuickConnect/Initiate")
    }

    func quickConnectState(secret: String) async throws -> QuickConnectResult {
        try await get("QuickConnect/Connect", query: [URLQueryItem(name: "secret", value: secret)])
    }

    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult {
        let body = try JSONSerialization.data(withJSONObject: ["Secret": secret])
        return try await send("Users/AuthenticateWithQuickConnect", method: "POST", body: body)
    }

    // MARK: - Request plumbing

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await send(path, method: "GET", query: query)
    }

    func send<T: Decodable>(
        _ path: String,
        method: String,
        body: Data? = nil,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await rawData(for: path, method: method, body: body, query: query)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw JellyfinError.decoding(underlying: error)
        }
    }

    func rawData(
        for path: String,
        method: String,
        body: Data? = nil,
        query: [URLQueryItem] = []
    ) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw JellyfinError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw JellyfinError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceInfo.authorizationHeader(token: token), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw JellyfinError.http(status: http.statusCode)
        }
        return data
    }
}
