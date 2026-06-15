import Foundation

/// Placeholder content mirroring the Claude Design mockups. Replaced by live
/// Jellyfin data in later phases — keep all sample content here so it's easy to find.
enum SampleData {
    static let books: [Book] = [
        Book(title: "Tidewater", author: "Marin Vale", narrator: "Imogen Frost", duration: "9h 12m", hue: 28),
        Book(title: "The Lantern Keeper", author: "E. R. Hollis", narrator: "Bram Cole", duration: "11h 04m", hue: 204),
        Book(title: "North of Anywhere", author: "Dahlia Quist", narrator: "Saoirse Lin", duration: "7h 48m", hue: 158),
        Book(title: "Slow Mornings", author: "Jonah Reed", narrator: "Theo Hart", duration: "6h 21m", hue: 96),
        Book(title: "The Copper Sea", author: "Amina Okafor", narrator: "Nadia Rue", duration: "13h 36m", hue: 14),
        Book(title: "Field Notes on Quiet", author: "Søren Aalto", narrator: "Elias Ward", duration: "5h 09m", hue: 262),
        Book(title: "Hollow & Hearth", author: "Margaret Stone", narrator: "June Park", duration: "10h 27m", hue: 338),
        Book(title: "Driftwood Almanac", author: "P. J. Lund", narrator: "Cassius Bell", duration: "8h 53m", hue: 222),
    ]

    static let continueListening: [Book] = [
        books[0].with(progress: 0.62, remaining: "3h 24m left"),
        books[2].with(progress: 0.28, remaining: "5h 36m left"),
        books[4].with(progress: 0.81, remaining: "2h 41m left"),
        books[7].with(progress: 0.14, remaining: "7h 38m left"),
    ]

    static let nowPlaying = books[0]

    static let chapters: [Chapter] = [
        Chapter(title: "The Harbour at Dawn", displayNumber: 1, duration: "42:18"),
        Chapter(title: "Saltlines", displayNumber: 2, duration: "38:05"),
        Chapter(title: "A Borrowed Boat", displayNumber: 3, duration: "51:44"),
        Chapter(title: "Low Water", displayNumber: 4, duration: "29:57"),
        Chapter(title: "The Ferryman", displayNumber: 5, duration: "47:12"),
        Chapter(title: "Northerly", displayNumber: 6, duration: "36:40"),
        Chapter(title: "The Crossing", displayNumber: 7, duration: "58:42"),
        Chapter(title: "Deep Channel", displayNumber: 8, duration: "44:09"),
        Chapter(title: "Landfall", displayNumber: 9, duration: "39:53"),
    ]

    static let downloads: [DownloadItem] = [
        DownloadItem(book: books[0], size: "214 MB", state: .done),
        DownloadItem(book: books[4], size: "318 MB", state: .done),
        DownloadItem(book: books[2], size: "182 MB", state: .downloading(progress: 0.46, transferred: "84 / 182 MB")),
        DownloadItem(book: books[7], size: "205 MB", state: .queued),
    ]
}

extension Book {
    func with(progress: Double, remaining: String) -> Book {
        var copy = self
        copy.progress = progress
        copy.remaining = remaining
        return copy
    }
}
