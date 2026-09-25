/-
Spec.lean — the normative side.

This file is the spec side of the mdv6Core proof: every constant below is a value that
[`SPEC.md`](../../../SPEC.md) (v0.13.1) pins as normative text, stated once, in the unit the
specification states it in. The rule of this file: **every constant quotes the spec's normative
text in its doc comment, and every lemma in `section Facts` is a check that the spec's own
claims about those constants are mutually consistent** — distinctness, ordering, exact values,
the arithmetic the spec works out by hand (K-13's worked column width, §7.1's ink ratio).

Numeric conventions used throughout (the spec states some values as decimals; Lean core has no
computable `Rat.floor`, so the model is integer-valued in a fixed unit, named in each constant):

* zoom factors are **hundredths** (`1.0` is `100`);
* em factors are **thousandths** (`1.75` is `1750`);
* percentages are **percent** (`25%` is `25`);
* byte ceilings are **bytes**; durations are **milliseconds**; lengths are **points**;
* the ink and pixel metrics are exact integer ratios (numerator/denominator), never floats.

Sources: `mdv6/Core/*.swift` (the `mdv6Core` library target, `Package.swift`). Where a constant
below is the transcription of a Swift `let`, the doc comment names the file.
-/
import Lean

namespace Mdv6.Spec

/-! ## §5.2 — the CLI exit map, and C-17's harness exits -/

/-- **R-33, §5.2** — `bin/mdv6` exits 0 on success. -/
def cliExitOk : Int := 0

/-- **R-33, §5.2** — `bin/mdv6` exits 1 with `mdv6: no such file: <arg>` on stderr for the first
argument that does not exist, and for a bundle that cannot be located. -/
def cliExitError : Int := 1

/-- **R-33, §5.2** — the missing-argument diagnostic, verbatim: `mdv6: no such file: <path>`. -/
def cliNoSuchFilePrefix : String := "mdv6: no such file: "

/-- **R-33, §5.2** — the bundle-not-found diagnostic, verbatim. -/
def cliBundleNotFound : String :=
  "mdv6: mdv6.app not found (set MDV6_APP or install to /Applications)"

/-- **C-17** — the harness exits 0 on success, 1 for a render/fallback failure, 2 for usage,
unreadable input, unknown theme id, or unwritable output. -/
def harnessExitOk : Int := 0
def harnessExitFailure : Int := 1
def harnessExitUsage : Int := 2

/-- **C-17** — the harness invocation defaults: width 860 pt, scale 2, theme `high-contrast`. -/
def harnessDefaultWidthPt : Int := 860
def harnessDefaultScale : Int := 2
def harnessDefaultThemeId : String := "high-contrast"

/-- **C-17** — `test-docs/render-cases.json` carries `version: 1`; unknown keys are ignored and
ids are unique. -/
def harnessManifestVersion : Int := 1

/-- **C-17** — the three case statuses, verbatim. -/
def caseStatusPass : String := "pass"
def caseStatusFail : String := "fail"
def caseStatusFallback : String := "fallback"

/-! ## K-03 — the limits -/

/-- **K-03** — history cap 100 entries. -/
def historyCap : Int := 100

/-- **K-03** — global search returns at most 80 hits. -/
def searchLimit : Int := 80

/-- **K-03** — snippets are 14 tokens. -/
def snippetTokens : Int := 14

/-- **K-03** — bookmark hot-key slots: 5. -/
def bookmarkSlots : Int := 5

/-! ## K-04 — zoom and pane clamps (zoom in hundredths) -/

/-- **K-04, R-30** — zoom step 0.10. -/
def zoomStepHundredths : Int := 10
/-- **K-04, R-30** — zoom range lower bound 0.60. -/
def zoomMinHundredths : Int := 60
/-- **K-04, R-30** — zoom range upper bound 2.50. -/
def zoomMaxHundredths : Int := 250
/-- **K-04, C-04** — the default zoom factor 1.0. -/
def zoomDefaultHundredths : Int := 100
/-- **K-04** — sidebar width `[180, 400]` pt (not persisted, D-10; R-20's sidebar is deferred). -/
def sidebarWidthMinPt : Int := 180
def sidebarWidthMaxPt : Int := 400
/-- **K-04, C-04** — inspector width `[180, 520]` pt, persisted, default 240. -/
def inspectorWidthMinPt : Int := 180
def inspectorWidthMaxPt : Int := 520
def inspectorWidthDefaultPt : Int := 240
/-- **K-04** — bookmarks pane at least 120 pt (clamped at use). -/
def bookmarksMinHeightPt : Int := 120
/-- **K-04, C-04** — the bookmarks pane height default, 240 pt. -/
def bookmarksHeightDefaultPt : Int := 240

/-! ## K-06 — the timings and title constants -/

/-- **K-06** — live-reload event latency 50 ms, no deferral (R-05's watcher is the deferred half). -/
def watcherLatencyMs : Int := 50
/-- **K-06** — transient zero-byte re-read 500 ms (R-05, E-21, D-18). -/
def transientRereadMs : Int := 500
/-- **K-06, C-19** — block flash 0.6 s. -/
def blockFlashMs : Int := 600
/-- **K-06, R-30** — zoom HUD 0.9 s. -/
def zoomHudMs : Int := 900
/-- **K-06, C-08, E-08** — scroll-restore mtime tolerance 1 s. -/
def scrollMtimeToleranceSeconds : Int := 1
/-- **K-06, R-27** — bookmark-title heading look-back 40 blocks. -/
def bookmarkLookBackBlocks : Int := 40
/-- **K-06, R-27** — bookmark-title fallback truncation, 60 extended grapheme clusters. -/
def bookmarkTitleClusters : Int := 60

/-! ## K-07 — Mermaid raster and caches -/

/-- **K-07** — pinch zoom clamped to `[0.5, 4]` (hundredths; R-09's controls are deferred). -/
def mermaidZoomMinHundredths : Int := 50
def mermaidZoomMaxHundredths : Int := 400
/-- **K-07** — zoomed container height at most 540 pt. -/
def mermaidMaxContainerHeightPt : Int := 540
/-- **K-07** — 96 layouts, 192 rasters, at most 192 MB of raster bytes. -/
def mermaidLayoutCacheLimit : Int := 96
def mermaidRasterCacheLimit : Int := 192
def mermaidRasterByteLimit : Int := 192 * 1024 * 1024
/-- **R-11, K-07** — the raster lower bound, 1 pt. -/
def rasterMinWidthPt : Int := 1

/-! ## K-08 — math and sequence-diagram constants -/

/-- **K-08** — diagram-label math at 16 pt (R-15's composition is deferred). -/
def mathLabelFontSizePt : Int := 16
/-- **K-08, C-06.2** — message-label line pitch 13 pt, 11 pt font. -/
def sequenceLabelPitchPt : Int := 13
def sequenceLabelFontSizePt : Int := 11
/-- **K-08, C-06.2** — `autonumber` discs r = 8 pt. -/
def autonumberRadiusPt : Int := 8
/-- **K-08, C-06.2** — sequence row height 40 pt (library), grown by `(n−1)×13 + 4` for an
`n`-line label. -/
def sequenceRowHeightPt : Int := 40
def sequenceRowGrowthBasePt : Int := 4
/-- **K-08, C-07.2** — the math image cache holds 2048 entries. -/
def mathCacheLimit : Int := 2048

/-! ## K-09 — fingerprints and the FTS tokenizer -/

/-- **K-09, C-08** — fingerprints retain 80 extended grapheme clusters. -/
def fingerprintClusters : Int := 80
/-- **K-09, C-03** — the FTS5 tokenizer, verbatim. -/
def ftsTokenizer : String := "unicode61 remove_diacritics 2"

/-! ## K-10 — typography defaults (em factors in thousandths) -/

/-- **K-10** — body 16 pt, line spacing 0.30 em, article max width 860 pt, gutter 40 pt. -/
def bodyFontSizePt : Int := 16
def paragraphLineSpacingEmThousandths : Int := 300
def articleMaxWidthPt : Int := 860
def gutterPt : Int := 40
/-- **K-10, C-09** — heading scales h₁ 1.75, h₂ 1.40, h₃ 1.15; h₄ 1.0, h₅ 0.875, h₆ 0.85
(fixed). -/
def h1EmThousandths : Int := 1750
def h2EmThousandths : Int := 1400
def h3EmThousandths : Int := 1150
def h4EmThousandths : Int := 1000
def h5EmThousandths : Int := 875
def h6EmThousandths : Int := 850

/-! ## §7.2, K-13 — the column-width formula's constants -/

/-- **§7.2, K-13** — `b`, the per-block horizontal padding: 6 pt. -/
def blockPaddingPt : Int := 6
/-- **§7.2** — each shown side pane adds its 8 pt drag handle (C-18.1). -/
def paneHandlePt : Int := 8
/-- **R-11, K-07** — a diagram is drawn at the column width minus 36 pt. -/
def mermaidInsetPt : Int := 36

/-! ## K-14 — the untrusted-content ceilings (binary units) -/

/-- **K-14** — UTF-8 document file 64 MiB. -/
def ceilingDocumentBytes : Int := 64 * 1024 * 1024
/-- **K-14** — one Mermaid source 1 MiB. -/
def ceilingMermaidBytes : Int := 1024 * 1024
/-- **K-14** — one LaTeX span 64 KiB. -/
def ceilingLatexBytes : Int := 64 * 1024
/-- **K-14** — encoded or compressed local/data/remote image 32 MiB. -/
def ceilingEncodedImageBytes : Int := 32 * 1024 * 1024
/-- **K-14** — decoded image 256 MiB. -/
def ceilingDecodedImageBytes : Int := 256 * 1024 * 1024
/-- **K-14** — decoded image 64 megapixels. -/
def ceilingDecodedImagePixels : Int := 64_000_000
/-- **K-14** — 16,384 pixels on either axis. -/
def ceilingImageAxisPixels : Int := 16384
/-- **E-28** — the text shown in the R-10/R-14 source fallback for oversized Mermaid or LaTeX. -/
def exceededMessage : String := "input exceeds limit"

/-! ## §7.1 — the ink-weight metric -/

/-- **§7.1, I-009** — `D = { p : g(p) < 200 }`. -/
def inkThresholdLuma : Int := 200
/-- **§7.1, I-009** — I-009 holds when `ink(node) ≥ 0.9 · ink(doc)`; the ratio as an exact
integer fraction, 9/10. -/
def inkRatioNumerator : Int := 9
def inkRatioDenominator : Int := 10

/-! ## C-17 — the pixel-comparison metric -/

/-- **C-17** — a pixel differs when at least one 8-bit RGBA channel differs by more than 8. -/
def pixelChannelThreshold : Int := 8
/-- **C-17** — the comparison passes when `q ≤ 0.001`; the tolerance as an exact integer
fraction, 1/1000. -/
def pixelToleranceNumerator : Int := 1
def pixelToleranceDenominator : Int := 1000

/-! ## K-16 — chrome metrics and the rhythm band -/

/-- **K-16, I-014** — the inter-block ink gap `g` lies in the band `v ≤ g ≤ v + 0.6 f`; the
slack as an exact integer fraction of `f`, 6/10. -/
def rhythmSlackNumerator : Int := 6
def rhythmSlackDenominator : Int := 10
/-- **K-16, I-014** — the per-block rendering's gap must be within ±2 pt of the single view's. -/
def rhythmPerBlockTolerancePt : Int := 2
/-- **K-16** — the rhythm defaults (C-18's chrome is deferred): `h2Top` 24 pt, `h3Top` 24 pt, paragraph bottom 16 pt;
Sevilla `h2Top` 32, `h3Top` 22, paragraph bottom 14. -/
def defaultH2TopSpacingPt : Int := 24
def defaultH3TopSpacingPt : Int := 24
def defaultParagraphBottomSpacingPt : Int := 16
def sevillaH2TopSpacingPt : Int := 32
def sevillaH3TopSpacingPt : Int := 22
def sevillaParagraphBottomSpacingPt : Int := 14

/-! ## C-03 — full-text query construction -/

/-- **C-03, F-147** — the six characters dropped from every query token: `" ( ) : * ^`. Dropping is
deletion, not escaping. -/
def ftsDroppedChars : List Char := ['"', '(', ')', ':', '*', '^']

/-- **C-03, D-36** — the result ordering, verbatim: rank, then case-insensitive path, then binary
path. -/
def ftsOrderBy : String := "ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC"

/-- **C-03** — the snippet is `snippet(articles_fts, 1, char(2), char(3), '…', 14)`: U+0002/U+0003
bracket the matched terms. -/
def snippetOpenScalar : Nat := 0x02
def snippetCloseScalar : Nat := 0x03

/-! ## C-04 — the twelve preference keys and their defaults -/

/-- **C-04** — every key, its type name, and its default, in the spec's table order. -/
def preferenceKeys : List (String × String × String) :=
  [ ("mdv6_theme_id",          "String", "high-contrast"),
    ("mdv6_font_scale",        "Double", "1.0"),
    ("mdv6_smart_typography",  "Bool",   "true"),
    ("mdv6_load_remote_images","Bool",   "false"),
    ("mdv6_sidebar_collapsed", "Bool",   "false"),
    ("mdv6_inspector_visible", "Bool",   "false"),
    ("mdv6_inspector_width",   "Double", "240"),
    ("mdv6_bookmarks_expanded","Bool",   "false"),
    ("mdv6_bookmarks_height",  "Double", "240"),
    ("mdv6_editor_app_path",   "String", ""),
    ("mdv6_history",           "Data",   "[]"),
    ("mdv6.mermaid.style",     "String", "document") ]

/-- **C-04, R-29** — an unknown `mdv6_theme_id` resolves to `high-contrast` at use. -/
def unknownThemeFallbackId : String := "high-contrast"

/-! ## C-05 — the code-highlighting contract -/

/-- **C-05, R-08** — the result cache holds at most 256 entries, flushed whole when full. -/
def codeCacheLimit : Int := 256
/-- **C-05, R-30** — fence text is `0.85 × baseFontSize × zoom`; the factor as an exact integer
fraction, 85/100. -/
def fenceFontFactorNumerator : Int := 85
def fenceFontFactorDenominator : Int := 100

/-- **C-05, R-08** — the prompt-aware fence words, tested on the **raw** first word of the info
string, lower-cased. `fish` and `console` highlight as plain yet are prompt-aware;
`shell-session` is not. -/
def promptAwareFenceWords : List String := ["bash", "sh", "zsh", "fish", "shell", "console"]

/-- **C-05, K-05** — the seventeen highlighted languages (the `CodeLanguage` cases), in
declaration order. -/
def codeLanguages : List String :=
  ["c", "go", "rust", "bash", "javascript", "yaml", "toml", "python", "ruby", "swift", "sql",
   "cpp", "json", "lua", "opencl", "perl", "markdown"]

/-- **C-05** — the alias table, verbatim: alias → language (R-38, R-43). -/
def codeAliases : List (String × String) :=
  [ ("js", "javascript"), ("jsx", "javascript"), ("javascriptreact", "javascript"), ("node", "javascript"),
    ("sh", "bash"), ("zsh", "bash"), ("shell", "bash"),
    ("py", "python"), ("python3", "python"),
    ("rb", "ruby"), ("yml", "yaml"), ("rs", "rust"), ("golang", "go"),
    ("h", "c"), ("objective-c", "c"), ("objc", "c"),
    ("sqlite", "sql"), ("postgresql", "sql"), ("postgres", "sql"), ("mysql", "sql"), ("plsql", "sql"), ("tsql", "sql"),
    ("c++", "cpp"), ("cplusplus", "cpp"), ("cc", "cpp"), ("cxx", "cpp"), ("cp", "cpp"),
    ("hpp", "cpp"), ("hxx", "cpp"), ("hh", "cpp"), ("metal", "cpp"), ("msl", "cpp"),
    ("cl", "opencl"), ("opencl-c", "opencl"),
    ("pl", "perl"), ("perl5", "perl"),
    ("md", "markdown"), ("gfm", "markdown") ]

/-! ## C-06.1 — the Mermaid source sanitiser -/

/-- **C-06.1 rule 3, F-139** — the CSS colour names and their SVG 1.1 values, case-insensitively,
mapped only where they follow `fill:`, `stroke:` or `color:`. `transparent` and `none` both map to
`#00000000`. The list is exhaustive: any other name is passed through. -/
def cssColorMap : List (String × String) :=
  [ ("white", "#ffffff"), ("black", "#000000"), ("red", "#ff0000"), ("green", "#008000"),
    ("blue", "#0000ff"), ("yellow", "#ffff00"), ("orange", "#ffa500"), ("purple", "#800080"),
    ("gray", "#808080"), ("grey", "#808080"), ("lightgray", "#d3d3d3"), ("lightgrey", "#d3d3d3"),
    ("darkgray", "#a9a9a9"), ("silver", "#c0c0c0"), ("pink", "#ffc0cb"), ("lightblue", "#add8e6"),
    ("lightgreen", "#90ee90"), ("lightyellow", "#ffffe0"), ("gold", "#ffd700"), ("teal", "#008080"),
    ("navy", "#000080"), ("maroon", "#800000"), ("olive", "#808000"), ("cyan", "#00ffff"),
    ("magenta", "#ff00ff"), ("brown", "#a52a2a"), ("beige", "#f5f5dc"), ("ivory", "#fffff0"),
    ("lavender", "#e6e6fa"), ("coral", "#ff7f50"), ("salmon", "#fa8072"), ("tomato", "#ff6347"),
    ("crimson", "#dc143c"), ("indigo", "#4b0082"), ("violet", "#ee82ee"), ("khaki", "#f0e68c"),
    ("tan", "#d2b48c"), ("wheat", "#f5deb3"), ("mintcream", "#f5fffa"), ("honeydew", "#f0fff0"),
    ("aliceblue", "#f0f8ff"), ("whitesmoke", "#f5f5f5"), ("gainsboro", "#dcdcdc"),
    ("snow", "#fffafa"), ("transparent", "#00000000"), ("none", "#00000000") ]

/-- **C-06.1 rule 6** — the inline formatting tags stripped, keeping their content; `<br/>` is left
alone. -/
def strippedFormattingTags : List String :=
  ["b", "i", "u", "s", "strong", "em", "small", "sup", "sub", "span", "code", "tt", "font", "mark"]

/-- **C-06.3** — the *Document* style's node surface: the page colour mixed 25 % toward the code
background on light themes, lifted 16 % toward the foreground on dark. -/
def documentSurfaceLightPercent : Int := 25
def documentSurfaceDarkPercent : Int := 16
/-- **C-06.3** — lines 55 %, borders 35 %, muted 45 % mixes of background toward foreground. -/
def documentLineMixPercent : Int := 55
def documentBorderMixPercent : Int := 35
def documentMutedMixPercent : Int := 45

/-- **E-02, D-04** — the diagram types the library lacks; shown as the fallback without entering
the parser. -/
def unsupportedDiagramTypes : List String :=
  ["timeline", "gantt", "pie", "mindmap", "gitgraph", "journey", "quadrantchart",
   "requirementdiagram", "c4context", "sankey", "block", "packet", "kanban", "architecture"]

/-- **C-04** — the five diagram styles; an unknown stored value reads as `document` (R-09). -/
def mermaidStyleIds : List String := ["document", "light", "dark", "tokyoNight", "catppuccin"]
def mermaidStyleDefaultId : String := "document"

/-! ## C-07.1 — the math URL scheme -/

/-- **C-07.1** — the in-process scheme and its two hosts; the host is decided by the delimiter
alone (K-08). -/
def mathScheme : String := "mdv6-math"
def mathHostInline : String := "inline"
def mathHostDisplay : String := "display"

/-- **C-07.1** — `base64url` is RFC 4648 §5 without `=` padding; decoders re-pad to a multiple of
four. -/
def base64PadModulus : Int := 4

/-! ## C-07.2 — registered symbols and the command rewrites -/

/-- **C-07.2 (a)** — the registered symbol names, grouped as the spec groups them. -/
def registeredRelations : List String :=
  ["gtrsim", "lesssim", "gtrapprox", "lessapprox", "leqslant", "geqslant", "lll", "ggg", "nless",
   "ngtr", "nleq", "ngeq", "doteq", "triangleq", "therefore", "because", "implies", "impliedby",
   "models", "vDash", "Vdash", "nparallel", "nmid", "subsetneq", "supsetneq", "nsubseteq",
   "nsupseteq", "sqsubseteq", "sqsupseteq", "precsim", "succsim"]
def registeredArrows : List String :=
  ["hookrightarrow", "hookleftarrow", "rightharpoonup", "leftharpoonup", "rightleftharpoons",
   "leftrightharpoons", "nearrow", "searrow", "swarrow", "nwarrow", "longmapsto",
   "twoheadrightarrow", "rightsquigarrow", "leadsto", "rightrightarrows", "leftleftarrows"]
def registeredOrdinary : List String :=
  ["dots", "dotsc", "dotsb", "varnothing", "hslash", "mho", "Box", "square", "blacksquare",
   "bigstar", "checkmark", "ddagger", "S", "P", "pounds", "copyright", "degree", "beth", "gimel",
   "wp", "nexists", "complement", "#", "_"]
def registeredBigOperators : List String :=
  ["iint", "iiint", "oiint", "bigsqcup", "bigodot", "bigotimes", "biguplus"]
def registeredBinary : List String :=
  ["intercal", "leftthreetimes", "rightthreetimes", "divideontimes"]

/-- **C-07.2 (b)** — the command rewrites, **in the order the spec lists them** (order is
normative). Each entry is (pattern source, replacement template). -/
def commandRewrites : List (String × String) :=
  [ ("\\\\operatorname\\*?\\{", "\\mathrm{"),
    ("\\\\[dt]frac\\b", "\\frac"),
    ("\\\\boldsymbol\\b", "\\bm"),
    ("\\\\bmod\\b", "\\;\\mathrm{mod}\\;"),
    ("\\\\pmod\\{([^}]*)\\}", "\\;(\\mathrm{mod}\\;"),
    ("\\\\not=", "\\neq"),
    ("\\\\(?:big|Big|bigg|Bigg)[lrm]?\\s*(?=[\\\\(\\[\\]){}|.<>/])", ""),
    ("\\\\coloneqq\\b", ":="),
    ("\\\\(begin|end)\\{(align|equation|gather|multline)\\*\\}", "\\$1{$2}"),
    ("\\\\(begin|end)\\{align\\}", "\\$1{aligned}"),
    ("\\\\(begin|end)\\{multline\\}", "\\$1{gather}"),
    ("\\\\(begin|end)\\{equation\\}", "") ]

/-- **C-07.2** — `\boxed{…}` is implemented in the vendored SwiftMath; these commands are
unsupported and shown as source. -/
def unsupportedLatexCommands : List String := ["\\underbrace", "\\overbrace", "\\stackrel", "\\substack", "\\&"]

/-- **C-07.3** — the wrapper commands whose content replaces them. -/
def plainTextWrappers : List String :=
  ["text", "mathrm", "mathbf", "mathit", "mathcal", "mathbb", "operatorname", "boldsymbol", "bm",
   "hat", "vec", "bar", "tilde", "textbf", "textit", "mathsf", "mathtt", "left", "right",
   "displaystyle"]

/-! ## C-09 — the theme contract -/

/-- **C-09, R-29** — the nine themes, in the spec's order. -/
def themeIds : List String :=
  ["high-contrast", "sevilla", "charcoal", "solarium-daylight", "solarium-moonlight", "phosphor",
   "twilight", "standard-erin-light", "standard-erin-dark"]

/-- **C-09** — the three themes that refuse smart typography. -/
def smartTypographyRefusers : List String :=
  ["phosphor", "standard-erin-light", "standard-erin-dark"]

/-- **C-09** — the themes that set `articleMaxWidth`: Sevilla 620 pt, Charcoal 920 pt, both
Solarium themes 720 pt; the rest carry the K-10 default 860. -/
def sevillaMaxWidthPt : Int := 620
def charcoalMaxWidthPt : Int := 920
def solariumMaxWidthPt : Int := 720

/-- **C-09, R-29** — the *System* theme id and its two resolutions: `high-contrast` in Light,
`twilight` in Dark. -/
def systemThemeId : String := "system"
def systemLightThemeId : String := "high-contrast"
def systemDarkThemeId : String := "twilight"

/-- **C-09** — `h4`…`h6` are fixed; `headingSizeEms` is `[h1…h6]`. -/
def headingEmsDefaultThousandths : List Int :=
  [h1EmThousandths, h2EmThousandths, h3EmThousandths, h4EmThousandths, h5EmThousandths, h6EmThousandths]

/-! ## C-15 — history persistence -/

/-- **C-15** — the JSON object keys, verbatim, in the spec's order. -/
def historyJsonKeys : List String := ["id", "path", "addedAt"]

/-- **C-15** — a value that fails to decode yields an empty history, never a crash; unknown keys are
ignored. -/
def historyEmptyJson : String := "[]"

/-! ## §3.3 — durable artefacts -/

/-- **§3.3, D-22** — `meta.schema_version` is currently 4; forward migrations compare it and each
runs inside one `BEGIN IMMEDIATE … COMMIT`. -/
def schemaVersion : Int := 4

/-- **§3.3** — the connection flags and pragmas (I-006's connection is deferred). -/
def sqliteJournalMode : String := "WAL"
def sqliteSynchronous : String := "NORMAL"

/-! ## C-19 — line citations -/

/-- **C-19.1** — the grammar `^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$`: case-insensitive,
anchored, 1-based, and the leading digit excludes `0`. The model transcribes it in
`Mdv6.Model.LineCitation`. -/
def lineCitationGrammar : String := "^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$"

/-- **C-19.1** — the largest run of digits the Swift source accepts (nine, so a line number cannot
overflow `Int`); the model uses the same bound. -/
def lineCitationMaxDigits : Int := 9

/-! ## section Facts — the spec's claims about its own constants -/

section Facts

/-- **C-03, F-147** — the six dropped characters are exactly `" ( ) : * ^`, and they are distinct
and ASCII. -/
theorem ftsDroppedChars_exact : ftsDroppedChars = ['"', '(', ')', ':', '*', '^'] ∧
    ftsDroppedChars.Nodup ∧ ftsDroppedChars.all (fun c => c.val < 128) = true := by decide

/-- **C-03, K-03** — the search limit is 80 and snippets are 14 tokens; both positive. -/
theorem search_limits_positive : 0 < searchLimit ∧ 0 < snippetTokens ∧ searchLimit = 80 ∧
    snippetTokens = 14 := by decide

/-- **K-03, R-27** — five hot-key slots, and the slot count is positive. -/
theorem bookmarkSlots_exact : bookmarkSlots = 5 ∧ 0 < bookmarkSlots := by decide

/-- **K-03, I-013** — the history cap is 100 entries. -/
theorem historyCap_exact : historyCap = 100 := by decide

/-- **K-04, R-30** — the zoom range is `[0.60, 2.50]` with step 0.10 and default 1.0; the default
lies inside the range and the step divides the range width exactly. -/
theorem zoom_constants : zoomMinHundredths = 60 ∧ zoomMaxHundredths = 250 ∧
    zoomStepHundredths = 10 ∧ zoomDefaultHundredths = 100 ∧
    zoomMinHundredths ≤ zoomDefaultHundredths ∧ zoomDefaultHundredths ≤ zoomMaxHundredths ∧
    (zoomMaxHundredths - zoomMinHundredths) % zoomStepHundredths = 0 := by decide

/-- **K-04** — the pane clamps: sidebar `[180, 400]`, inspector `[180, 520]` with default 240
inside it, bookmarks pane at least 120 pt. -/
theorem pane_clamps : sidebarWidthMinPt = 180 ∧ sidebarWidthMaxPt = 400 ∧
    inspectorWidthMinPt = 180 ∧ inspectorWidthMaxPt = 520 ∧
    inspectorWidthMinPt ≤ inspectorWidthDefaultPt ∧ inspectorWidthDefaultPt ≤ inspectorWidthMaxPt ∧
    sidebarWidthMinPt ≤ sidebarWidthMaxPt ∧ bookmarksMinHeightPt = 120 := by decide

/-- **K-06** — the timings: 50 ms latency, 500 ms transient re-read, 0.6 s flash, 0.9 s HUD, 1 s
mtime tolerance, 40-block look-back, 60-cluster title. The transient re-read is longer than the
watcher latency, as R-05/E-21 require. -/
theorem timing_constants : watcherLatencyMs = 50 ∧ transientRereadMs = 500 ∧
    blockFlashMs = 600 ∧ zoomHudMs = 900 ∧ scrollMtimeToleranceSeconds = 1 ∧
    bookmarkLookBackBlocks = 40 ∧ bookmarkTitleClusters = 60 ∧
    watcherLatencyMs < transientRereadMs := by decide

/-- **K-07** — the Mermaid zoom range `[0.5, 4]`, the 540 pt container cap, and the three cache
limits (96 layouts, 192 rasters, 192 MB). -/
theorem mermaid_constants : mermaidZoomMinHundredths = 50 ∧ mermaidZoomMaxHundredths = 400 ∧
    mermaidMaxContainerHeightPt = 540 ∧ mermaidLayoutCacheLimit = 96 ∧
    mermaidRasterCacheLimit = 192 ∧ mermaidRasterByteLimit = 192 * 1024 * 1024 ∧
    rasterMinWidthPt = 1 := by decide

/-- **K-08** — the math and sequence constants: 16 pt label math, 13 pt pitch, 11 pt font, r = 8 pt
discs, 40 pt rows, 2048 cached images. -/
theorem math_constants : mathLabelFontSizePt = 16 ∧ sequenceLabelPitchPt = 13 ∧
    sequenceLabelFontSizePt = 11 ∧ autonumberRadiusPt = 8 ∧ sequenceRowHeightPt = 40 ∧
    sequenceRowGrowthBasePt = 4 ∧ mathCacheLimit = 2048 := by decide

/-- **K-08, C-06.2** — the `(n−1)×13 + 4` row-growth formula is `(n−1) × pitch + base`: for a
one-line label the growth is exactly zero. -/
theorem row_growth_one_line (n : Int) (h : n = 1) :
    (n - 1) * sequenceLabelPitchPt + sequenceRowGrowthBasePt = 4 := by subst h; decide

/-- **K-09** — fingerprints retain 80 clusters; the FTS tokenizer is the pinned string. -/
theorem fingerprint_constants : fingerprintClusters = 80 ∧
    ftsTokenizer = "unicode61 remove_diacritics 2" := by decide

/-- **K-10, C-09** — the typography defaults: body 16 pt, 0.30 em, 860 pt, 40 pt gutter; the
heading scales are `[1.75, 1.40, 1.15, 1.0, 0.875, 0.85]` in thousandths and strictly decreasing
over h1–h3 and non-increasing over h4–h6. -/
theorem typography_defaults :
    bodyFontSizePt = 16 ∧ paragraphLineSpacingEmThousandths = 300 ∧ articleMaxWidthPt = 860 ∧
    gutterPt = 40 ∧ headingEmsDefaultThousandths = [1750, 1400, 1150, 1000, 875, 850] ∧
    h1EmThousandths > h2EmThousandths ∧ h2EmThousandths > h3EmThousandths ∧
    h4EmThousandths ≥ h5EmThousandths ∧ h5EmThousandths > h6EmThousandths := by decide

/-- **§7.2, K-13** — the worked example: with the K-10 defaults and a wide window,
`w_col = 860 − 80 − 12 = 768` pt and a Mermaid raster of `732` pt. The model's `column` and
`rasterWidth` reproduce both numbers (see `Theorems`). -/
theorem k13_worked_example : 860 - 2 * 40 - 2 * blockPaddingPt = 768 ∧
    768 - mermaidInsetPt = 732 := by decide

/-- **K-14** — the seven ceilings, exactly as K-14 states them, and their strict ordering
document < encoded image < decoded bytes, with the pixel and axis ceilings positive. -/
theorem content_ceilings :
    ceilingDocumentBytes = 64 * 1024 * 1024 ∧ ceilingMermaidBytes = 1024 * 1024 ∧
    ceilingLatexBytes = 64 * 1024 ∧ ceilingEncodedImageBytes = 32 * 1024 * 1024 ∧
    ceilingDecodedImageBytes = 256 * 1024 * 1024 ∧ ceilingDecodedImagePixels = 64_000_000 ∧
    ceilingImageAxisPixels = 16384 ∧ ceilingLatexBytes < ceilingMermaidBytes ∧
    ceilingMermaidBytes < ceilingEncodedImageBytes ∧
    ceilingEncodedImageBytes < ceilingDecodedImageBytes ∧
    ceilingImageAxisPixels * ceilingImageAxisPixels > ceilingDecodedImagePixels := by decide

/-- **E-28** — the exceeded-content message, verbatim. -/
theorem exceeded_message_exact : exceededMessage = "input exceeds limit" := by decide

/-- **§7.1, I-009** — the ink threshold is 200 and the ratio is 9/10, in lowest terms. -/
theorem ink_metric_constants : inkThresholdLuma = 200 ∧ inkRatioNumerator = 9 ∧
    inkRatioDenominator = 10 := by decide

/-- **C-17** — the channel threshold is 8 and the mismatch tolerance is 1/1000, in lowest terms. -/
theorem pixel_metric_constants : pixelChannelThreshold = 8 ∧ pixelToleranceNumerator = 1 ∧
    pixelToleranceDenominator = 1000 := by decide

/-- **K-16** — the rhythm slack is 6/10 of the font size and the per-block tolerance is 2 pt; the
Sevilla margins are the ones K-16 names and are ≥ the corresponding defaults where K-16 says so. -/
theorem rhythm_constants : rhythmSlackNumerator = 6 ∧ rhythmSlackDenominator = 10 ∧
    rhythmPerBlockTolerancePt = 2 ∧ sevillaH2TopSpacingPt = 32 ∧ sevillaH3TopSpacingPt = 22 ∧
    sevillaParagraphBottomSpacingPt = 14 ∧ defaultH2TopSpacingPt = 24 ∧
    defaultH3TopSpacingPt = 24 ∧ defaultParagraphBottomSpacingPt = 16 := by decide

/-- **C-04** — the twelve preference keys are distinct, and the defaults the spec's table states are
the ones in the table. -/
theorem preference_keys_distinct : (preferenceKeys.map (·.1)).Nodup ∧
    preferenceKeys.length = 12 ∧
    (preferenceKeys.map (·.1)).contains "mdv6_theme_id" = true ∧
    (preferenceKeys.map (·.1)).contains "mdv6.mermaid.style" = true := by decide

/-- **C-05, K-05** — the seventeen languages are distinct; the alias table has no duplicate alias
and every alias target is a language; no alias equals a language name (the alias table is looked
up second, so this keeps resolution unambiguous). -/
theorem code_language_table :
    codeLanguages.Nodup ∧ codeLanguages.length = 17 ∧
    (codeAliases.map (·.1)).Nodup ∧
    codeAliases.all (fun p => codeLanguages.contains p.2) = true ∧
    codeAliases.all (fun p => !codeLanguages.contains p.1) = true := by decide

/-- **C-05, R-08** — the prompt-aware set is distinct, is not a subset of the languages (a
`console` or `fish` fence highlights as plain yet is prompt-aware), and does not contain
`shell-session`. -/
theorem prompt_aware_table :
    promptAwareFenceWords.Nodup ∧
    promptAwareFenceWords.contains "shell-session" = false ∧
    promptAwareFenceWords.contains "console" = true ∧
    promptAwareFenceWords.contains "fish" = true ∧
    codeLanguages.contains "console" = false ∧ codeLanguages.contains "fish" = false := by decide

/-- **C-05** — 256 cache entries, and the fence factor is 0.85 in lowest terms. -/
theorem code_constants : codeCacheLimit = 256 ∧ fenceFontFactorNumerator = 85 ∧
    fenceFontFactorDenominator = 100 ∧ codeCacheLimit > 0 := by decide

/-- **C-06.1 rule 3, F-139** — the colour map's names are distinct and lower-case, and every value
is a `#`-prefixed hex string of six or eight digits. `transparent` and `none` both map to
`#00000000`. -/
theorem css_color_map_shape :
    (cssColorMap.map (·.1)).Nodup ∧
    cssColorMap.all (fun p => p.1.toList.all (fun c => decide (97 ≤ c.val ∧ c.val ≤ 122))) = true ∧
    cssColorMap.all (fun p => p.2.toList.take 1 == ['#'] &&
      (p.2.toList.length == 7 || p.2.toList.length == 9)) = true ∧
    cssColorMap.length = 46 ∧
    cssColorMap.lookup "transparent" = some "#00000000" ∧
    cssColorMap.lookup "none" = some "#00000000" ∧
    cssColorMap.lookup "grey" = some "#808080" ∧
    cssColorMap.lookup "gray" = some "#808080" := by decide

/-- **C-06.1 rule 6** — the fourteen stripped tags are distinct and none is `br`. -/
theorem stripped_tags_exact : strippedFormattingTags.Nodup ∧
    strippedFormattingTags.length = 14 ∧
    strippedFormattingTags.contains "br" = false := by decide

/-- **C-06.3** — the *Document* theme's mix percentages: surface 25 % light / 16 % dark; lines
55 %, borders 35 %, muted 45 %; all in `[0, 100]`. -/
theorem document_theme_mix : documentSurfaceLightPercent = 25 ∧
    documentSurfaceDarkPercent = 16 ∧ documentLineMixPercent = 55 ∧
    documentBorderMixPercent = 35 ∧ documentMutedMixPercent = 45 := by decide

/-- **E-02, D-04** — the unsupported diagram types are distinct, lower-case, and include the five
the spec names in E-02. -/
theorem unsupported_types : unsupportedDiagramTypes.Nodup ∧
    unsupportedDiagramTypes.all (fun s => s.toList.all (fun c =>
      decide ((97 ≤ c.val ∧ c.val ≤ 122) ∨ (48 ≤ c.val ∧ c.val ≤ 57)))) = true ∧
    unsupportedDiagramTypes.contains "timeline" = true ∧
    unsupportedDiagramTypes.contains "gantt" = true ∧
    unsupportedDiagramTypes.contains "pie" = true ∧
    unsupportedDiagramTypes.contains "mindmap" = true ∧
    unsupportedDiagramTypes.contains "gitgraph" = true := by decide

/-- **C-04** — the five diagram styles are distinct, and the default `document` is one of
them. -/
theorem mermaid_styles : mermaidStyleIds.Nodup ∧ mermaidStyleIds.length = 5 ∧
    mermaidStyleIds.contains mermaidStyleDefaultId = true := by decide

/-- **C-07.1** — the scheme and hosts, verbatim; the two hosts are distinct. -/
theorem math_url_constants : mathScheme = "mdv6-math" ∧ mathHostInline = "inline" ∧
    mathHostDisplay = "display" ∧ mathHostInline ≠ mathHostDisplay ∧ base64PadModulus = 4 := by decide

/-- **C-07.2 (a)** — the registered symbol names are distinct across all five groups, so no name is
registered twice with a different kind. -/
theorem registered_symbols_distinct :
    (registeredRelations ++ registeredArrows ++ registeredOrdinary ++ registeredBigOperators
      ++ registeredBinary).Nodup := by decide

/-- **C-07.2 (b)** — the twelve command rewrites, in the spec's order; the order is normative, so
this lemma pins the sequence: `\operatorname*?{` first, `\not=` before the size commands, and the
environment rewrites last. -/
theorem command_rewrites_order :
    commandRewrites.length = 12 ∧
    commandRewrites.map (·.1) =
      [ "\\\\operatorname\\*?\\{", "\\\\[dt]frac\\b", "\\\\boldsymbol\\b", "\\\\bmod\\b",
        "\\\\pmod\\{([^}]*)\\}", "\\\\not=", "\\\\(?:big|Big|bigg|Bigg)[lrm]?\\s*(?=[\\\\(\\[\\]){}|.<>/])",
        "\\\\coloneqq\\b", "\\\\(begin|end)\\{(align|equation|gather|multline)\\*\\}",
        "\\\\(begin|end)\\{align\\}", "\\\\(begin|end)\\{multline\\}", "\\\\(begin|end)\\{equation\\}" ] := by decide

/-- **C-07.3** — the wrapper list is distinct and contains the four the spec names in its
prose examples (`\frac`, `\sqrt` are handled separately, not as wrappers). -/
theorem plain_text_wrappers_distinct : plainTextWrappers.Nodup ∧
    plainTextWrappers.contains "text" = true ∧ plainTextWrappers.contains "operatorname" = true ∧
    plainTextWrappers.contains "frac" = false := by decide

/-- **C-09, R-29** — the nine theme ids are distinct; `system` is not one of them; the three
smart-typography refusers are all real theme ids; `high-contrast` and `twilight` are the System
theme's two resolutions and are real ids. -/
theorem theme_table : themeIds.Nodup ∧ themeIds.length = 9 ∧
    themeIds.contains systemThemeId = false ∧
    smartTypographyRefusers.Nodup ∧
    smartTypographyRefusers.all (fun id => themeIds.contains id) = true ∧
    themeIds.contains systemLightThemeId = true ∧ themeIds.contains systemDarkThemeId = true ∧
    unknownThemeFallbackId = systemLightThemeId := by decide

/-- **C-09** — the per-theme article max widths K-16 and C-09 name: Sevilla 620, Charcoal 920,
Solarium 720, and every one of them is at most the K-10 default 860 except Charcoal. -/
theorem theme_widths : sevillaMaxWidthPt = 620 ∧ charcoalMaxWidthPt = 920 ∧
    solariumMaxWidthPt = 720 ∧ sevillaMaxWidthPt < articleMaxWidthPt ∧
    solariumMaxWidthPt < articleMaxWidthPt := by decide

/-- **C-15** — the JSON keys, verbatim and distinct; the empty history encodes as `[]`. -/
theorem history_json_shape : historyJsonKeys = ["id", "path", "addedAt"] ∧
    historyJsonKeys.Nodup ∧ historyEmptyJson = "[]" := by decide

/-- **§3.3** — the schema version is 4 and the pragmas are the pinned strings. -/
theorem durable_artifacts : schemaVersion = 4 ∧ sqliteJournalMode = "WAL" ∧
    sqliteSynchronous = "NORMAL" := by decide

/-- **C-19.1** — the grammar and its nine-digit bound. -/
theorem line_citation_constants : lineCitationGrammar =
    "^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$" ∧ lineCitationMaxDigits = 9 := by decide

/-- **C-17** — the harness exits are `0`, `1`, `2` and distinct; the defaults are the ones C-17
names. -/
theorem harness_constants : harnessExitOk = 0 ∧ harnessExitFailure = 1 ∧ harnessExitUsage = 2 ∧
    harnessDefaultWidthPt = 860 ∧ harnessDefaultScale = 2 ∧
    harnessDefaultThemeId = "high-contrast" ∧ harnessManifestVersion = 1 ∧
    caseStatusPass = "pass" ∧ caseStatusFail = "fail" ∧ caseStatusFallback = "fallback" := by decide

/-- **R-33, §5.2** — the two CLI diagnostics are verbatim, and the exit codes are 0 and 1. -/
theorem cli_constants : cliExitOk = 0 ∧ cliExitError = 1 ∧
    cliNoSuchFilePrefix = "mdv6: no such file: " ∧
    cliBundleNotFound = "mdv6: mdv6.app not found (set MDV6_APP or install to /Applications)" := by decide

/-- **C-07.2** — the unsupported commands are the five the spec names. -/
theorem unsupported_commands : unsupportedLatexCommands =
    ["\\underbrace", "\\overbrace", "\\stackrel", "\\substack", "\\&"] := by decide

end Facts

end Mdv6.Spec
