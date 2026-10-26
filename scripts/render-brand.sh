#!/usr/bin/env bash
# Renders the app icon (Liquid Glass layers + classic icon set) and brand previews from
# Sources/Design/BrandMark.swift. Re-run after changing the logo.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -parse-as-library Sources/Design/Theme.swift Sources/Design/BrandMark.swift scripts/BrandRenderer.swift -o build/brand-renderer
build/brand-renderer "$PWD"
