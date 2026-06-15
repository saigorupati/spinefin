import SwiftUI

/// Persistent mini-player docked above the tab bar. Tapping expands to Now Playing.
struct MiniPlayerBar: View {
    @Environment(\.palette) private var p
    @Environment(PlayerModel.self) private var player

    var body: some View {
        if let book = player.current {
            Button {
                player.showNowPlaying = true
            } label: {
                VStack(spacing: 0) {
                    HStack(spacing: 11) {
                        CoverArt(hue: book.hue, cornerRadius: 9, label: nil, imageURL: book.coverURL)
                            .frame(width: 38, height: 38)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                        VStack(alignment: .leading, spacing: 1) {
                            MarqueeText(text: book.title, size: 14, weight: .semibold, color: p.text)
                            Text(player.chapterShort.isEmpty ? book.author : player.chapterShort)
                                .font(.system(size: 12))
                                .foregroundStyle(p.text2)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 6)

                        Button {
                            player.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(p.text)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)

                    ProgressBar(value: player.displayProgress, height: 2.5)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }
                .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
    }
}
