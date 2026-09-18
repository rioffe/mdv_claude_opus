#!/usr/bin/env bash
# Launches build/mdv6.app on an isolated store (§9.6) and captures its window: `screencapture -l` when the terminal has
# screen-recording permission, else the app's own MDV6_SNAPSHOT_DIR hook (a window snapshot, no screen access needed).
#   tools/observe.sh <name> <file.md> [--theme ID]   → build/observed/<name>.png ; the app keeps running (pid printed)
#   tools/observe.sh snap <name>                     → snapshot the running app's key window as build/observed/<name>.png
#   tools/observe.sh quit                            → quit the observed app
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export MDV6_SUPPORT_DIR="${MDV6_SUPPORT_DIR:-$TMPDIR/mdv6-observed}"
export MDV6_DEFAULTS_SUITE="${MDV6_DEFAULTS_SUITE:-mdv6.observed}"
export MDV6_SNAPSHOT_DIR="$ROOT/build/observed"
mkdir -p build/observed
case "${1:-}" in
  snap)
    name="${2:-window}"
    pid="$(pgrep -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6" | head -1)"
    wid="$(swift tools/windowid.swift "$pid" 2>/dev/null | head -1 | cut -d' ' -f1)"
    if [ -n "$wid" ] && screencapture -l "$wid" -o "build/observed/$name.png" 2>/dev/null; then echo "screencapture → build/observed/$name.png"; exit 0; fi
    osascript -e "tell application \"System Events\" to set frontmost of first process whose unix id is $pid to true" >/dev/null 2>&1
    sleep 0.3
    swift - <<SWIFT
import Foundation
DistributedNotificationCenter.default().postNotificationName(Notification.Name("mdv6.snapshot"), object: nil, userInfo: ["name": "$name", "all": "${SNAP_ALL:-0}"], deliverImmediately: true)
SWIFT
    sleep 1
    ls build/observed/"$name"*.png >/dev/null 2>&1 && echo "snapshot hook → $(ls build/observed/"$name"*.png | tr '\n' ' ')" || { echo "no snapshot written"; exit 1; }
    ;;
  drive)
    # tools/observe.sh drive command <AppCommand raw value> | drive action <name> [index]
    kind="${2:?command|action}"; value="${3:?value}"; index="${4:-0}"; path="${5:-}"
    swift - <<SWIFT
import Foundation
DistributedNotificationCenter.default().postNotificationName(Notification.Name("mdv6.drive"), object: nil, userInfo: ["$kind": "$value", "index": "$index", "path": "$path"], deliverImmediately: true)
SWIFT
    sleep 0.8 ;;
  quit)
    pkill -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6"; echo "quit" ;;
  *)
    name="${1:?name}"; file="${2:?file}"; shift 2
    if [ "${1:-}" = "--theme" ]; then defaults write "$MDV6_DEFAULTS_SUITE" mdv6_theme_id -string "$2"; shift 2; fi
    pkill -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6" 2>/dev/null; sleep 0.5
    "$ROOT/build/mdv6.app/Contents/MacOS/mdv6" "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")" >/dev/null 2>&1 &
    sleep 4
    echo "pid $(pgrep -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6" | head -1)"
    "$0" snap "$name" ;;
esac
