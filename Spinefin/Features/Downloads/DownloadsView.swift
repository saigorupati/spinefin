import SwiftUI

struct DownloadsView: View {
    @Environment(\.palette) private var p
    @Environment(DownloadManager.self) private var downloads

    private var records: [DownloadRecord] {
        downloads.records.values.sorted { $0.title < $1.title }
    }
    private var totalBytes: Int64 { records.reduce(0) { $0 + $1.totalBytes } }

    var body: some View {
        NavigationStack {
            ZStack {
                SpineBackground()
                if records.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Downloads")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(p.text)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    Text("\(records.count) book\(records.count == 1 ? "" : "s")")
                    dot
                    Text("\(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)) used")
                }
                .font(.system(size: 13.5))
                .foregroundStyle(p.text2)
                .padding(.top, 6)

                Text("ON THIS IPHONE")
                    .font(.system(size: 12.5, weight: .semibold)).tracking(0.4)
                    .foregroundStyle(p.text3)
                    .padding(.top, 22).padding(.bottom, 4)

                ForEach(records) { record in
                    DownloadRow(record: record)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No downloads", systemImage: "arrow.down.circle")
        } description: {
            Text("Download a book from its detail page to listen offline.")
        }
    }

    private var dot: some View { Text("·").opacity(0.5) }
}

private struct DownloadRow: View {
    @Environment(\.palette) private var p
    @Environment(DownloadManager.self) private var downloads
    let record: DownloadRecord

    private var progress: Double { downloads.activeProgress[record.key] ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CoverArt(hue: record.hue, cornerRadius: 12, label: nil,
                         imageURL: downloads.coverURL(for: record.key))
                    .frame(width: 56, height: 56)
                    .shadow(color: p.shadow, radius: 10, y: 6)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title)
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(p.text).lineLimit(1)
                            Text(subtitle).font(.system(size: 13)).foregroundStyle(p.text2).lineLimit(1)
                        }
                        Spacer()
                        trailing
                    }
                    if record.status == .downloading {
                        VStack(spacing: 6) {
                            ProgressBar(value: progress, height: 4)
                            HStack {
                                Text("Downloading · \(Int(progress * 100))%")
                                Spacer()
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(p.text3)
                        }
                        .padding(.top, 9)
                    }
                }
            }
            .padding(.vertical, 14)
            Divider().overlay(p.sep)
        }
    }

    private var subtitle: String {
        record.status == .done ? "\(record.author)" : record.author
    }

    @ViewBuilder private var trailing: some View {
        switch record.status {
        case .done:
            HStack(spacing: 10) {
                Text(ByteCountFormatter.string(fromByteCount: record.totalBytes, countStyle: .file))
                    .font(.system(size: 12.5, design: .monospaced)).foregroundStyle(p.text3)
                Button { downloads.delete(record.key) } label: {
                    Image(systemName: "trash").font(.system(size: 16)).foregroundStyle(p.text3)
                }
                .buttonStyle(.plain)
            }
        case .downloading, .queued:
            Button { downloads.delete(record.key) } label: {
                Image(systemName: "xmark.circle").font(.system(size: 18)).foregroundStyle(p.text3)
            }
            .buttonStyle(.plain)
        case .failed:
            Text("Failed").font(.system(size: 12.5)).foregroundStyle(.orange)
        }
    }
}
