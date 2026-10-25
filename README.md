# WallLoop

Live video wallpapers for macOS, made from your own videos.

Put videos in a folder, give WallLoop access to it, and your desktop plays them on a loop,
muted and hardware-decoded, one window per display. WallLoop lives in the menu bar.

> **Status:** early development (Milestone 2 of 8). Videos in `~/Movies/WallLoop` play as the
> wallpaper on every display, with Next, Previous, Pause and the shuffle timer in the menu bar.
> Choosing other folders lands in Milestone 3.

<!-- Screenshots: add docs/screenshots/menu.png, library.png and general.png when the UI is final. -->

## Requirements

- macOS 14 Sonoma or later. On macOS 26 and later, WallLoop uses Liquid Glass.
- To build: Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  (`brew install xcodegen`).

## Build and run

The Xcode project is generated from `project.yml` and isn't checked in. Regenerate it whenever you
add or remove files, or change `project.yml`:

```bash
xcodegen generate
```

Build the Developer ID flavour (Debug):

```bash
xcodebuild -project WallLoop.xcodeproj -scheme WallLoop -configuration Debug -derivedDataPath build/DerivedData build
```

Build the Mac App Store flavour:

```bash
xcodebuild -project WallLoop.xcodeproj -scheme WallLoop-AppStore -configuration Debug -derivedDataPath build/DerivedData build
```

Run the unit tests:

```bash
xcodebuild -project WallLoop.xcodeproj -scheme WallLoop -derivedDataPath build/DerivedData test
```

Launch the app you just built:

```bash
open build/DerivedData/Build/Products/Debug/WallLoop.app
```

WallLoop has no Dock icon. Look for its icon in the menu bar. Opening the app again while it runs
shows the Settings window.

### Signing

Out of the box, builds are signed ad hoc ("Sign to Run Locally") so they work on any Mac without an
Apple Developer account. To sign with your team, create `Config/Local.xcconfig` (it's gitignored):

```
DEVELOPMENT_TEAM = ABCDE12345
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = Apple Development
```

## Project layout

| Path | What's in it |
| --- | --- |
| `project.yml` | XcodeGen spec: the `WallLoop` (Developer ID) and `WallLoop-AppStore` targets, plus tests |
| `Config/` | Info.plist, entitlements for each target, shared build settings |
| `Sources/App` | Entry point, app delegate, and `AppModel`, which connects library, scheduler and engine |
| `Sources/Settings` | `SettingsStore`: preferences saved in `UserDefaults` |
| `Sources/Engine` | `WallpaperEngine`: one desktop-level window per display, shared looping players, lock screen stills |
| `Sources/Library` | `Library`: the videos WallLoop can play |
| `Sources/Scheduler` | `Scheduler`: shuffle deck, in-order playback, history for Previous |
| `Sources/MenuBar` | `MenuBarController`: the status item and its menu |
| `Sources/SettingsWindow` | SwiftUI Settings window (Library, General, About) |
| `Sources/Design` | Liquid Glass helpers, with fallbacks for macOS 14–15 |
| `Sources/Resources` | Asset catalog and app icon |
| `Tests/` | Unit tests (Swift Testing) |
| `scripts/` | Tooling, such as the placeholder icon generator |

Both app targets are sandboxed and compile the same sources. They differ in entitlements and in the
`DIRECT` / `APPSTORE` compilation conditions. Sparkle auto-updates and the experimental Labs features
will only ever ship in the `DIRECT` build.

## Privacy

WallLoop has no analytics, no tracking and no accounts. It reads only the folders you choose, and
your videos, settings and thumbnails never leave your Mac.

## License

MIT. See `LICENSE` (added in Milestone 7).
