import Foundation

/// Audiobook browsing endpoints: libraries → albums (books) → audio (chapters),
/// plus image and stream URL builders.
extension JellyfinAPI {
    /// The user's top-level libraries.
    func userViews(userId: String) async throws -> [BaseItem] {
        let response: ItemsResponse = try await get("Users/\(userId)/Views")
        return response.items
    }

    /// Albums (= audiobooks) inside a library.
    func albums(parentId: String, userId: String) async throws -> [BaseItem] {
        let response: ItemsResponse = try await get("Users/\(userId)/Items", query: [
            .init(name: "ParentId", value: parentId),
            .init(name: "IncludeItemTypes", value: "MusicAlbum"),
            .init(name: "Recursive", value: "true"),
            .init(name: "SortBy", value: "SortName"),
            .init(name: "Fields", value: "Overview,RunTimeTicks,ProductionYear,Artists,AlbumArtist"),
            .init(name: "ImageTypeLimit", value: "1"),
        ])
        return response.items
    }

    /// Ordered audio tracks (= chapters) within a book.
    func tracks(albumId: String, userId: String) async throws -> [BaseItem] {
        let response: ItemsResponse = try await get("Users/\(userId)/Items", query: [
            .init(name: "ParentId", value: albumId),
            .init(name: "IncludeItemTypes", value: "Audio"),
            .init(name: "SortBy", value: "ParentIndexNumber,IndexNumber,SortName"),
            .init(name: "Fields", value: "RunTimeTicks"),
        ])
        return response.items
    }

    // MARK: - URLs

    /// Primary cover image URL for an item.
    func primaryImageURL(itemId: String, tag: String?, maxWidth: Int = 500) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("Items/\(itemId)/Images/Primary"), resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = [.init(name: "fillWidth", value: String(maxWidth)), .init(name: "quality", value: "90")]
        if let tag { query.append(.init(name: "tag", value: tag)) }
        if let token { query.append(.init(name: "api_key", value: token)) }
        components?.queryItems = query
        return components?.url
    }

    /// Raw original-file download URL (preserves embedded chapters; used for
    /// chapter extraction and offline downloads).
    func downloadURL(itemId: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("Items/\(itemId)/Download"), resolvingAgainstBaseURL: false)
        if let token { components?.queryItems = [.init(name: "api_key", value: token)] }
        return components?.url
    }

    /// Direct audio stream URL for a track (used by the playback engine later).
    func audioStreamURL(itemId: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("Audio/\(itemId)/universal"), resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = [
            .init(name: "Container", value: "mp3,aac,m4a,m4b,flac,ogg,wav"),
            .init(name: "AudioCodec", value: "aac"),
            .init(name: "DeviceId", value: DeviceInfo.deviceId),
        ]
        if let token { query.append(.init(name: "api_key", value: token)) }
        components?.queryItems = query
        return components?.url
    }
}
