import Foundation
import Observation

/// Loads and holds the active server's audiobook library. Replaces SampleData
/// for the Library and Book Detail screens.
@MainActor
@Observable
final class LibraryStore {
    private(set) var books: [Book] = []
    private(set) var continueListening: [Book] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded = false

    private var api: JellyfinAPI?
    private var server: ServerConnection?
    weak var downloads: DownloadManager?

    var serverID: String? { server?.id }

    // Local playback progress (Jellyfin can't store resume for Music libraries).
    struct ProgressEntry: Codable { var seconds: Double; var duration: Double; var updatedAt: Date }
    private var progress: [String: ProgressEntry] = [:]
    private let progressDefaultsKey = "spinefin.progress"

    init() {
        loadPersistedProgress()
    }

    /// Point the store at a server. Resets cached content when the server changes.
    func configure(_ server: ServerConnection?) {
        guard let server, let url = server.baseURL else {
            api = nil; self.server = nil
            return
        }
        if self.server?.id == server.id { return }
        self.server = server
        self.api = JellyfinAPI(baseURL: url, token: server.accessToken)
        books = []; continueListening = []; hasLoaded = false; errorMessage = nil
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await load()
    }

    func load() async {
        guard let api, let server else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let views = try await api.userViews(userId: server.userId)
            let musicLibraries = views.filter { $0.collectionType == "music" }
            var loaded: [Book] = []
            for library in musicLibraries {
                let albums = try await api.albums(parentId: library.id, userId: server.userId)
                loaded.append(contentsOf: albums.map { Book(album: $0, api: api) })
            }
            books = loaded
            refreshContinueListening()
            hasLoaded = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load your library."
        }
    }

    // MARK: - Local progress (resume + Continue Listening)

    private func progressKey(_ bookId: String) -> String { "\(server?.id ?? "")|\(bookId)" }

    /// Saved resume position (seconds) for a book, if any.
    func savedPosition(_ bookId: String) -> Double? {
        progress[progressKey(bookId)]?.seconds
    }

    /// Persists playback position; refreshes Continue Listening.
    func saveProgress(bookId: String, seconds: Double, duration: Double) {
        guard server != nil, duration > 0 else { return }
        progress[progressKey(bookId)] = ProgressEntry(seconds: seconds, duration: duration, updatedAt: Date())
        persistProgress()
        refreshContinueListening()
    }

    func clearProgress(bookId: String) {
        progress[progressKey(bookId)] = nil
        persistProgress()
        refreshContinueListening()
    }

    func markFinished(bookId: String, durationSeconds: Double) {
        guard server != nil, durationSeconds > 0 else { return }
        progress[progressKey(bookId)] = ProgressEntry(seconds: durationSeconds, duration: durationSeconds, updatedAt: Date())
        persistProgress()
        refreshContinueListening()
    }

    private func refreshContinueListening() {
        let prefix = "\(server?.id ?? "")|"
        let active = progress
            .filter { $0.key.hasPrefix(prefix) && $0.value.seconds > 5 && $0.value.seconds < $0.value.duration * 0.98 }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
        continueListening = active.compactMap { entry in
            let bookId = String(entry.key.dropFirst(prefix.count))
            guard var book = books.first(where: { $0.id == bookId }) else { return nil }
            let fraction = entry.value.duration > 0 ? entry.value.seconds / entry.value.duration : 0
            book.progress = fraction
            book.remaining = TimeFormat.remaining(totalTicks: Int64(entry.value.duration * 1e7), progress: fraction)
            return book
        }
    }

    private func loadPersistedProgress() {
        guard let data = UserDefaults.standard.data(forKey: progressDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: ProgressEntry].self, from: data) else { return }
        progress = decoded
    }

    private func persistProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressDefaultsKey)
        }
    }

    /// Chapters for a book. Multi-file books use their ordered tracks; single-file
    /// books extract embedded chapter markers from the file (falling back to one
    /// chapter if the file has none).
    func chapters(for book: Book) async throws -> [Chapter] {
        try await playable(for: book).chapters
    }

    /// Resolves a book into a playable timeline for the playback engine.
    func playable(for book: Book) async throws -> PlayableBook {
        guard let api, let server else {
            throw JellyfinError.invalidResponse
        }
        // Fully offline if the book is downloaded — no network needed.
        if let offline = downloads?.offlinePlayable(server.id, book: book) {
            return offline
        }
        let tracks = try await api.tracks(albumId: book.id, userId: server.userId)

        func seconds(_ ticks: Int64?) -> Double {
            guard let ticks else { return 0 }
            return Double(ticks) / Double(TimeFormat.ticksPerSecond)
        }

        // Prefer a local file when the book has been downloaded.
        let serverId = server.id
        func itemURL(_ itemId: String) -> URL? {
            if let local = downloads?.localURL(serverId, bookId: book.id, itemId: itemId) {
                return local
            }
            return api.downloadURL(itemId: itemId)
        }

        // Single-file book: one item, chapters are embedded seek points.
        if tracks.count <= 1, let track = tracks.first, let url = itemURL(track.id) {
            let total = seconds(track.runTimeTicks ?? book.runTimeTicks)
            let embedded = await ChapterExtractor.embeddedChapters(url: url)
            let chapters = embedded.isEmpty
                ? Chapter.list(from: [(title: track.name, durationTicks: track.runTimeTicks, startTicks: 0)])
                : embedded
            let starts = chapters.map { Double($0.startTicks ?? 0) / Double(TimeFormat.ticksPerSecond) }
            let resume = (track.userData?.played ?? false) ? 0 : seconds(track.userData?.playbackPositionTicks)
            return PlayableBook(
                book: book,
                items: [PlayableItem(itemId: track.id, url: url, duration: total)],
                chapters: chapters,
                chapterStarts: starts,
                itemOffsets: [0],
                totalDuration: total,
                isSingleFile: true,
                resumeSeconds: resume
            )
        }

        // Multi-file book: each track is an item and a chapter.
        var items: [PlayableItem] = []
        var offsets: [Double] = []
        var chapterItems: [(title: String, durationTicks: Int64?, startTicks: Int64?)] = []
        var running = 0.0
        var resume = 0.0
        var foundResume = false
        for track in tracks {
            guard let url = itemURL(track.id) else { continue }
            let dur = seconds(track.runTimeTicks)
            offsets.append(running)
            items.append(PlayableItem(itemId: track.id, url: url, duration: dur))
            chapterItems.append((title: track.name, durationTicks: track.runTimeTicks,
                                 startTicks: Int64(running * Double(TimeFormat.ticksPerSecond))))
            // Resume = first track not fully played (mid-track if it has a saved position).
            if !foundResume, !(track.userData?.played ?? false) {
                resume = running + seconds(track.userData?.playbackPositionTicks)
                foundResume = true
            }
            running += dur
        }
        return PlayableBook(
            book: book,
            items: items,
            chapters: Chapter.list(from: chapterItems),
            chapterStarts: offsets,
            itemOffsets: offsets,
            totalDuration: running,
            isSingleFile: false,
            resumeSeconds: resume
        )
    }

}
