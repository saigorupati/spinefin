import SwiftUI

/// Sheet presented from Now Playing: jump to a chapter or a saved bookmark.
struct ChaptersBookmarksSheet: View {
    @Environment(\.palette) private var p
    @Environment(PlayerModel.self) private var player
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(\.dismiss) private var dismiss

    let bookId: String
    @State private var tab: Int

    init(bookId: String, initialTab: Int = 0) {
        self.bookId = bookId
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SpineBackground()
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("Chapters").tag(0)
                        Text("Bookmarks").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    if tab == 0 { chaptersList } else { bookmarksList }
                }
            }
            .navigationTitle(tab == 0 ? "Chapters" : "Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.tint(p.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var chaptersList: some View {
        List {
            ForEach(Array(player.chapters.enumerated()), id: \.element.id) { index, chapter in
                Button {
                    player.seekTo(seconds: Double(chapter.startTicks ?? 0) / 1e7)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Group {
                            if index == player.currentChapterIndex {
                                Image(systemName: "waveform").font(.system(size: 13)).foregroundStyle(p.accent)
                            } else if let n = chapter.displayNumber {
                                Text("\(n)").font(.system(size: 13).monospacedDigit()).foregroundStyle(p.text3)
                            } else {
                                Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(p.text3)
                            }
                        }
                        .frame(width: 24)
                        Text(chapter.title)
                            .font(.system(size: 15, weight: index == player.currentChapterIndex ? .semibold : .regular))
                            .foregroundStyle(index == player.currentChapterIndex ? p.accent : p.text)
                            .lineLimit(1)
                        Spacer()
                        Text(chapter.duration).font(.system(size: 12, design: .monospaced)).foregroundStyle(p.text3)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var bookmarksList: some View {
        let items = bookmarks.bookmarks(forBook: bookId)
        return Group {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No bookmarks", systemImage: "bookmark")
                } description: {
                    Text("Tap the bookmark button while listening to save your spot.")
                }
            } else {
                List {
                    ForEach(items) { bookmark in
                        Button {
                            player.seekTo(seconds: bookmark.positionSeconds)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bookmark.fill").font(.system(size: 14)).foregroundStyle(p.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.chapterTitle.isEmpty ? "Bookmark" : bookmark.chapterTitle)
                                        .font(.system(size: 15, weight: .medium)).foregroundStyle(p.text).lineLimit(1)
                                    Text(bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12)).foregroundStyle(p.text3)
                                }
                                Spacer()
                                Text(TimeFormat.clock(ticks: Int64(bookmark.positionSeconds * 1e7)))
                                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(p.text2)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        offsets.map { items[$0] }.forEach(bookmarks.delete)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
