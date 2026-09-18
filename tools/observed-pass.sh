#!/usr/bin/env bash
# The §9.6 observed pass (T-44, T-47, T-48) driven through the app's own command path on an isolated seeded store;
# every state is captured to build/observed/*.png for a person to compare with reference/*.png.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
export MDV6_SUPPORT_DIR="$TMPDIR/mdv6-observed" MDV6_DEFAULTS_SUITE=mdv6.observed
O=tools/observe.sh
seed() { swift run --package-path tools/seed-store seed-store "$MDV6_SUPPORT_DIR" "$MDV6_DEFAULTS_SUITE" "$1" test-docs/math.md test-docs/syntax.md test-docs/tables.md test-docs/code.md test-docs/links.md 2>&1 | tail -1; }
d() { $O drive "$@" >/dev/null; }

seed sevilla
$O T-44-sevilla-start test-docs/math.md
d command setPlaceholder; d action selectTOC 4; $O snap T-44-sevilla-placeholder-toc
d action hover 15; $O snap T-48-stripe-paragraph
d action hover 13; $O snap T-48-stripe-table
d action scrollTo 0; d action selectTOC 0; d action unhover; d command searchHistory; $O snap T-44-search-revealed
d command find; $O snap T-23-findbar-or-global-search
d action toggleBookmarks; $O snap T-44-bookmarks-collapsed
d action toggleBookmarks; d action collapseSidebar; $O snap T-44-sidebar-collapsed
d action expandSidebar
# T-48: placeholder menu → Clear Placeholder; bookmark moves (third → Move Up → second; Move to Bottom; Remove)
d action clearPlaceholder; $O snap T-48-placeholder-cleared
d action moveUp 3; $O snap T-48-third-moved-up
d action moveToBottom 2; $O snap T-48-moved-to-bottom
d action removeBookmark 4; $O snap T-48-removed
$O quit >/dev/null; sleep 1
$O T-48-relaunch-order test-docs/math.md
# T-47: a second window on tables.md; then delete rows until the title reverts
d action newWindow 0 "$ROOT/test-docs/tables.md"; sleep 2; $O snap T-47-second-window
$O quit >/dev/null; sleep 1
seed sevilla >/dev/null
defaults write mdv6.observed mdv6_history -data "$(printf '[]' | xxd -p | tr -d '\n')" 2>/dev/null
$O T-47-single test-docs/syntax.md
d action deleteHistoryRow 0; $O snap T-47-empty-title
$O quit >/dev/null; sleep 1
# Charcoal and Twilight: structure unchanged, title legible on the dark strip (I-015, C-18.1)
seed charcoal >/dev/null; $O T-44-charcoal test-docs/math.md; d command setPlaceholder; d action selectTOC 4; $O snap T-44-charcoal-states; $O quit >/dev/null; sleep 1
seed twilight >/dev/null; $O T-44-twilight test-docs/math.md; d command setPlaceholder; d action selectTOC 4; $O snap T-44-twilight-states; $O quit >/dev/null
ls build/observed/
