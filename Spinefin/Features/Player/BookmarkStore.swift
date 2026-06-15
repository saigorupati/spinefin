import Foundation
import Observation

struct Bookmark: Codable, Identifiable, Hashable {
    var id = UUID()
    let bookId: String
    let bookTitle: String
    let positionSeconds: Double
    let chapterTitle: String
    let createdAt: Date
}

/// Local store of user bookmarks (Jellyfin has no audio-bookmark concept).
@MainActor
@Observable
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []
    private let defaultsKey = "spinefin.bookmarks"

    init() { load() }

    func bookmarks(forBook bookId: String) -> [Bookmark] {
        bookmarks.filter { $0.bookId == bookId }.sorted { $0.positionSeconds < $1.positionSeconds }
    }

    @discardableResult
    func add(bookId: String, bookTitle: String, positionSeconds: Double, chapterTitle: String) -> Bookmark {
        let bookmark = Bookmark(bookId: bookId, bookTitle: bookTitle,
                                positionSeconds: positionSeconds, chapterTitle: chapterTitle,
                                createdAt: Date())
        bookmarks.append(bookmark)
        persist()
        return bookmark
    }

    func delete(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else { return }
        bookmarks = decoded
    }
}
