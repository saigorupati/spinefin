# Spinefin

A native iOS audiobook player for [Jellyfin](https://jellyfin.org). Jellyfin has no
first-class audiobook support, so Spinefin treats a **Music-type library** as an
audiobook shelf (book = album, chapter = track) and adds the listening features that
matter: resume, chapters, offline downloads, speed, and a sleep timer.

## Status

Working today:

- ✅ Project generated from `project.yml` (XcodeGen), iOS 26+, Liquid Glass
- ✅ Multi-server onboarding: add server → sign in (username/password) or **Quick Connect** — verified against a live Jellyfin 10.11 server
- ✅ Keychain-backed session storage, multi-server switching, sign out
- ✅ **Full design system** implemented from the Claude Design handoff — amber tokens, warm dark/light palettes, reusable components (cover card, glass panels, pill buttons, chapter rows, mini-player)
- ✅ **All 7 screens** built in SwiftUI: Add Server, Sign In, Library, Book Detail, Now Playing, Downloads, Settings — mini-player docked above a native Liquid Glass tab bar
- ✅ **Library + Book Detail on live data** (`LibraryStore`): real books (Music-library albums), cover art, and chapters — handles both multi-track and single-file books. Verified against the live server.
- ✅ **Embedded chapter extraction** (`ChapterExtractor`): reads chapter markers straight from single-file `.m4b`s via AVFoundation (Jellyfin doesn't expose them for audio).
- ✅ **Playback engine** (`PlayerModel`): `AVQueuePlayer` streaming, global position across multi-file books, chapter seeking (incl. seeking within single-file books by embedded offsets), variable speed, sleep timer, background audio + lock-screen/Bluetooth controls. Real mini-player + Now Playing with a draggable scrubber. Verified streaming + chapter-seek against the live server.
- ✅ **Progress + resume** (local): playback position is saved on-device (`LibraryStore` progress store) and resumed across launches; drives the **Continue Listening** row. Verified: resumed mid-book after an app kill.
- ✅ **Offline downloads** (`DownloadManager`): download a book (audio + cached cover) with live progress, persisted manifest, delete/manage. The download record stores the full timeline (items, durations, chapters), so downloaded books play **fully offline** — `LibraryStore.playable` short-circuits to a local timeline with no network. Verified: downloaded book played from local files with no server call.
- ✅ **Background downloads**: a background `URLSession` (singleton `DownloadManager.shared` + `AppDelegate` completion-handler wiring) keeps downloads running when the app is suspended or killed, and reconnects to in-flight tasks on launch. Verified: a download completed while the app was force-killed.
- ✅ **Chapters + bookmarks**: tap a chapter in Book Detail to play from it; a chapters/bookmarks sheet in Now Playing (jump to chapter or saved spot); a working Bookmark button with local storage (`BookmarkStore`).

> **Why local, not Jellyfin:** Jellyfin only persists resume positions for Video/Book content types — **Music-type libraries don't store resume** (a progress report just marks the track "played"). Verified against the live server. Cross-device sync would require changing the server library's content type (see roadmap note).

> Downloads still renders from `Core/Models/SampleData.swift` until Phase 5; the view stays, only the data source changes.

### Screenshot harness

Debug builds honor a `SPINEFIN_PREVIEW` env var to render one screen directly:

```sh
SIMCTL_CHILD_SPINEFIN_PREVIEW=nowplaying xcrun simctl launch <udid> com.spinefin.app
# values: library · detail · nowplaying · downloads · settings · signin
```

## Roadmap

1. ~~Scaffold + auth/onboarding~~ ✅
2. ~~Library browsing (albums = books, tracks/chapters), book detail~~ ✅
3. ~~Playback engine (background audio, lock-screen controls, speed, sleep timer)~~ ✅
4. ~~Progress + resume~~ ✅ (local storage; Jellyfin can't store resume for Music libraries)
5. ~~Offline downloads~~ ✅ (delegate-based `URLSession`, offline playback from local files)
6. ~~Chapters + bookmarks~~ ✅ (tap-a-chapter, chapters/bookmarks sheet, local bookmarks)
7. App Store prep — ✅ icon, privacy manifest, launch screen, version, draft screenshots & metadata ([STORE.md](STORE.md)). Remaining: your Apple Developer signing + upload.

Post-v1: CarPlay.

## Architecture

- **SwiftUI**, iOS 26+, built against the iOS 26 SDK (Liquid Glass).
- **`JellyfinAPI`** — focused hand-written REST client (`Core/Networking`).
- **`AuthStore`** — `@Observable`, keychain-persisted multi-server session state.
- App Transport Security allows HTTP for self-hosted LAN servers.
- Background-audio capability declared up front.

## Develop

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate          # regenerate Spinefin.xcodeproj after editing project.yml
open Spinefin.xcodeproj
```

`Spinefin.xcodeproj` is generated and git-ignored — edit `project.yml`, not the project.
