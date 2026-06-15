# Spinefin — App Store Submission

Draft metadata + checklist for submitting Spinefin to the App Store.

## What's already done (in the project)
- ✅ **App icon** — `Spinefin/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024², amber spine mark)
- ✅ **Privacy manifest** — `Spinefin/Support/PrivacyInfo.xcprivacy` (no tracking, no data collected; required-reason APIs declared for UserDefaults `CA92.1` and file timestamp `C617.1`)
- ✅ **Launch screen** — branded warm-dark background (`LaunchBackground` color)
- ✅ **Version** — `1.0.0 (1)` (set in `project.yml`)
- ✅ **Draft screenshots** — `marketing/01–04` (see note on sizes below)

## App Store Connect metadata (draft)

- **Name:** Spinefin
- **Subtitle (≤30):** Audiobooks for Jellyfin
- **Category:** Books (primary), Entertainment (secondary)
- **Age rating:** 4+
- **Promotional text:** A warm, focused audiobook player for your self-hosted Jellyfin library — resume, chapters, offline, and a beautiful Now Playing screen.
- **Keywords (≤100):** jellyfin,audiobook,audiobooks,player,offline,self-hosted,books,listening,chapters,stream
- **Support URL / Marketing URL:** _TODO — add a real URL (required)._

**Description (draft):**
> Spinefin turns your self-hosted Jellyfin server into a first-class audiobook player.
>
> • Connect to any Jellyfin server (username/password or Quick Connect)
> • Browse your audiobooks with cover art, search, and sort
> • Chapters — including chapters embedded in single-file .m4b books that Jellyfin doesn't expose
> • Resume where you left off, with a Continue Listening shelf
> • Background playback, lock-screen & Bluetooth controls, variable speed, sleep timer, bookmarks
> • Download books for offline listening
>
> Self-hosted and private — your library never leaves your server.

**Privacy nutrition label:** Data Not Collected. No tracking.

## Screenshots
Drafts are in `marketing/` at 1206×2622 (iPhone 16 Pro, 6.3").
**App Store Connect requires 6.9" (1320×2868).** Regenerate on that simulator before upload:
```sh
xcrun simctl boot "iPhone 16 Pro Max"
# then re-run the capture (see scripts/ or the preview harness: SPINEFIN_PREVIEW=library|detail|nowplaying|downloads)
```

## Signing (needs your Apple Developer account — $99/yr)
1. In **App Store Connect**, register the bundle id `com.spinefin.app` and create the app record.
2. Open the project: `open Spinefin.xcodeproj`
3. Select the **Spinefin** target → **Signing & Capabilities** → check *Automatically manage signing* → choose your **Team**.
   (Or set `DEVELOPMENT_TEAM` in `project.yml` and re-run `xcodegen generate`.)
4. Confirm the **Background Modes → Audio** capability is present (it is, via Info.plist).

## Build & upload
```sh
xcodegen generate
xcodebuild -project Spinefin.xcodeproj -scheme Spinefin \
  -sdk iphoneos -configuration Release \
  -archivePath build/Spinefin.xcarchive archive
# then export & upload via Xcode Organizer, or:
xcodebuild -exportArchive -archivePath build/Spinefin.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist
xcrun altool --upload-app -f build/export/Spinefin.ipa -t ios  # or use Transporter
```

## Pre-submission checklist
- [ ] Apple Developer Program membership active
- [ ] Bundle id `com.spinefin.app` registered; app record created
- [ ] Signing team set; Release archive builds
- [ ] 6.9" screenshots regenerated
- [ ] Support URL + privacy policy URL added
- [ ] App Review note: explain it requires a user's own Jellyfin server; provide a demo server + test login for review
- [ ] Consider: background-download continuation before 1.0 (currently downloads run while the app is active)
