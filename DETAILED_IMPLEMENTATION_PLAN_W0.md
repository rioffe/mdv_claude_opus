# Detailed implementation plan — W0: Runnable bundle

> - **Wave:** W0 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 1 — "Runnable bundle").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** `swift build`, `make`, `codesign --verify --deep --strict build/mdv6.app`, `bin/mdv6 --version`, `bin/mdv6 nope.md`, `make dist` (untagged) and `swift test` all reach the exit codes in §6; the app opens one window.
> - **Budget:** 150–250 production lines across 4–5 files (`IMPLEMENTATION_PLAN.md` §5 row "Package, app entry…"), plus 600–900 non-source lines.
> - **Depends on:** nothing. **Unlocks:** every later wave (the package, the vendored libraries, `tools/speccheck.sh`, the CI workflow).

## 1. Objective and spec obligations

| spec id | obligation | how this wave discharges it |
|---|---|---|
| R-33 | `bin/mdv6` surface of §5.2 | the launcher script, tested by T-03's launcher clauses |
| R-34 | `make` builds `build/mdv6.app`; `make install`; `dist` refuses without an exact tag | `Makefile` + `build.sh`; T-01, T-02 |
| C-01 | bundle layout, document types, entitlements | `mdv6/Info.plist`, `mdv6/mdv6.entitlements`, `build.sh` |
| C-13 | build outputs and ad-hoc codesign | `build.sh` |
| K-01, K-02, K-12 | toolchain, identifier/version, signed bundle, nothing beside `Contents/` | `Package.swift`, `Info.plist`, `build.sh` |
| K-05, R-38 (half) | eleven grammars vendored and pinned | `mdv6/Grammars/*`, `CGrammars` target, `README.md`; highlighting is W3 |
| I-011, T-34 | vendored SwiftMath = upstream 1.7.3 + listed patches | `Vendor/SwiftMath`, its `README.md`, `tools/check-swiftmath.sh` |
| R-37 (half) | suite runnable with `swift test`; CI on push/PR | test targets with one stub file per §9 group; `.github/workflows/build.yml` |
| K-11 (negative half) | `dist` exits before `clean` when untagged or `VERSION=` given | `check-version` target; T-02 |
| E-30 (half) | one window per launch, non-restorable | `App/main.swift` disables state restoration; `WindowAccessor` in W6 |
| T-01, T-02, T-03 (launcher clauses) | scripted build/launcher tests | `tools/gate-w0.sh` runs them |

## 2. Entry preconditions

- Swift ≥ 5.9 toolchain (`swift --version`), macOS ≥ 13, network access to github.com and fonts sources.
- External assets to fetch (recorded with commit/tag in the READMEs): `mgriebling/SwiftMath` tag `1.7.3`; grammars — `tree-sitter/tree-sitter-c`, `-go`, `-rust`, `-bash`, `-javascript`, `-python`, `-ruby`, `tree-sitter-grammars/tree-sitter-yaml`, `-toml`, `alex-pinkus/tree-sitter-swift` (`0.7.3-with-generated-files`), `DerekStride/tree-sitter-sql` (`v0.3.11`); fonts — Alegreya (Google Fonts, OFL), Besley (`indestructible-type/Besley`, OFL), OpenDyslexic (`antijingoist/opendyslexic`, OFL); Latin Modern Math comes with SwiftMath's bundle (GUST licence).

## 3. Deliverables, file by file

### 3.1 `Package.swift` — NEW, ~90–120 lines
`swift-tools-version: 5.9`, `platforms: [.macOS(.v13)]`. Targets: `CGrammars` (C, path `mdv6/Grammars`, sources = every `src/parser.c` + `src/scanner.c`, `publicHeadersPath: "include"`, `cSettings: [.headerSearchPath("<lang>/src")…]`, `-std=c11`); `mdv6Core` (path `mdv6/Core`, resources `.copy("../Fonts")`, `.copy("../Queries")`, `.copy("../Help.md")`; deps MarkdownUI, SwiftTreeSitter, BeautifulMermaid, SwiftMath (path `Vendor/SwiftMath`), CGrammars; `linkerSettings: [.linkedLibrary("sqlite3")]`); `mdv6` executable (path `App`); `mdv6Tests`, `mdv6RenderTests` (paths `Tests/…`). Dependencies: `swift-markdown-ui` from `2.0.2`, `SwiftTreeSitter` from `0.8.0`, `beautiful-mermaid-swift` from `1.0.4`.

### 3.2 `Vendor/SwiftMath/` — NEW (vendored), patches only counted
Upstream 1.7.3 `Sources/SwiftMath` verbatim except the four patches of §10: (1) `MTFont.fontBundle` resolves `mathFonts.bundle` from `Bundle.main` first, then `Bundle.module`, then `Vendor/SwiftMath/mathFonts.bundle` by `#filePath` (C-13); (2) `MTMathAtom.init(type:value:)` made `public`; (3) `\boxed{…}` — `MTBoxed` atom + `MTBoxDisplay` (frame of fraction-rule thickness, 0.35 em padding, C-07.2); (4) `mathFonts.bundle` trimmed to `latinmodern-math.otf` + `.plist` + licences. `Vendor/SwiftMath/README.md` lists each patch by file and hunk. `Vendor/SwiftMath/Package.swift` unchanged apart from the trimmed resource.

### 3.3 `mdv6/Grammars/` — NEW (vendored)
`<lang>/src/parser.c`, `scanner.c` where present, `tree-sitter/*.h` headers; `include/CGrammars.h` declaring `const TSLanguage *tree_sitter_<lang>(void)` for the eleven; `README.md` with repository, tag/commit, licence per grammar (K-05). `mdv6/Queries/<lang>-highlights.scm` copied from each grammar's `queries/highlights.scm` (C-01 lists `*-highlights.scm`).

### 3.4 `mdv6/Fonts/*.otf`, `mdv6/AppIcon.icns`, `mdv6/Help.md`, `mdv6/Info.plist`, `mdv6/mdv6.entitlements` — NEW
Fonts: Alegreya (6 weights), Besley (6), OpenDyslexic (4). Icon generated from a script-drawn `MDV6.png` via `make icon` (`sips` + `iconutil`). `Help.md` — the user-facing help with the sections R-31/§2 cite (`Opening files`, `Moving around`, `Find`, `Bookmarks`, `Sidebars`, `Diagrams and math`, `Editor integration`); final text written in W7. `Info.plist`: `CFBundleIdentifier com.mdv6.app`, `LSMinimumSystemVersion 13.0`, `CFBundleShortVersionString 1.0.0`, `CFBundleVersion 1`, `CFBundleDocumentTypes` (extensions `md markdown mdown`, `LSItemContentTypes net.daringfireball.markdown public.plain-text`), `NSPrincipalClass NSApplication`, `LSApplicationCategoryType`. Entitlements: `com.apple.security.app-sandbox` false, `com.apple.security.files.user-selected.read-only` true.

### 3.5 `build.sh` — NEW, ~80 lines
`build.sh {debug|release}`: `swift build -c $CONFIG`, assemble `build/mdv6.app/Contents/{MacOS/mdv6, Info.plist, Resources/{AppIcon.icns, *.otf, *-highlights.scm, mathFonts.bundle/, mdv6, Help.md}}` (the `mdv6` resource is a copy of `bin/mdv6`), `codesign --force --sign - --entitlements mdv6/mdv6.entitlements build/mdv6.app`, then `codesign --verify --deep --strict`. Nothing besides `Contents/` at the bundle root (K-12). Also copies the SwiftPM resource bundle (`mdv6_mdv6Core.bundle`) into `Resources/` so `Bundle.module` resolves in the bundled app.

### 3.6 `Makefile` — NEW, ~150 lines
Targets of §5.3 verbatim: `build` (default: `deps` then `./build.sh debug`), `release`, `run`, `install`, `install-cli`, `uninstall`, `register`, `clean`, `dist` (= `check-version clean release sign zip-notary notarize staple zip-release checksum verify-release`), `github-release`, `icon`, `check-version`, `test`. `VERSION := $(shell git describe --tags --exact-match 2>/dev/null)`; `check-version` fails when `VERSION` is empty, not `v[0-9]+.[0-9]+.[0-9]+`, or when `$(origin VERSION)` is `command line`. Variables `TEAM_ID`, `CERT_NAME`, `NOTARY_PROFILE ?= mdv6-notary`, `NOTES_FILE`; `sign` exits 1 when `CERT_NAME` is empty; `notarize` exits 1 when `NOTARY_PROFILE` is empty. Artefacts `dist/mdv6-$(VERSION:v%=%)-macos.zip` + `.sha256` (K-11).

### 3.7 `bin/mdv6` — NEW, ~90 lines (bash)
Lines 2–9 are the usage text. Bundle search order of §5.2 evaluated before arguments; `--version` reads `CFBundleShortVersionString` with `defaults read`/`plutil`; `-` as the sole argument copies stdin to `$(mktemp -t mdv6-stdin).md`; each argument resolved absolute, first missing → `mdv6: no such file: <arg>` exit 1; `open -a "$APP" "${paths[@]}"`.

### 3.8 `App/main.swift` — NEW, ~20 lines
`import mdv6Core; mdv6Main.run()` — the executable is thin; `mdv6Core` exposes `public enum mdv6Main { public static func run() }` which in W0 starts `NSApplication` with one window titled `mdv6` (W6 replaces the body).

### 3.9 `mdv6/Core/mdv6App.swift` — NEW (W0 stub, W6 owns), ~40 lines
`mdv6Main.run()` and an `NSApplicationDelegate` that sets `NSApp.setActivationPolicy(.regular)`, opens one non-restorable `NSWindow`, and disables secure state restoration (`applicationSupportsSecureRestorableState` → false; `NSWindow.isRestorable = false`).

### 3.10 `.github/workflows/build.yml` — NEW
On push to `main`, pull request, `workflow_dispatch`: `macos-15`, `swift test`, `./build.sh debug`, `./build.sh release`, verify the C-13 layout, `tar czf mdv6-release.tar.gz -C build mdv6.app`, upload; on push to `main` publish the rolling `latest` prerelease with `gh release`.

### 3.11 `Tests/mdv6Tests/*.swift`, `Tests/mdv6RenderTests/*.swift` — NEW stubs
One file per §9 group: `ContractTests.swift`, `PersistenceTests.swift`, `SessionTests.swift`, `ChromeModelTests.swift` (unit target); `RenderPipelineTests.swift`, `RhythmAndDisplayMathTests.swift`, `HarnessTests.swift` (render target). Each holds one placeholder `testTargetBuilds` that is replaced by the owning wave.

### 3.12 `tools/speccheck.sh`, `tools/gate-w0.sh`, `tools/check-swiftmath.sh` — NEW
`speccheck.sh`: runs `swift test --xunit-output junit.xml`, then Phase A and (with `SPECCHECK_JUDGE_URL` set) Phase B with `--src mdv6/Core --tests Tests`. `gate-w0.sh`: the §6 commands with their expected exits. `check-swiftmath.sh`: clones upstream 1.7.3 to a temp dir and `diff -r`s against `Vendor/SwiftMath/Sources`, printing the changed files (T-34).

## 4. Work items, in order (red → green → refactor)

- **W0-01** Test first: `tools/gate-w0.sh` asserting `swift build` exit 0 → create `Package.swift`, `App/main.swift`, `mdv6/Core/mdv6App.swift`, stub tests; evidence: `swift build` exit 0.
- **W0-02** Vendor SwiftMath: copy upstream, apply the four patches, write `README.md`; test: `tools/check-swiftmath.sh` prints only the listed files; evidence: its output.
- **W0-03** Vendor grammars and queries; `CGrammars` compiles; test: `swift build` exit 0 with `CGrammars` linked; evidence: `nm` of the built library lists `tree_sitter_swift` and `tree_sitter_sql`.
- **W0-04** Fonts, icon, `Info.plist`, entitlements, `build.sh`; test: `gate-w0.sh` asserts `build/mdv6.app` layout (C-13 list) and `codesign --verify --deep --strict` exit 0, `otool -l build/mdv6.app/Contents/MacOS/mdv6 | grep -A3 LC_BUILD_VERSION` shows `minos 13.0`; evidence: the script's output.
- **W0-05** `Makefile` with `check-version`; test: `make dist` and `make dist VERSION=9.9.9` exit non-zero and print no `swift build`/`clean` line (T-02); evidence: exit codes and captured stdout.
- **W0-06** `bin/mdv6`; test: `bin/mdv6 --version` → `1.0.0`; `bin/mdv6 nope.md` → stderr `mdv6: no such file: nope.md`, exit 1; `MDV6_APP=/nonexistent bin/mdv6 --version` still finds `build/mdv6.app` (search order); `bin/mdv6 -h` prints the usage lines; evidence: script output (T-03 launcher clauses).
- **W0-07** CI workflow and `tools/speccheck.sh`; test: `swift test` exit 0 on the stubs; `speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --out build/speccheck` exits 0 or 1 (a red gate, not 2/3 — the invocation is valid); evidence: the summary line.

## 5. Test plan

| group/target file | spec ids | what must be asserted | how it runs |
|---|---|---|---|
| `tools/gate-w0.sh` | R-33, R-34, C-01, C-13, K-01, K-02, K-11, K-12, T-01, T-02, T-03 | exits and outputs of §6 | `bash tools/gate-w0.sh` |
| `tools/check-swiftmath.sh` | I-011, T-34 | diff lists only README-listed files | `bash tools/check-swiftmath.sh` |
| stub test files | R-37 | targets compile and run | `swift test` |

## 6. Gate: commands and expected results

1. `swift build` — exit 0.
2. `make` — exit 0; `build/mdv6.app/Contents/{MacOS/mdv6,Info.plist,Resources/{AppIcon.icns,mdv6,Help.md,mathFonts.bundle}}` exist; `ls build/mdv6.app` prints only `Contents`.
3. `codesign --verify --deep --strict build/mdv6.app` — exit 0.
4. `plutil -extract CFBundleIdentifier raw build/mdv6.app/Contents/Info.plist` → `com.mdv6.app`; `…CFBundleShortVersionString` → `1.0.0`.
5. `bin/mdv6 --version` → stdout `1.0.0`, exit 0. `bin/mdv6 nope.md` → stderr `mdv6: no such file: nope.md`, exit 1.
6. `make dist; echo $?` → non-zero, output contains `check-version` failure and no `swift build`; same for `make dist VERSION=9.9.9`.
7. `swift test` — exit 0 (stubs).
8. `bash tools/check-swiftmath.sh` — prints exactly the files `Vendor/SwiftMath/README.md` lists, exit 0.
9. `open build/mdv6.app` — one window appears (observed), then quit.

## 7. Traceability

| spec id | file.symbol | test | status now → after |
|---|---|---|---|
| R-33 | `bin/mdv6` | T-03 (launcher clauses) | not yet realised → realised (app-side clauses pending W5/W6) |
| R-34, K-11 | `Makefile.check-version`, `build.sh` | T-01, T-02 | not yet realised → realised (T-43 pending: no identity) |
| C-01, C-13, K-02, K-12 | `Info.plist`, `mdv6.entitlements`, `build.sh` | T-01 | not yet realised → realised |
| K-01 | `Package.swift` | T-01 | not yet realised → realised |
| K-05, R-38 | `mdv6/Grammars`, `CGrammars` | T-06, T-37 (W3) | not yet realised → vendored (highlighting W3) |
| I-011 | `Vendor/SwiftMath/README.md` | T-34 | not yet realised → realised |
| R-37 | `Tests/*`, `.github/workflows/build.yml` | `swift test`, CI | not yet realised → suite exists (cases W1–W6) |

## 8. Risks, traps, and the structural rules this wave must not break

- **Grammar ABI:** the runtime is tree-sitter 0.25; a grammar generated for ABI < 13 fails to load at run time, not at build time. Trap: pick tags generated with tree-sitter ≥ 0.22. Check: W3's `Language(language:)` load test for all eleven.
- **tree-sitter-swift** is ~10 MB generated; use the `-with-generated-files` tag (D-15). Do not run `tree-sitter generate`.
- **SwiftPM overlapping target paths:** `mdv6Core` at `mdv6/Core` and `CGrammars` at `mdv6/Grammars` — never at `mdv6/`.
- **`Bundle.module` in a bundled app:** SwiftPM writes `mdv6_mdv6Core.bundle` next to the executable; `build.sh` copies it into `Contents/Resources`, else fonts and queries are missing at launch while `swift run` works. Gate 2 checks the copy.
- **Rule (§6 "Unverified digests"):** every tag/commit written into `Grammars/README.md` and `Vendor/SwiftMath/README.md` is the one actually cloned (`git rev-parse` recorded at fetch time).
- **Rule (§6 "self-certifying commits"):** the W0 commit body carries the gate outputs.

## 9. Exit criteria and handoff contract

Frozen after W0: `Package.swift` target names and paths (`mdv6Core`, `mdv6`, `CGrammars`, `mdv6Tests`, `mdv6RenderTests`), `Vendor/SwiftMath` (edited only by a recorded patch), `mdv6/Grammars`, `build.sh`, `Makefile` target names, `bin/mdv6`. Symbols later waves call: `mdv6Main.run()` (W6 replaces its body), `CGrammars.tree_sitter_<lang>()` (W3), `Bundle.module` resources `Fonts/`, `Queries/`, `Help.md` (W1 registers fonts; W3 loads queries; W5 copies Help). Next wave re-runs `swift build && bash tools/gate-w0.sh` to confirm W0 is intact.
