#!/usr/bin/env bash
# Renders site/assets/*.png from the app's brand code (Sources/Design/Theme.swift and
# BrandMark.swift). Re-run after changing the logo. favicon.svg is hand-written to match.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build
swiftc -O -parse-as-library Sources/Design/Theme.swift Sources/Design/BrandMark.swift \
    site/tools/SiteAssets.swift -o build/site-assets
build/site-assets "$PWD"
# WebP copy of the page icon (brew install webp); the PNG stays as the fallback.
if command -v cwebp >/dev/null; then
    cwebp -quiet -q 90 -alpha_q 100 site/assets/icon-512.png -o site/assets/icon-512.webp
else
    echo "cwebp not found: skipping site/assets/icon-512.webp" >&2
fi
