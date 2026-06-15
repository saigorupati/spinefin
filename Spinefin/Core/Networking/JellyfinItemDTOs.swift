import Foundation

/// Subset of Jellyfin's BaseItemDto covering audiobook browsing.
struct BaseItem: Decodable, Sendable {
    let id: String
    let name: String
    let type: String?
    let collectionType: String?
    let runTimeTicks: Int64?
    let indexNumber: Int?
    let productionYear: Int?
    let overview: String?
    let artists: [String]?
    let albumArtist: String?
    let album: String?
    let albumId: String?
    let imageTags: [String: String]?
    let userData: ItemUserData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case collectionType = "CollectionType"
        case runTimeTicks = "RunTimeTicks"
        case indexNumber = "IndexNumber"
        case productionYear = "ProductionYear"
        case overview = "Overview"
        case artists = "Artists"
        case albumArtist = "AlbumArtist"
        case album = "Album"
        case albumId = "AlbumId"
        case imageTags = "ImageTags"
        case userData = "UserData"
    }

    var primaryImageTag: String? { imageTags?["Primary"] }
}

struct ItemUserData: Decodable, Sendable {
    let playbackPositionTicks: Int64?
    let playedPercentage: Double?
    let played: Bool?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playedPercentage = "PlayedPercentage"
        case played = "Played"
    }
}

/// Standard `{ Items: [...], TotalRecordCount }` envelope.
struct ItemsResponse: Decodable, Sendable {
    let items: [BaseItem]
    let totalRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
