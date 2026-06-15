import Foundation
import AVFoundation

/// Reads embedded chapter markers from an audio file (e.g. a single `.m4b`) using
/// AVFoundation. Works over the network — only the metadata atoms are fetched.
///
/// Jellyfin doesn't surface embedded chapters for audio items, so for single-file
/// audiobooks we extract them straight from the file.
enum ChapterExtractor {
    static func embeddedChapters(url: URL) async -> [Chapter] {
        let asset = AVURLAsset(url: url)
        let languages = Locale.preferredLanguages
        guard let groups = try? await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: languages),
              !groups.isEmpty else {
            return []
        }

        var items: [(title: String, durationTicks: Int64?, startTicks: Int64?)] = []
        for (index, group) in groups.enumerated() {
            let titleItems = AVMetadataItem.metadataItems(
                from: group.items,
                filteredByIdentifier: .commonIdentifierTitle
            )
            var title = "Chapter \(index + 1)"
            if let item = titleItems.first {
                let loaded = (try? await item.load(.stringValue)) ?? nil
                if let value = loaded, !value.isEmpty { title = value }
            }
            let startTicks = Int64(group.timeRange.start.seconds * Double(TimeFormat.ticksPerSecond))
            let durationTicks = Int64(group.timeRange.duration.seconds * Double(TimeFormat.ticksPerSecond))
            items.append((title: title, durationTicks: durationTicks, startTicks: startTicks))
        }
        return Chapter.list(from: items)
    }
}
