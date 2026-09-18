#!/usr/bin/env bash
# `make icon`: regenerate mdv6/AppIcon.icns from MDV6.png (drawn by tools/make-icon.swift when absent).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[ -f MDV6.png ] || swift tools/make-icon.swift MDV6.png
rm -rf build_icon && mkdir -p build_icon/AppIcon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s MDV6.png --out build_icon/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  d=$((s*2)); sips -z $d $d MDV6.png --out build_icon/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build_icon/AppIcon.iconset -o mdv6/AppIcon.icns
rm -rf build_icon
echo "wrote mdv6/AppIcon.icns"
