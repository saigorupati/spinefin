import SwiftUI

/// Routes iOS's background-download relaunch events to the download manager.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        // Touching .shared recreates the background session so pending events deliver.
        Task { @MainActor in
            DownloadManager.shared.backgroundCompletionHandler = completionHandler
        }
    }
}

@main
struct SpinefinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthStore()
    @State private var player = PlayerModel()
    @State private var library = LibraryStore()
    @State private var downloads = DownloadManager.shared
    @State private var bookmarks = BookmarkStore()
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let preview = ProcessInfo.processInfo.environment["SPINEFIN_PREVIEW"] {
                PreviewHost(name: preview)
            } else {
                root
            }
            #else
            root
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { player.saveProgress() }
        }
    }

    private var root: some View {
        RootView()
            .environment(auth)
            .environment(player)
            .environment(library)
            .environment(downloads)
            .environment(bookmarks)
            .environment(settings)
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
    }
}
