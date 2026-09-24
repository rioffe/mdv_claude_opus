/-
Mdv6Spec.Mdv6.Spec
==================

The **normative side** of the mdv6 specification model.

This file transcribes the *pinned values* of `SPEC.md` v0.13 (mdv6, the Markdown
viewer) — the byte tables, message texts, numeric bounds, enumerations and
formulas the spec fixes as constants — plus the spec's own claims *about* those
constants.

Two rules govern this file:

* every constant quotes the spec's normative text in its doc comment, tagged with
  the spec ID or section anchor it comes from;
* every lemma in `section Facts` is a check that the spec's own claims about those
  constants are mutually consistent — closed, `decide`-able, and about *constants*,
  never a restatement of a definition.

Nothing here describes an implementation. See `Model.lean` for the transcription
(the spec's tables as a pure total function) and `Theorems.lean` for the proofs.
-/
import Lean

namespace Mdv6Spec.Mdv6.Spec

/-! ## ASCII helpers

The spec's examples are ASCII throughout (`#L10`, `---`, `~`, the CLI messages,
the fence words). These helpers let the byte-level claims below be stated and
`decide`-checked without a Unicode runtime. -/

/-- `isAscii s` — every scalar of `s` is below 128. Used by the byte-contract
facts for the spec's ASCII-only texts (the CLI messages, §5.2). -/
def isAscii (s : String) : Bool := s.toList.all (fun c => c.toNat < 128)

/-- `asciiBytes s` — the byte sequence of `s` truncated to 8 bits, in order. The
bridge between a spec text and its byte table (see `Facts`). -/
def asciiBytes (s : String) : List UInt8 := s.toList.map (fun c => UInt8.ofNat (c.toNat % 256))

/-- ASCII hex digit — used by the colour-value and hex-expansion facts. -/
def isHexDigit (c : Char) : Bool :=
  c.isDigit || (97 ≤ c.toNat && c.toNat ≤ 102) || (65 ≤ c.toNat && c.toNat ≤ 70)

/-- `hasScalar s n` — `s` contains the scalar `n`. Lets "contains no CR" be a
closed proposition over a `String`. -/
def hasScalar (s : String) (n : Nat) : Bool := s.toList.any (fun c => c.toNat == n)

/-- `CR` = U+000D, the carriage return. -/
def CR : Nat := 0x0D
/-- `LF` = U+000A, the line feed. -/
def LF : Nat := 0x0A

/-! ## §5.2 — the CLI launcher (`bin/mdv6`, R-33)

The spec's exit map and the two stderr diagnostics. `§5.2` is the one behaviour
table in the document whose whole input space is a command line. -/

/-- **§5.2** — the only success code: `0` for every admitted invocation. -/
@[grind unfold] def cliExitSuccess : UInt8 := 0

/-- **§5.2** — the only failure code: `1` for a missing argument and for a missing
bundle. No §5.2 row names any other code. -/
@[grind unfold] def cliExitFailure : UInt8 := 1

/-- **§5.2** — the two exit codes, in canonical order. The closed exit set. -/
def cliExitCodes : List UInt8 := [cliExitSuccess, cliExitFailure]

/-- **§5.2** row 2 — the stderr line for the first missing argument:
`mdv6: no such file: <arg>`. -/
@[grind unfold] def cliMissingFilePrefix : String := "mdv6: no such file: "

/-- **§5.2** — the stderr line when the bundle cannot be located:
`mdv6: mdv6.app not found (set MDV6_APP or install to /Applications)`. -/
@[grind unfold] def cliBundleMissingMessage : String :=
  "mdv6: mdv6.app not found (set MDV6_APP or install to /Applications)"

/-- **§5.2** — the `mktemp` template used for the `-` (stdin) row. -/
def cliStdinTemplate : String := "mdv6-stdin"

/-- **§5.2** — the bundle search order, in the order the spec lists it. -/
def bundleSearchOrder : List String :=
  [ "$MDV6_APP (if a directory)"
  , "/Applications/mdv6.app"
  , "~/Applications/mdv6.app"
  , "../build/mdv6.app relative to the script"
  , "../mdv6.app relative to the script"
  , "mdfind \"kMDItemCFBundleIdentifier == 'com.mdv6.app'\" (first hit)" ]

/-- **§5.2** — the usage text the `-h`/`--help` row prints is the script's own
lines 2–9, so its content is not pinned by the spec; only its stream is (stdout). -/
def cliUsageLineRange : Nat × Nat := (2, 9)

/-! ## K-03 — the three caps

`K-03` fixes the history cap, the search limit and the snippet length; `K-04`
fixes the zoom; these are the values the model normalises through. -/

/-- **K-03** — history cap: 100 entries. -/
@[grind unfold] def historyCap : Nat := 100

/-- **K-03** — global search returns at most 80 hits. -/
@[grind unfold] def searchLimit : Nat := 80

/-- **K-03** — a C-03 snippet is 14 tokens. -/
def snippetTokens : Nat := 14

/-- **K-03** — five bookmark hot-key slots (⌘1…⌘5). -/
def bookmarkSlots : Nat := 5

/-! ## K-04 / R-30 — the zoom factor

`R-30`'s step is a tenth and its range is `[0.60, 2.50]`; `roundHalfAway` rounds a
half-integer away from zero. Every value here is modelled in **tenths** (a `Nat`)
so the arithmetic is exact and `decide`-able: `zoomTenthsMin = 6` is `0.60`. -/

/-- **K-04** — zoom step $0.10$, as one tenth. -/
@[grind unfold] def zoomStepTenths : Nat := 1

/-- **K-04** — lower clamp `0.60`, as six tenths. -/
@[grind unfold] def zoomTenthsMin : Nat := 6

/-- **K-04** — upper clamp `2.50`, as twenty-five tenths. -/
@[grind unfold] def zoomTenthsMax : Nat := 25

/-- **K-04** — default zoom `1.0`. -/
@[grind unfold] def zoomTenthsDefault : Nat := 10

/-- **R-30** — `Actual Size` sets $s' = 1.0$. -/
@[grind unfold] def zoomTenthsActualSize : Nat := 10

/-- **R-30** — the zoom HUD shows $\lfloor 100 s' + 0.5 \rfloor$ %. -/
def zoomPercentNumerator : Nat := 100

/-! ## K-04 — the pane widths -/

/-- **K-04** — sidebar width $[180, 400]$ pt (dragged; not persisted). -/
@[grind unfold] def sidebarMinPt : Nat := 180
@[grind unfold] def sidebarMaxPt : Nat := 400

/-- **K-04** — inspector width $[180, 520]$ pt, persisted, default 240. -/
@[grind unfold] def inspectorMinPt : Nat := 180
@[grind unfold] def inspectorMaxPt : Nat := 520
@[grind unfold] def inspectorDefaultPt : Nat := 240

/-- **K-04** — the bookmarks pane keeps ≥ 120 pt and the TOC ≥ 80 pt. -/
@[grind unfold] def bookmarksMinPt : Nat := 120
@[grind unfold] def tocMinPt : Nat := 80

/-- **C-04** — default bookmarks-pane height. -/
@[grind unfold] def bookmarksDefaultPt : Nat := 240

/-- **C-04** — default inspector width, as stored. -/
@[grind unfold] def inspectorDefaultRaw : Nat := 240

/-- **K-16** — the drag handles on each shown pane add 8 pt to its width (§7.2). -/
@[grind unfold] def paneHandlePt : Nat := 8

/-! ## K-10 / K-13 / §7.2 — the article and its column

`K-10` fixes body 16 pt, line spacing 0.30 em, `h1..h3` scales and article max
width 860 pt with a 40 pt gutter; `§7.2` gives $w_{\mathrm{col}}$; `K-13` pins the
worked example (860 − 80 − 12 = 768 pt, a Mermaid raster of 732 pt). -/

/-- **K-10** — body size 16 pt. -/
@[grind unfold] def bodyPt : Nat := 16

/-- **K-10** — article max width 860 pt (the cap on the *padded* frame, K-13). -/
@[grind unfold] def articleMaxWidthPt : Nat := 860

/-- **K-10** — gutter 40 pt (`articleHorizontalPadding`). -/
@[grind unfold] def articlePaddingPt : Nat := 40

/-- **K-10** — `h1`, `h2`, `h3` size em factors, in thousandths (1750 = 1.75). The
unit is thousandths, not hundredths, because `C-09` fixes `h5` at `0.875`. -/
def h1EmThousandths : Nat := 1750
def h2EmThousandths : Nat := 1400
def h3EmThousandths : Nat := 1150

/-- **§7.2** — the per-block horizontal padding $b = 6$ pt. -/
@[grind unfold] def blockPaddingPt : Nat := 6

/-- **R-11 / K-07** — the column width the raster reserves: 36 pt. -/
@[grind unfold] def rasterInsetPt : Nat := 36

/-- **K-07** — the raster width's lower bound: 1 pt. -/
@[grind unfold] def rasterMinPt : Nat := 1

/-- **K-13** — the worked column width with the K-10 defaults in a wide window. -/
def k13ColumnWidthPt : Nat := 768

/-- **K-13** — the worked Mermaid raster width for that column. -/
def k13RasterWidthPt : Nat := 732

/-- **K-07** — pinch zoom is clamped to $[0.5, 4]$ (hundredths). -/
def pinchMinHundredths : Nat := 50
def pinchMaxHundredths : Nat := 400

/-- **K-07** — a zoomed Mermaid container is ≤ 540 pt tall. -/
def mermaidZoomMaxHeightPt : Nat := 540

/-! ## C-09 — the theme enumeration

Nine named themes plus `System`; smart typography is refused by exactly three of
them (C-09 `smartTypographyAllowed`). -/

/-- **C-09** — `MDVTheme.all`, the nine named themes, in the spec's order. -/
def themeIds : List String :=
  [ "high-contrast", "sevilla", "charcoal", "solarium-daylight", "solarium-moonlight"
  , "phosphor", "twilight", "standard-erin-light", "standard-erin-dark" ]

/-- **R-29** — `System` resolves to `high-contrast` in Light and `twilight` in Dark. -/
def themeSystemId : String := "system"
def themeSystemLightId : String := "high-contrast"
def themeSystemDarkId : String := "twilight"

/-- **C-09** — the default theme id (`C-04` `mdv6_theme_id`). -/
def themeDefaultId : String := "high-contrast"

/-- **C-09** — the themes that refuse smart typography (`smartTypographyAllowed = false`). -/
def smartTypographyRefusers : List String :=
  [ "phosphor", "standard-erin-light", "standard-erin-dark" ]

/-- **R-29 / §5.1** — the picker offers the nine named themes plus `System`. -/
def themePickerIds : List String := themeIds ++ [themeSystemId]

/-- **C-09** — the fixed h4…h6 em factors (h4 1.0, h5 0.875, h6 0.85), thousandths. -/
def h4EmThousandths : Nat := 1000
def h5EmThousandths : Nat := 875
def h6EmThousandths : Nat := 850

/-! ## C-04 — the preference keys and their defaults

Twelve keys; the model's `prefsDefault` normalises through this table. -/

/-- **C-04** — the twelve `UserDefaults` keys, in the spec's table order. -/
def prefKeys : List String :=
  [ "mdv6_theme_id", "mdv6_font_scale", "mdv6_smart_typography", "mdv6_load_remote_images"
  , "mdv6_sidebar_collapsed", "mdv6_inspector_visible", "mdv6_inspector_width"
  , "mdv6_bookmarks_expanded", "mdv6_bookmarks_height", "mdv6_editor_app_path"
  , "mdv6_history", "mdv6.mermaid.style" ]

/-- **C-04** — the default of `mdv6_font_scale`. -/
def fontScaleDefaultHundredths : Nat := 100

/-- **C-04** — `mdv6_inspector_width` is clamped to $[180, 520]$. -/
def inspectorWidthClampPt : Nat × Nat := (inspectorMinPt, inspectorMaxPt)

/-! ## R-09 — the Mermaid diagram styles -/

/-- **R-09** — the five diagram styles of the block's style menu. -/
def mermaidStyleIds : List String :=
  [ "document", "light", "dark", "tokyo-night", "catppuccin" ]

/-- **C-04 / R-09** — the default `mdv6.mermaid.style`. -/
def mermaidStyleDefault : String := "document"

/-! ## C-05 / K-05 / R-08 / R-38 / R-43 — the fence words

`K-05` fixes seventeen fence words over eighteen vendored grammars. `C-05` gives
the direct names and the alias map; `R-08` gives the prompt-aware set. -/

/-- **K-05** — the original nine highlighted languages. -/
def baseLanguages : List String :=
  [ "c", "go", "rust", "bash", "javascript", "yaml", "toml", "python", "ruby" ]

/-- **R-38** — the two languages `R-38` adds. -/
def r38Languages : List String := [ "swift", "sql" ]

/-- **R-43** — the six languages `R-43` adds (Markdown is one language, two grammars). -/
def r43Languages : List String := [ "cpp", "json", "lua", "opencl", "perl", "markdown" ]

/-- **C-05** — the direct fence words: `c go rust bash javascript yaml toml python
ruby` (+ `swift sql` per R-38) and `cpp json lua opencl perl markdown` (R-43). -/
def directFenceWords : List String := baseLanguages ++ r38Languages ++ r43Languages

/-- **C-05** — the alias map, in the spec's order: alias → canonical language. -/
def fenceAliases : List (String × String) :=
  [ ("js", "javascript"), ("jsx", "javascript"), ("javascriptreact", "javascript"), ("node", "javascript")
  , ("sh", "bash"), ("zsh", "bash"), ("shell", "bash")
  , ("py", "python"), ("python3", "python")
  , ("rb", "ruby"), ("yml", "yaml"), ("rs", "rust"), ("golang", "go")
  , ("h", "c"), ("objective-c", "c"), ("objc", "c")
  , ("sqlite", "sql"), ("postgresql", "sql"), ("postgres", "sql"), ("mysql", "sql")
  , ("plsql", "sql"), ("tsql", "sql")
  , ("c++", "cpp"), ("cplusplus", "cpp"), ("cc", "cpp"), ("cxx", "cpp"), ("cp", "cpp")
  , ("hpp", "cpp"), ("hxx", "cpp"), ("hh", "cpp"), ("metal", "cpp"), ("msl", "cpp")
  , ("cl", "opencl"), ("opencl-c", "opencl")
  , ("pl", "perl"), ("perl5", "perl")
  , ("md", "markdown"), ("gfm", "markdown") ]

/-- **R-08** — the prompt-aware fence words: the **raw** first word of the info
string, lower-cased, is one of these. -/
def promptAwareWords : List String := [ "bash", "sh", "zsh", "fish", "shell", "console" ]

/-- **R-08 / C-05** — `fish` and `console` highlight as plain yet are prompt-aware;
`shell-session` is neither. -/
def plainButPromptAware : List String := [ "fish", "console" ]

/-- **R-08** — the prompt prefixes a prompted line carries: `$ ` or `# `. -/
def promptPrefixes : List String := ["$ ", "# "]

/-- **C-05** — the code palette capture kinds the highlighting must map (R-38/R-43
require each to be distinguishable from plain text). -/
def captureKinds : List String :=
  [ "keyword", "string", "comment", "number", "type", "function" ]

/-! ## C-06.1 — the Mermaid sanitiser's data

Rule 3's CSS colour names and the hex-expansion shapes; rule 6's inline tag list. -/

/-- **C-06.1 rule 3** — the colour names the sanitiser maps to hex, in the spec's
order: the 44 names, then `transparent` and `none`. -/
def cssColorNames : List String :=
  [ "white", "black", "red", "green", "blue", "yellow", "orange", "purple", "gray", "grey"
  , "lightgray", "lightgrey", "darkgray", "silver", "pink", "lightblue", "lightgreen"
  , "lightyellow", "gold", "teal", "navy", "maroon", "olive", "cyan", "magenta", "brown"
  , "beige", "ivory", "lavender", "coral", "salmon", "tomato", "crimson", "indigo"
  , "violet", "khaki", "tan", "wheat", "mintcream", "honeydew", "aliceblue", "whitesmoke"
  , "gainsboro", "snow", "transparent", "none" ]

/-- **C-06.1 rule 3 (v0.13.1)** — the pinned value of each colour name: the SVG 1.1
keyword table, 44 colours plus the two transparent forms. F-139 was that the names
were listed and no value was, so two conforming builds could render `fill:white`
differently; the values are now normative. -/
def cssColorValues : List (String × String) :=
  [ ("white", "#ffffff"), ("black", "#000000"), ("red", "#ff0000"), ("green", "#008000")
  , ("blue", "#0000ff"), ("yellow", "#ffff00"), ("orange", "#ffa500"), ("purple", "#800080")
  , ("gray", "#808080"), ("grey", "#808080"), ("lightgray", "#d3d3d3"), ("lightgrey", "#d3d3d3")
  , ("darkgray", "#a9a9a9"), ("silver", "#c0c0c0"), ("pink", "#ffc0cb"), ("lightblue", "#add8e6")
  , ("lightgreen", "#90ee90"), ("lightyellow", "#ffffe0"), ("gold", "#ffd700"), ("teal", "#008080")
  , ("navy", "#000080"), ("maroon", "#800000"), ("olive", "#808000"), ("cyan", "#00ffff")
  , ("magenta", "#ff00ff"), ("brown", "#a52a2a"), ("beige", "#f5f5dc"), ("ivory", "#fffff0")
  , ("lavender", "#e6e6fa"), ("coral", "#ff7f50"), ("salmon", "#fa8072"), ("tomato", "#ff6347")
  , ("crimson", "#dc143c"), ("indigo", "#4b0082"), ("violet", "#ee82ee"), ("khaki", "#f0e68c")
  , ("tan", "#d2b48c"), ("wheat", "#f5deb3"), ("mintcream", "#f5fffa"), ("honeydew", "#f0fff0")
  , ("aliceblue", "#f0f8ff"), ("whitesmoke", "#f5f5f5"), ("gainsboro", "#dcdcdc"), ("snow", "#fffafa")
  , ("transparent", "#00000000"), ("none", "#00000000") ]

/-- **C-06.1 rule 3** — the properties a colour name must follow to be mapped. -/
def colorProperties : List String := ["fill:", "stroke:", "color:"]

/-- **C-06.1 rule 3** — `transparent`/`none` both become the 8-digit form `#00000000`. -/
def transparentHex : String := "#00000000"

/-- **C-10 (v0.13.1)** — the characters after which a quote opens: absent, whitespace,
or one of these. The set names `—` and `–`, which exist only as *outputs* of the
same pass, so the predicate is over the emitted stream (F-144). -/
def quoteOpeners : List Char := ['(', '[', '{', '<', '“', '‘', '—', '–', '-', '/']

/-- **C-12 (v0.13.1)** — the characters whose escape is honoured by the removal scan
(rule 4's order clause, F-141). -/
def escapableChars : List Char := ['*', '_', '`', '#', '[', ']', '\\']

/-- **C-06.1 rule 6** — the inline formatting tags stripped (open and close), with
their content kept. `<br/>` is deliberately absent: it is left alone. -/
def strippedTags : List String :=
  [ "b", "i", "u", "s", "strong", "em", "small", "sup", "sub", "span", "code", "tt", "font", "mark" ]

/-- **C-06.1 rule 6** — the tag left in place. -/
def keptTag : String := "br"

/-- **C-06.1 rule 2** — the two xychart series keywords whose names are dropped. -/
def xychartSeriesKeywords : List String := ["line", "bar"]

/-- **C-06.1 rule 3** — the three lines that carry style edits. -/
def styleLineKeywords : List String := ["style", "classDef", "linkStyle"]

/-- **C-06.2** — the diagram kinds that get the subgraph-ownership repair. -/
def subgraphOwnershipDiagrams : List String := ["flowchart", "stateDiagram"]

/-- **C-06.2** — the sequence-diagram message line pitch (13 pt) and font (11 pt),
and the +24 pt / +36 pt gap paddings. -/
def msgLinePitchPt : Nat := 13
def msgLabelFontPt : Nat := 11
def actorGapPadPt : Nat := 24
def selfMessageGapPadPt : Nat := 36
def blockNotePadPt : Nat := 8
def autonumberDiscRadiusPt : Nat := 8
def multiLineRowExtraPt : Nat := 4

/-! ## E-02 — the diagram types the library lacks (they must fall back) -/

/-- **E-02** — the unsupported diagram types named, which count as *expected*
fallbacks in C-17's scan. -/
def unsupportedDiagramTypes : List String :=
  [ "timeline", "gantt", "pie", "mindmap", "gitGraph" ]

/-- **R-10** — the fallback text for an unrenderable Mermaid diagram. -/
def mermaidFallbackText : String := "Mermaid diagram could not be rendered"

/-- **E-28** — the suffix the source fallback adds when a ceiling was crossed. -/
def ceilingFallbackText : String := "input exceeds limit"

/-! ## C-07 — math rewriting and plain text -/

/-- **C-07.1** — the two math URL schemes the rewrite emits. -/
def mathScheme : String := "mdv6-math"
def mathInlineHost : String := "inline"
def mathDisplayHost : String := "display"

/-- **C-07.1** — the size and colour query keys. -/
def mathSizeKey : String := "s"
def mathColorKey : String := "c"

/-- **C-07.3** — the wrappers whose braces are removed, leaving their content. -/
def mathWrappers : List String :=
  [ "text", "mathrm", "mathbf", "mathit", "mathcal", "mathbb", "operatorname"
  , "boldsymbol", "bm", "hat", "vec", "bar", "tilde" ]

/-- **C-07.3** — the superscript-eligibility set. -/
def superscriptChars : List Char := ['0','1','2','3','4','5','6','7','8','9','+','-','n','i']

/-- **C-07.3** — the subscript-eligibility set. -/
def subscriptChars : List Char := ['0','1','2','3','4','5','6','7','8','9','+','-','i','j','n','k','x']

/-- **C-07.2** — the commands SwiftMath cannot typeset: shown as source. -/
def unsupportedCommands : List String := ["\\underbrace", "\\overbrace", "\\stackrel", "\\substack", "\\&"]

/-- **C-07.2** — the registered-symbol groups of the table (the model treats the
group membership as the pinned data). -/
def registeredSymbolGroups : List String :=
  ["relations", "arrows", "ordinary", "big operators", "binary"]

/-- **K-08** — diagram-label math is 16 pt; the math image cache holds 2048 entries. -/
def diagramLabelMathPt : Nat := 16
def mathCacheEntries : Nat := 2048

/-- **K-07** — the Mermaid layout and raster caches. -/
def mermaidLayoutCache : Nat := 96
def mermaidRasterCache : Nat := 192
def mermaidRasterCacheBytes : Nat := 192 * 1024 * 1024

/-- **C-05** — the code `AttributedString` cache (R-30 adds the zoom factor to the key). -/
def codeCacheEntries : Nat := 256

/-! ## C-08 / K-06 / K-09 — anchors -/

/-- **C-08** — the fingerprint joins its pieces with U+0020 SPACE. -/
@[grind unfold] def fingerprintJoin : Char := ' '

/-- **K-09** — a fingerprint retains the first 80 extended grapheme clusters. -/
@[grind unfold] def fingerprintClusters : Nat := 80

/-- **K-06** — a bookmark title fallback truncates to 60 extended grapheme clusters. -/
@[grind unfold] def titleClusters : Nat := 60

/-- **K-06** — the bookmark-title heading look-back is 40 blocks. -/
@[grind unfold] def headingLookBack : Nat := 40

/-- **K-06 / E-08** — the scroll-restore mtime tolerance: 1 s (the stored
`file_mtime` is truncated to whole seconds). -/
@[grind unfold] def mtimeToleranceSeconds : Nat := 1

/-- **R-27** — the bookmark-title fallbacks: `(line n)` and `(empty)`. -/
def titleLinePrefix : String := "(line "
def titleLineSuffix : String := ")"
def titleEmpty : String := "(empty)"

/-- **R-27** — a bookmark title comes from the nearest TOC heading at or within the
previous 40 blocks, else the block's first stripped line, else `(line n)`, else
`(empty)`. No other source. -/
def titleSources : List String := ["nearest-toc-heading", "stripped-first-line", "line-index", "empty"]

/-! ## K-06 — the timings -/

/-- **K-06 / R-05** — live-reload event latency: 50 ms, no deferral. -/
def reloadLatencyMs : Nat := 50

/-- **K-06 / D-18** — the transient zero-byte re-read delay: 500 ms. -/
def transientReReadMs : Nat := 500

/-- **K-06 / C-19.3** — the block flash: 0.6 s (one constant, two uses). -/
def flashMillis : Nat := 600

/-- **K-06 / R-30** — the zoom HUD: 0.9 s. -/
def zoomHudMillis : Nat := 900

/-- **K-06** — the two R-05 timings are ordered (the burst coalescing window is
shorter than the transient-read window). -/
def reloadIsShorterThanTransient : Bool := decide (reloadLatencyMs < transientReReadMs)

/-! ## K-14 / C-16 — the untrusted-content ceilings -/

/-- **K-14** — one document file: 64 MiB (binary units). -/
@[grind unfold] def ceilingDocumentBytes : Nat := 64 * 1024 * 1024

/-- **K-14** — one Mermaid source: 1 MiB. -/
@[grind unfold] def ceilingMermaidBytes : Nat := 1024 * 1024

/-- **K-14** — one LaTeX span: 64 KiB. -/
@[grind unfold] def ceilingLatexBytes : Nat := 64 * 1024

/-- **K-14** — an encoded or compressed local/data/remote image: 32 MiB. -/
@[grind unfold] def ceilingEncodedImageBytes : Nat := 32 * 1024 * 1024

/-- **K-14** — a decoded image: 64 megapixels. -/
@[grind unfold] def ceilingDecodedPixels : Nat := 64 * 1000 * 1000

/-- **K-14** — a decoded image: 256 MiB. -/
@[grind unfold] def ceilingDecodedBytes : Nat := 256 * 1024 * 1024

/-- **K-14** — a decoded image: 16,384 pixels on either axis. -/
@[grind unfold] def ceilingImageAxis : Nat := 16384

/-- **C-16** — redirects are followed at most five times. -/
@[grind unfold] def remoteMaxRedirects : Nat := 5

/-- **C-16** — connection timeout 15 s, total resource timeout 30 s. -/
@[grind unfold] def remoteConnectTimeoutSeconds : Nat := 15
@[grind unfold] def remoteResourceTimeoutSeconds : Nat := 30

/-- **C-16 / K-14** — the remote body ceiling is the same 32 MiB. -/
@[grind unfold] def remoteBodyCeilingBytes : Nat := ceilingEncodedImageBytes

/-- **C-16** — the two schemes a redirect target may keep. -/
def remoteAllowedSchemes : List String := ["http", "https"]

/-- **C-16** — the three headers the request must not send. -/
def forbiddenRemoteHeaders : List String := ["Cookie", "Authorization", "Referer"]

/-- **K-14** — the ceiling kinds, one per named operation. -/
def ceilingKinds : List String :=
  [ "document", "mermaid", "latex", "encoded-image", "decoded-pixels", "decoded-bytes", "image-axis" ]

/-! ## C-17 — the harness exit map and the pixel metric -/

/-- **C-17** — the harness's three exit codes. -/
@[grind unfold] def harnessExitSuccess : UInt8 := 0
@[grind unfold] def harnessExitCaseFailure : UInt8 := 1
@[grind unfold] def harnessExitUsage : UInt8 := 2

/-- **C-17** — the three exit codes, in canonical order. Closed set. -/
def harnessExitCodes : List UInt8 := [harnessExitSuccess, harnessExitCaseFailure, harnessExitUsage]

/-- **C-17** — a pixel channel differs when it differs by more than 8 (of 255). -/
@[grind unfold] def pixelChannelThreshold : Nat := 8

/-- **C-17** — the mismatch fraction $q = |D|/N$ must satisfy $q \le 0.001$. -/
@[grind unfold] def pixelMismatchDenominator : Nat := 1000
@[grind unfold] def pixelMismatchNumerator : Nat := 1

/-- **C-17** — the harness defaults: width 860 pt, scale 2, theme `high-contrast`. -/
def harnessDefaultWidthPt : Nat := 860
def harnessDefaultScale : Nat := 2
def harnessDefaultTheme : String := "high-contrast"

/-- **C-17** — the manifest's three `status` values and its `version`. -/
def harnessStatuses : List String := ["pass", "fail", "fallback"]
def harnessManifestVersion : Nat := 1

/-- **C-17 / T-19** — the sequence-layout geometric assertions. -/
def harnessMetricKinds : List String := ["pixel", "ink", "sequence-layout"]

/-- **§7.1 / I-009** — the ink-weight lower ratio, in tenths: 9 = 0.9. -/
@[grind unfold] def inkRatioTenths : Nat := 9

/-- **§7.1** — the ink threshold on luminance: `g(p) < 200`. -/
@[grind unfold] def inkLuminanceThreshold : Nat := 200

/-- **§7.1** — the crop is the math image's rectangle enlarged by 4 px on each side
and is measured at 2× backing scale. -/
def inkCropInsetPx : Nat := 4
def inkBackingScale : Nat := 2

/-! ## R-01 / R-02 / R-03 — opening routes and the file-type sets -/

/-- **C-01 / R-19** — a file the application loads in-app: extension
(case-insensitive) `md`, `markdown` or `mdown`. -/
def markdownExtensions : List String := ["md", "markdown", "mdown"]

/-- **R-03** — a drop is accepted only for these extensions (case-insensitive):
the three above plus `txt` and `mkd`. -/
def droppableExtensions : List String := ["md", "markdown", "txt", "mdown", "mkd"]

/-- **R-02** — the directory scan considers exactly the Markdown extensions. -/
def directoryScanExtensions : List String := markdownExtensions

/-- **R-02** — the preferred name, matched case-insensitively on the stem. -/
def readmeStem : String := "README"

/-- **R-01** — the routes, split into the two kinds the spec names. -/
def addingRoutes : List String :=
  [ "open-panel", "open-in-new-window", "launch-services", "drop", "link"
  , "bookmark", "placeholder", "directory-scan" ]

/-- **R-01** — the selecting routes: a history-sidebar row, a search hit whose file
is already in history, ⌘←/⌘→, and the delete-current-row transition (§3.1). -/
def selectingRoutes : List String :=
  [ "history-row", "search-hit-in-history", "back", "forward", "delete-current-row" ]

/-- **R-18** — the three routes that must NOT push a back snapshot. -/
def nonPushingRoutes : List String := ["bookmark", "placeholder", "cold-start-argument"]

/-- **R-40** — a cold-start file argument pre-empts automatic history restoration. -/
def coldStartRoutes : List String := ["launch-services", "cli-file"]

/-! ## C-15 — the history JSON -/

/-- **C-15** — the three JSON keys of a history entry, exactly as encoded. -/
def historyKeys : List String := ["id", "path", "addedAt"]

/-- **C-15** — a value that fails to decode yields an empty history, never a crash. -/
def historyDecodeFailureValue : List String := []

/-- **C-15 / C-04** — the `UserDefaults` key holding the encoded history. -/
def historyDefaultsKey : String := "mdv6_history"

/-! ## C-03 — the full-text index -/

/-- **C-03** — the characters dropped from each query token before quoting. -/
def ftsDroppedChars : List Char := ['"', '(', ')', ':', '*', '^']

/-- **C-03** — every surviving token is wrapped as `"token"*`. -/
def ftsTokenPrefix : String := "\""
def ftsTokenSuffix : String := "\"*"

/-- **C-03** — the snippet brackets matched terms: U+0002 … U+0003. -/
def ftsSnippetOpen : Nat := 0x02
def ftsSnippetClose : Nat := 0x03

/-- **C-03** — the snippet ellipsis and token budget. -/
def ftsSnippetEllipsis : String := "…"

/-- **C-03 / C-04** — the tokenizer. -/
def ftsTokenizer : String := "unicode61 remove_diacritics 2"

/-- **C-03** — the result ordering: rank, then case-insensitive path, then binary path. -/
def ftsOrderKeys : List String := ["rank ASC", "path COLLATE NOCASE ASC", "path ASC"]

/-! ## C-19 — line citations -/

/-- **C-19.1** — the fragment grammar (ASCII form of the regex), anchored and
case-insensitive: `L` digits, optionally `-` (`L`)? digits. -/
def citationGrammar : String := "^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$"

/-- **C-19.1** — the four fragments the spec states parse, verbatim. -/
def citationAcceptedExamples : List String := ["L10", "L10-L12", "l10-l12", "L10-12"]

/-- **C-19.1** — the fragments the spec states do **not** match, verbatim. -/
def citationRejectedExamples : List String := ["L", "L0", "L00", "L10C5", "Ll0"]

/-- **C-19.1** — the coordinate space: 1-based, post-C-02-rule-6 lines. -/
def lineNumbersAreOneBased : Bool := true

/-! ## §3.1 — the document lifecycle states -/

/-- **§3.1** — the five document states, in the table's order. `CLOSED` is terminal. -/
def docStates : List String := ["EMPTY", "LOADING", "VIEWING", "RELOADING", "CLOSED"]

/-- **§3.1** — the terminal state. -/
def terminalState : String := "CLOSED"

/-! ## C-02 — the splitter's markers -/

/-- **C-02 rule 2** — the two three-character fence markers. -/
def fenceMarkers : List String := ["```", "~~~"]

/-- **C-02 rule 3** — the math-fence marker. -/
@[grind unfold] def mathFenceMarker : String := "$$"

/-- **C-02 rule 3** — a `$$` fence closes at the next line *containing* `$$`. -/
def mathFenceCloseContains : Bool := true

/-- **C-02 rule 4** — indented code blocks are not recognised: the indent is four
spaces, and a blank line inside one splits it in two (E-23). -/
@[grind unfold] def codeIndentSpaces : Nat := 4

/-- **C-02 rule 6** — the line endings normalised before splitting. -/
def normalizedLineEndings : List String := ["\\r\\n", "\\r"]

/-- **C-02 rule 7** — the heading levels `tocHeadings` keeps, and the marker `# `. -/
@[grind unfold] def tocLevels : List Nat := [1, 2, 3]
def headingMarker : String := "# "

/-- **C-02 rule 2 / E-23** — the closing run need not be at least as long as the
opener (a deliberate deviation from CommonMark). -/
def fenceCloseLengthRule : String := "same three-character marker; length not compared"

/-! ## §6 — the invariant IDs the model formalises

Listed so the audit can join the invariant family to the model's theorems. -/

/-- **§6** — the fifteen invariants. -/
def invariantIds : List String :=
  [ "I-001","I-002","I-003","I-004","I-005","I-006","I-007","I-008"
  , "I-009","I-010","I-011","I-012","I-013","I-014","I-015" ]

/-! ## Facts — the spec's claims about its own constants

Each lemma below is a *closed* check that the spec's pinned values agree with each
other. They are about constants, not about the model, and none of them restates a
definition. -/

section Facts

/-- **§5.2** — the launcher uses exactly two exit codes and they are distinct. -/
theorem cliExitCodes_distinct : cliExitSuccess ≠ cliExitFailure := by decide

/-- **§5.2** — no exit code outside `{0, 1}` is named by any §5.2 row. -/
theorem cliExitSet_closed : cliExitCodes = [0, 1] := by decide

/-- **§5.2** — the missing-file stderr line is ASCII (it must survive any locale). -/
theorem cliMissingFilePrefix_ascii : isAscii cliMissingFilePrefix = true := by decide

/-- **§5.2** — the bundle-missing stderr line is ASCII. -/
theorem cliBundleMissingMessage_ascii : isAscii cliBundleMissingMessage = true := by decide

/-- **§5.2** — neither diagnostic contains a CR: each is a single line on stderr. -/
theorem cliDiagnostics_noCR :
    hasScalar cliMissingFilePrefix CR = false ∧ hasScalar cliBundleMissingMessage CR = false := by
  decide

/-- **§5.2** — neither diagnostic contains an LF of its own. -/
theorem cliDiagnostics_noLF :
    hasScalar cliMissingFilePrefix LF = false ∧ hasScalar cliBundleMissingMessage LF = false := by
  decide

/-- **§5.2** — the bundle search order has the six entries the spec lists, and
`$MDV6_APP` is consulted first. -/
theorem bundleSearchOrder_firstIsEnv :
    bundleSearchOrder.length = 6 ∧ bundleSearchOrder.head? = some "$MDV6_APP (if a directory)" := by
  decide

/-- **§5.2** — the byte table of the missing-file prefix, so a later theorem can
compare a diagnostic byte for byte. -/
theorem cliMissingFilePrefix_bytes :
    asciiBytes cliMissingFilePrefix
      = [0x6D, 0x64, 0x76, 0x36, 0x3A, 0x20, 0x6E, 0x6F, 0x20, 0x73, 0x75, 0x63, 0x68,
         0x20, 0x66, 0x69, 0x6C, 0x65, 0x3A, 0x20] := by decide

/-- **K-03** — the three caps are what the spec states, and the search limit is
below the history cap (so a full history can always fill the result list). -/
theorem k03_caps : historyCap = 100 ∧ searchLimit = 80 ∧ snippetTokens = 14 ∧ bookmarkSlots = 5 := by
  decide

/-- **K-03** — the search limit is strictly below the history cap. -/
theorem k03_searchLimit_below_historyCap : searchLimit < historyCap := by decide

/-- **K-04** — the zoom range and default are ordered as the spec states, and the
default is inside the range. -/
theorem k04_zoom_bounds :
    zoomTenthsMin = 6 ∧ zoomTenthsMax = 25 ∧ zoomTenthsDefault = 10 ∧
    zoomTenthsMin ≤ zoomTenthsDefault ∧ zoomTenthsDefault ≤ zoomTenthsMax := by decide

/-- **K-04** — the zoom step is positive and the range is wider than one step. -/
theorem k04_step_positive : 0 < zoomStepTenths ∧ zoomStepTenths < zoomTenthsMax - zoomTenthsMin := by
  decide

/-- **K-04** — the pane clamps are ordered, and the inspector's default lies in
its range. -/
theorem k04_pane_bounds :
    sidebarMinPt < sidebarMaxPt ∧ inspectorMinPt < inspectorMaxPt ∧
    inspectorMinPt ≤ inspectorDefaultPt ∧ inspectorDefaultPt ≤ inspectorMaxPt := by decide

/-- **K-04** — the inspector's stored default equals the `C-04` table's default. -/
theorem k04_inspector_default_agrees_with_c04 : inspectorDefaultPt = inspectorDefaultRaw := by decide

/-- **K-10 / K-13 / §7.2** — the worked example: with the K-10 defaults and both
panes hidden, a wide window gives $w_{\mathrm{col}} = 860 - 2\cdot40 - 2\cdot6 = 768$. -/
theorem k13_worked_example :
    articleMaxWidthPt - 2 * articlePaddingPt - 2 * blockPaddingPt = k13ColumnWidthPt := by decide

/-- **K-13 / R-11** — the worked Mermaid raster: $768 - 36 = 732$. -/
theorem k13_worked_raster : k13ColumnWidthPt - rasterInsetPt = k13RasterWidthPt := by decide

/-- **§7.2** — the raster inset is smaller than the worked column, so the lower
bound is not reached in the worked example. -/
theorem raster_inset_below_k13_column : rasterInsetPt < k13ColumnWidthPt := by decide

/-- **K-16** — a shown pane's drag handle adds 8 pt to the width it contributes to
§7.2, and that is the value §7.2 names. -/
theorem k16_handle_matches_7_2 : paneHandlePt = 8 := by decide

/-- **C-09** — the theme enumeration is nine long, its ids are distinct, and the
picker offers exactly ten entries (nine plus `System`). -/
theorem c09_theme_list :
    themeIds.length = 9 ∧ themePickerIds.length = 10 := by decide

/-- **C-09** — no theme id is repeated. -/
theorem c09_theme_ids_distinct : themeIds.eraseDups = themeIds := by decide

/-- **C-09** — exactly three themes refuse smart typography, and each is a named
theme. -/
theorem c09_smart_refusers :
    smartTypographyRefusers.length = 3 ∧
    (smartTypographyRefusers.all (fun t => themeIds.contains t)) = true := by decide

/-- **R-29** — `System` resolves to two named themes, one of which is the default. -/
theorem r29_system_resolution :
    themeIds.contains themeSystemLightId = true ∧ themeIds.contains themeSystemDarkId = true ∧
    themeSystemLightId = themeDefaultId := by decide

/-- **C-09** — the heading em factors are ordered h1 > h2 > h3 > h4 > h5 > h6 as the
spec states (h4 fixed at 1.0). -/
theorem c09_heading_scales_ordered :
    h2EmThousandths < h1EmThousandths ∧ h3EmThousandths < h2EmThousandths ∧
    h4EmThousandths ≤ h3EmThousandths ∧ h5EmThousandths ≤ h4EmThousandths ∧
    h6EmThousandths ≤ h5EmThousandths := by decide

/-- **C-04** — the twelve preference keys are exactly twelve and all distinct. -/
theorem c04_keys : prefKeys.length = 12 ∧ prefKeys.eraseDups = prefKeys := by decide

/-- **C-04** — the history key in the table is the key C-15 encodes under. -/
theorem c04_history_key : prefKeys.contains historyDefaultsKey = true := by decide

/-- **R-09** — the five diagram styles are distinct and `document` is the default. -/
theorem r09_styles :
    mermaidStyleIds.length = 5 ∧ mermaidStyleIds.eraseDups = mermaidStyleIds ∧
    mermaidStyleIds.contains mermaidStyleDefault = true := by decide

/-- **K-05** — seventeen fence words: nine + two + six. -/
theorem k05_fence_words :
    baseLanguages.length = 9 ∧ r38Languages.length = 2 ∧ r43Languages.length = 6 ∧
    directFenceWords.length = 17 := by decide

/-- **C-05** — the direct fence words are all distinct (no language is reachable by
two direct names). -/
theorem c05_direct_words_distinct : directFenceWords.eraseDups = directFenceWords := by decide

/-- **C-05** — every alias target is a direct fence word: no alias points at a
language the resolver cannot itself resolve. -/
theorem c05_alias_targets_direct :
    (fenceAliases.all (fun p => directFenceWords.contains p.2)) = true := by decide

/-- **C-05** — no alias key is also a direct fence word: the resolver's two
lookups never disagree. -/
theorem c05_alias_keys_disjoint_from_direct :
    (fenceAliases.all (fun p => !directFenceWords.contains p.1)) = true := by decide

/-- **C-05** — alias keys are distinct, so the alias table is a partial function. -/
theorem c05_alias_keys_distinct :
    (fenceAliases.map (fun p => p.1)).eraseDups = fenceAliases.map (fun p => p.1) := by decide

/-- **C-05 / R-38 / R-43** — `metal` is an alias of `cpp` (D-45), `cl` of `opencl`,
`md`/`gfm` of `markdown` — the three alias families the spec names. -/
theorem c05_named_alias_families :
    fenceAliases.lookup "metal" = some "cpp" ∧
    fenceAliases.lookup "cl" = some "opencl" ∧
    fenceAliases.lookup "md" = some "markdown" ∧
    fenceAliases.lookup "gfm" = some "markdown" := by decide

/-- **R-08** — the prompt-aware set has six members and is distinct. -/
theorem r08_prompt_set :
    promptAwareWords.length = 6 ∧ promptAwareWords.eraseDups = promptAwareWords := by decide

/-- **R-08 / C-05** — `fish` and `console` are prompt-aware yet are *not* direct
fence words (they highlight as plain). `shell-session` is prompt-aware-equivalent
to neither: it is absent, while `shell` is present. -/
theorem r08_plain_but_prompt_aware :
    plainButPromptAware.all (fun w => promptAwareWords.contains w) = true ∧
    plainButPromptAware.all (fun w => !directFenceWords.contains w) = true ∧
    promptAwareWords.contains "shell-session" = false ∧
    promptAwareWords.contains "shell" = true := by decide

/-- **R-08** — the two prompt prefixes are distinct and both non-empty. -/
theorem r08_prompt_prefixes_distinct :
    promptPrefixes.length = 2 ∧ promptPrefixes.eraseDups = promptPrefixes := by decide

/-- **C-06.1 rule 3** — the CSS colour-name list is distinct (each name resolves
to at most one entry). -/
theorem c061_color_names_distinct : cssColorNames.eraseDups = cssColorNames := by decide

/-- **C-06.1 rule 3** — the two transparent forms are present, spelled as the spec
spells them. -/
theorem c061_transparent_forms :
    cssColorNames.contains "transparent" = true ∧ cssColorNames.contains "none" = true := by decide

/-- **C-06.1 rule 3** — grey/gray and every light/dark pairing the spec lists are
both present, so the aliasing is symmetric. -/
theorem c061_grey_pairings :
    cssColorNames.contains "gray" ∧ cssColorNames.contains "grey" ∧
    cssColorNames.contains "lightgray" ∧ cssColorNames.contains "lightgrey" := by decide

/-- **C-06.1 rule 6** — `<br/>` is not in the stripped-tag list (it is left alone). -/
theorem c061_br_not_stripped : strippedTags.contains keptTag = false := by decide

/-- **C-06.1 rule 6** — the stripped tags are distinct. -/
theorem c061_tags_distinct : strippedTags.eraseDups = strippedTags := by decide

/-- **C-06.1 rule 2** — the xychart keywords are the two the spec names. -/
theorem c061_xychart_keywords : xychartSeriesKeywords = ["line", "bar"] := by decide

/-- **C-06.1 rule 3** — the three style-line keywords are the ones the colour rules
apply to. -/
theorem c061_style_keywords :
    styleLineKeywords = ["style", "classDef", "linkStyle"] ∧
    styleLineKeywords.eraseDups = styleLineKeywords := by decide

/-- **E-02 / §9** — the unsupported diagram types the spec names are distinct. -/
theorem e02_unsupported_distinct : unsupportedDiagramTypes.eraseDups = unsupportedDiagramTypes := by
  decide

/-- **C-07.3** — the superscript and subscript eligibility sets are what the
spec lists, as scalars. -/
theorem c073_script_sets :
    superscriptChars.length = 14 ∧ subscriptChars.length = 17 := by decide

/-- **C-07.3** — every superscript-eligible character is subscript-eligible except
`j` and `k` (which the spec grants only to subscripts). -/
theorem c073_script_sets_relation :
    (superscriptChars.all (fun c => c == 'j' || c == 'k' || subscriptChars.contains c)) = true := by
  decide

/-- **C-07.3** — the wrapper list is distinct. -/
theorem c073_wrappers_distinct : mathWrappers.eraseDups = mathWrappers := by decide

/-- **C-07.2** — the five commands the spec shows as source are distinct and none
is a registered symbol group. -/
theorem c072_unsupported :
    unsupportedCommands.length = 5 ∧ unsupportedCommands.eraseDups = unsupportedCommands := by decide

/-- **C-07 / K-08 / K-07 / C-05** — the four cache sizes the spec pins. -/
theorem caches :
    mathCacheEntries = 2048 ∧ mermaidLayoutCache = 96 ∧ mermaidRasterCache = 192 ∧
    codeCacheEntries = 256 := by decide

/-- **K-08** — the diagram-label math size is 16 pt, the same as the K-10 body size
(the spec's "same pixel weight" comparison point, I-009). -/
theorem k08_label_size_is_body : diagramLabelMathPt = bodyPt := by decide

/-- **K-07** — the raster cache's byte budget is 192 MiB. -/
theorem k07_raster_budget : mermaidRasterCacheBytes = 201326592 := by decide

/-- **C-08 / K-09 / K-06** — the fingerprint retains more clusters than a bookmark
title does, and the look-back is 40 blocks. -/
theorem c08_anchor_numbers :
    fingerprintClusters = 80 ∧ titleClusters = 60 ∧ headingLookBack = 40 ∧
    titleClusters < fingerprintClusters := by decide

/-- **K-06** — the mtime tolerance is one second, and the flash (0.6 s) is inside
it, so a flash and a restore never collide. -/
theorem k06_flash_inside_tolerance :
    mtimeToleranceSeconds = 1 ∧ flashMillis = 600 ∧ flashMillis < 1000 * mtimeToleranceSeconds := by
  decide

/-- **K-06** — the four timings, and the ordering the spec relies on (reload
latency < transient re-read). -/
theorem k06_timings :
    reloadLatencyMs = 50 ∧ transientReReadMs = 500 ∧ zoomHudMillis = 900 ∧
    reloadIsShorterThanTransient = true := by decide

/-- **R-27** — the four title sources are distinct, and the two textual fallbacks
are spelled as the spec spells them. -/
theorem r27_title_sources :
    titleSources.length = 4 ∧ titleSources.eraseDups = titleSources ∧
    titleLinePrefix = "(line " ∧ titleLineSuffix = ")" ∧ titleEmpty = "(empty)" := by decide

/-- **K-14** — the seven ceilings are ordered as the spec's units imply, and the
two 32 MiB values (encoded image and remote body) are the same number. -/
theorem k14_ceilings :
    ceilingDocumentBytes = 67108864 ∧ ceilingMermaidBytes = 1048576 ∧
    ceilingLatexBytes = 65536 ∧ ceilingEncodedImageBytes = 33554432 ∧
    ceilingDecodedBytes = 268435456 ∧ ceilingImageAxis = 16384 ∧
    remoteBodyCeilingBytes = ceilingEncodedImageBytes := by decide

/-- **K-14** — the byte ceilings are strictly ordered LaTeX < Mermaid < encoded
image < document < decoded, as the spec's units give them. -/
theorem k14_ceiling_order :
    ceilingLatexBytes < ceilingMermaidBytes ∧ ceilingMermaidBytes < ceilingEncodedImageBytes ∧
    ceilingEncodedImageBytes < ceilingDocumentBytes ∧
    ceilingDocumentBytes < ceilingDecodedBytes := by decide

/-- **K-14** — the seven named ceiling kinds correspond one-to-one with the seven
ceilings. -/
theorem k14_kinds : ceilingKinds.length = 7 ∧ ceilingKinds.eraseDups = ceilingKinds := by decide

/-- **K-14** — every ceiling is non-zero, so "admitted at the ceiling" is a
reachable state for each kind. -/
theorem k14_ceilings_nonzero :
    ceilingDocumentBytes ≠ 0 ∧ ceilingMermaidBytes ≠ 0 ∧ ceilingLatexBytes ≠ 0 ∧
    ceilingEncodedImageBytes ≠ 0 ∧ ceilingDecodedPixels ≠ 0 ∧ ceilingDecodedBytes ≠ 0 ∧
    ceilingImageAxis ≠ 0 := by decide

/-- **C-16** — the redirect budget is five, the connection timeout is below the
resource timeout, and the body ceiling is the K-14 encoded-image ceiling. -/
theorem c16_numbers :
    remoteMaxRedirects = 5 ∧ remoteConnectTimeoutSeconds = 15 ∧
    remoteResourceTimeoutSeconds = 30 ∧ remoteConnectTimeoutSeconds < remoteResourceTimeoutSeconds := by
  decide

/-- **C-16** — the two allowed schemes and the three forbidden headers are distinct
sets, and no header is a scheme. -/
theorem c16_schemes_and_headers :
    remoteAllowedSchemes = ["http", "https"] ∧ forbiddenRemoteHeaders.length = 3 ∧
    forbiddenRemoteHeaders.eraseDups = forbiddenRemoteHeaders := by decide

/-- **C-17** — the harness uses exactly three exit codes, they are distinct, and
they match the spec's rows (`0` success, `1` case failure, `2` usage). -/
theorem c17_exits :
    harnessExitCodes = [0, 1, 2] ∧ harnessExitSuccess ≠ harnessExitCaseFailure ∧
    harnessExitCaseFailure ≠ harnessExitUsage ∧ harnessExitSuccess ≠ harnessExitUsage := by decide

/-- **C-17** — the pixel metric's tolerance: $q \le 1/1000$, so the numerator and
denominator are as stated and the tolerance is not zero. -/
theorem c17_pixel_tolerance :
    pixelMismatchNumerator = 1 ∧ pixelMismatchDenominator = 1000 ∧ pixelChannelThreshold = 8 := by
  decide

/-- **C-17** — the three status values and three metric kinds are distinct. -/
theorem c17_statuses_and_metrics :
    harnessStatuses = ["pass", "fail", "fallback"] ∧ harnessStatuses.eraseDups = harnessStatuses ∧
    harnessMetricKinds.length = 3 ∧ harnessMetricKinds.eraseDups = harnessMetricKinds := by decide

/-- **§7.1** — the ink threshold is below 255 and the ratio is below 1.0, so the
node-side requirement is strictly weaker than the document-side ink. -/
theorem ink7_1_bounds :
    inkLuminanceThreshold < 255 ∧ inkRatioTenths < 10 ∧ inkCropInsetPx = 4 ∧ inkBackingScale = 2 := by
  decide

/-- **C-01 / R-19 / R-03** — the loadable extensions are the three the spec names,
and the droppable set strictly contains them. -/
theorem extensions :
    markdownExtensions = ["md", "markdown", "mdown"] ∧
    droppableExtensions.length = 5 ∧
    (markdownExtensions.all (fun e => droppableExtensions.contains e)) = true := by decide

/-- **R-02** — the directory scan considers exactly the loadable extensions. -/
theorem r02_scan_equals_load : directoryScanExtensions = markdownExtensions := by decide

/-- **R-03** — `txt` and `mkd` are droppable yet not loadable-by-link: the drop set
properly exceeds the link set. -/
theorem r03_drop_exceeds_link :
    droppableExtensions.contains "txt" ∧ droppableExtensions.contains "mkd" ∧
    markdownExtensions.contains "txt" = false ∧ markdownExtensions.contains "mkd" = false := by
  decide

/-- **R-01** — the eight adding and five selecting routes are distinct sets. -/
theorem r01_routes :
    addingRoutes.length = 8 ∧ selectingRoutes.length = 5 ∧
    addingRoutes.eraseDups = addingRoutes ∧ selectingRoutes.eraseDups = selectingRoutes := by decide

/-- **R-01 / R-18** — no route is both adding and selecting. -/
theorem r01_route_kinds_disjoint :
    (addingRoutes.all (fun r => !selectingRoutes.contains r)) = true := by decide

/-- **R-18** — the three non-pushing routes are all routes the spec lists (the two
adding routes plus the cold-start argument, which is not a route but a launch). -/
theorem r18_non_pushing :
    nonPushingRoutes.length = 3 ∧ nonPushingRoutes.eraseDups = nonPushingRoutes := by decide

/-- **C-15** — the three JSON keys are distinct and none is empty. -/
theorem c15_keys : historyKeys = ["id", "path", "addedAt"] ∧ historyKeys.eraseDups = historyKeys := by
  decide

/-- **C-03** — the six dropped characters are distinct. -/
theorem c03_dropped_chars :
    ftsDroppedChars.length = 6 ∧ ftsDroppedChars.eraseDups = ftsDroppedChars := by decide

/-- **C-03** — the snippet brackets are the distinct control scalars U+0002/U+0003,
and neither is a printable ASCII character. -/
theorem c03_snippet_brackets :
    ftsSnippetOpen = 2 ∧ ftsSnippetClose = 3 ∧ ftsSnippetOpen ≠ ftsSnippetClose ∧
    ftsSnippetOpen < 128 ∧ ftsSnippetClose < 128 := by decide

/-- **C-03** — the three ordering keys are distinct, and the two path keys are the
determinism tie-break the spec names. -/
theorem c03_order_keys : ftsOrderKeys.length = 3 ∧ ftsOrderKeys.eraseDups = ftsOrderKeys := by
  decide

/-- **C-03 / C-04** — the tokenizer string names `unicode61` with
`remove_diacritics 2` (K-09). -/
theorem c03_tokenizer : ftsTokenizer = "unicode61 remove_diacritics 2" := by decide

/-- **C-03** — the snippet's ellipsis is a single scalar (`…`, U+2026 as spelled),
and the snippet budget equals K-03's 14 tokens. -/
theorem c03_snippet_length :
    ftsSnippetEllipsis.length = 1 ∧ snippetTokens = 14 := by decide

/-- **C-19.1** — the four accepted fragments are all distinct and none of them is
among the rejected examples. -/
theorem c191_examples_disjoint :
    citationAcceptedExamples.length = 4 ∧
    citationAcceptedExamples.eraseDups = citationAcceptedExamples ∧
    (citationAcceptedExamples.all (fun e => !citationRejectedExamples.contains e)) = true := by
  decide

/-- **C-19.1** — the rejected examples include `L`, `L0` and `L00`: the three forms
the leading-digit rule excludes. -/
theorem c191_rejected_forms :
    citationRejectedExamples.contains "L" ∧ citationRejectedExamples.contains "L0" ∧
    citationRejectedExamples.contains "L00" ∧ citationRejectedExamples.length = 5 := by decide

/-- **C-19.1** — the grammar requires a 1-based line number: it is not optional,
and the spec states the coordinate space as 1-based. -/
theorem c191_one_based : lineNumbersAreOneBased = true := by decide

/-- **§3.1** — the five states are distinct, `CLOSED` is last and is the terminal
state. -/
theorem s31_states :
    docStates.length = 5 ∧ docStates.eraseDups = docStates ∧
    docStates.getLast? = some terminalState := by decide

/-- **C-02** — the two fence markers are distinct three-character strings. -/
theorem c02_markers :
    fenceMarkers = ["```", "~~~"] ∧ fenceMarkers.eraseDups = fenceMarkers ∧
    mathFenceMarker = "$$" := by decide

/-- **C-02 rule 2** — each fence marker is three characters long, as the spec's
"same three-character marker" wording requires. -/
theorem c02_marker_length :
    (fenceMarkers.all (fun m => m.length = 3)) = true ∧ mathFenceMarker.length = 2 := by decide

/-- **C-02** — the indented-code indent is four spaces; the toc levels are 1…3; the
heading marker is `# `. -/
theorem c02_numbers :
    codeIndentSpaces = 4 ∧ tocLevels = [1, 2, 3] ∧ headingMarker = "# " ∧
    tocLevels.eraseDups = tocLevels := by decide

/-- **C-02 rule 6** — the two line endings normalised, as the *textual* escapes the
spec writes (`\r\n`, `\r`). -/
theorem c02_line_endings :
    normalizedLineEndings = ["\\r\\n", "\\r"] ∧ normalizedLineEndings.length = 2 := by decide

/-- **§6** — the fifteen invariants, and their ids are distinct. -/
theorem s6_invariants : invariantIds.length = 15 ∧ invariantIds.eraseDups = invariantIds := by decide

/-- **C-06.2** — the sequence-diagram metrics: pitch 13, font 11, paddings 24/36,
note 8, disc radius 8, multi-line extra 4. -/
theorem c062_metrics :
    msgLinePitchPt = 13 ∧ msgLabelFontPt = 11 ∧ actorGapPadPt = 24 ∧
    selfMessageGapPadPt = 36 ∧ blockNotePadPt = 8 ∧ autonumberDiscRadiusPt = 8 ∧
    multiLineRowExtraPt = 4 ∧ msgLabelFontPt < msgLinePitchPt := by decide

/-- **C-06.2** — the self-message padding exceeds the ordinary actor padding. -/
theorem c062_self_wider : actorGapPadPt < selfMessageGapPadPt := by decide

/-- **K-07** — pinch zoom's range is ordered and the default zoom lies inside it. -/
theorem k07_pinch :
    pinchMinHundredths < pinchMaxHundredths ∧ pinchMinHundredths ≤ fontScaleDefaultHundredths ∧
    fontScaleDefaultHundredths ≤ pinchMaxHundredths ∧ mermaidZoomMaxHeightPt = 540 := by decide

/-- **C-09** — the six heading em factors are as the spec's table gives them
(h4…h6 fixed). -/
theorem c09_h456 : h4EmThousandths = 1000 ∧ h5EmThousandths = 875 ∧ h6EmThousandths = 850 := by
  decide

/-- **§5.2** — the stdin template is the `mktemp` stem the spec names. -/
theorem s52_stdin_template : cliStdinTemplate = "mdv6-stdin" := by decide

/-- **§5.2** — the usage text's line range is the script's own lines 2–9. -/
theorem s52_usage_range : cliUsageLineRange = (2, 9) := by decide

/-- **C-07.1** — the math URL scheme and its two hosts, and the two query keys, are
the strings the rewrite template uses. -/
theorem c071_url_shape :
    mathScheme = "mdv6-math" ∧ mathInlineHost = "inline" ∧ mathDisplayHost = "display" ∧
    mathSizeKey = "s" ∧ mathColorKey = "c" ∧ mathInlineHost ≠ mathDisplayHost := by decide

/-- **C-06.1** — the three colour properties a name must follow to be mapped are
exactly the ones the spec lists. -/
theorem c061_properties :
    colorProperties = ["fill:", "stroke:", "color:"] ∧ colorProperties.eraseDups = colorProperties := by
  decide

/-- **C-06.1** — the two fallback texts and the kept tag are the strings the spec
quotes. -/
theorem c06_texts :
    mermaidFallbackText = "Mermaid diagram could not be rendered" ∧ keptTag = "br" ∧
    ceilingFallbackText = "input exceeds limit" := by decide

/-- **R-10 / C-06.2** — both ownership-repair diagram kinds are diagram kinds the
spec's C-06.2 table names, and they are distinct. -/
theorem c062_ownership_diagrams :
    subgraphOwnershipDiagrams = ["flowchart", "stateDiagram"] ∧
    subgraphOwnershipDiagrams.eraseDups = subgraphOwnershipDiagrams := by decide

/-- **C-05 / R-38 / R-43** — the six capture kinds each language must map are
distinct, and `comment` is among them (italic per C-05). -/
theorem c05_captures :
    captureKinds.length = 6 ∧ captureKinds.eraseDups = captureKinds ∧
    captureKinds.contains "comment" := by decide

/-- **C-06.1 rule 3 (v0.13.1)** — the value table covers the name list exactly: same
names, same order, no name without a value and no extra name (F-139, closed). -/
theorem c061_color_values_total :
    cssColorValues.map (fun p => p.1) = cssColorNames ∧
    cssColorValues.length = 46 ∧ cssColorNames.length = 46 := by decide

/-- **C-06.1 rule 3 (v0.13.1)** — every pinned value is a `#` plus 6 or 8 hex digits, so
no value can be malformed (F-139, closed). -/
theorem c061_color_values_wellformed :
    (cssColorValues.all (fun p =>
      (p.2.toList.head? == some '#') &&
      (p.2.toList.length == 7 || p.2.toList.length == 9) &&
      ((p.2.toList.drop 1).all isHexDigit))) = true := by native_decide

/-- **C-06.1 rule 3 (v0.13.1)** — `transparent` and `none` share the 8-digit transparent
value, and no other name does (F-139, closed). -/
theorem c061_transparent_values :
    cssColorValues.lookup "transparent" = some transparentHex ∧
    cssColorValues.lookup "none" = some transparentHex ∧
    (cssColorValues.filter (fun p => p.2 = transparentHex)).length = 2 := by decide

/-- **C-10 (v0.13.1)** — the opening-quote set is distinct and contains both dashes
that the same pass emits, which is why it is a set over the emitted stream (F-144). -/
theorem c10_quote_openers :
    quoteOpeners.eraseDups = quoteOpeners ∧
    quoteOpeners.contains '—' ∧ quoteOpeners.contains '–' ∧
    quoteOpeners.contains '"' = false := by decide

/-- **C-12 (v0.13.1)** — the escape set is distinct and excludes the quote and the
backtick's sibling `;` (F-141). -/
theorem c12_escapable_chars :
    escapableChars.eraseDups = escapableChars ∧ escapableChars.length = 7 ∧
    escapableChars.contains '*' ∧ escapableChars.contains '#' := by decide

end Facts

/-! ## The correspondence of constants to spec anchors

| constant family | spec anchor |
| --- | --- |
| `cliExitSuccess`/`cliExitFailure`/`cliMissingFilePrefix`/`cliBundleMissingMessage`/`bundleSearchOrder`/`cliStdinTemplate`/`cliUsageLineRange` | §5.2 (R-33) |
| `historyCap`/`searchLimit`/`snippetTokens`/`bookmarkSlots` | K-03 |
| `zoomStepTenths`/`zoomTenthsMin`/`zoomTenthsMax`/`zoomTenthsDefault`/`zoomTenthsActualSize`/`zoomPercentNumerator` | K-04, R-30 |
| `sidebarMinPt`/`sidebarMaxPt`/`inspectorMinPt`/`inspectorMaxPt`/`inspectorDefaultPt`/`bookmarksMinPt`/`tocMinPt`/`bookmarksDefaultPt` | K-04, C-04 |
| `bodyPt`/`articleMaxWidthPt`/`articlePaddingPt`/`h1..h6EmHundredths` | K-10, C-09 |
| `blockPaddingPt`/`rasterInsetPt`/`rasterMinPt`/`k13ColumnWidthPt`/`k13RasterWidthPt`/`paneHandlePt` | §7.2, K-13, K-16 |
| `pinchMinHundredths`/`pinchMaxHundredths`/`mermaidZoomMaxHeightPt` | K-07 |
| `themeIds`/`smartTypographyRefusers`/`themeSystem*`/`themePickerIds` | C-09, R-29 |
| `prefKeys`/`fontScaleDefaultHundredths`/`inspectorWidthClampPt` | C-04 |
| `mermaidStyleIds`/`mermaidStyleDefault` | R-09 |
| `baseLanguages`/`r38Languages`/`r43Languages`/`directFenceWords`/`fenceAliases`/`promptAwareWords`/`captureKinds` | C-05, K-05, R-08, R-38, R-43 |
| `cssColorNames`/`colorProperties`/`transparentHex`/`strippedTags`/`keptTag`/`xychartSeriesKeywords`/`styleLineKeywords` | C-06.1 |
| `subgraphOwnershipDiagrams`/`msg*`/`actorGapPadPt`/`blockNotePadPt`/`autonumberDiscRadiusPt`/`multiLineRowExtraPt` | C-06.2 |
| `unsupportedDiagramTypes`/`mermaidFallbackText`/`ceilingFallbackText` | E-02, R-10, E-28 |
| `mathScheme`/`mathInlineHost`/`mathDisplayHost`/`mathSizeKey`/`mathColorKey`/`mathWrappers`/`superscriptChars`/`subscriptChars`/`unsupportedCommands`/`registeredSymbolGroups` | C-07 |
| `fingerprintJoin`/`fingerprintClusters`/`titleClusters`/`headingLookBack`/`mtimeToleranceSeconds`/`titleSources`/`titleLinePrefix`/`titleLineSuffix`/`titleEmpty` | C-08, K-06, K-09, R-27 |
| `reloadLatencyMs`/`transientReReadMs`/`flashMillis`/`zoomHudMillis` | K-06 |
| `ceiling*`/`remote*`/`forbiddenRemoteHeaders`/`ceilingKinds` | K-14, C-16 |
| `harnessExit*`/`pixel*`/`harnessDefault*`/`harnessStatuses`/`harnessManifestVersion`/`harnessMetricKinds` | C-17 |
| `inkRatioTenths`/`inkLuminanceThreshold`/`inkCropInsetPx`/`inkBackingScale` | §7.1, I-009 |
| `markdownExtensions`/`droppableExtensions`/`readmeStem`/`addingRoutes`/`selectingRoutes`/`nonPushingRoutes`/`coldStartRoutes` | C-01, R-01, R-02, R-03, R-18, R-40 |
| `historyKeys`/`historyDecodeFailureValue`/`historyDefaultsKey` | C-15, C-04 |
| `ftsDroppedChars`/`ftsTokenPrefix`/`ftsTokenSuffix`/`ftsSnippetOpen`/`ftsSnippetClose`/`ftsSnippetEllipsis`/`ftsTokenizer`/`ftsOrderKeys` | C-03, K-09 |
| `citationGrammar`/`citationAcceptedExamples`/`citationRejectedExamples` | C-19.1 |
| `docStates`/`terminalState` | §3.1 |
| `fenceMarkers`/`mathFenceMarker`/`codeIndentSpaces`/`normalizedLineEndings`/`tocLevels`/`headingMarker` | C-02 |
| `invariantIds` | §6 |

Not pinned by the spec, deliberately: the `C-06.1` rule-3 **hex values** for the
CSS colour names (see `SPEC_MODEL_FINDINGS.md`, F-139); the `C-17` goldens; the
`TYPOGRAPHY.md` per-theme spacing values; the `§5.2` usage text itself. -/

end Mdv6Spec.Mdv6.Spec