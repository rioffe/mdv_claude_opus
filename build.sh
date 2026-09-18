#!/usr/bin/env bash
# build.sh {debug|release} — C-13: swift build, assemble build/mdv6.app, ad-hoc codesign (K-12).
set -euo pipefail
CONFIG="${1:-debug}"
case "$CONFIG" in debug|release) ;; *) echo "usage: build.sh {debug|release}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

swift build -c "$CONFIG" --product mdv6
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/mdv6.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/mdv6" "$APP/Contents/MacOS/mdv6"
cp mdv6/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp mdv6/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp mdv6/Fonts/*.otf "$APP/Contents/Resources/"
cp mdv6/Queries/*-highlights.scm "$APP/Contents/Resources/"
cp -R Vendor/SwiftMath/Sources/SwiftMath/mathFonts.bundle "$APP/Contents/Resources/mathFonts.bundle"
cp bin/mdv6 "$APP/Contents/Resources/mdv6"
chmod +x "$APP/Contents/Resources/mdv6"
cp mdv6/Help.md "$APP/Contents/Resources/Help.md"
# SwiftPM resource bundle for mdv6Core (fonts/queries/Help are also copied flat above so C-01's layout holds).
if [ -d "$BIN/mdv6_mdv6Core.bundle" ]; then cp -R "$BIN/mdv6_mdv6Core.bundle" "$APP/Contents/Resources/"; fi

codesign --force --sign - --entitlements mdv6/mdv6.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "built $APP ($CONFIG)"
