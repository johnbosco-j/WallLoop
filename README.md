# WallLoop

Live video wallpapers for macOS, made from your own videos.

Put videos in a folder, give WallLoop access to it, and your desktop plays them on a loop,
muted and hardware-decoded, one window per display. WallLoop lives in the menu bar, and it's free
and open source.

> **Status:** in development, not yet released. Items marked *(planned, M…)* below arrive in a later
> milestone.

<!-- Screenshots: add these files when the UI is final, then remove this comment.
![The WallLoop menu](docs/screenshots/menu.png)
![The Library in Settings](docs/screenshots/library.png)
![General settings](docs/screenshots/general.png)
-->

## Features

- **Your videos as the wallpaper.** MP4, MOV and M4V play muted and looping behind your desktop
  icons, on every display and every Space.
- **Every display.** The same video everywhere, or a different one on each display. WallLoop follows
  displays as you connect, disconnect or rearrange them.
- **Fill, Fit or Stretch**, just like the system's own wallpaper settings.
- **Lock screen that matches.** Each time the video changes, a still frame becomes the desktop
  picture, so the lock screen and login window show the same scene.
- **Shuffle or in order**, changing every 5, 15 or 30 minutes, every 1 or 3 hours, daily, or never.
  Shuffle plays every video once before repeating.
- **Menu bar controls:** Previous, Next, Pause and what's playing now.
- **Light on battery:** hardware-decoded playback that never keeps your display awake.
- **Automatic updates** through Sparkle.
- *(planned, M3)* Choose any folders, live updates as you add or remove videos, thumbnails,
  drag and drop to import, and a check that skips videos your Mac can't decode in hardware.
- *(planned, M4)* Favorites, "shuffle favorites only", and the current video's thumbnail in the menu.
- *(planned, M5)* Pause automatically on battery, in Low Power Mode, when an app covers the desktop,
  and while the Mac is locked or asleep.
- *(planned, M6)* Library grid, launch at login and global keyboard shortcuts.

## Install

1. Download the latest `WallLoop-x.y.z.dmg` from the WallLoop page on our community site.
2. Open the DMG and drag **WallLoop** onto **Applications**.
3. Open WallLoop from Applications. It has no Dock icon: look for its icon in the menu bar.
4. Add your videos. Put them in **Movies › WallLoop** (WallLoop creates the folder on first launch),
   or choose another folder in **Settings › Library** *(planned, M3)*. macOS asks once for
   permission to read each folder you choose.

WallLoop is signed with a Developer ID and notarized by Apple, so it opens without Gatekeeper
warnings. If macOS says it can't check the app, you downloaded an unsigned test build: get the
release DMG instead.

Requires macOS 14 Sonoma or later. On macOS 26 and later, WallLoop uses Liquid Glass.

## Privacy

WallLoop has no analytics, no tracking and no accounts. It reads only the folders you choose, and
your videos, settings and thumbnails never leave your Mac.

Its only network access is Sparkle's update check, which downloads the appcast and updates from
the URL configured at build time. You can turn automatic checks off in **Settings › About**.

## Performance

<!-- Filled in after measuring a release build: CPU and GPU use while playing 1080p and 4K HEVC
and H.264 on one and two displays, on battery and on power, measured with
`sudo powermetrics --samplers cpu_power,gpu_power -i 5000` and Activity Monitor. -->

*Measurements coming before the first release.*

## Build from source

You need Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

The Xcode project is generated from `project.yml` and isn't checked in. Regenerate it whenever you
add or remove files, or change `project.yml`:

```bash
xcodegen generate
```

Build (Debug):

```bash
xcodebuild -project WallLoop.xcodeproj -scheme WallLoop -configuration Debug -derivedDataPath build/DerivedData build
```

Run the unit tests:

```bash
xcodebuild -project WallLoop.xcodeproj -scheme WallLoop -derivedDataPath build/DerivedData test
```

Launch the app you just built:

```bash
open build/DerivedData/Build/Products/Debug/WallLoop.app
```

Opening the app again while it runs shows the Settings window.

Every push and pull request is built and tested on GitHub Actions (`.github/workflows/build.yml`).

### Signing for development

Out of the box, builds are signed ad hoc ("Sign to Run Locally") so they work on any Mac without an
Apple Developer account. To sign with your team, create `Config/Local.xcconfig` (it's gitignored):

```
DEVELOPMENT_TEAM = ABCDE12345
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = Apple Development
```

### Project layout

| Path | What's in it |
| --- | --- |
| `project.yml` | XcodeGen spec: the `WallLoop` app, its Sparkle package, and the unit tests |
| `Config/` | Info.plist, entitlements, shared build settings (including the Sparkle feed URL and key) |
| `Sources/App` | Entry point, app delegate, and `AppModel`, which connects library, scheduler and engine |
| `Sources/Settings` | `SettingsStore`: preferences saved in `UserDefaults` |
| `Sources/Engine` | `WallpaperEngine`: one desktop-level window per display, shared looping players, lock screen stills |
| `Sources/Library` | `Library`: the videos WallLoop can play |
| `Sources/Scheduler` | `Scheduler`: shuffle deck, in-order playback, history for Previous |
| `Sources/MenuBar` | `MenuBarController`: the status item and its menu |
| `Sources/SettingsWindow` | SwiftUI Settings window (Library, General, About) |
| `Sources/Updates` | `Updater`: Sparkle auto-updates |
| `Sources/Design` | Liquid Glass helpers, with fallbacks for macOS 14–15 |
| `Sources/Resources` | Asset catalog and app icon |
| `Tests/` | Unit tests (Swift Testing) |
| `scripts/` | `release.sh`, and the placeholder icon generator |

The app is sandboxed with Hardened Runtime. Its entitlements allow reading folders you choose,
remembering them, the Movies folder, outgoing network connections (Sparkle only), and Sparkle's
installer services.

## Releasing

WallLoop ships as a Developer ID-signed, notarized DMG with Sparkle updates. It isn't on the Mac App
Store. `scripts/release.sh` does the whole build: archive, export, verify, notarize, staple, DMG,
sign, notarize the DMG, and update the appcast.

### One-time setup

1. **Join the [Apple Developer Program](https://developer.apple.com/programs/)** (paid, yearly).
2. **Create a Developer ID Application certificate.** In Xcode, open Settings › Accounts, select
   your team, click Manage Certificates, then + › Developer ID Application. Check that it's in your
   keychain:
   ```bash
   security find-identity -v -p codesigning
   ```
3. **Find your Team ID** under Membership details at
   [developer.apple.com/account](https://developer.apple.com/account).
4. **Save notarization credentials.** Create an app-specific password at
   [account.apple.com](https://account.apple.com) (Sign-In and Security › App-Specific Passwords),
   then store it in your keychain under a profile name. It asks for the password:
   ```bash
   xcrun notarytool store-credentials wallloop-notary --apple-id you@example.com --team-id ABCDE12345
   ```
5. **Create the Sparkle update signing key.** Build once so Swift Package Manager downloads Sparkle,
   then run its `generate_keys`. It saves the private key in your login keychain and prints the
   public key:
   ```bash
   build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
   ```
   Back up the private key somewhere safe (`generate_keys -x wallloop-sparkle-private-key`). If
   you lose it, existing users can't install updates.
6. **Point the app at your appcast.** Add to `Config/Local.xcconfig`. Write `https:/$()/` instead
   of `https://`, because `//` starts a comment in xcconfig files:
   ```
   APPCAST_URL = https:/$()/your-site.example/wallloop/appcast.xml
   SPARKLE_PUBLIC_KEY = the-public-key-printed-by-generate_keys
   ```
   Until these are set, the updater stays off and "Check for Updates…" is disabled.
7. **Pick a download folder on your site**, served over HTTPS. The appcast, DMGs and delta updates
   all live there.

### Each release

1. Bump `MARKETING_VERSION` (for example `0.2.0`) and `CURRENT_PROJECT_VERSION` in `project.yml`.
   The build number must go up every release, because Sparkle compares it.
2. Move the `Unreleased` notes in `CHANGELOG.md` under the new version. Optionally write release
   notes as `dist/updates/WallLoop-0.2.0.html`, and Sparkle shows them in the update window.
3. Run the release script:
   ```bash
   TEAM_ID=ABCDE12345 NOTARY_PROFILE=wallloop-notary DOWNLOAD_URL_PREFIX=https://your-site.example/wallloop/ scripts/release.sh
   ```
4. Upload `dist/WallLoop-0.2.0.dmg`, `dist/updates/appcast.xml` and any new `.delta` files from
   `dist/updates/` to that folder on your site. Keep `dist/updates/` between releases, because
   Sparkle builds the feed and delta updates from the DMGs in it.
5. Tag the release:
   ```bash
   git tag v0.2.0 && git push origin v0.2.0
   ```

Options: `VERSION` and `BUILD` override the version, `SIGN_IDENTITY` picks a specific certificate,
`SPARKLE_BIN` points at Sparkle's tools, and `SKIP_DMG_LAYOUT=1` skips arranging the DMG window
(which asks Finder through AppleScript).

To check the build and DMG without an Apple Developer account, make an unsigned test DMG. Never
upload it:

```bash
ADHOC=1 scripts/release.sh
```

### App icon

`Sources/Resources/Assets.xcassets/AppIcon.appiconset` holds a placeholder made by
`scripts/make-placeholder-icon.swift`. To replace it, design a 1024 × 1024 px master and export
these PNGs over the existing files, keeping the names:

| File | Size (px) |
| --- | --- |
| `icon_16x16.png` | 16 × 16 |
| `icon_16x16@2x.png` | 32 × 32 |
| `icon_32x32.png` | 32 × 32 |
| `icon_32x32@2x.png` | 64 × 64 |
| `icon_128x128.png` | 128 × 128 |
| `icon_128x128@2x.png` | 256 × 256 |
| `icon_256x256.png` | 256 × 256 |
| `icon_256x256@2x.png` | 512 × 512 |
| `icon_512x512.png` | 512 × 512 |
| `icon_512x512@2x.png` | 1024 × 1024 |

Follow the macOS icon grid: the artwork sits in an 824 × 824 px rounded square centred on the
1024 px canvas, with transparent margins.

For Liquid Glass on macOS 26 and later, you can also make a layered icon in Apple's Icon Composer.
Save it as `Sources/Resources/WallLoop.icon`, then set `ASSETCATALOG_COMPILER_APPICON_NAME: WallLoop`
in `project.yml` and run `xcodegen generate`. macOS 26 uses the `.icon`. Keep the PNG set so
macOS 14 and 15 still have an icon.

## Legal

WallLoop plays only videos you already have. It doesn't bundle, download or scrape any wallpaper
content, and it doesn't use any other wallpaper app's servers or code. The "Get Free Wallpapers"
menu only opens [Pexels](https://www.pexels.com/videos/), [Pixabay](https://pixabay.com/videos/)
and [Mixkit](https://mixkit.co/free-stock-video/) in your browser. Check each site's license
before you use a video.

## License

WallLoop is released under the [MIT License](LICENSE).
