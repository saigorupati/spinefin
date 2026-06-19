import SwiftUI
import UIKit
import Observation
import AVFoundation
import MediaPlayer

/// The audiobook playback engine: streams from Jellyfin via `AVQueuePlayer`, tracks a
/// global position across multi-file books, seeks chapters, and drives background
/// audio + lock-screen controls.
@MainActor
@Observable
final class PlayerModel {
    // Published state
    private(set) var current: Book?
    private(set) var chapters: [Chapter] = []
    private(set) var currentChapterIndex = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var position: Double = 0      // global seconds
    private(set) var duration: Double = 0
    private(set) var errorMessage: String?
    var showNowPlaying = false

    var rate: Float = 1.0 {
        didSet {
            if isPlaying { player.rate = rate }
            updateNowPlayingInfo()
        }
    }

    private(set) var sleepMinutes: Int?        // nil = off

    // Engine internals
    private let player = AVQueuePlayer()
    private var playable: PlayableBook?
    private var currentItemIndex = 0
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var sleepTask: Task<Void, Never>?
    private var remoteConfigured = false

    // Lock-screen / Control Center artwork, fetched lazily per book.
    private var nowPlayingArtwork: MPMediaItemArtwork?
    private var artworkURL: URL?

    // Progress persistence (local — Jellyfin can't store resume for Music libraries)
    private weak var library: LibraryStore?
    private var lastProgressSave = Date.distantPast

    weak var settings: SettingsStore?
    var skipBackSeconds: Int { settings?.skipBackSeconds ?? 15 }
    var skipForwardSeconds: Int { settings?.skipForwardSeconds ?? 30 }
    func skipBackward() { skip(by: -Double(skipBackSeconds)) }
    func skipForward() { skip(by: Double(skipForwardSeconds)) }

    var progress: Double { duration > 0 ? min(1, max(0, position / duration)) : 0 }

    /// Progress for display — falls back to a seeded fraction for a restored-but-not-yet-loaded book.
    var displayProgress: Double { duration > 0 ? progress : seededFraction }
    private var seededFraction: Double = 0

    /// "Chapter 7 · The Crossing"
    var chapterDisplay: String {
        guard chapters.indices.contains(currentChapterIndex) else { return "" }
        return chapters[currentChapterIndex].displayTitle
    }

    /// "Ch. 7 · The Crossing" (mini-player)
    var chapterShort: String {
        guard chapters.indices.contains(currentChapterIndex) else { return "" }
        return chapters[currentChapterIndex].displayTitle
    }

    var elapsedText: String { TimeFormat.clock(ticks: Int64(position * 1e7)) }
    var remainingText: String { "-" + TimeFormat.clock(ticks: Int64(max(0, duration - position) * 1e7)) }

    // MARK: - Loading

    /// Begin playing a book, optionally from a specific position. `present` opens Now Playing.
    func play(_ book: Book, using library: LibraryStore, startSeconds: Double? = nil, present: Bool = true) {
        if present { showNowPlaying = true }
        if current?.id == book.id, playable != nil {
            if let startSeconds { seekGlobal(to: startSeconds) }
            if !isPlaying { beginPlaying() }
            return
        }
        Task { await load(book, using: library, startSeconds: startSeconds) }
    }

    /// Seek the currently-loaded book to an absolute position (chapter taps, bookmarks).
    func seekTo(seconds: Double) { seekGlobal(to: seconds) }

    private func load(_ book: Book, using library: LibraryStore, startSeconds: Double? = nil) async {
        stop()
        isLoading = true
        errorMessage = nil
        self.library = library
        current = book
        chapters = []
        position = 0
        duration = 0
        loadArtwork(for: book)
        do {
            let resolved = try await library.playable(for: book)
            configure(with: resolved)
            let resume = startSeconds ?? library.savedPosition(book.id) ?? resolved.resumeSeconds
            seekGlobal(to: resume)
            beginPlaying()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load this book."
        }
        isLoading = false
    }

    /// Persists the current position (call on book switch / app background).
    func stop() { persistProgress() }
    func saveProgress() { persistProgress() }

    /// Show the last-played book in the mini-player without streaming, so the user
    /// can resume. Tapping play loads and resumes it.
    func restoreLastPlayed(_ book: Book, fraction: Double, using library: LibraryStore) {
        guard current == nil, playable == nil else { return }
        self.library = library
        current = book
        seededFraction = fraction
        isPlaying = false
        loadArtwork(for: book)
    }

    private func configure(with resolved: PlayableBook) {
        playable = resolved
        chapters = resolved.chapters
        duration = resolved.totalDuration
        currentChapterIndex = 0
        if let speed = settings?.defaultSpeed { rate = Float(speed) }
        configureAudioSession()
        configureRemoteCommands()
        rebuildQueue(fromItem: 0, seekInItem: 0)
        addObservers()
    }

    // MARK: - Transport

    func togglePlayPause() {
        // Restored-but-not-loaded book: load and resume on first tap.
        if playable == nil {
            guard let book = current, let library else { return }
            Task { await load(book, using: library) }
            return
        }
        if isPlaying {
            player.pause()
            isPlaying = false
            persistProgress()
        } else {
            beginPlaying()
        }
        updateNowPlayingInfo()
    }

    private func beginPlaying() {
        player.play()
        player.rate = rate
        isPlaying = true
        updateNowPlayingInfo()
        persistProgress()
    }

    func skip(by delta: Double) {
        seekGlobal(to: position + delta)
    }

    func nextChapter() {
        guard let starts = playable?.chapterStarts, !starts.isEmpty else { return }
        let next = min(currentChapterIndex + 1, starts.count - 1)
        seekGlobal(to: starts[next])
    }

    func previousChapter() {
        guard let starts = playable?.chapterStarts, !starts.isEmpty else { return }
        // Within the first few seconds of a chapter, jump to the previous one.
        let start = starts[currentChapterIndex]
        let target = (position - start) > 3 ? currentChapterIndex : max(0, currentChapterIndex - 1)
        seekGlobal(to: starts[target])
    }

    func seek(toFraction fraction: Double) {
        seekGlobal(to: fraction * duration)
    }

    func playChapter(_ index: Int) {
        guard let starts = playable?.chapterStarts, starts.indices.contains(index) else { return }
        seekGlobal(to: starts[index])
        if !isPlaying { beginPlaying() }
    }

    func cycleSpeed() {
        let steps: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75]
        let next = steps.first { $0 > rate } ?? steps[0]
        rate = next
    }

    func setSleep(minutes: Int?) {
        sleepMinutes = minutes
        sleepTask?.cancel()
        guard let minutes else { return }
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(minutes * 60)))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isPlaying else { return }
                self.togglePlayPause()
                self.sleepMinutes = nil
            }
        }
    }

    // MARK: - Seeking core

    /// Seeks to a global position, rebuilding the queue if it lands in a different item.
    private func seekGlobal(to globalSeconds: Double) {
        guard let playable else { return }
        let clamped = min(max(0, globalSeconds), max(0, duration - 0.5))
        let index = itemIndex(forGlobal: clamped)
        let inItem = clamped - playable.itemOffsets[index]

        let itemChanged = index != currentItemIndex
        if itemChanged {
            rebuildQueue(fromItem: index, seekInItem: inItem)
            if isPlaying { player.play(); player.rate = rate }
        } else {
            player.seek(to: CMTime(seconds: inItem, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }
        position = clamped
        updateChapterIndex()
        updateNowPlayingInfo()
        persistProgress()
    }

    private func itemIndex(forGlobal seconds: Double) -> Int {
        guard let offsets = playable?.itemOffsets else { return 0 }
        var index = 0
        for (i, start) in offsets.enumerated() where start <= seconds { index = i }
        return index
    }

    private func rebuildQueue(fromItem index: Int, seekInItem inItem: Double) {
        guard let playable else { return }
        player.removeAllItems()
        for item in playable.items[index...] {
            player.insert(AVPlayerItem(url: item.url), after: nil)
        }
        currentItemIndex = index
        if inItem > 0 {
            player.seek(to: CMTime(seconds: inItem, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    // MARK: - Observers

    private func addObservers() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.itemDidEnd() }
        }
    }

    private func tick() {
        guard let playable, player.currentItem != nil else { return }
        let inItem = player.currentTime().seconds
        guard inItem.isFinite else { return }
        position = playable.itemOffsets[currentItemIndex] + inItem
        updateChapterIndex()
        updateNowPlayingInfo()

        if isPlaying, Date().timeIntervalSince(lastProgressSave) >= 10 {
            persistProgress()
        }
    }

    private func itemDidEnd() {
        guard let playable else { return }
        if currentItemIndex < playable.items.count - 1 {
            currentItemIndex += 1   // AVQueuePlayer auto-advances; keep our index in sync
            persistProgress()
        } else {
            isPlaying = false
            persistProgress()
        }
    }

    private func updateChapterIndex() {
        guard let starts = playable?.chapterStarts else { return }
        var index = 0
        for (i, start) in starts.enumerated() where start <= position + 0.25 { index = i }
        currentChapterIndex = index
    }

    // MARK: - Progress persistence

    private func persistProgress() {
        guard let library, let book = current, duration > 0 else { return }
        lastProgressSave = Date()
        library.saveProgress(bookId: book.id, seconds: position, duration: duration)
    }

    // MARK: - System integration

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func configureRemoteCommands() {
        guard !remoteConfigured else { return }
        remoteConfigured = true
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .commandFailed }
            self.togglePlayPause(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.togglePlayPause(); return .success
        }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardSeconds)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(); return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackSeconds)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.nextChapter(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previousChapter(); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seekGlobal(to: e.positionTime); return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current?.title ?? "",
            MPMediaItemPropertyArtist: current?.author ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0,
        ]
        if chapters.indices.contains(currentChapterIndex) {
            info[MPMediaItemPropertyAlbumTitle] = chapters[currentChapterIndex].title
        }
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Fetches the cover image for the lock screen / Control Center once per book.
    private func loadArtwork(for book: Book) {
        guard let url = book.coverURL else {
            nowPlayingArtwork = nil
            artworkURL = nil
            return
        }
        guard url != artworkURL else { return }   // already loaded / loading this cover
        artworkURL = url
        nowPlayingArtwork = nil
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                guard let self, self.artworkURL == url else { return }   // book changed mid-fetch
                self.nowPlayingArtwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.updateNowPlayingInfo()
            }
        }
    }
}
