#!/usr/bin/env bash
# W0 gate (DETAILED_IMPLEMENTATION_PLAN_W0.md §6): T-01, T-02, T-03 launcher clauses; R-33, R-34, C-01, C-13, K-01, K-02, K-11, K-12.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }

check "T-01 swift build" 'swift build >/dev/null 2>&1'
check "T-01 make builds build/mdv6.app" 'make >/dev/null 2>&1 && [ -d build/mdv6.app ]'
for f in Contents/MacOS/mdv6 Contents/Info.plist Contents/Resources/AppIcon.icns Contents/Resources/mdv6 Contents/Resources/Help.md Contents/Resources/mathFonts.bundle/latinmodern-math.otf Contents/Resources/Alegreya-Regular.otf Contents/Resources/swift-highlights.scm; do
  check "C-13 $f present" "[ -e build/mdv6.app/$f ]"
done
check "K-12 only Contents/ at bundle root" '[ "$(ls build/mdv6.app)" = "Contents" ]'
check "K-12 codesign --verify --deep --strict" 'codesign --verify --deep --strict build/mdv6.app 2>/dev/null'
check "K-02 CFBundleIdentifier com.mdv6.app" '[ "$(plutil -extract CFBundleIdentifier raw build/mdv6.app/Contents/Info.plist)" = com.mdv6.app ]'
check "K-02 CFBundleShortVersionString 1.0.0" '[ "$(plutil -extract CFBundleShortVersionString raw build/mdv6.app/Contents/Info.plist)" = 1.0.0 ]'
check "K-01 LSMinimumSystemVersion 13.0" '[ "$(plutil -extract LSMinimumSystemVersion raw build/mdv6.app/Contents/Info.plist)" = 13.0 ]'
check "K-01 otool minos 13.0" 'otool -l build/mdv6.app/Contents/MacOS/mdv6 | grep -A4 LC_BUILD_VERSION | grep -q "minos 13.0"'
check "C-01 document types" 'plutil -p build/mdv6.app/Contents/Info.plist | grep -q net.daringfireball.markdown'
check "T-03 bin/mdv6 --version prints 1.0.0" '[ "$(MDV6_APP= bin/mdv6 --version)" = 1.0.0 ]'
check "T-03 bin/mdv6 nope.md exits 1 with message" 'out=$(bin/mdv6 nope.md 2>&1 >/dev/null); [ $? -eq 1 ] && [ "$out" = "mdv6: no such file: nope.md" ]'
check "T-03 MDV6_APP=/nonexistent falls through search order" '[ "$(MDV6_APP=/nonexistent bin/mdv6 --version)" = 1.0.0 ]'
check "§5.2 bin/mdv6 -h prints usage" 'bin/mdv6 -h | grep -q "^usage: mdv6"'
# The last search step is Spotlight; a stub mdfind on PATH makes it return nothing so the not-found path is reachable.
check "§5.2 bundle not found exits 1 before args" 'tmp=$(mktemp -d); cp bin/mdv6 "$tmp/mdv6"; printf "#!/bin/sh\nexit 0\n" > "$tmp/mdfind"; chmod +x "$tmp/mdfind"; out=$(cd / && MDV6_APP=/nonexistent PATH="$tmp:/usr/bin:/bin" HOME=/nonexistent "$tmp/mdv6" --version 2>&1); rc=$?; rm -rf "$tmp"; [ $rc -eq 1 ] && echo "$out" | grep -q "mdv6.app not found"'
check "T-02 make dist refuses untagged HEAD before clean/build" 'out=$(make dist 2>&1); rc=$?; [ $rc -ne 0 ] && echo "$out" | grep -q check-version && ! echo "$out" | grep -q "swift build" && ! echo "$out" | grep -q "rm -rf build" && [ -d build/mdv6.app ]'
check "T-02 make dist VERSION=9.9.9 refused" 'out=$(make dist VERSION=9.9.9 2>&1); rc=$?; [ $rc -ne 0 ] && echo "$out" | grep -q "command line" && [ -d build/mdv6.app ]'
check "R-37 swift test runs" 'swift test >/dev/null 2>&1'
check "I-011 vendored SwiftMath inventory" 'bash tools/check-swiftmath.sh >/dev/null 2>&1'
exit $fail
