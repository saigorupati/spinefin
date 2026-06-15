import SwiftUI

struct MainTabView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(AuthStore.self) private var auth
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadManager.self) private var downloads
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var player = player
        Group {
            if player.current != nil {
                tabs.tabViewBottomAccessory { MiniPlayerBar() }
            } else {
                tabs
            }
        }
        .fullScreenCover(isPresented: $player.showNowPlaying) {
            NowPlayingView()
        }
        .task(id: auth.activeServerID) {
            library.configure(auth.activeServer)
            library.downloads = downloads
            player.settings = settings
            await library.loadIfNeeded()
            // Show the last-played book in the mini-player so it can be resumed.
            if player.current == nil, let last = library.continueListening.first {
                player.restoreLastPlayed(last, fraction: last.progress ?? 0, using: library)
            }
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical.fill") {
                LibraryView()
            }
            Tab("Downloads", systemImage: "arrow.down.circle.fill") {
                DownloadsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}
