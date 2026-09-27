#!/usr/bin/env bash
# fetch-mermaid.sh — C-13 / K-19: the pinned mermaid.js for the R-46 web path.
#   tools/fetch-mermaid.sh ensure        download Vendor/mermaid/mermaid.min.js when absent, then verify it
#   tools/fetch-mermaid.sh verify FILE   exit 1, naming both digests, unless FILE's SHA-256 is the pinned one
set -euo pipefail
MERMAID_VERSION="11.4.1"
MERMAID_SHA256="a43bc1afd446f9c4cc66ac5dd45d02e8d65e26fc5344ec0ef787f88d6ddb6f9e"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/Vendor/mermaid/mermaid.min.js"

verify() {
    local actual
    actual="$(shasum -a 256 "$1" | awk '{print $1}')"
    if [ "$actual" != "$MERMAID_SHA256" ]; then
        echo "mermaid.min.js SHA-256 mismatch for $1" >&2
        echo "  expected: $MERMAID_SHA256" >&2
        echo "  actual:   $actual" >&2
        echo "  delete the file and re-run, or update MERMAID_SHA256 together with MERMAID_VERSION." >&2
        exit 1
    fi
}

case "${1:-}" in
    ensure)
        if [ ! -f "$TARGET" ]; then
            echo "→ fetching mermaid.js $MERMAID_VERSION"
            mkdir -p "$(dirname "$TARGET")"
            curl -fsSL "https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VERSION}/dist/mermaid.min.js" -o "$TARGET.tmp"
            mv "$TARGET.tmp" "$TARGET"
        fi
        verify "$TARGET" ;;
    verify) verify "${2:?verify FILE}" ;;
    *) echo "usage: fetch-mermaid.sh {ensure|verify FILE}" >&2; exit 2 ;;
esac
