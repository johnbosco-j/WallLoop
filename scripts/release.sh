#!/usr/bin/env bash
#
# Builds, signs, notarizes and packages WallLoop for direct download.
#
# Usage:
#   TEAM_ID=ABCDE12345 NOTARY_PROFILE=wallloop-notary \
#   DOWNLOAD_URL_PREFIX=https://example.org/downloads/wallloop/ \
#     scripts/release.sh
#
#   ADHOC=1 scripts/release.sh     # unsigned DMG for local testing only
#
# Environment:
#   TEAM_ID              Apple Developer Team ID (required unless ADHOC=1)
#   NOTARY_PROFILE       Keychain profile saved with `xcrun notarytool store-credentials`
#                        (required unless ADHOC=1)
#   DOWNLOAD_URL_PREFIX  Where the DMGs will be downloadable from; used for the appcast
#                        enclosure URLs (required unless ADHOC=1)
#   VERSION, BUILD       Override MARKETING_VERSION / CURRENT_PROJECT_VERSION from project.yml
#   SIGN_IDENTITY        Code signing identity (default: "Developer ID Application")
#   SPARKLE_BIN          Folder containing Sparkle's generate_appcast (default: the SwiftPM
#                        artifact under build/)
#   DMG_NAME             File name of the DMG (default: WallLoop-<version>.dmg)
#   ADHOC=1              Skip signing, notarization and the appcast
#
# Output goes to dist/: the DMG, and dist/updates/ with every release DMG plus appcast.xml.
# Keep dist/updates/ between releases: Sparkle builds the feed and delta updates from it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ADHOC="${ADHOC:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
BUILD_DIR="$ROOT/build/release"
DIST_DIR="$ROOT/dist"
UPDATES_DIR="$DIST_DIR/updates"
ARCHIVE="$BUILD_DIR/WallLoop.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"

log() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"; }

project_setting() { awk -v key="$1:" '$1 == key { print $2; exit }' project.yml; }

# Submits a file for notarization and waits; fails with the notary log if Apple rejects it.
notarize() {
    local file="$1" result status id
    result="$BUILD_DIR/notary-$(basename "$file").json"
    xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait \
        --output-format json >"$result" || true
    status="$(plutil -extract status raw -o - "$result" 2>/dev/null || echo unknown)"
    if [[ "$status" != "Accepted" ]]; then
        id="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
        cat "$result" >&2
        [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
        die "Notarization of $(basename "$file") finished with status: $status"
    fi
    echo "Notarization accepted."
}

# --- Check inputs and tools ------------------------------------------------------------

need xcodebuild "Install Xcode from the App Store."
need xcodegen "Install it with: brew install xcodegen"
need python3 "Install Python 3 (it ships with the Xcode command line tools)."

# dmgbuild lays out the DMG window by writing Finder's .DS_Store directly, so it needs no
# Finder automation permission and works in CI. It lives in its own venv under build/.
DMGBUILD_VENV="$ROOT/build/tools/dmgbuild"
if [[ ! -x "$DMGBUILD_VENV/bin/dmgbuild" ]]; then
    log "Installing dmgbuild into build/tools"
    python3 -m venv "$DMGBUILD_VENV"
    "$DMGBUILD_VENV/bin/pip" install --quiet "dmgbuild>=1.6,<2"
fi

if [[ "$ADHOC" == 1 ]]; then
    warn "ADHOC=1: this DMG is NOT signed or notarized. Gatekeeper will block it on other Macs."
    warn "Use it only for local testing. Never upload it."
else
    : "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID}"
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a profile saved with xcrun notarytool store-credentials}"
    : "${DOWNLOAD_URL_PREFIX:?Set DOWNLOAD_URL_PREFIX to the URL folder the DMGs are served from}"
    security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY" \
        || die "No \"$SIGN_IDENTITY\" certificate in your keychain. See README, Releasing."
fi

VERSION="${VERSION:-$(project_setting MARKETING_VERSION)}"
BUILD="${BUILD:-$(project_setting CURRENT_PROJECT_VERSION)}"
[[ -n "$VERSION" && -n "$BUILD" ]] || die "Couldn't read the version from project.yml."
DMG_NAME="${DMG_NAME:-WallLoop-$VERSION$([[ "$ADHOC" == 1 ]] && echo "-adhoc").dmg}"
DMG="$DIST_DIR/$DMG_NAME"

log "Releasing WallLoop $VERSION ($BUILD)"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# --- Build -----------------------------------------------------------------------------

log "Generating the Xcode project"
xcodegen generate --quiet

settings=(MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD")
if [[ "$ADHOC" != 1 ]]; then
    settings+=(
        CODE_SIGN_STYLE=Manual
        CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
        DEVELOPMENT_TEAM="$TEAM_ID"
        ENABLE_HARDENED_RUNTIME=YES
        OTHER_CODE_SIGN_FLAGS=--timestamp
    )
fi

log "Archiving"
xcodebuild archive \
    -project WallLoop.xcodeproj -scheme WallLoop -configuration Release \
    -archivePath "$ARCHIVE" -derivedDataPath "$BUILD_DIR/DerivedData" \
    "${settings[@]}" | grep -E "error:|warning:|ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d "$ARCHIVE" ]] || die "Archive failed. Run the xcodebuild command above without the filter for details."

mkdir -p "$EXPORT_DIR"
if [[ "$ADHOC" == 1 ]]; then
    cp -R "$ARCHIVE/Products/Applications/WallLoop.app" "$EXPORT_DIR/"
    # Hardened Runtime's library validation won't let an ad hoc app load an ad hoc
    # framework (Sparkle), and ad hoc builds are never notarized, so re-sign everything
    # ad hoc without it, inside out, keeping each component's entitlements.
    log "Re-signing ad hoc without Hardened Runtime"
    sparkle="$EXPORT_DIR/WallLoop.app/Contents/Frameworks/Sparkle.framework"
    for item in "$sparkle/Versions/B/XPCServices/Installer.xpc" \
                "$sparkle/Versions/B/XPCServices/Downloader.xpc" \
                "$sparkle/Versions/B/Autoupdate" \
                "$sparkle/Versions/B/Updater.app" \
                "$sparkle" \
                "$EXPORT_DIR/WallLoop.app"; do
        codesign --force --sign - --preserve-metadata=entitlements,identifier "$item"
    done
    codesign --verify --deep --strict "$EXPORT_DIR/WallLoop.app"
else
    log "Exporting with Developer ID"
    cat >"$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$SIGN_IDENTITY</string>
</dict>
</plist>
EOF
    xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" | tail -n 2
fi
APP="$EXPORT_DIR/WallLoop.app"
[[ -d "$APP" ]] || die "Export failed: $APP not found."

# --- Verify, notarize and staple the app ------------------------------------------------

if [[ "$ADHOC" != 1 ]]; then
    feed="$(plutil -extract SUFeedURL raw -o - "$APP/Contents/Info.plist")"
    key="$(plutil -extract SUPublicEDKey raw -o - "$APP/Contents/Info.plist")"
    [[ "$feed" != *example.com* && "$key" != REPLACE* ]] \
        || die "Set APPCAST_URL and SPARKLE_PUBLIC_KEY in Config/Local.xcconfig before releasing."

    log "Verifying the signature"
    codesign --verify --deep --strict --verbose=2 "$APP"

    log "Notarizing the app"
    ditto -c -k --keepParent "$APP" "$BUILD_DIR/WallLoop.zip"
    notarize "$BUILD_DIR/WallLoop.zip"
    xcrun stapler staple "$APP"

    log "Checking Gatekeeper"
    spctl --assess --type execute -vv "$APP"
fi

# --- DMG -------------------------------------------------------------------------------

log "Building $DMG_NAME"
rm -f "$DMG"
"$DMGBUILD_VENV/bin/dmgbuild" -s scripts/dmg/settings.py \
    -D app="$APP" \
    -D background="$ROOT/scripts/dmg/background.tiff" \
    -D icon="$APP/Contents/Resources/AppIcon.icns" \
    "WallLoop" "$DMG"

if [[ "$ADHOC" != 1 ]]; then
    log "Signing and notarizing the DMG"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -vv "$DMG"

    # --- Appcast -----------------------------------------------------------------------

    log "Updating the appcast"
    if [[ -z "${SPARKLE_BIN:-}" ]]; then
        tool="$(find "$BUILD_DIR/DerivedData/SourcePackages/artifacts" \
            -type f -name generate_appcast -path '*Sparkle/bin/*' -print -quit)"
        SPARKLE_BIN="$(dirname "${tool:-.}")"
    fi
    [[ -x "$SPARKLE_BIN/generate_appcast" ]] || die "generate_appcast not found. Set SPARKLE_BIN."
    mkdir -p "$UPDATES_DIR"
    cp "$DMG" "$UPDATES_DIR/"
    "$SPARKLE_BIN/generate_appcast" --download-url-prefix "$DOWNLOAD_URL_PREFIX" "$UPDATES_DIR"
fi

# --- Summary ---------------------------------------------------------------------------

log "Done"
printf '  DMG:      %s (%s)\n' "$DMG" "$(du -h "$DMG" | cut -f1)"
if [[ "$ADHOC" == 1 ]]; then
    printf '  Signed:   no (ad hoc build for local testing)\n'
else
    printf '  Appcast:  %s\n' "$UPDATES_DIR/appcast.xml"
    printf '  Upload the DMG and appcast.xml (plus any delta files) to %s\n' "$DOWNLOAD_URL_PREFIX"
fi
