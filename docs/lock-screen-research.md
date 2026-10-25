# Live video on the lock screen: research notes

*Researched 25 October 2026 on macOS 27.0.1 (26A434) with Xcode 27.1 (27A9275) and the MacOSX27 SDK.*

## Question

Can a third-party app show **live video on the macOS lock screen and login window** on macOS 26
or later, using the system wallpaper extension point (`EXAppExtensionAttributes` →
`EXExtensionPointIdentifier = com.apple.wallpaper`)?

Project rule: build it **only** if it can be done with public, documented API. That means no
declarations reconstructed from private symbols, no code copied from other apps, and no other
app's servers.

## Answer

**No, not with public API.** We did not build a Labs extension target.

The wallpaper extension point exists, and Apple's own wallpapers (Aerials, Dynamic, Sonoma,
Sequoia and others) are extensions of it. But the framework behind it, `WallpaperExtensionKit`,
is a **private framework**. The SDK ships it with no headers, no Swift interface and no module
map. The extension point's definition lists an Apple-private entitlement as required, but
**macOS 27 doesn't enforce it** (see the correction in section 2): a notarized third-party
extension without it is launched by the system. Apple documents neither the extension point nor
the framework, and nothing about wallpapers was announced at WWDC25 or WWDC26. So the blocker is
the undocumented, private protocol, not signing or notarization.

WallLoop instead sets a still frame of the current video as the desktop picture, using public
API. The lock screen shows that frame (see [What WallLoop does instead](#what-wallloop-does-instead)).

## Method and findings

### 1. The SDK

The `MacOSX27.sdk` and `MacOSX27.0.sdk` paths are symlinks to `MacOSX.sdk`, so the searches
below target the real directory.

```bash
SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
find "$SDK/" -iname '*wallpaper*'
```

All matches are under **`System/Library/PrivateFrameworks`**, and none are under `Frameworks`:

| Framework | Contents in the SDK |
| --- | --- |
| `WallpaperExtensionKit.framework` | `WallpaperExtensionKit.tbd` only |
| `Wallpaper.framework` | `.tbd` only |
| `WallpaperFoundation.framework` | `.tbd` only |
| `WallpaperTypes.framework` | `.tbd` only |
| `WallpaperServices.framework` | `.tbd` only |
| `WallpaperSettingsUI.framework` | `.tbd` only |
| `WallpaperAnalytics.framework` | `.tbd` only |

```bash
find "$SDK/System/Library/PrivateFrameworks" -path '*Wallpaper*' \
  \( -name '*.h' -o -name '*.swiftinterface' -o -name '*.modulemap' -o -name '*.swiftmodule' \)
# → no output
```

- **The frameworks have no headers, Swift interfaces or modules.** A `.tbd` is only a linker stub:
  a list of exported symbol names. `WallpaperExtensionKit.tbd` gives its install name as
  `/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/…` (version 313.0.4,
  Swift ABI 7). It exports a long list of mangled Swift symbols (the file is 965 lines).
- **Using it would mean reverse engineering.** Calling the framework requires hand-writing
  declarations that match those mangled names, or loading it at runtime and inspecting its types.
  The project rule excludes both. We did not decode or use any of the symbols.
- **No public framework mentions wallpapers.**
  ```bash
  grep -rIl -i wallpaper "$SDK/System/Library/Frameworks" --include='*.h' --include='*.swiftinterface'
  grep -rIl "com.apple.wallpaper" "$SDK/System/Library/Frameworks"
  grep -rIl -i wallpaper "$SDK/usr/include"
  # → no output for all three
  ```
  The only public API in this area is `NSWorkspace.setDesktopImageURL(_:for:options:)`, which
  speaks of the "desktop image", not "wallpaper".
- **Xcode has no wallpaper extension template.**
  ```bash
  find /Applications/Xcode.app/Contents/Developer -path '*Templates*' -iname '*wallpaper*'   # → 0 results
  ```

### 2. The running system

```bash
plutil -p /System/Library/ExtensionKit/ExtensionPoints/com.apple.wallpaper.appexpt
```
```
"com.apple.wallpaper" => {
  "EXRequiredEntitlements"     => { "com.apple.private.wallpaper.extension" => true }
  "EXRequiredHostEntitlements" => { "com.apple.private.wallpaper.extension-host" => true }
}
```

**This is the decisive finding.** The extension point requires every extension to carry
**`com.apple.private.wallpaper.extension`**. The `com.apple.private.` prefix marks an
Apple-private entitlement. Apple staff have said on the developer forums that third-party
developers can't get a provisioning profile that authorizes an Apple-private entitlement
([thread 756747](https://developer.apple.com/forums/thread/756747),
[thread 87740](https://developer.apple.com/forums/thread/87740)).

**Correction (25 October 2026, later the same day).** The entitlement requirement is not enforced
in practice. A notarized Developer ID app installed on this Mac ships an extension declaring
`EXExtensionPointIdentifier = com.apple.wallpaper` whose only entitlement is
`com.apple.security.app-sandbox` (no `com.apple.private.wallpaper.extension`, no provisioning
profile), and the system launches it. We checked only its signing metadata and Info.plist
(`codesign -d --entitlements`, `codesign -dvv`, `plutil -p`, `otool -L`), not its code. Its
extension links only the public `ExtensionFoundation` and `AVFoundation`, not
`WallpaperExtensionKit`, so it must implement the wallpaper agent's private protocol itself.

```bash
ls /System/Library/ExtensionKit/Extensions | grep -i -E 'wallpaper|aerial'
pluginkit -mAvvv -p com.apple.wallpaper
```

These list Apple's own wallpaper extensions: `WallpaperAerialsExtension`,
`WallpaperDynamicExtension`, `WallpaperImageExtension`, `WallpaperSonomaExtension`,
`WallpaperSequoiaExtension`, `WallpaperGradientExtension`, `WallpaperMacintoshExtension` and
others. Live and animated wallpapers on the lock screen come from these extensions. A
third-party app installed on this Mac also registers an extension at this point. We deliberately
didn't inspect it, because of the rule against studying other wallpaper apps.

### 3. Documentation and WWDC

| Source | Finding |
| --- | --- |
| [ExtensionKit](https://developer.apple.com/documentation/extensionkit) and [ExtensionFoundation](https://developer.apple.com/documentation/extensionfoundation) docs (read via their JSON data, which has no "wallpaper" mentions) | General app-extension and extension-point APIs. No wallpaper extension point is documented. |
| [App extension Info.plist keys](https://developer.apple.com/Library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AppExtensionKeys.html) | No wallpaper extension point identifier is listed. |
| [`NSWorkspace.setDesktopImageURL(_:for:options:)`](https://developer.apple.com/documentation/appkit/nsworkspace/setdesktopimageurl(_:for:options:)) | Public since macOS 10.6. Sets the desktop image for one screen, with scaling, clipping and fill-colour options, and must be called on the main thread. It doesn't mention the lock screen. |
| [ScreenSaver framework](https://developer.apple.com/documentation/screensaver) | Public, but it's for screen savers, not wallpapers. A screen saver doesn't run on the lock screen or login window as its background. |
| [Customize the wallpaper on your Mac](https://support.apple.com/guide/mac-help/choose-your-desktop-picture-mchlp3013/mac) and [Wallpaper settings](https://support.apple.com/guide/mac-help/wallpaper-settings-mchlp1103/mac) (Apple Support) | Apple's aerials animate as you lock or unlock your Mac, and by default the aerial wallpaper is also the screen saver. Users can pick their own pictures or folders, but those are static images. |
| Apple Developer Forums ([765870](https://developer.apple.com/forums/thread/765870), [111581](https://developer.apple.com/forums/thread/111581)) | Developers asking for a wallpaper or lock screen API are told to file enhancement requests. No API exists. |
| WWDC25 (macOS 26) and WWDC26 (macOS 27) coverage | New default wallpapers, but no developer wallpaper or lock screen API. |

Public write-ups say the third-party projects that reach this extension point load
`WallpaperExtensionKit` at runtime and inspect its private types. That is the reverse-engineering
path this project rules out. We didn't read any of their code.

## Risks if WallLoop used the private extension point anyway

Recorded so the decision is easy to revisit:

- **It could break on any macOS update.** Private frameworks have no stability promise. Their
  types, XPC protocol or entitlement checks can change in any update, even a minor one, with no
  warning or deprecation period.
- **The private entitlement could start being enforced.** It's listed as required today but not
  checked; a future update could start checking it, and Apple won't grant it.
- **App Store:** guideline 2.5.1 (public APIs only) means it would be rejected. WallLoop isn't on
  the App Store, but this rules that channel out for good.
- **Notarization:** notarization checks for malware and code signing, not API use, so it might
  still pass. That isn't a promise it will run.
- **System stability:** the wallpaper agent also draws the lock screen and login window. A
  misbehaving extension could leave the lock screen black or crash the agent, at the one moment
  the user needs to get back into their Mac.
- **Trust and support:** it would depend on undocumented behaviour, against WallLoop's promise to
  be simple and private. Bugs would show up as "my lock screen broke", which is hard to support.

## What WallLoop does instead

This is the default, stable path, in `Sources/Engine/LockScreenStill.swift`:

1. Every time the wallpaper changes, WallLoop reads a frame from each display's video with
   `AVAssetImageGenerator.image(at:)`. This runs in the background and is sized to the display.
2. It writes the frame as a JPEG with a **unique file name** (`still-<UUID>.jpg`). The system
   caches desktop pictures by URL, so reusing a name can show a stale image.
3. It calls `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` for each screen. The scaling
   options match the video's Fill, Fit or Stretch mode, so nothing jumps when the screen locks.
4. It deletes the previous stills once the new ones are set.

On macOS 14 and later, the lock screen shows the desktop picture, so it shows the same frame the
live video was playing. Only the lock screen itself is still; the desktop is live again as soon
as you unlock.

## What would change this conclusion

- **Apple publishes the framework.** For example, `WallpaperExtensionKit` moves to
  `System/Library/Frameworks` with headers or a `.swiftinterface`, or gets a documentation page.
- **Apple opens the extension point.** For example, a new `.appexpt` without the
  `com.apple.private.` entitlement requirement, or an entitlement developers can request in the
  developer portal.
- **Xcode adds a "Wallpaper Extension" target template.**
- **A WWDC session or the release notes announce third-party wallpapers or lock screen
  backgrounds for macOS.**

If any of these happen, we'd build the separate `WallLoopLockScreen` extension target as planned:
a Labs toggle in Settings that's off by default, embedded only in the direct build, sharing the
current video through an App Group container. The main app would keep working without it.

### Checklist for each new macOS or Xcode release

```bash
SDK="$(xcrun --sdk macosx --show-sdk-path)/"
# 1. Any public wallpaper framework or interface?
find "$SDK/System/Library/Frameworks" -iname '*wallpaper*'
grep -rIl -i wallpaper "$SDK/System/Library/Frameworks" --include='*.h' --include='*.swiftinterface'
# 2. Does the private framework now ship an interface?
find "$SDK/System/Library/PrivateFrameworks" -path '*Wallpaper*' \( -name '*.h' -o -name '*.swiftinterface' \)
# 3. Does the extension point still require a private entitlement?
plutil -p /System/Library/ExtensionKit/ExtensionPoints/com.apple.wallpaper.appexpt
# 4. Is there an Xcode template?
find "$(xcode-select -p)" -path '*Templates*' -iname '*wallpaper*'
```

Then search developer.apple.com and that year's WWDC session list for "wallpaper".
