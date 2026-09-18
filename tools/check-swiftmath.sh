#!/usr/bin/env bash
# T-34 / I-011: the vendored SwiftMath differs from upstream 1.7.3 only in the files Vendor/SwiftMath/README.md lists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d -t mdv6-swiftmath)"
trap 'rm -rf "$TMP"' EXIT
git clone -q --depth 1 --branch 1.7.3 https://github.com/mgriebling/SwiftMath "$TMP/upstream"
EXPECTED="MathBundle/MathFont.swift
MathRender/MTFont.swift
MathRender/MTMathList.swift
MathRender/MTMathListBuilder.swift
MathRender/MTMathListDisplay.swift
MathRender/MTTypesetter.swift"
# Changed or added files (the trimmed font bundle only removes files, listed separately).
CHANGED="$(cd "$ROOT/Vendor/SwiftMath/Sources/SwiftMath" && diff -rq . "$TMP/upstream/Sources/SwiftMath" 2>/dev/null \
  | grep -v '^Only in ' | sed -E 's#^Files \./([^ ]+) and .*#\1#' | sort || true)"
ONLY_UPSTREAM="$(cd "$ROOT/Vendor/SwiftMath/Sources/SwiftMath" && diff -rq . "$TMP/upstream/Sources/SwiftMath" 2>/dev/null \
  | grep "^Only in $TMP/upstream" | sed -E 's#^Only in [^:]+/Sources/SwiftMath/?([^:]*): (.*)$#\1/\2#; s#^/##' | sort || true)"
ONLY_VENDORED="$(cd "$ROOT/Vendor/SwiftMath/Sources/SwiftMath" && diff -rq . "$TMP/upstream/Sources/SwiftMath" 2>/dev/null \
  | grep '^Only in \.' | sort || true)"
echo "changed files:"; echo "$CHANGED"
echo "removed from the font bundle (patch 4):"; echo "$ONLY_UPSTREAM"
if [ -n "$ONLY_VENDORED" ]; then echo "UNEXPECTED files only in the vendored tree:"; echo "$ONLY_VENDORED"; exit 1; fi
if [ "$CHANGED" != "$(echo "$EXPECTED" | sort)" ]; then echo "UNEXPECTED changed-file set (see README.md)"; exit 1; fi
if echo "$ONLY_UPSTREAM" | grep -v '^mathFonts.bundle/' | grep -q .; then echo "UNEXPECTED removals outside mathFonts.bundle"; exit 1; fi
echo "check-swiftmath: OK — only README-listed files differ"
