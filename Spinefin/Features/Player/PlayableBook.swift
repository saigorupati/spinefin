import Foundation

/// One playable source file: a track (multi-file book) or the whole file (single-file).
struct PlayableItem: Sendable, Hashable {
    let itemId: String     // Jellyfin item id (for progress reporting)
    let url: URL
    let duration: Double   // seconds
}

/// A book resolved into something the playback engine can play, with a global
/// timeline (chapters expressed as absolute offsets in seconds).
struct PlayableBook: Sendable {
    let book: Book
    let items: [PlayableItem]
    let chapters: [Chapter]
    let chapterStarts: [Double]   // global second at which each chapter begins
    let itemOffsets: [Double]     // global second at which each item begins
    let totalDuration: Double
    let isSingleFile: Bool
    let resumeSeconds: Double     // saved global position to resume from (0 if none)
}
