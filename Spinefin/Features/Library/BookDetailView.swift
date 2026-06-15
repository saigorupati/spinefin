import SwiftUI

struct BookDetailView: View {
    @Environment(\.palette) private var p
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.dismiss) private var dismiss
    let book: Book

    @State private var chapters: [Chapter] = []
    @State private var isLoadingChapters = false
    @State private var descExpanded = false

    /// Live position if this book is playing, else the saved resume position.
    private var effectivePosition: Double {
        player.current?.id == book.id ? player.position : (library.savedPosition(book.id) ?? 0)
    }
    /// Number of real chapters (excludes front/back-matter sections).
    private var chapterCount: Int { chapters.filter { $0.displayNumber != nil }.count }
    private var totalSeconds: Double { Double(book.runTimeTicks ?? 0) / 1e7 }
    private var fraction: Double { totalSeconds > 0 ? min(1, effectivePosition / totalSeconds) : 0 }
    private var hasProgress: Bool { effectivePosition > 5 }

    /// Index of the chapter containing the current position (for highlighting).
    private var currentChapterIndex: Int? {
        guard hasProgress, !chapters.isEmpty else { return nil }
        let posTicks = Int64(effectivePosition * 1e7)
        var index = 0
        for (i, c) in chapters.enumerated() where (c.startTicks ?? 0) <= posTicks { index = i }
        return index
    }

    var body: some View {
        ZStack {
            SpineBackground()
            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    CoverArt(hue: book.hue, cornerRadius: 20, imageURL: book.coverURL)
                        .frame(width: 212, height: 212)
                        .shadow(color: .black.opacity(0.4), radius: 26, y: 18)
                        .padding(.top, 6)

                    Text(book.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(p.text)
                        .multilineTextAlignment(.center)
                        .padding(.top, 22)
                    if !book.author.isEmpty {
                        Text(book.author).font(.system(size: 16)).foregroundStyle(p.text2).padding(.top, 5)
                    }
                    if !book.narrator.isEmpty {
                        Text("Narrated by \(book.narrator)").font(.system(size: 13.5)).foregroundStyle(p.text3).padding(.top, 3)
                    }

                    HStack(spacing: 8) {
                        Text(book.duration)
                        if chapterCount > 0 { dot; Text("\(chapterCount) chapters") }
                    }
                    .font(.system(size: 12.5)).foregroundStyle(p.text3)
                    .padding(.top, 12)

                    HStack(spacing: 11) {
                        PillButton(title: resumeTitle, systemImage: "play.fill", filled: true) {
                            player.play(book, using: library)
                        }
                        downloadButton
                    }
                    .padding(.top, 22)

                    if hasProgress {
                        ProgressBar(value: fraction, height: 4).padding(.top, 12)
                        HStack {
                            Text("\(Int(fraction * 100))% complete")
                            Spacer()
                            Text("\(TimeFormat.clock(ticks: Int64(effectivePosition * 1e7))) / \(book.duration)")
                        }
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(p.text3)
                        .padding(.top, 7)
                    }

                    if let overview = book.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(overview)
                                .font(.system(size: 15))
                                .foregroundStyle(p.text2)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                                .lineLimit(descExpanded ? nil : 4)
                            Button(descExpanded ? "less" : "more") {
                                withAnimation(.easeInOut(duration: 0.2)) { descExpanded.toggle() }
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(p.accent)
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                    }

                    SectionHeader(title: "Chapters", trailing: chapterCount == 0 ? nil : "\(chapterCount) · \(book.duration)")
                        .padding(.top, 26).padding(.bottom, 4)

                    if isLoadingChapters {
                        ProgressView().tint(p.accent).frame(maxWidth: .infinity).padding(.top, 24)
                    } else {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                            Button {
                                let start = Double(chapter.startTicks ?? 0) / 1e7
                                player.play(book, using: library, startSeconds: start, present: false)
                            } label: {
                                ChapterRow(chapter: chapter, isCurrent: index == currentChapterIndex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadChapters() }
    }

    @ViewBuilder
    private var downloadButton: some View {
        let state = library.serverID.flatMap { downloads.uiState($0, book.id) }
        Button {
            switch state {
            case .none:
                downloads.download(book, using: library)
            case .done:
                if let key = library.serverID.map({ DownloadManager.key($0, book.id) }) {
                    downloads.delete(key)
                }
            default:
                break
            }
        } label: {
            Group {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(p.accent)
                case .downloading(let progress, _):
                    ZStack {
                        Circle().stroke(p.track, lineWidth: 2)
                        Circle().trim(from: 0, to: max(0.02, progress))
                            .stroke(p.accent, style: .init(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)
                case .queued:
                    ProgressView().tint(p.accent)
                case .none:
                    Image(systemName: "arrow.down").font(.system(size: 20)).foregroundStyle(p.accent)
                }
            }
            .frame(width: 52, height: 52)
            .background {
                RoundedRectangle(cornerRadius: 16).fill(p.glassFill)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(p.glassBorder, lineWidth: 0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private var resumeTitle: String {
        guard hasProgress else { return "Play" }
        let remaining = TimeFormat.remaining(totalTicks: book.runTimeTicks, progress: fraction) ?? ""
        return "Resume · \(remaining)"
    }

    private func loadChapters() async {
        guard chapters.isEmpty else { return }
        isLoadingChapters = true
        defer { isLoadingChapters = false }
        chapters = (try? await library.chapters(for: book)) ?? []
    }

    private var topBar: some View {
        HStack {
            circleButton("chevron.left") { dismiss() }
            Spacer()
            Menu {
                downloadMenuItem
                Divider()
                Button { library.markFinished(bookId: book.id, durationSeconds: totalSeconds) } label: {
                    Label("Mark as Finished", systemImage: "checkmark.circle")
                }
                Button { library.clearProgress(bookId: book.id) } label: {
                    Label("Clear Progress", systemImage: "arrow.counterclockwise")
                }
            } label: {
                circleLabel("ellipsis")
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var downloadMenuItem: some View {
        let state = library.serverID.flatMap { downloads.uiState($0, book.id) }
        if case .done = state {
            Button(role: .destructive) {
                if let key = library.serverID.map({ DownloadManager.key($0, book.id) }) { downloads.delete(key) }
            } label: { Label("Remove Download", systemImage: "trash") }
        } else if state == nil {
            Button { downloads.download(book, using: library) } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
        }
    }

    private var dot: some View { Text("·").opacity(0.5) }

    private func circleButton(_ s: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { circleLabel(s) }
            .buttonStyle(.plain)
    }

    private func circleLabel(_ s: String) -> some View {
        Image(systemName: s).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text2)
            .frame(width: 42, height: 42)
            .background {
                Circle().fill(p.glassFill).overlay(Circle().strokeBorder(p.glassBorder, lineWidth: 0.5))
            }
    }
}

private struct ChapterRow: View {
    @Environment(\.palette) private var p
    let chapter: Chapter
    var isCurrent: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Group {
                    if isCurrent {
                        Image(systemName: "waveform").font(.system(size: 14)).foregroundStyle(p.accent)
                    } else if let number = chapter.displayNumber {
                        Text("\(number)")
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(p.text3)
                    } else {
                        // Front/back-matter section (credits, intro…)
                        Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(p.text3)
                    }
                }
                .frame(width: 26)

                Text(chapter.title)
                    .font(.system(size: 15.5, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? p.accent : p.text)
                    .lineLimit(1)
                Spacer()
                Text(chapter.duration)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(p.text3)
            }
            .padding(.vertical, 13)
            Divider().overlay(p.sep).padding(.leading, 40)
        }
    }
}
