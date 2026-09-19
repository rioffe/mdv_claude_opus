# mdv6

A native macOS viewer for Markdown that renders a `.md` file the way a good document viewer renders a PDF — GitHub-flavoured Markdown, tree-sitter code highlighting, native Mermaid diagrams and LaTeX math, with history, full-text search, bookmarks and back/forward — and never edits the file. Built from scratch against [`SPEC.md`](SPEC.md) (v0.13) and [`TYPOGRAPHY.md`](TYPOGRAPHY.md); every pixel is drawn by AppKit/SwiftUI/CoreText, and anything a renderer cannot handle is shown as its source, never as a blank.

## Setup

- macOS 13.0 or newer; the Swift 5.9+ toolchain (`swift-tools-version: 5.9`; built and tested here with the Swift 6.4 toolchain of Xcode 27.0 on macOS 26.6). No Xcode project — `swift build` and `build.sh` only.
- Dependencies resolve from GitHub on the first build: `swift-markdown-ui` 2.4.1, `SwiftTreeSitter` 0.25.0 (tree-sitter 0.25.10), `beautiful-mermaid-swift` 1.0.4 (`elk-swift` 1.0.2). SwiftMath 1.7.3 is vendored at `Vendor/SwiftMath` with four listed patches ([`Vendor/SwiftMath/README.md`](Vendor/SwiftMath/README.md)); eighteen tree-sitter grammars are vendored under [`mdv6/Grammars`](mdv6/Grammars/README.md); the Alegreya, Besley and OpenDyslexic faces under [`mdv6/Fonts`](mdv6/Fonts/README.md). SQLite is the system `libsqlite3` (FTS5).
- Everything is offline and deterministic except one path: `http(s)` images, fetched only after **View → Load Remote Images** is switched on, through an ephemeral, cookie-free, header-free `GET` with bounded redirects, time and size.
- Environment variables: `MDV6_APP` (launcher: the bundle to use), `MDV6_SUPPORT_DIR` and `MDV6_DEFAULTS_SUITE` (an isolated store for tests and observed runs — replace `~/Library/Application Support/mdv6` and the `com.mdv6.app` defaults domain; an empty value is unset), `MDV6_SNAPSHOT_DIR` (observation hook: `tools/observe.sh`).

```bash
make                 # swift build + build/mdv6.app (ad-hoc signed)
make install         # /Applications/mdv6.app, lsregister, /usr/local/bin/mdv6 → bin/mdv6
```

## Quick start

```bash
make
open build/mdv6.app test-docs/math.md            # or: bin/mdv6 test-docs/math.md
bin/mdv6 test-docs/                               # a directory: README.md or the first .md, the rest in history
echo '# hi' | bin/mdv6 -                          # stdin
bin/mdv6 --version                                # 1.0.0
```

`test-docs/` holds the corpus the tests and the observed pass use: `syntax.md`, `code.md`, `math.md`, `images.md`, `links.md` + `links-sibling.md`, `tables.md`, `thematic-break.md`, `rhythm.md`, `display-math.md`, `diagrams.md`, `mermaid/*.mmd`, `render-cases.json` and `goldens/`.

## Usage

### The window (§5.1 of the spec)

Three panes: the history sidebar (left; ⌃⌘S; drag its divider 180–400 pt; the chevron on the divider collapses it), the article, and the inspector (right; ⌥⌘0 or the toolbar's right-sidebar button; 180–520 pt, persisted) with **ON THIS PAGE** (the `#`–`###` headings, filter with the magnifier) and **BOOKMARKS** (collapsible header with a count; draggable height). The toolbar is five icon buttons: Open… (⌘O), Edit in external editor (⌘E), the theme pop-up (nine themes + System), Bookmark Current Spot (⌘D; filled when the file has one; the new row is revealed in the inspector and marked current), Toggle Inspector (⌥⌘0).

| Menu · item | Shortcut | Notes |
| --- | --- | --- |
| mdv6 · Install Command Line Tool… | — | symlinks `/usr/local/bin/mdv6` → the bundled helper; unprivileged first, then an administrator dialog; every outcome is an alert except cancelling |
| File · Open… / Open in New Window… | ⌘O / ⌘⇧O | ⌘⇧O is the only way to a second window |
| File · Edit · Edit Current File / Choose Editor… / Forget Editor | ⌘E | no editor set → the chooser; a launch failure → an alert with *Choose Different Editor…* |
| Edit · Find… / Search History… | ⌘F / ⌘⇧F | ⌘F goes to the history search field while the sidebar has focus |
| Navigate · Back / Forward | ⌘← / ⌘→ | no-op when empty; beeps when the target file is gone |
| View · Show/Hide Sidebar / Inspector | ⌃⌘S / ⌥⌘0 | |
| View · Zoom In / Zoom Out / Actual Size | ⌘= / ⌘- | 0.60–2.50 in 0.10 steps; a HUD shows the percentage for 0.9 s |
| View · Smart Typography / Load Remote Images | — | "(off for this theme)" for Phosphor and the Standard Erin pair |
| Bookmarks · Bookmark Current Spot / Set Placeholder / Jump to Placeholder / 1…5 | ⌘D / ⌘⇧0 / ⌘0 / ⌘1…⌘5 | slots disabled when empty; a missing file beeps |
| Help · mdv6 Help | ⌘? | copies the bundled `Help.md` to the support directory on every use |

In the article: click a heading to copy its section as Markdown (it flashes); drag to select prose; hover a code block for wrap/copy (right-click: *Copy Without Prompts* on prompted shell blocks); hover a Mermaid diagram for the style menu, source toggle, PNG export and copy (pinch to zoom); right-click display math for *Copy LaTeX*. Local Markdown links open in-app (fragments jump to the first matching GitHub-style slug); a GitHub-style **line citation** — `[Foo.md L10-L12](Foo.md#L10-L12)`, also `#L10`, `#l10-12`, `#L10-12`, and a reversed range — opens the target, scrolls the block containing the cited line to the top and flashes it for 0.6 s. The citation is a position move, not a choice: it pushes no back snapshot and selects no TOC row, unlike a slug fragment. Highlighting is block-granular (the paragraph containing the line, D-44), and a citation works only for the Markdown extensions above — a `.swift` or other target goes to the system opener (C-19.5). Files are watched by path and reload in place on save.

### `bin/mdv6` (§5.2)

| Invocation | Effect | Exit |
| --- | --- | --- |
| `mdv6` | opens the app | 0 |
| `mdv6 FILE… ` / `mdv6 DIR` | absolute paths through `open -a` (LaunchServices); the last file is displayed | 0; `1` + `mdv6: no such file: <arg>` for the first missing argument |
| `mdv6 -` | stdin → `$(mktemp -t mdv6-stdin).md` (sole argument only) | 0 |
| `mdv6 -h` / `--help` | usage (lines 2–9 of the script) | 0 |
| `mdv6 --version` | `CFBundleShortVersionString` of the located bundle | 0 |
| bundle not found | `mdv6: mdv6.app not found (set MDV6_APP or install to /Applications)` | 1 |

Search order: `$MDV6_APP` → `/Applications/mdv6.app` → `~/Applications/mdv6.app` → `../build/mdv6.app` and `../mdv6.app` relative to the script → Spotlight by bundle identifier.

### `make` (§5.3)

`build` (default), `release`, `run`, `install`, `install-cli`, `uninstall`, `register`, `clean`, `icon`, `test`, and the release chain `dist` = `check-version clean release sign zip-notary notarize staple zip-release checksum verify-release` (+ `github-release`). `dist` refuses before any build step unless `HEAD` carries an exact `vX.Y.Z` tag; a command-line `VERSION=` is rejected. Release inputs: `TEAM_ID`, `CERT_NAME` (the checked-in default is a placeholder — set your Developer ID), `NOTARY_PROFILE` (default `mdv6-notary`), `NOTES_FILE`. Artefacts: `dist/mdv6-<version>-macos.zip` + `.sha256`.

### `render-harness` (C-17)

```bash
swift run --package-path tools/render-harness render-harness INPUT --output FILE [--width 860] [--scale 2] [--theme high-contrast]
swift run --package-path tools/render-harness render-harness --scan test-docs/mermaid --output-dir "$TMPDIR/mdv6-scan"
swift run --package-path tools/render-harness render-harness --check test-docs/render-cases.json [--case ID]
```

Exit codes: 0 success / every case as expected; 1 a render or fallback failure; 2 usage, unreadable input, unknown theme or case, unwritable output (the output's parent must exist). One JSON record per case on stdout (`id`, `status` ∈ `pass`/`fail`/`fallback`, `output`); diagnostics on stderr. The harness is one `main.swift` that links `mdv6Core`; discovery, manifest and metrics live in `mdv6/Core/HarnessCases.swift`.

## Artifacts and schemas

- **History** — `UserDefaults["mdv6_history"]`, JSON `[{"id": "<UUID>", "path": "/abs/file.md", "addedAt": <seconds since 2001>}]`, most recent first, ≤ 100; a value that fails to decode is an empty history.
- **Preferences** — `mdv6_theme_id` (`high-contrast`), `mdv6_font_scale` (1.0), `mdv6_smart_typography` (true), `mdv6_load_remote_images` (false), `mdv6_sidebar_collapsed` (false), `mdv6_inspector_visible` (false), `mdv6_inspector_width` (240, clamped 180–520), `mdv6_bookmarks_expanded` (false), `mdv6_bookmarks_height` (240, ≥ 120), `mdv6_editor_app_path` (""), `mdv6.mermaid.style` (`document`). A wrong type, out-of-range number or unknown id falls back at use.
- **`mdv6.db`** (`~/Library/Application Support/mdv6/`, WAL, `synchronous=NORMAL`, `FULLMUTEX`; `meta.schema_version` = 4, each migration one transaction):

```sql
CREATE TABLE articles (id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, filename TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '', indexed_at INTEGER NOT NULL,
    file_mtime INTEGER NOT NULL DEFAULT 0, file_size INTEGER NOT NULL DEFAULT 0);
CREATE VIRTUAL TABLE articles_fts USING fts5(filename, content, path UNINDEXED,
    content='articles', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
CREATE TABLE bookmarks (id INTEGER PRIMARY KEY, path TEXT NOT NULL, title TEXT NOT NULL,
    sort_order INTEGER NOT NULL, created_at INTEGER NOT NULL,
    block_index INTEGER NOT NULL DEFAULT 0, block_fingerprint TEXT NOT NULL DEFAULT '');
CREATE TABLE scroll_positions (path TEXT PRIMARY KEY, block_index INTEGER NOT NULL,
    block_fingerprint TEXT NOT NULL, updated_at INTEGER NOT NULL, file_mtime INTEGER NOT NULL DEFAULT 0);
```

Search queries split the input on whitespace, drop `" ( ) : * ^`, wrap each survivor as `"token"*` and AND them; results use `ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC LIMIT 80` with `snippet(articles_fts, 1, char(2), char(3), '…', 14)`.

- **Help** — `~/Library/Application Support/mdv6/Help.md`, overwritten on every ⌘?.
- **Math URLs** — `![](mdv6-math://inline|display/<base64url(latex)>?s=<size>&c=<RRGGBBAA>)` (in-process only).
- **Column width** (§7.2), with $w_{\mathrm{area}}$ the content width, $w_{\mathrm{side}}$/$w_{\mathrm{insp}}$ the shown panes plus their 8 pt handles, $p$ the theme's gutter and $b = 6$ pt:

$$
w_{\mathrm{col}} = \min\bigl(w_{\mathrm{area}} - w_{\mathrm{side}} - w_{\mathrm{insp}},\; w_{\max}\bigr) - 2p - 2b, \qquad
\text{raster width} = \lfloor \min(\text{natural}, \max(w_{\mathrm{col}} - 36, 1)) \rfloor .
$$

- **Ink weight** (§7.1), over the pixels $D = \{p : g(p) < 200\}$ of a 2× crop enlarged by 4 px and composited on white:

$$
\mathrm{ink}(P) = \frac{1}{|D|} \sum_{p \in D} \bigl(255 - g(p)\bigr), \qquad \mathrm{ink}(P) = 0 \text{ when } D = \varnothing ;
$$

a Mermaid math node passes when $\mathrm{ink}(P_{\mathrm{node}}) \geq 0.9 \cdot \mathrm{ink}(P_{\mathrm{doc}})$. Pixel comparisons pass when $q = |D|/N \leq 0.001$ with $D$ the pixels whose channel differs by more than 8.

- **Render-cases manifest** — `test-docs/render-cases.json` (`version: 1`, cases with `id`, `input`, `kind`, `width`, `scale`, `expect`, optional `golden`, `metric` ∈ `pixel` / `ink` / `sequence-layout` / `rhythm` / `display-math`, optional `theme`). The metric cases are the oracles; the `pixel` goldens are regression guards produced by this pipeline on this host (`tools/update-goldens.sh`).

## Project layout

```
Package.swift                 mdv6Core (mdv6/Core), mdv6 (App), CGrammars (mdv6/Grammars), mdv6Tests, mdv6RenderTests
App/main.swift                the executable: mdv6Main.run()
mdv6/Core/
  ParsedDocument.swift        C-02 block split and TOC headings
  HeadingSlug.swift           C-11 GitHub slugs
  Sections.swift              C-12 section ranges, inline-Markdown stripping
  Anchors.swift               C-08 fingerprints, anchor resolution, scroll validity
  BookmarkTitle.swift         R-27 title rule
  SmartTypography.swift       C-10
  FTSQuery.swift              C-03 query construction and constants
  MathMarkdown.swift          C-07.1 spans/rewrite, C-07.3 plain text
  MathSpec.swift, MathSymbols.swift, MathImageCache.swift   C-07.2 typesetting (vendored SwiftMath)
  MDVMermaidPipeline.swift    C-06.1 sanitiser; prepare/displaySize/rasterize; styles, caches, zoom
  MermaidRepairs.swift        C-06.2 repairs (ownership, state styles, sequence rules)
  MermaidMathNodes.swift      R-15 math node labels
  MDVMermaidDiagramView.swift diagram view + Mermaid fence chrome
  CodeLanguage.swift, CodeRenderer.swift, CodeBlockChrome.swift   C-05 highlighting and code chrome
  ContentLimits.swift         K-14 ceilings; PipelineProbe.swift the parser-entry hook
  ImageLoading.swift          K-14 image decoding, C-16 RemoteImageLoader; ImageProviders.swift the placeholders
  ThemeManager.swift          C-09 MDVTheme, nine themes, ThemeCatalog, CodePalette, fonts
  ArticleTheme.swift          MarkdownUI theme from MDVTheme
  ArticleView.swift           per-block article (rhythm, find tint, stripe, heading click)
  MathViews.swift             inline provider, centred display math, image provider
  FindHighlight.swift         R-24 find model (pure)
  ZoomStep.swift, ColumnWidth.swift, RenderMetrics.swift   R-30, §7.2, §7.1 / C-17 / K-16 metrics
  Database.swift              SQLite (C-03, C-08, migrations)
  HistoryManager.swift, BookmarksManager.swift, PlaceholderStore.swift, Preferences.swift, FileSystem.swift
  AppModel.swift              store bootstrap, startup, window↔session registry
  DocumentSession.swift       §3.1 lifecycle and every navigation/find/bookmark rule
  FileWatcher.swift, SessionClock.swift, HelpManager.swift, EditorLauncher.swift, Diagnostics.swift
  ChromeModel.swift           C-18 metrics/opacities/rules
  SidebarViews.swift          history sidebar and inspector
  DocumentRootView.swift      the window: panes, toolbar, find bar, HUD, command routing
  WindowAccessor.swift        non-restorable windows, appearance, observation hooks
  mdv6App.swift               SwiftUI App, menus, open events, CLI installer
  DocumentRenderer.swift, HarnessCases.swift   offscreen rendering, C-17 harness logic
mdv6/Fonts, mdv6/Queries, mdv6/Grammars, mdv6/Help.md, mdv6/Info.plist, mdv6/mdv6.entitlements, mdv6/AppIcon.icns
Vendor/SwiftMath              vendored SwiftMath 1.7.3 (+ patches)
Tests/mdv6Tests               unit, persistence, session, chrome-rule, build/launcher, diagnostics tests
Tests/mdv6RenderTests         code/math/Mermaid/image pipelines, rhythm & display math, harness, snapshots
tools/render-harness          the C-17 executable (one main.swift)
tools/seed-store, tools/observe.sh, tools/observed-pass.sh, tools/idle-cpu.sh, tools/windowid.swift, tools/click.swift   observed pass
tools/speccheck.sh, tools/gate-w0.sh, tools/check-swiftmath.sh, tools/update-goldens.sh, tools/build-icon.sh
bin/mdv6, build.sh, Makefile, .github/workflows/build.yml
test-docs/                    corpus, Mermaid diagrams, render-cases.json, goldens
```

## Verification

The §9.1 tests read the built bundle, so build first:

```bash
make                                                  # build/mdv6.app; codesign --verify --deep --strict passes
swift test --parallel --xunit-output junit.xml         # the whole suite (T-32 runs the 35 s idle-CPU protocol)
speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --strict --out build/speccheck
export SPECCHECK_JUDGE_URL=https://openrouter.ai/api/v1/chat/completions SPECCHECK_JUDGE_MODEL=openai/gpt-4o-mini SPECCHECK_JUDGE_API_KEY="$OPENROUTER_API_KEY"
speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge llm --strict --out build/speccheck-llm
swift run --package-path tools/render-harness render-harness --scan test-docs/mermaid --output-dir "$TMPDIR/mdv6-scan"
swift run --package-path tools/render-harness render-harness --check test-docs/render-cases.json
bash tools/gate-w0.sh                                 # T-01/T-02/T-03 launcher clauses from the shell
bash tools/check-swiftmath.sh                         # T-34: the vendored diff against upstream (needs network)
tools/observed-pass.sh                                # T-44/T-47/T-48 states → build/observed/*.png (isolated store)
swift tools/click.swift X Y [move|click|right|drag X2 Y2]   # a real pointer event at global screen coordinates (needs Accessibility)
```

`tools/speccheck.sh` runs the test suite and both speccheck phases in one go. Notes: `--parallel` is what makes `swift test` write the xUnit file; test files keep `//` out of string literals on lines with braces (speccheck's Swift adapter treats `//` as a comment even inside a literal). The observed pass drives the running app through its own §5.1 command path (`MDV6_SNAPSHOT_DIR` hooks) and writes window snapshots without needing screen-recording permission; the report says what was looked at.

## Scope

The full specification is implemented. One row is *verification pending* on this host, not deferred: T-43 (a Developer ID signing + notarisation run needs credentials and a `vX.Y.Z` tag; the tag gate and the whole chain — dry-run in a tagged clone — are verified). The §9.6 observed tests (T-44, T-47, T-48) have been driven with real pointer and keyboard input (`tools/click.swift`, `screencapture`) including the hover chevron, Esc hiding the search field, the context menus and drag reorder; the spec asks for a person's look at the result, so `SPEC_BUILD_REPORT.md` lists the snapshots to open.

Two hosts sharing one machine: another build of mdv6 with the same bundle identifier (`com.mdv6.app`) shares `~/Library/Application Support/mdv6` and the `com.mdv6.app` defaults with this one; run one at a time, or give this one an isolated store (`MDV6_SUPPORT_DIR`, `MDV6_DEFAULTS_SUITE`).
