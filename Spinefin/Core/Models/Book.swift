import Foundation

/// View model for an audiobook. Built from sample data or mapped from a Jellyfin
/// `MusicAlbum` (`id` is the Jellyfin item id when live).
struct Book: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var author: String
    var narrator: String
    var duration: String
    var hue: Double = 28
    var coverURL: URL? = nil
    var overview: String? = nil
    var runTimeTicks: Int64? = nil
    var progress: Double? = nil
    var remaining: String? = nil
}

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    /// Sequential chapter number; `nil` for front/back-matter sections (credits, intro…).
    let displayNumber: Int?
    let duration: String
    /// Start offset within the source file (used for seeking single-file books).
    var startTicks: Int64? = nil

    var isSection: Bool { displayNumber == nil }

    /// Label for the player. Avoids redundant prefixing when the title already
    /// carries its own numbering (e.g. "Chapter One - …").
    var displayTitle: String {
        guard let number = displayNumber else { return title }
        let lower = title.lowercased()
        if lower.hasPrefix("chapter") || lower.hasPrefix("part ") || lower.hasPrefix("book ") {
            return title
        }
        return "Chapter \(number) · \(title)"
    }

    /// Front/back matter that shouldn't take a chapter number.
    static func isFrontBackMatter(_ title: String) -> Bool {
        let t = title.lowercased()
        let keys = ["credit", "introduction", "prologue", "foreword", "preface",
                    "epigraph", "dedication", "acknowledg", "epilogue", "afterword",
                    "about the author", "appendix", "copyright", "title page"]
        return keys.contains { t.contains($0) }
    }

    /// Builds a chapter list, numbering only real chapters (front/back matter is unnumbered).
    static func list(from items: [(title: String, durationTicks: Int64?, startTicks: Int64?)]) -> [Chapter] {
        var counter = 0
        return items.map { item in
            let section = isFrontBackMatter(item.title)
            let number: Int?
            if section {
                number = nil
            } else {
                counter += 1
                number = counter
            }
            return Chapter(title: item.title, displayNumber: number,
                           duration: TimeFormat.clock(ticks: item.durationTicks),
                           startTicks: item.startTicks)
        }
    }
}

enum DownloadState: Hashable {
    case done
    case downloading(progress: Double, transferred: String)
    case queued
}

struct DownloadItem: Identifiable, Hashable {
    let id = UUID()
    let book: Book
    let size: String
    let state: DownloadState
}

extension Book {
    /// Maps a Jellyfin album item to a Book. `api` supplies the cover URL.
    init(album: BaseItem, api: JellyfinAPI) {
        self.id = album.id
        self.title = album.name
        let artist = album.artists?.joined(separator: ", ") ?? album.albumArtist ?? ""
        self.author = artist
        self.narrator = ""
        self.duration = TimeFormat.duration(ticks: album.runTimeTicks)
        self.runTimeTicks = album.runTimeTicks
        self.overview = album.overview
        self.coverURL = api.primaryImageURL(itemId: album.id, tag: album.primaryImageTag)
        // Stable hue fallback (used only if the cover image fails to load).
        self.hue = Double(abs(album.id.hashValue) % 360)
    }
}
