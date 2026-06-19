import SwiftUI
import AVKit

/// Full-screen Now Playing: huge artwork over a blurred backdrop, scrubber,
/// transport, and the utility row (speed / sleep / bookmark / output).
struct NowPlayingView: View {
    @Environment(\.palette) private var p
    @Environment(PlayerModel.self) private var player
    @Environment(BookmarkStore.self) private var bookmarks
    @Environment(\.dismiss) private var dismiss

    @State private var dragFraction: Double?
    @State private var sheetDragY: CGFloat = 0
    @State private var showChaptersSheet = false
    @State private var bookmarkFlash = false

    var body: some View {
        let book = player.current ?? SampleData.nowPlaying
        ZStack {
            LinearGradient(
                colors: [
                    Color(hslHue: book.hue, saturation: 0.44, lightness: 0.46),
                    Color(hslHue: book.hue, saturation: 0.38, lightness: 0.22),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .blur(radius: 60).scaleEffect(1.6).ignoresSafeArea()

            // Static tint over the blurred gradient. A live `.ultraThinMaterial` here
            // re-samples the moving backdrop during the cover's slide-down dismiss,
            // which shows up as a band of color sliding out of sync — so we tint directly.
            Rectangle()
                .fill(p.isDark ? Color.black.opacity(0.74) : Color(hex: "F4EEE4").opacity(0.7))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header(book: book)
                Spacer(minLength: 8)
                CoverArt(hue: book.hue, cornerRadius: 24, imageURL: book.coverURL)
                    .frame(width: 286, height: 286)
                    .shadow(color: .black.opacity(0.5), radius: 35, y: 20)
                    .overlay { if player.isLoading { ProgressView().tint(.white).scaleEffect(1.4) } }
                    .gesture(dismissDrag)
                Spacer(minLength: 8)
                controls(book: book)
            }
            .offset(y: sheetDragY)

            if bookmarkFlash {
                Label("Bookmarked", systemImage: "bookmark.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(p.onAccent)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(p.accent))
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .sheet(isPresented: $showChaptersSheet) {
            ChaptersBookmarksSheet(bookId: book.id)
        }
    }

    private func addBookmark() {
        guard let book = player.current else { return }
        bookmarks.add(bookId: book.id, bookTitle: book.title,
                      positionSeconds: player.position, chapterTitle: player.chapterDisplay)
        withAnimation(.spring(duration: 0.25)) { bookmarkFlash = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { bookmarkFlash = false }
        }
    }

    /// Drag the artwork down to dismiss, matching a sheet's feel.
    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 { sheetDragY = value.translation.height }
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { sheetDragY = 0 }
                }
            }
    }

    private func header(book: Book) -> some View {
        HStack {
            circleButton("chevron.down") { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text("NOW PLAYING").font(.system(size: 11)).tracking(1.4).foregroundStyle(p.text3)
                Text(book.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.text2).lineLimit(1)
            }
            Spacer()
            circleButton("list.bullet") { showChaptersSheet = true }
        }
        .padding(.horizontal, 24).padding(.top, 12)
    }

    private func controls(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MarqueeText(text: book.title, size: 23, weight: .bold, color: p.text)
            Text(player.chapterDisplay.isEmpty ? book.author : player.chapterDisplay)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent).lineLimit(1)
                .padding(.top, 4)

            scrubber.padding(.top, 22)

            HStack {
                Text(player.elapsedText)
                Spacer()
                Text(player.remainingText)
            }
            .font(.system(size: 12, design: .monospaced)).foregroundStyle(p.text2).padding(.top, 9)

            transport.padding(.top, 18)

            utilities.padding(.top, 26)
        }
        .padding(.horizontal, 28).padding(.bottom, 30)
    }

    private var scrubber: some View {
        GeometryReader { geo in
            let fraction = dragFraction ?? player.displayProgress
            let x = fraction * geo.size.width
            let midY = geo.size.height / 2
            ZStack(alignment: .leading) {
                Capsule().fill(p.track).frame(height: 6).position(x: geo.size.width / 2, y: midY)
                Capsule().fill(p.accent).frame(width: max(0, x), height: 6).position(x: max(0, x) / 2, y: midY)
                Circle().fill(p.accent)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .overlay(Circle().stroke(p.accentSoft, lineWidth: 4))
                    .position(x: min(max(8, x), geo.size.width - 8), y: midY)
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = min(1, max(0, value.location.x / geo.size.width))
                    }
                    .onEnded { value in
                        let f = min(1, max(0, value.location.x / geo.size.width))
                        player.seek(toFraction: f)
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 16)
    }

    private var transport: some View {
        HStack {
            iconButton("backward.end.fill", size: 22) { player.previousChapter() }
            Spacer()
            skipButton("gobackward", seconds: "\(player.skipBackSeconds)") { player.skipBackward() }
            Spacer()
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24)).foregroundStyle(p.onAccent)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(p.accent))
                    .shadow(color: p.accentSoft, radius: 13, y: 10)
            }
            .buttonStyle(.plain)
            Spacer()
            skipButton("goforward", seconds: "\(player.skipForwardSeconds)") { player.skipForward() }
            Spacer()
            iconButton("forward.end.fill", size: 22) { player.nextChapter() }
        }
    }

    private var utilities: some View {
        HStack(spacing: 10) {
            Button { player.cycleSpeed() } label: { tileText(speedText, label: "Speed") }
                .buttonStyle(.plain)

            Menu {
                Button("Off") { player.setSleep(minutes: nil) }
                ForEach([5, 10, 15, 30, 45, 60], id: \.self) { m in
                    Button("\(m) min") { player.setSleep(minutes: m) }
                }
            } label: {
                tileIcon("moon", label: player.sleepMinutes.map { "\($0)m" } ?? "Sleep",
                         active: player.sleepMinutes != nil)
            }

            Button { addBookmark() } label: {
                tileIcon("bookmark", label: "Bookmark", active: hasBookmarks)
            }
            .buttonStyle(.plain)
            outputTile
        }
    }

    private var hasBookmarks: Bool {
        guard let id = player.current?.id else { return false }
        return !bookmarks.bookmarks(forBook: id).isEmpty
    }

    private var outputTile: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(p.glassFill)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(p.glassBorder, lineWidth: 0.5))
                RoutePickerButton(tint: UIColor(p.text))
                    .frame(width: 26, height: 26)
            }
            .frame(width: 50, height: 50)
            Text("Output").font(.system(size: 11)).foregroundStyle(p.text2)
        }
        .frame(maxWidth: .infinity)
    }

    private var speedText: String {
        let r = player.rate
        return r.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.1f×", r) : String(format: "%g×", r)
    }

    // MARK: - Pieces

    private func tileText(_ text: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(text)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(p.text)
                .frame(width: 50, height: 50)
                .background(tileBackground(active: false))
            Text(label).font(.system(size: 11)).foregroundStyle(p.text2)
        }
        .frame(maxWidth: .infinity)
    }

    private func tileIcon(_ system: String, label: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: system).font(.system(size: 18))
                .foregroundStyle(active ? p.accent : p.text)
                .frame(width: 50, height: 50)
                .background(tileBackground(active: active))
            Text(label).font(.system(size: 11)).foregroundStyle(active ? p.accent : p.text2)
        }
        .frame(maxWidth: .infinity)
    }

    private func tileBackground(active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(active ? p.accentSoft : p.glassFill)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(p.glassBorder, lineWidth: 0.5))
    }

    private func circleButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.text)
                .frame(width: 40, height: 40)
                .background { Circle().fill(p.glassFill).overlay(Circle().strokeBorder(p.glassBorder, lineWidth: 0.5)) }
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ system: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: size)).foregroundStyle(p.text)
        }
        .buttonStyle(.plain)
    }

    private func skipButton(_ system: String, seconds: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: system).font(.system(size: 34)).foregroundStyle(p.text)
                Text(seconds).font(.system(size: 9, weight: .bold)).foregroundStyle(p.text).offset(y: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Native AirPlay / output route picker.
private struct RoutePickerButton: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tint
        view.activeTintColor = tint
        view.prioritizesVideoDevices = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
    }
}
