#if DEBUG
import SwiftUI

/// Screenshot/dev harness. When launched with `SPINEFIN_PREVIEW`, signs in to the
/// test server for real and renders one screen with live data. Debug-only.
struct PreviewHost: View {
    let name: String

    @State private var auth = AuthStore.preview()
    @State private var player = PlayerModel()
    @State private var library = LibraryStore()
    @State private var downloads = DownloadManager.shared
    @State private var bookmarks = BookmarkStore()
    @State private var settings = SettingsStore()
    @State private var ready = false

    // Supplied via env vars so no credentials live in source:
    // SPINEFIN_PREVIEW_URL / SPINEFIN_PREVIEW_USER / SPINEFIN_PREVIEW_PASS
    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var serverURL: String { env["SPINEFIN_PREVIEW_URL"] ?? "" }

    var body: some View {
        Group {
            if ready {
                resolved
            } else {
                ZStack { SpineBackground(); ProgressView().tint(Theme.accent) }
                    .task { await boot() }
            }
        }
        .environment(auth)
        .environment(player)
        .environment(library)
        .environment(downloads)
        .environment(bookmarks)
        .environment(settings)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var resolved: some View {
        switch name {
        case "detail":
            NavigationStack {
                if let book = library.books.first {
                    BookDetailView(book: book)
                } else {
                    Text("No books").foregroundStyle(.secondary)
                }
            }
        case "nowplaying":
            NowPlayingView()
        case "downloads":
            DownloadsView()
        case "settings":
            SettingsView()
        case "signin":
            NavigationStack {
                LoginView(server: DiscoveredServer(baseURLString: serverURL, serverName: "Demo"))
            }
        default:
            MainTabView()
        }
    }

    private func boot() async {
        if !serverURL.isEmpty, let url = URL(string: serverURL) {
            let api = JellyfinAPI(baseURL: url)
            let user = env["SPINEFIN_PREVIEW_USER"] ?? ""
            let pass = env["SPINEFIN_PREVIEW_PASS"] ?? ""
            if let result = try? await api.authenticate(username: user, password: pass) {
                let server = ServerConnection(
                    serverName: "Demo",
                    baseURLString: serverURL,
                    userId: result.user.id,
                    username: result.user.name,
                    accessToken: result.accessToken,
                    serverId: result.serverId
                )
                auth = AuthStore.preview(server: server)
                library.configure(server)
                library.downloads = downloads
                player.settings = settings
                await library.load()
                if name == "nowplaying", let book = library.books.first {
                    player.play(book, using: library)
                }
            }
        }
        ready = true
    }
}
#endif
