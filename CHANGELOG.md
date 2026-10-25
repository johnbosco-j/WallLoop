# Changelog

All notable changes to WallLoop are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and WallLoop uses
[Semantic Versioning](https://semver.org/). The first public release will be 0.1.0.

## [Unreleased]

### Added

- Direct distribution: Developer ID signing, notarization and a DMG built by `scripts/release.sh`.
- Automatic updates with Sparkle 2: "Check for Updates…" in the menu bar and About, plus an
  "Automatically check for updates" setting.
- GitHub Actions workflow that builds and tests every push and pull request.
- MIT license.
- Live video wallpaper on every display: one desktop-level window per display that follows
  display changes and Space switches, with Fill, Fit and Stretch scaling.
- The same video on all displays, or a different one on each.
- Lock screen and login window match the wallpaper: a still frame becomes the desktop picture.
- Shuffle (every video plays before any repeats) or in-order playback, a shuffle timer from
  5 minutes to daily, and Previous / Next / Pause in the menu bar.
- Menu bar app with a Settings window (Library, General, About) that uses Liquid Glass on
  macOS 26 and later.

### Removed

- The Mac App Store build flavour. WallLoop is distributed only as a direct download.
