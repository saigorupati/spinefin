import Foundation
import Observation

/// One downloaded file within a book (ordered; carries duration for the offline timeline).
struct DownloadedItem: Codable, Hashable {
    let itemId: String
    var fileName: String
    let durationSeconds: Double
}

/// Persisted chapter so a downloaded book's timeline can be rebuilt offline.
struct StoredChapter: Codable, Hashable {
    let title: String
    let displayNumber: Int?
    let duration: String
    let startTicks: Int64?
}

/// Persisted record of a downloaded (or downloading) book — includes the full
/// playback timeline so playback needs no network when offline.
struct DownloadRecord: Codable, Identifiable, Hashable {
    let key: String          // "serverId|bookId"
    let bookId: String       // Jellyfin album id
    let title: String
    let author: String
    let hue: Double
    var coverFile: String?
    var items: [DownloadedItem]
    var chapters: [StoredChapter]
    var totalDuration: Double
    var isSingleFile: Bool
    var totalBytes: Int64
    var status: Status
    var id: String { key }

    enum Status: String, Codable { case queued, downloading, done, failed }
}

/// Downloads audiobooks for offline playback. Delegate-based `URLSession` for real
/// progress; files live in Application Support and survive launches.
@MainActor
@Observable
final class DownloadManager: NSObject {
    private(set) var records: [String: DownloadRecord] = [:]
    private(set) var activeProgress: [String: Double] = [:]   // key -> 0...1

    /// Shared instance — there must be exactly one owner of the background session.
    static let shared = DownloadManager()

    /// Set by the app delegate when iOS relaunches us to finish background downloads.
    var backgroundCompletionHandler: (() -> Void)?

    private var session: URLSession!
    private var keyTasks: [String: Set<Int>] = [:]            // key -> task identifiers
    private var taskKey: [Int: String] = [:]                  // task id -> key
    private var taskBytes: [Int: (done: Int64, total: Int64)] = [:]

    private let manifestKey = "spinefin.downloads.manifest"
    private static let sessionID = "com.spinefin.downloads"

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadManifest()
        reconnect()
    }

    /// Rebuilds the task→book mapping from tasks still running after a relaunch.
    private func reconnect() {
        session.getAllTasks { tasks in
            Task { @MainActor in
                for task in tasks {
                    guard let desc = task.taskDescription else { continue }
                    let parts = desc.split(separator: "|", maxSplits: 2).map(String.init)
                    guard parts.count >= 3 else { continue }
                    let key = "\(parts[0])|\(parts[1])"
                    self.taskKey[task.taskIdentifier] = key
                    self.keyTasks[key, default: []].insert(task.taskIdentifier)
                    self.taskBytes[task.taskIdentifier] = (task.countOfBytesReceived, task.countOfBytesExpectedToReceive)
                }
                for key in Set(self.keyTasks.keys) { self.recomputeProgress(for: key) }
            }
        }
    }

    // MARK: - Queries

    static func key(_ serverId: String, _ bookId: String) -> String { "\(serverId)|\(bookId)" }

    func record(_ serverId: String, _ bookId: String) -> DownloadRecord? {
        records[Self.key(serverId, bookId)]
    }

    func uiState(_ serverId: String, _ bookId: String) -> DownloadState? {
        guard let rec = record(serverId, bookId) else { return nil }
        switch rec.status {
        case .done:
            return .done
        case .downloading:
            let frac = activeProgress[rec.key] ?? 0
            return .downloading(progress: frac, transferred: byteText(rec.totalBytes))
        case .queued, .failed:
            return .queued
        }
    }

    /// Local file URL for a downloaded item, if available.
    func localURL(_ serverId: String, bookId: String, itemId: String) -> URL? {
        let key = Self.key(serverId, bookId)
        guard let rec = records[key], rec.status == .done,
              let file = rec.items.first(where: { $0.itemId == itemId }), !file.fileName.isEmpty else { return nil }
        let url = Self.bookDirectory(for: key).appendingPathComponent(file.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Builds a fully-offline playable timeline from the stored record (no network).
    func offlinePlayable(_ serverId: String, book: Book) -> PlayableBook? {
        let key = Self.key(serverId, book.id)
        guard let rec = records[key], rec.status == .done, !rec.items.isEmpty else { return nil }
        let dir = Self.bookDirectory(for: key)
        var items: [PlayableItem] = []
        var offsets: [Double] = []
        var running = 0.0
        for it in rec.items {
            let url = dir.appendingPathComponent(it.fileName)
            guard !it.fileName.isEmpty, FileManager.default.fileExists(atPath: url.path) else { return nil }
            offsets.append(running)
            items.append(PlayableItem(itemId: it.itemId, url: url, duration: it.durationSeconds))
            running += it.durationSeconds
        }
        let chapters = rec.chapters.map {
            Chapter(title: $0.title, displayNumber: $0.displayNumber, duration: $0.duration, startTicks: $0.startTicks)
        }
        return PlayableBook(
            book: book,
            items: items,
            chapters: chapters,
            chapterStarts: chapters.map { Double($0.startTicks ?? 0) / 1e7 },
            itemOffsets: offsets,
            totalDuration: rec.totalDuration > 0 ? rec.totalDuration : running,
            isSingleFile: rec.isSingleFile,
            resumeSeconds: 0
        )
    }

    /// Local cached cover URL for a downloaded book.
    func coverURL(for key: String) -> URL? {
        guard let cover = records[key]?.coverFile else { return nil }
        return Self.bookDirectory(for: key).appendingPathComponent(cover)
    }

    // MARK: - Actions

    func download(_ book: Book, using library: LibraryStore) {
        guard let serverId = library.serverID else { return }
        let key = Self.key(serverId, book.id)
        guard records[key] == nil else { return }

        records[key] = DownloadRecord(
            key: key, bookId: book.id, title: book.title, author: book.author,
            hue: book.hue, coverFile: nil, items: [], chapters: [],
            totalDuration: 0, isSingleFile: false, totalBytes: 0, status: .downloading
        )
        activeProgress[key] = 0
        persist()

        Task {
            do {
                let playable = try await library.playable(for: book)
                await cacheCover(book, key: key)
                startDownloads(playable: playable, key: key)
            } catch {
                records[key]?.status = .failed
                persist()
            }
        }
    }

    func deleteAll() {
        Array(records.keys).forEach(delete)
    }

    var totalBytes: Int64 { records.values.reduce(0) { $0 + $1.totalBytes } }

    func delete(_ key: String) {
        cancelTasks(for: key)
        try? FileManager.default.removeItem(at: Self.bookDirectory(for: key))
        records[key] = nil
        activeProgress[key] = nil
        persist()
    }

    // MARK: - Download plumbing

    private func startDownloads(playable: PlayableBook, key: String) {
        let dir = Self.bookDirectory(for: key)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Persist the timeline up front so the book can play fully offline.
        records[key]?.items = playable.items.map {
            DownloadedItem(itemId: $0.itemId, fileName: "", durationSeconds: $0.duration)
        }
        records[key]?.chapters = playable.chapters.map {
            StoredChapter(title: $0.title, displayNumber: $0.displayNumber, duration: $0.duration, startTicks: $0.startTicks)
        }
        records[key]?.totalDuration = playable.totalDuration
        records[key]?.isSingleFile = playable.isSingleFile
        persist()

        var ids = Set<Int>()
        for item in playable.items {
            let task = session.downloadTask(with: item.url)
            task.taskDescription = "\(key)|\(item.itemId)"
            taskKey[task.taskIdentifier] = key
            taskBytes[task.taskIdentifier] = (0, 0)
            ids.insert(task.taskIdentifier)
            task.resume()
        }
        keyTasks[key] = ids
    }

    private func cacheCover(_ book: Book, key: String) async {
        guard let url = book.coverURL else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        let dir = Self.bookDirectory(for: key)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("cover.jpg")
        try? data.write(to: dest)
        records[key]?.coverFile = "cover.jpg"
        persist()
    }

    private func cancelTasks(for key: String) {
        session.getAllTasks { tasks in
            for t in tasks where (t.taskDescription?.hasPrefix(key + "|") ?? false) { t.cancel() }
        }
        if let ids = keyTasks[key] {
            ids.forEach { taskKey[$0] = nil; taskBytes[$0] = nil }
        }
        keyTasks[key] = nil
    }

    private func recomputeProgress(for key: String) {
        guard let ids = keyTasks[key] else { return }
        var done: Int64 = 0, total: Int64 = 0
        for id in ids {
            let b = taskBytes[id] ?? (0, 0)
            done += b.done
            total += max(b.total, b.done)
        }
        activeProgress[key] = total > 0 ? Double(done) / Double(total) : 0
        records[key]?.totalBytes = total
    }

    private func finishedTask(_ id: Int, itemId: String, key: String, fileName: String, bytes: Int64) {
        if let idx = records[key]?.items.firstIndex(where: { $0.itemId == itemId }) {
            records[key]?.items[idx].fileName = fileName
        }
        taskBytes[id] = (bytes, bytes)
        recomputeProgress(for: key)
        let allDone = records[key]?.items.allSatisfy { !$0.fileName.isEmpty } ?? false
        if allDone {
            records[key]?.status = .done
            activeProgress[key] = 1
        }
        persist()
    }

    private func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: manifestKey)
        }
    }

    private func loadManifest() {
        guard let data = UserDefaults.standard.data(forKey: manifestKey),
              let decoded = try? JSONDecoder().decode([String: DownloadRecord].self, from: data) else { return }
        // Keep in-flight downloads too — the background session reconnects to them.
        records = decoded
    }

    nonisolated private static func bookDirectory(for key: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let safe = key.replacingOccurrences(of: "|", with: "_").replacingOccurrences(of: "@", with: "_")
        return base.appendingPathComponent("SpinefinDownloads/\(safe)", isDirectory: true)
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        let id = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let key = self.taskKey[id] else { return }
            self.taskBytes[id] = (totalBytesWritten, totalBytesExpectedToWrite)
            self.recomputeProgress(for: key)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // Must move the file synchronously — `location` is removed after this returns.
        guard let desc = downloadTask.taskDescription else { return }
        let parts = desc.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count >= 3 else { return }
        let key = "\(parts[0])|\(parts[1])"
        let itemId = parts[2]
        let suggested = downloadTask.response?.suggestedFilename ?? "\(itemId).m4b"
        let ext = (suggested as NSString).pathExtension.isEmpty ? "m4b" : (suggested as NSString).pathExtension
        let fileName = "\(itemId).\(ext)"

        let dir = Self.bookDirectory(for: key)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: location, to: dest)
        let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path)
        let bytes = (attrs?[.size] as? Int64) ?? 0

        let id = downloadTask.taskIdentifier
        Task { @MainActor in
            self.finishedTask(id, itemId: itemId, key: key, fileName: fileName, bytes: bytes)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let id = task.taskIdentifier
        Task { @MainActor in
            guard let key = self.taskKey[id], (error as NSError).code != NSURLErrorCancelled else { return }
            self.records[key]?.status = .failed
            self.persist()
        }
    }
}
