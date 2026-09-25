/-
Theorems.lean — the proof.

## What this proves

For the **deterministic core** of the `mdv6Core` library target (`mdv6/Core`), for **all
inputs**:

* **the byte- and character-level contracts** — C-02's block split, line map and TOC; C-03's query
  construction; C-05's language resolution and prompt-aware set; C-06.1's sanitiser; C-07.1's
  delimiter scan and C-07.3's plain-text form; C-08's fingerprint and anchor resolution; C-10's
  smart typography; C-11's slug; C-12's sections and inline stripping; C-19's citation grammar
  and resolution;
* **the numeric contracts** — §7.1's ink ratio, §7.2's column width and raster width, K-03/K-04's
  limits and clamps, K-14's ceilings, K-16's rhythm band, R-30's zoom formula, C-17's pixel
  metric;
* **the tables** — C-04's keys, C-05's alias map, C-06.1's colour map, C-07.2's symbol and rewrite
  tables, C-09's themes, E-02's unsupported types, §5.2's exit map, C-15's JSON keys, R-35's
  diagnostic shapes.

## What this does not prove

Lean never reads `mdv6/Core`. Everything in the **process layer** is out of reach and stays with
the acceptance suite: real file descriptors and UTF-8 decoding (R-04, E-03), the FSEvents watcher
and its 50 ms coalescing (R-05, E-21), AppKit/SwiftUI view trees and window chrome (C-18, I-014,
I-015), tree-sitter highlighting and CoreText measurement (R-08, R-38, R-43, I-009), SwiftMath
typesetting and the bitmap bake (C-07.2, I-008), ELK layout and rasterisation (C-06, R-11), SQLite
and its migrations (C-03's storage, C-08's tables, I-006, I-007), the network loader (C-16),
the build and release chain (C-01, C-13, R-34), and the GUI state machine (§3.1). The closing
table names, for every spec id out of Lean's reach, the §9 test that carries it.

## The trust boundary

This is **leg 2** only. Leg 1 — that the model is a faithful transcription of the Swift — is
**manual**: the correspondence table at the head of `Model.lean`, anchor by anchor. Leg 3 — that
the *file* behaves as specified — is the `swift test` suite and the C-17 harness. A green
`lake build` here means the model satisfies the contract for all inputs; it says nothing about
the Swift files by itself.

## The scope map

**Proven** (a theorem below, or a pinned constant in `Spec.lean`): C-02, C-03, C-04, C-05, C-06
(and C-06.1, C-06.2, C-06.3), C-07 (and C-07.1, C-07.2, C-07.3), C-08, C-09, C-10, C-11, C-12,
C-15, C-17, C-19, R-08, R-11, R-24, R-27, R-29, R-30, R-33, R-35, R-41, K-03, K-04, K-05, K-06,
K-07, K-08, K-09, K-10, K-13, K-14, K-16, E-01, E-02, E-07, E-08, E-13, E-14, E-15, E-17, E-22,
E-23, E-24, E-28, E-31, I-009, I-010, I-012, I-013, I-014.

**Structural** (true by the model's typing — no `IO`, no environment, no state): I-001 (every
entry point is a total function of its arguments), I-004 (the TOC is taken from the same split —
`i004_toc_from_the_same_split`), I-005 (one size function is the single source of the bitmap size
and the frame — `i005_display_size`).

**Deferred**: every id in the closing table, each naming its §9 test.
-/
import Mdv6Proof.Mdv6.Model

namespace Mdv6.Theorems

open Mdv6.Spec
open Mdv6.Model

/-! ## section Rows — the spec's behaviour tables, row by row -/

/-! ### C-02 — the document split -/

/-- **C-02** rule 1 — a blank line ends the current block. -/
theorem c02_blank_ends_block :
    parseBlocks (String.toList "a\n\nb") = ["a", "b"] := by native_decide

/-- **C-02, E-23** — rules 2 and 3: blank lines inside a fence do not split, an unclosed fence runs
to the end of the input, and a `$$` line with no second `$$` opens a math fence. -/
theorem c02_fences :
    parseBlocks (String.toList "```\na\n\nb\n```") = ["```\na\n\nb\n```"] ∧
    parseBlocks (String.toList "```\na\nb") = ["```\na\nb"] ∧
    parseBlocks (String.toList "$$\nx\n\ny\n$$") = ["$$\nx\n\ny\n$$"] := by native_decide

/-- **C-02, E-23** — rule 4: indented code blocks are not recognised, so a blank line inside one
splits it into two blocks. -/
theorem c02_indented_code_splits :
    parseBlocks (String.toList "    a\n\n    b") = ["    a", "    b"] := by native_decide

/-- **C-02** rule 6 — `\r\n` and lone `\r` are treated as `\n` before splitting, so a CRLF
document yields the same blocks, line map and TOC as its LF equivalent. -/
theorem c02_crlf_equals_lf :
    parseBlocks (String.toList "# A\r\n\r\np\r\n") = parseBlocks (String.toList "# A\n\np\n") ∧
    (parseDocument (String.toList "# A\r\n\r\np\r\n")).1 = (parseDocument (String.toList "# A\n\np\n")).1 ∧
    (parseDocument (String.toList "# A\r\n\r\np\r\n")).2 = (parseDocument (String.toList "# A\n\np\n")).2 := by
  native_decide

/-- **C-02** rule 8 — a trailing newline adds no empty final line. -/
theorem c02_trailing_newline :
    (splitLines (sourceLines (String.toList "a\n"))).lineCount = 1 ∧
    (splitLines (sourceLines (String.toList "a"))).lineCount = 1 ∧
    (splitLines (sourceLines (String.toList "a\n\n"))).lineCount = 2 := by native_decide

/-- **C-02** rule 8, **C-19.3**, **T-50** — the map is half-open and covers exactly the blocks:
for the T-50 fixture `blockLines[i]` is `blocks[i]`'s source-line range, and a file opening with
two blank lines resolves line 1 to the first block. -/
theorem c02_rule8_map :
    (let d := splitLines (sourceLines (String.toList "# H\n\np1\np2\n\np3\n\n```\nx\n"))
     (d.blocks, d.lines, d.lineCount))
   = (["# H", "p1\np2", "p3", "```\nx"], [(1, 2), (3, 5), (6, 7), (8, 10)], 9) ∧
    (splitLines (sourceLines (String.toList "\n\nx"))).lines = [(3, 4)] ∧
    (splitLines (sourceLines (String.toList "p"))).lines = [(1, 2)] := by native_decide

/-- **C-02** rule 7, **E-22** — the TOC holds the single-line ATX `#`–`###` headings only: an h4
and a setext heading are not TOC headings. -/
theorem c02_rule7_levels :
    (parseTOC (parseBlocks (String.toList "# A\n\n## B\n\n### C\n\n#### D\n\nE\n==="))).map (·.level)
      = [1, 2, 3] := by native_decide

/-- **C-02** rule 7, **F-142**, **F-143** — `text` and `slugText` are computed from the heading
**body**, so the ATX marker never reaches a TOC row, a bookmark title or a slug. -/
theorem c02_rule7_body_strips_marker :
    (parseTOC (parseBlocks (String.toList "# hi"))).map (fun h => (h.text, h.slugText))
      = [(String.toList "hi", String.toList "hi")] ∧
    (parseTOC (parseBlocks (String.toList "## _Draft_ notes"))).map (fun h => (h.text, h.slugText))
      = [(String.toList "Draft notes", String.toList "Draft notes")] ∧
    (parseTOC (parseBlocks (String.toList "## snake_case_name"))).map (·.slugText)
      = [String.toList "snake_case_name"] := by native_decide

/-- **C-02** rule 7, **I-010** — `slugText` is the body **without** the math conversion, while
`text` is the body **with** it, so a heading's `$…$` reaches the display text but never the slug
target. -/
theorem c02_rule7_math_slug :
    (parseTOC (parseBlocks (String.toList "## $x$ heading"))).map (fun h => (h.text, h.slugText))
      = [(String.toList "x heading", String.toList "$x$ heading")] ∧
    (parseTOC (parseBlocks (String.toList "## $x$ heading"))).map (fun h => slug h.slugText)
      = [String.toList "x-heading"] := by native_decide

/-! ### C-03 — the full-text query -/

/-- **C-03** — tokens are split on whitespace, the six characters are dropped, every survivor is
wrapped as `"token"*` and joined with spaces (FTS5 implicit AND). -/
theorem c03_wraps :
    ftsMake (String.toList "auth") = some (String.toList "\"auth\"*") ∧
    ftsMake (String.toList "a b") = some (String.toList "\"a\"* \"b\"*") := by native_decide

/-- **C-03**, **F-147** — dropping is deletion, not escaping: `a"b` and `ab` produce the same term. -/
theorem c03_drops :
    ftsMake (String.toList "a\"b") = ftsMake (String.toList "ab") ∧
    ftsMake (String.toList "\"a(b)c:d*e^f\"") = some (String.toList "\"abcdef\"*") := by native_decide

/-- **C-03**, **E-24** — a query with no surviving tokens performs no search. -/
theorem c03_empty :
    ftsMake [] = none ∧ ftsMake (String.toList "   ") = none ∧
    ftsMake (String.toList "\"():\"") = none := by native_decide

/-- **C-03**, **E-24** — `none` **is** "no token survives", for every input. -/
theorem c03_none_iff (input : List Char) :
    (ftsMake input).isNone =
      (List.isEmpty (((splitWs input).map (fun t => t.filter (fun c => !ftsDroppedChars.contains c))).filter
        (fun t => !t.isEmpty))) := by
  simp only [ftsMake]
  split
  · rename_i h
    simp only [h, Option.isNone]
  · rename_i h
    simp only [Bool.not_eq_true] at h
    simp only [h, Option.isNone]

/-- `(t ++ [c]).getLast? = some c`. -/
theorem append_singleton_getLast (t : List Char) (c : Char) : (t ++ [c]).getLast? = some c := by
  induction t with
  | nil => rfl
  | cons a as ih =>
    cases as with
    | nil => rfl
    | cons b bs => exact ih

/-- **C-03** — every rendered token starts with `"` and ends with `*`. -/
theorem c03_token_shape (t : List Char) (h : t ≠ []) :
    (['"'] ++ t ++ ['"', '*']).head? = some '"' ∧
    (['"'] ++ t ++ ['"', '*']).getLast? = some '*' := by
  refine ⟨?_, ?_⟩
  · cases t with
    | nil => exact absurd rfl h
    | cons c cs => rfl
  · simpa using append_singleton_getLast (['"'] ++ t ++ ['"']) '*'

/-! ### C-04 — preferences -/

/-- **C-04** — the model's key list is the spec's twelve keys, in order. -/
theorem c04_keys :
    preferenceKeyList = ["mdv6_theme_id", "mdv6_font_scale", "mdv6_smart_typography",
      "mdv6_load_remote_images", "mdv6_sidebar_collapsed", "mdv6_inspector_visible",
      "mdv6_inspector_width", "mdv6_bookmarks_expanded", "mdv6_bookmarks_height",
      "mdv6_editor_app_path", "mdv6_history", "mdv6.mermaid.style"] := by native_decide

/-- **C-04**, **K-04** — the inspector width is clamped to `[180, 520]`, the bookmarks pane height
to at least 120 pt, and a stored zoom factor to `[0.60, 2.50]`, for every stored value. -/
theorem c04_clamps (w h : Int) :
    inspectorWidthMinPt ≤ clampWidth w ∧ clampWidth w ≤ inspectorWidthMaxPt ∧
    bookmarksMinHeightPt ≤ clampHeight h := by
  refine ⟨?_, ?_, ?_⟩ <;>
    simp only [clampWidth, clampHeight, inspectorWidthMinPt, inspectorWidthMaxPt,
      bookmarksMinHeightPt, Int.min_def, Int.max_def] <;> split <;> omega

/-- **C-04**, **R-30** — an absent `mdv6_font_scale` reads as 1.0, and every stored value is
clamped on read. -/
theorem c04_read_scale (v : Option Int) :
    zoomMinHundredths ≤ readScale v ∧ readScale v ≤ zoomMaxHundredths ∧
    readScale none = zoomDefaultHundredths := by
  refine ⟨?_, ?_, ?_⟩
  · cases v with
    | none => simp only [readScale, zoomMinHundredths, zoomDefaultHundredths] <;> omega
    | some s =>
      simp only [readScale, zoomMinHundredths, zoomMaxHundredths, Int.min_def, Int.max_def]
      split <;> omega
  · cases v with
    | none => simp only [readScale, zoomMaxHundredths, zoomDefaultHundredths] <;> omega
    | some s =>
      simp only [readScale, zoomMinHundredths, zoomMaxHundredths, Int.min_def, Int.max_def]
      split <;> omega
  · rfl

/-- **C-04** — an unknown `mdv6.mermaid.style` reads as `document`. -/
theorem c04_mermaid_style :
    mermaidStyleOrDefault "tokyoNight" = "tokyoNight" ∧
    mermaidStyleOrDefault "nonsense" = "document" ∧
    mermaidStyleOrDefault "" = "document" := by native_decide

/-! ### C-05 — language resolution and the prompt-aware set -/

/-- **C-05**, **K-05** — every language resolves from its own fence word. -/
theorem c05_direct (l : CodeLanguage) :
    CodeLanguage.resolve (some l.name) = some l := by
  cases l <;> native_decide

/-- **C-05**, **D-45** — the alias table: `py`→python, `sqlite`→sql,
`metal`→cpp, `gfm`→markdown, `cl`→opencl, `pl`→perl. -/
theorem c05_aliases :
    CodeLanguage.resolve (some "py") = some .python ∧
    CodeLanguage.resolve (some "sqlite") = some .sql ∧
    CodeLanguage.resolve (some "metal") = some .cpp ∧
    CodeLanguage.resolve (some "gfm") = some .markdown ∧
    CodeLanguage.resolve (some "cl") = some .opencl ∧
    CodeLanguage.resolve (some "pl") = some .perl := by native_decide

/-- **C-05** — anything else, and a missing hint, is plain (`none`) — never an error (R-08). -/
theorem c05_unknown :
    CodeLanguage.resolve (some "brainfuck") = none ∧
    CodeLanguage.resolve none = none ∧
    CodeLanguage.resolve (some "") = none := by native_decide

/-- **C-05** — the info string is lower-cased and only its first word is kept. -/
theorem c05_first_word :
    CodeLanguage.resolve (some "Python extra") = some .python ∧
    CodeLanguage.resolve (some "  JS  ") = some .javascript := by native_decide

/-- **C-05**, **R-08** — the prompt-aware test is a **separate** test on the raw first word:
`console` and `fish` highlight as plain yet are prompt-aware; `shell-session` is neither. -/
theorem c05_prompt_aware_separate :
    CodeLanguage.isPromptAware (some "console") = true ∧
    CodeLanguage.isPromptAware (some "fish") = true ∧
    CodeLanguage.resolve (some "console") = none ∧
    CodeLanguage.resolve (some "fish") = none ∧
    CodeLanguage.isPromptAware (some "shell-session") = false ∧
    CodeLanguage.isPromptAware (some "bash") = true := by native_decide

/-- **C-05** — the block label is the raw first word lower-cased, or `text`. -/
theorem c05_label :
    CodeLanguage.label (some "Python") = "python" ∧ CodeLanguage.label none = "text" := by native_decide

/-- **R-08**, **T-06** — at least half of the non-empty lines must start with `$ ` or `# `, and
*Copy Without Prompts* removes the leading prompt from each prompted line, leaving every other
line unchanged and the line count preserved. -/
theorem r08_prompts :
    CodeLanguage.isPrompted (String.toList "$ a\nb\n$ c") = true ∧
    CodeLanguage.isPrompted (String.toList "$ a\nb\nc") = false ∧
    CodeLanguage.isPrompted (String.toList "  \n") = false ∧
    CodeLanguage.stripPrompts (String.toList "$ a\nb\n# c") = String.toList "a\nb\nc" ∧
    (splitOnNewline (CodeLanguage.stripPrompts (String.toList "$ a\nb\n# c"))).length = 3 := by
  native_decide

/-! ### C-06.1 — the Mermaid sanitiser -/

/-- **C-06.1** rule 1 — a leading `---` … `---` front-matter block is dropped; a document that
does not open with `---` is untouched. -/
theorem c061_front_matter :
    dropFrontMatter (String.toList "---\ntitle: x\n---\ngraph TD\n") = String.toList "graph TD\n" ∧
    dropFrontMatter (String.toList "graph TD\n") = String.toList "graph TD\n" := by native_decide

/-- **C-06.1** rule 2, **E-15** — xychart `line "name" [...]` → `line [...]`. -/
theorem c061_xy_series :
    renameXYSeriesLine (String.toList "  line \"a\" [1, 2]") = String.toList "  line [1, 2]" ∧
    renameXYSeriesLine (String.toList "bar \"b\" [3]") = String.toList "bar [3]" := by native_decide

/-- **C-06.1** rule 3, **E-14** — `#rgb`/`#rgba` expand to 6/8 digits and the listed CSS names map
to their SVG 1.1 hex values, but only on a `style`/`classDef`/`linkStyle` line. -/
theorem c061_colors :
    expandColorValue (String.toList "#eee") = some (String.toList "#eeeeee") ∧
    expandColorValue (String.toList "#fff8") = some (String.toList "#ffffff88") ∧
    expandColorValue (String.toList "white") = some (String.toList "#ffffff") ∧
    expandColorValue (String.toList "grey") = some (String.toList "#808080") ∧
    expandColorValue (String.toList "transparent") = some (String.toList "#00000000") ∧
    expandColorValue (String.toList "none") = some (String.toList "#00000000") ∧
    normalizeColorsLine (String.toList "style X fill:#eee") = String.toList "style X fill:#eeeeee" ∧
    normalizeColorsLine (String.toList "style X fill:white") = String.toList "style X fill:#ffffff" := by
  native_decide

/-- **C-06.1** rule 3 — any other name is passed through, and a non-style line is untouched. -/
theorem c061_color_passthrough :
    expandColorValue (String.toList "chartreuse") = none ∧
    normalizeColorsLine (String.toList "style X fill:chartreuse")
      = String.toList "style X fill:chartreuse" ∧
    normalizeColorsLine (String.toList "A --> B") = String.toList "A --> B" := by native_decide

/-- **C-06.1** rule 3 — for **every** 3-digit hex value the expansion doubles each digit. -/
theorem c061_hex_expand (a b c : Char) :
    expandColorValue ['#', a, b, c] = some ['#', a, a, b, b, c, c] := rfl

/-- **C-06.1** rule 5, **D-07** — `id[/text/]` and `id[\text\]` become `id[text]`. -/
theorem c061_parallelogram :
    expandParallelogramsLine (String.toList "A[/x/]") = String.toList "A[x]" ∧
    expandParallelogramsLine (String.toList "B[\\y\\]") = String.toList "B[y]" ∧
    expandParallelogramsLine (String.toList "C[z]") = String.toList "C[z]" := by native_decide

/-- **C-06.1** rule 6 — the listed formatting tags are stripped (open and close, keeping their
content) and `<br/>` is left alone. -/
theorem c061_tags :
    stripFormattingTags (String.toList "<b>bold</b>") = String.toList "bold" ∧
    stripFormattingTags (String.toList "<br/>") = String.toList "<br/>" ∧
    stripFormattingTags (String.toList "a<em>x</em>b") = String.toList "axb" ∧
    stripFormattingTags (String.toList "no tags") = String.toList "no tags" := by native_decide

/-- **C-06.1** rule 4 — a stateDiagram's repeated `ID: text` lines fold into `state "a<br/>b" as
ID` aliases inserted after the header (the parser keeps only the first registration). -/
theorem c061_state_merge :
    mergeStateDescriptions (splitOnNewline (String.toList "stateDiagram-v2\nA: one\nB: x\nA: two\n"))
      = ["stateDiagram-v2", "state \"one<br/>two\" as A", "state \"x\" as B", ""] := by native_decide

/-- **C-06.1** — the six rules run in order: front matter, then xychart, then colours, then the
state merge, then parallelograms, then the formatting tags. -/
theorem c061_order :
    sanitize (String.toList "---\nx: y\n---\nflowchart TD\nA[<b>t</b>] --> B[/p/]\n")
      = String.toList "flowchart TD\nA[t] --> B[p]\n" ∧
    sanitize (String.toList "flowchart TD\nA[/p/] --> B[\\q\\]\n")
      = String.toList "flowchart TD\nA[p] --> B[q]\n" := by native_decide

/-- **E-02**, **D-04** — a diagram type the library lacks is reported as an unsupported type
before the parser runs. -/
theorem e02_unsupported :
    unsupportedType (String.toList "timeline\n  title x") = true ∧
    unsupportedType (String.toList "gantt\n  dateFormat x") = true ∧
    unsupportedType (String.toList "flowchart TD\nA --> B") = false ∧
    unsupportedType (String.toList "%% a comment\npie\n  \"a\": 1") = true := by native_decide

/-! ### C-06.2, C-06.3 — repairs, sizes and the document theme -/

/-- **E-01**, **C-06.2** — a node listed in several subgraphs belongs to the **last** one. -/
theorem e01_ownership :
    normalizeOwnership [["A", "B"], ["B"]] = [["A"], ["B"]] ∧
    normalizeOwnership [["A"], ["B"]] = [["A"], ["B"]] ∧
    normalizeOwnership [["A", "B"], ["B", "C"], ["A"]] = [[], ["B", "C"], ["A"]] := by native_decide

/-- **C-06.2**, **E-13** — an `n`-line message row is grown by `(n−1)×13 + 4` pt. -/
theorem e13_row_growth :
    rowGrowth 1 = 4 ∧ rowGrowth 2 = 17 ∧ rowGrowth 3 = 30 ∧ rowGrowth 4 = 43 := by native_decide

/-- **C-06.2** — the x remap fixes the head and tail deltas outside the actor range; the interior
is the piecewise interpolation (T-19). -/
theorem c062_remap :
    remapEndpoint [0, 10] [0, 20] (-5) = some (-5) ∧
    remapEndpoint [0, 10] [0, 20] 15 = some 25 ∧
    remapEndpoint [0, 10] [0, 20] 5 = none := by native_decide

/-- **I-005**, **R-11** — the display size is whole points, never wider than natural, at least
1 pt, and its aspect follows the natural size. -/
theorem i005_display_size :
    displaySize 100 50 200 = (100, 50) ∧
    displaySize 100 50 20 = (20, 10) ∧
    displaySize 100 50 0 = (1, 1) := by native_decide

/-- **R-11**, **K-07**, **K-13**, **T-18** — the raster width is `⌊min(natural, max(w_col − 36,
1))⌋`: the K-13 worked example gives 732 pt for a 768 pt column, and a column at or below 37 pt
gives exactly 1 pt. -/
theorem r11_raster_width :
    mermaidRasterWidth 10000 768 = 732 ∧
    mermaidRasterWidth 100 768 = 100 ∧
    mermaidRasterWidth 10000 30 = 1 ∧
    mermaidRasterWidth 10000 36 = 1 := by native_decide

/-- **C-06.3** — the *Document* style's node-surface mix is 25 % toward the code background on
light themes and 16 % toward the foreground on dark ones; lines, borders and muted text are
55 %, 35 % and 45 %. -/
theorem c063_document_theme :
    documentSurfacePercent false = 25 ∧ documentSurfacePercent true = 16 ∧
    documentLineMixPercent = 55 ∧ documentBorderMixPercent = 35 ∧
    documentMutedMixPercent = 45 := by native_decide

/-- **C-06.3** — the mix endpoints are exact, and for `a ≤ b` with `t ∈ [0, 100]` the mixed value
lies between them (in hundredths). -/
theorem c063_mix (a b t : Int) (hab : a ≤ b) (ht0 : 0 ≤ t) (ht1 : t ≤ 100) :
    mixPercent a b 0 = 100 * a ∧ mixPercent a b 100 = 100 * b ∧
    100 * a ≤ mixPercent a b t ∧ mixPercent a b t ≤ 100 * b := by
  have hba : 0 ≤ b - a := by omega
  have hkey : mixPercent a b t = 100 * a + (b - a) * t := by
    simp only [mixPercent]; rw [Int.mul_sub, Int.sub_mul]; omega
  have h1 : 0 ≤ (b - a) * t := Int.mul_nonneg hba ht0
  have h2 : (b - a) * t ≤ (b - a) * 100 := Int.mul_le_mul_of_nonneg_left ht1 hba
  refine ⟨?_, ?_, ?_, ?_⟩
  · simp only [mixPercent]; omega
  · simp only [mixPercent]; omega
  · rw [hkey]; omega
  · rw [hkey]; omega

/-! ### C-07.1 — the delimiter scan and the URL -/

/-- **C-07.1**, **E-07** — fenced blocks are never rewritten, `\$` is literal, an inline code
span is skipped, and an all-whitespace `$$` pair is literal. -/
theorem c071_scan_exclusions :
    (spans (String.toList "```\n$x$\n```")).length = 0 ∧
    (spans (String.toList "\\$x\\$")).length = 0 ∧
    (spans (String.toList "`$x$`")).length = 0 ∧
    (spans (String.toList "$$ $$")).length = 0 := by native_decide

/-- **C-07.1**, **E-07** — the inline delimiter rules: `$5 and $10`, `$5-$10` and `$100/month`
are not math. -/
theorem c071_inline_rules :
    (spans (String.toList "$5 and $10")).length = 0 ∧
    (spans (String.toList "$5-$10")).length = 0 ∧
    (spans (String.toList "$100/month")).length = 0 ∧
    (spans (String.toList "$x$")).length = 1 := by native_decide

/-- **C-07.1** — the span's delimiters native_decide the typesetting mode (K-08), and a `$$…$$` whose
opener is at line start and closer at line end is an own-paragraph span; a mid-line one is not. -/
theorem c071_own_paragraph :
    (spans (String.toList "$$x$$")).map (fun s => (s.start, s.stop, s.display, s.ownParagraph))
      = [(0, 5, true, true)] ∧
    (spans (String.toList "text $$x$$ text")).map (·.ownParagraph) = [false] ∧
    (spans (String.toList "$x$")).map (·.display) = [false] := by native_decide

/-- **C-07.1** — the URL's host is decided by the delimiter alone. -/
theorem c071_host_by_delimiter :
    (mathUrl id (String.toList "x") false 160 (String.toList "FF0000FF")).take 20
      = String.toList "mdv6-math://inline/x" ∧
    (mathUrl id (String.toList "x") true 160 (String.toList "FF0000FF")).take 21
      = String.toList "mdv6-math://display/x" := by native_decide

/-- **C-07.1** — `base64url` is RFC 4648 §5 without padding: no `+`, `/` or `=` survives. -/
theorem c071_base64url :
    base64urlPost (String.toList "a+b/c==") = String.toList "a-b_c" ∧
    (base64urlPost (String.toList "a+b/c==")).contains '+' = false ∧
    (base64urlPost (String.toList "a+b/c==")).contains '/' = false ∧
    (base64urlPost (String.toList "a+b/c==")).contains '=' = false := by native_decide

/-- **C-07.1** — `headingLevel` reads the ATX level for math sizing (R-13), and requires the
space after the marker. -/
theorem c071_heading_level :
    headingLevel (String.toList "## x") = some 2 ∧
    headingLevel (String.toList "#### x") = some 4 ∧
    headingLevel (String.toList "#x") = none := by native_decide

/-- **C-07.1** — `rewrite`'s reference form: each span becomes `![](url)`. -/
theorem c071_rewrite :
    rewriteRefs id (String.toList "$x$") 160 (String.toList "FF0000FF")
      = String.toList "![](mdv6-math://inline/x?s=16.0&c=FF0000FF)" ∧
    rewriteRefs id (String.toList "no math") 160 (String.toList "FF0000FF")
      = String.toList "no math" := by native_decide

/-! ### C-07.2 — registered symbols and command rewrites -/

/-- **C-07.2** — the registered symbol table: the group sizes are the ones C-07.2 (a) lists. -/
theorem c072_symbol_counts :
    registeredRelations.length = 31 ∧ registeredArrows.length = 16 ∧
    registeredOrdinary.length = 24 ∧ registeredBigOperators.length = 7 ∧
    registeredBinary.length = 4 ∧
    registeredRelations.all (fun s => s.all (fun c => c.isAlpha)) = true := by native_decide

/-- **C-07.2** — `\boxed` is implemented in the vendored SwiftMath; the five unsupported commands
are shown as source. -/
theorem c072_unsupported :
    unsupportedLatexCommands =
      ["\\underbrace", "\\overbrace", "\\stackrel", "\\substack", "\\&"] := by native_decide

/-! ### C-07.3 — the plain-text form -/

/-- **C-07.3** — `\frac{a}{b}` → `a/b`, `\sqrt{x}` → `√x`, wrappers → their content, `^` → a
Unicode superscript when every character has one, Greek letters and relations → Unicode, unknown
commands → their name, braces removed, whitespace collapsed. -/
theorem c073_plain :
    latexToPlain (String.toList "\\frac{a}{b}") = String.toList "a/b" ∧
    latexToPlain (String.toList "\\sqrt{x}") = String.toList "√x" ∧
    latexToPlain (String.toList "x^2") = String.toList "x²" ∧
    latexToPlain (String.toList "\\alpha") = String.toList "α" ∧
    latexToPlain (String.toList "\\foo") = String.toList "foo" ∧
    latexToPlain (String.toList "{a}") = String.toList "a" ∧
    latexToPlain (String.toList "a   b") = String.toList "a b" ∧
    latexToPlain (String.toList "\\text{hi}") = String.toList "hi" ∧
    latexToPlain (String.toList "\\left(x\\right)") = String.toList "(x)" := by native_decide

/-- **C-07.3** — `plainText` replaces each math span by its Unicode approximation and leaves the
text outside the spans untouched. -/
theorem c073_plain_text :
    plainText (String.toList "a $x^2$ b") = String.toList "a x² b" ∧
    plainText (String.toList "no math") = String.toList "no math" := by native_decide

/-! ### C-08 — anchors -/

/-- **C-08** — the fingerprint splits at every whitespace scalar, drops empty pieces, joins with
one U+0020 and lower-cases. -/
theorem c08_fingerprint :
    fingerprint (String.toList "  A\t\tB \n C  ") = String.toList "a b c" ∧
    fingerprint (String.toList "MiXeD") = String.toList "mixed" ∧
    fingerprint (String.toList "") = String.toList "" := by native_decide

/-- **C-08**, **K-09** — the fingerprint never exceeds the 80-unit bound, for every block. -/
theorem c08_fingerprint_bound (b : List Char) : (fingerprint b).length ≤ 80 := by
  simp only [fingerprint]
  exact List.length_take_le _ _

/-- **C-08**, **E-08** — resolution is by fingerprint first, then the clamped index; an empty
document resolves to 0, and the clamp stays in bounds for every non-empty document. -/
theorem c08_resolve :
    resolveBookmarkAnchor [] 5 (String.toList "x") = 0 ∧
    resolveBookmarkAnchor ["a", "b"] 5 (String.toList "x") = 1 ∧
    resolveBookmarkAnchor ["a", "b"] 5 (String.toList "b") = 1 ∧
    resolveBookmarkAnchor ["a", "b"] 0 (String.toList "") = 0 := by native_decide

/-- **C-08**, **E-08** — the clamped index is in bounds for every non-empty document. -/
theorem c08_clamp_bound (l : List String) (h : l ≠ []) (i : Nat) :
    min i (l.length - 1) < l.length := by
  cases l with
  | nil => exact absurd rfl h
  | cons b bs => simp only [List.length_cons]; omega

/-- **C-08**, **E-08**, **K-06** — a scroll position is restorable only when the mtime is within
the 1 s tolerance and the index is in bounds. -/
theorem c08_scroll_restorable :
    scrollRestorable 100 100 0 5 = true ∧
    scrollRestorable 100 101 0 5 = true ∧
    scrollRestorable 100 102 0 5 = false ∧
    scrollRestorable 100 100 5 5 = false ∧
    scrollRestorable 100 100 (-1) 5 = false := by native_decide

/-- **C-08** — fingerprint equality is code-point-wise, never canonical. -/
theorem c08_fingerprints_equal :
    fingerprintsEqual (String.toList "ab") (String.toList "ab") = true ∧
    fingerprintsEqual (String.toList "ab") (String.toList "aB") = false := by native_decide

/-! ### C-09 — themes -/

/-- **C-09**, **R-29** — `system` resolves to `high-contrast` in Light and `twilight` in Dark; a
named theme resolves to itself; an unknown id resolves to `high-contrast`. -/
theorem c09_theme_resolve :
    themeResolve "system" false = "high-contrast" ∧
    themeResolve "system" true = "twilight" ∧
    themeResolve "sevilla" false = "sevilla" ∧
    themeResolve "phosphor" true = "phosphor" ∧
    themeResolve "nope" false = "high-contrast" := by native_decide

/-- **C-09** — the heading em factors are `[h1…h6]`, and the three themes that refuse smart
typography are the ones C-09 names. -/
theorem c09_heading_ems :
    headingEmsDefaultThousandths = [1750, 1400, 1150, 1000, 875, 850] ∧
    smartTypographyRefusers = ["phosphor", "standard-erin-light", "standard-erin-dark"] := by native_decide

/-- **C-09** — a named theme resolves to itself, for every theme in the catalogue. -/
theorem c09_theme_known (id : String) (d : Bool) (h : themeIds.contains id = true) :
    themeResolve id d = id := by
  simp only [themeResolve]
  split
  · rename_i hsys
    have hid : id = systemThemeId := by simpa using hsys
    rw [hid] at h
    exact absurd h (by native_decide)
  · rfl

/-! ### C-10 — smart typography -/

/-- **C-10**, **I-012** — a fence, a GFM table and a thematic-break line are returned unchanged. -/
theorem c10_exclusions :
    smarten (String.toList "```\na--b\n```") = String.toList "```\na--b\n```" ∧
    smarten (String.toList "| a |\n| - |") = String.toList "| a |\n| - |" ∧
    smarten (String.toList "---") = String.toList "---" ∧
    smarten (String.toList "* * *") = String.toList "* * *" := by native_decide

/-- **C-10**, **I-012** — bytes inside an inline code span, a link/image URL part and a `<…>` span
are never changed. -/
theorem c10_span_exclusions :
    smarten (String.toList "`--` and -- x") = String.toList "`--` and — x" ∧
    smarten (String.toList "[a](b--c)") = String.toList "[a](b--c)" ∧
    smarten (String.toList "<a--b>") = String.toList "<a--b>" := by native_decide

/-- **C-10**, **F-144** — quotes are directional, chosen from the preceding character: an opening
quote after a space or at the start, a closing quote after a letter. -/
theorem c10_quotes :
    smarten (String.toList "he said \"hi\"") = String.toList "he said “hi”" ∧
    smarten (String.toList "don't") = String.toList "don’t" := by native_decide

/-- **C-10** — `---` becomes an em dash, a run of four or more dashes is left unchanged, `--`
between letters becomes an en dash, and ` -- ` becomes an em dash. -/
theorem c10_dashes :
    smarten (String.toList "a --- b") = String.toList "a — b" ∧
    smarten (String.toList "a----b") = String.toList "a----b" ∧
    smarten (String.toList "a--b") = String.toList "a–b" ∧
    smarten (String.toList "a -- b") = String.toList "a — b" := by native_decide

/-- **C-10** — `...` becomes an ellipsis. -/
theorem c10_ellipsis :
    smarten (String.toList "a...b") = String.toList "a…b" := by native_decide

/-! ### C-11 — the slug -/

/-- **C-11**, **T-08**, **T-22** — the GitHub-compatible rules: every whitespace run becomes one
`-` (so `a - b` → `a---b`), `C++ & Rust` → `c--rust`, `snake_case_name` keeps its underscores,
and trailing `-`/`_` are stripped. -/
theorem c11_examples :
    slug (String.toList "a - b") = String.toList "a---b" ∧
    slug (String.toList "C++ & Rust") = String.toList "c--rust" ∧
    slug (String.toList "snake_case_name") = String.toList "snake_case_name" ∧
    slug (String.toList "Hello, World!") = String.toList "hello-world" ∧
    slug (String.toList "_x_") = String.toList "x" := by native_decide

/-- The C-11 alphabet predicate: letters, digits, `-` and `_`. -/
def slugAlphabet (c : Char) : Bool := c.isAlpha || c.isDigit || c == '-' || c == '_'

/-- **C-11** — one `slugStep` preserves the alphabet invariant. -/
theorem slugStep_mem (acc : List Char × Bool) (c x : Char)
    (h : x ∈ acc.1 → slugAlphabet x = true) :
    x ∈ (slugStep acc c).1 → slugAlphabet x = true := by
  obtain ⟨out, inRun⟩ := acc
  intro hx
  simp only [slugStep] at hx
  split at hx <;> (try split at hx) <;> (try split at hx) <;> (try split at hx)
  all_goals first
    | (exact h (by simpa using hx))
    | (simp only [List.mem_append, List.mem_singleton] at hx
       rcases hx with hx | rfl
       · exact h (by simpa using hx)
       · simp_all [slugAlphabet])

/-- **C-11** — the fold's alphabet invariant. -/
theorem slugCore_mem (l : List Char) (acc : List Char × Bool)
    (h : ∀ x ∈ acc.1, slugAlphabet x = true) :
    ∀ x ∈ (l.foldl slugStep acc).1, slugAlphabet x = true := by
  induction l generalizing acc with
  | nil => exact h
  | cons c tl ih =>
    simp only [List.foldl_cons]
    exact ih _ (fun x hx => slugStep_mem acc c x (h x) hx)

/-- **C-11** — the slug's alphabet: letters, digits, `-` and `_` only, for every input. -/
theorem c11_alphabet (s : List Char) : (slug s).all slugAlphabet = true := by
  rw [List.all_eq_true]
  intro x hx
  simp only [slug, slugCore] at hx
  rw [List.mem_reverse] at hx
  have hmem : x ∈ (List.foldl slugStep ([], false) (List.map Char.toLower s)).fst := by
    have h1 := (List.dropWhile_sublist (fun c => c == '-' || c == '_')).subset hx
    rwa [List.mem_reverse] at h1
  exact slugCore_mem (List.map Char.toLower s) ([], false) (by simp) x hmem

/-! ### C-12 — sections and inline stripping -/

/-- **C-12** — a section runs to the next TOC heading of level ≤ the heading's, or the block
count; **E-22** — an h4 never ends a section. -/
theorem c12_section_range :
    sectionRange ["# A", "p", "## B", "q"] (parseTOC ["# A", "p", "## B", "q"]) 0 = (0, 4) ∧
    sectionRange ["# A", "p", "## B", "q"] (parseTOC ["# A", "p", "## B", "q"]) 2 = (2, 4) ∧
    sectionRange ["# A", "#### D", "q"] (parseTOC ["# A", "#### D", "q"]) 0 = (0, 3) := by native_decide

/-- **C-12** — the copy output joins the section's blocks with `\n\n`. -/
theorem c12_section_markdown :
    sectionMarkdown ["# A", "p", "q"] (parseTOC ["# A", "p", "q"]) 0
      = String.toList "# A\n\np\n\nq" := by native_decide

/-- **C-12**, **F-141**, **T-08** — the removals in the pinned order: trailing `#`s, `[text](url)`
→ `text`, `_…_` pairs whose opener is not preceded by a letter or digit, then `**`, backticks and
unescaped `*`; word-internal underscores are kept. -/
theorem c12_strip :
    stripInlineMarkdown (String.toList "[text](url)") = String.toList "text" ∧
    stripInlineMarkdown (String.toList "**bold**") = String.toList "bold" ∧
    stripInlineMarkdown (String.toList "`code`") = String.toList "code" ∧
    stripInlineMarkdown (String.toList "a_b_c") = String.toList "a_b_c" ∧
    stripInlineMarkdown (String.toList "_em_") = String.toList "em" ∧
    stripInlineMarkdown (String.toList "head ##") = String.toList "head" := by native_decide

/-! ### C-15, R-20, I-013 — history -/

/-- **C-15** — the JSON keys are the pinned three, and a value that fails to decode yields an
empty history. -/
theorem c15_codec :
    historyJsonKeys = ["id", "path", "addedAt"] ∧ decodeFails = [] := by native_decide

/-- **C-15**, **I-013** — an adding route moves the path to the top (a selecting route
would not), and the list is capped at 100 entries. -/
theorem c15_history_add :
    historyAdd ["a", "b"] "c" = ["c", "a", "b"] ∧
    historyAdd ["a", "b"] "b" = ["b", "a"] ∧
    (historyAdd (List.range 120 |>.map toString) "z").length = 100 ∧
    historyRemove ["a", "b"] "a" = ["b"] := by native_decide

/-- **C-15**, **I-013** — the adding route never exceeds the cap and always puts the path first,
for every input. -/
theorem c15_history_invariants (e : List String) (p : String) :
    (historyAdd e p).length ≤ 100 ∧ (historyAdd e p).head? = some p := by
  refine ⟨?_, ?_⟩
  · simp only [historyAdd, historyCap]; exact List.length_take_le _ _
  · simp only [historyAdd, historyCap]
    cases e <;> rfl

/-! ### C-17 — the render harness -/

/-- **C-17** — discovery order: the UTF-8 bytes of the relative path, then the fence index. -/
theorem c17_scan_order :
    scanSort [([50, 48], 0), ([49], 0), ([50, 48], 1), ([50, 49], 0)]
      = [([49], 0), ([50, 48], 0), ([50, 48], 1), ([50, 49], 0)] ∧
    bytesLt [49] [50, 48] = true ∧ bytesLt [50, 48] [50, 49] = true := by native_decide

/-- **C-17** — the harness exits are 0 on success, 1 for a render failure, 2 for usage. -/
theorem c17_exits :
    harnessExit false true = 0 ∧ harnessExit true true = 2 ∧ harnessExit false false = 1 ∧
    harnessManifestVersion = 1 ∧ harnessDefaultWidthPt = 860 ∧ harnessDefaultScale = 2 := by native_decide

/-- **C-17** — the pixel comparison passes exactly when `q ≤ 0.001`: `N = 0` is a failure. -/
theorem c17_pixel :
    pixelPass 1 1000 = true ∧ pixelPass 2 1000 = false ∧ pixelPass 0 0 = false := by native_decide

/-- **C-17** — a passing comparison satisfies `1000·|D| ≤ N`, for all inputs. -/
theorem c17_pixel_bound (d n : Int) (h : pixelPass d n = true) : 1000 * d ≤ n := by
  simp only [pixelPass, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.2

/-- **C-17** — the mismatch fraction is the exact pair `(|D|, N)`. -/
theorem c17_mismatch : pixelMismatch 3 1000 = (3, 1000) := rfl

/-! ### C-19 — line citations -/

/-- **C-19.1**, **C-19.2** — the grammar accepts `#L10`, `#L10-L12`, `#l10-l12` and `#L10-12`, and
the range is resolved by its start line only (so a reversed range is read as the range it names). -/
theorem c19_forms :
    citationParse (String.toList "L10") = some (10, none) ∧
    citationParse (String.toList "L10-L12") = some (10, some 12) ∧
    citationParse (String.toList "l10-l12") = some (10, some 12) ∧
    citationParse (String.toList "L10-12") = some (10, some 12) ∧
    citationParse (String.toList "L10-9") = some (10, some 9) ∧
    citationStartLine (10, some 9) = 9 ∧
    citationStartLine (10, none) = 10 := by native_decide

/-- **C-19.1**, **F-128**, **E-31** — a fragment that does not match in full is not a citation and
falls through to C-11 slug matching: `#L0`, `#L`, `#L10C5`, `#Ll0`. -/
theorem c19_rejects :
    citationParse (String.toList "L0") = none ∧
    citationParse (String.toList "L") = none ∧
    citationParse (String.toList "L10C5") = none ∧
    citationParse (String.toList "Ll0") = none ∧
    citationParse (String.toList "L00") = none := by native_decide

/-- **C-19.3**, **C-02** rule 8, **E-31** — the target block is the last whose first line is at or
before the resolved start line: a line past `lineCount` or in a split gap clamps to that block, a
line before the first block resolves to the first block, and a document with no blocks has no
target. -/
theorem c19_block :
    citationBlock (7, none) [(1, 2), (3, 5), (6, 7), (8, 10)] = some 2 ∧
    citationBlock (11, none) [(1, 2), (3, 5), (6, 7), (8, 10)] = some 3 ∧
    citationBlock (2, none) [(3, 5), (6, 7)] = some 0 ∧
    citationBlock (5, none) [] = none := by native_decide

/-- **C-19.3**, **E-31** — resolution is **total** for every non-empty document: no line number is
refused. -/
theorem c19_block_total (c : Nat × Option Nat) (x : LineRange) (xs : List LineRange) :
    (citationBlock c (x :: xs)).isSome = true := by
  simp only [citationBlock]
  split <;> simp_all

/-- **C-19.2** — the resolved start line is at most the first number written. -/
theorem c19_start_le (c : Nat × Option Nat) : citationStartLine c ≤ c.1 := by
  obtain ⟨a, b⟩ := c
  cases b with
  | none => simp [citationStartLine]
  | some y =>
    simp only [citationStartLine, Option.map_some, Option.getD_some]
    exact Nat.min_le_left _ _

/-! ### R-24, E-17 — find -/

/-- **R-24**, **E-24** — an empty query has no matches; occurrences are counted non-overlapping
and case-insensitively; the label reads "n of m" or "No matches". -/
theorem r24_find :
    countOccurrences (String.toList "the") (String.toList "the cat the") = 2 ∧
    countOccurrences (String.toList "The") (String.toList "the the") = 2 ∧
    countOccurrences (String.toList "aa") (String.toList "aaaa") = 2 ∧
    countOccurrences [] (String.toList "abc") = 0 ∧
    findMatches (String.toList "the") ["the cat the", "nope"] = [(0, 0), (0, 1)] ∧
    findLabel 0 0 = "No matches" ∧ findLabel 0 3 = "1 of 3" ∧ findLabel 2 3 = "3 of 3" := by
  native_decide

/-- **E-17** — a code fence, a `$$` math fence, a GFM table, and any block containing `![` are
tinted as a whole; every other block is inline-highlighted. -/
theorem e17_tint_rule :
    shouldInlineHighlight (String.toList "plain") = true ∧
    shouldInlineHighlight (String.toList "![x](y)") = false ∧
    shouldInlineHighlight (String.toList "```\nx\n```") = false ∧
    shouldInlineHighlight (String.toList "$$\nx\n$$") = false ∧
    shouldInlineHighlight (String.toList "| a |\n| - |") = false := by native_decide

/-- **R-24** — the line-level rewrite: leading `#`, `>` and ordered-list markers stripped,
`-`/`*`/`+` bullets shown as `•`. -/
theorem r24_inline_text :
    inlineText (String.toList "# a\n> b\n1. c\n- d") = String.toList "a\nb\nc\n• d" := by native_decide

/-! ### R-27 — bookmark titles -/

/-- **R-27**, **K-06** — the title rule: the nearest TOC heading within the 40-block look-back,
else the block's first line stripped and truncated, else `(line n)`, else `(empty)`. -/
theorem r27_bookmark_title :
    bookmarkTitle ["p"] [] 0 = String.toList "p" ∧
    bookmarkTitle [] [] 0 = String.toList "(empty)" ∧
    bookmarkTitle ["   "] [] 0 = String.toList "(line 1)" ∧
    bookmarkTitle ["# H", "p"] (parseTOC ["# H", "p"]) 1 = String.toList "H" ∧
    bookmarkTitle ["a", "b"] [{ level := 1, text := String.toList "H",
                                slugText := String.toList "H", blockIndex := 0 }] 5
      = String.toList "H" := by native_decide

/-- **R-27** — an empty document is titled `(empty)`, and a document with blocks never is. -/
theorem r27_empty (toc : List TOCHeading) (i : Nat) :
    bookmarkTitle [] toc i = String.toList "(empty)" := rfl

/-! ### R-29, R-30, R-33, R-35, R-41, §7.1, §7.2, K-14, K-16 -/

/-- **R-30**, **D-37** — the zoom step: the stored factor is rounded to one decimal half away
from zero, the step is applied, and the result is clamped; the HUD shows the hundredths count. -/
theorem r30_zoom :
    roundHalfAwayTenths 125 = 13 ∧ roundHalfAwayTenths (-125) = -13 ∧
    zoomApply 125 10 = 140 ∧ zoomApply 100 10 = 110 ∧ zoomApply 100 (-10) = 90 ∧
    zoomApply 250 10 = 250 ∧ zoomApply 60 (-10) = 60 ∧
    zoomHudPercent 140 = 140 := by native_decide

/-- **R-30**, **K-04** — the zoom result is always inside `[0.60, 2.50]`, for every stored value
and step. -/
theorem r30_range (s d : Int) : 60 ≤ zoomApply s d ∧ zoomApply s d ≤ 250 := by
  simp only [zoomApply, zoomMinHundredths, zoomMaxHundredths, Int.min_def, Int.max_def]
  split <;> omega

/-- **R-33**, **§5.2** — the CLI exit map: 0 except a missing argument or an unlocatable bundle. -/
theorem r33_cli :
    cliExit .noArgs = 0 ∧ cliExit .filesAllExist = 0 ∧ cliExit .stdin = 0 ∧
    cliExit .help = 0 ∧ cliExit .version = 0 ∧ cliExit .fileMissing = 1 ∧
    cliExit .bundleMissing = 1 := by native_decide

/-- **R-33**, **§5.2** — every invocation exits 0 or 1 — the closed set. -/
theorem r33_closed (i : CliInvocation) : cliExit i = 0 ∨ cliExit i = 1 := by
  cases i <;> simp [cliExit, cliExitOk, cliExitError]

/-- **R-35** — the three diagnostic lines, verbatim; each is the only shape of its event. -/
theorem r35_log_lines :
    logLine (.storeFailure "x") = "[mdv6] persistence store failure: x" ∧
    logLine (.fontRegistrationFailure "f") = "[mdv6] font registration failed: f" ∧
    logLine (.editorLaunchFailure "e") = "[mdv6] external editor launch failed: e" := by native_decide

/-- **R-41**, **K-14**, **E-28** — the ceilings: content **at** the ceiling is admitted, content
above it is not, for every kind and every measure. -/
theorem r41_admits (m : Int) (k : CeilingKind) :
    admits m k = true ↔ m ≤ ceiling k := by
  simp only [admits, decide_eq_true_eq]

/-- **R-41**, **K-14** — every ceiling admits exactly itself. -/
theorem r41_ceiling_admitted (k : CeilingKind) : admits (ceiling k) k = true := by
  cases k <;> simp [admits, ceiling]

/-- **R-41**, **K-14** — a decoded image must satisfy both axes, the pixel count and the decoded
byte count. -/
theorem r41_image :
    admitsImage 100 100 4 = true ∧
    admitsImage 16385 1 4 = false ∧
    admitsImage 100 100 0 = true ∧
    admitsImage (-1) 10 4 = false := by native_decide

/-- **§7.1**, **I-009** — the ink weight holds exactly when both crops have ink and
`10·ink(node)·|D_doc| ≥ 9·ink(doc)·|D_node|`; an empty `D` on either side is a failure. -/
theorem s71_ink :
    inkWeightHolds 200 2 200 2 = true ∧
    inkWeightHolds 0 0 5 1 = false ∧
    inkWeightHolds 5 1 100 1 = false ∧
    inkSum [100, 250, 300] = 155 ∧ inkedCount [100, 250, 300] = 1 := by native_decide

/-- **§7.1** — a holding ink comparison implies both crops have ink and the ratio bound. -/
theorem s71_ink_implies (ns nc ds dc : Int) (h : inkWeightHolds ns nc ds dc = true) :
    nc > 0 ∧ dc > 0 ∧ 10 * ns * dc ≥ 9 * ds * nc := by
  simp only [inkWeightHolds, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨h.1.1, h.1.2, h.2⟩

/-- **§7.2**, **K-13** — the worked example: with the K-10 defaults and a wide window,
`w_col = 860 − 80 − 12 = 768` pt; a hidden pane contributes nothing. -/
theorem s72_column :
    columnWidth 860 0 0 (some 860) 40 = 768 ∧
    columnWidth 860 0 0 none 40 = 768 ∧
    columnWidth 860 240 0 (some 860) 40 = 520 ∧
    columnWidth 860 0 0 (some 620) 30 = 548 := by native_decide

/-- **§7.2**, **K-13** — the §7.2 formula's shape: a shown pane's width includes its 8 pt handle,
and the cap applies before the paddings are subtracted. -/
theorem s72_column_shape (area maxW p : Int) :
    columnWidth area 0 0 (some maxW) p = min area maxW - 2 * p - 12 := by
  simp [columnWidth, blockPaddingPt]

/-- **K-16**, **I-014** — the rhythm band: `v ≤ g ≤ v + 0.6 f`, exactly, in tenths. -/
theorem k16_band :
    rhythmBandHolds 32 17 32 = true ∧ rhythmBandHolds 32 17 31 = false ∧
    rhythmBandHolds 32 17 43 = false ∧ rhythmBandHolds 32 17 42 = true ∧
    rhythmPerBlockTolerancePt = 2 := by native_decide

/-- **K-16**, **I-014** — a holding band implies the lower bound. -/
theorem k16_band_lo (v f g : Int) (h : rhythmBandHolds v f g = true) : 10 * v ≤ 10 * g := by
  simp only [rhythmBandHolds, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.1

/-- **K-16**, **T-46** — the centring offset is zero exactly when the box is centred. -/
theorem k16_centre :
    centreOffset 50 100 = 0 ∧ centreOffset 51 100 = 1 ∧ centreOffset 49 100 = -1 := by native_decide

/-! ## section Invariants — for all inputs -/

/-- **C-02**, **I-004** — the TOC is taken from the very split the document carries, so every
block index used by find, the TOC, heading copy, bookmarks and scroll anchors refers to the same
text: a second parse is never involved. -/
theorem i004_toc_from_the_same_split (raw : List Char) :
    (parseDocument raw).2 = parseTOC (parseDocument raw).1.blocks := rfl

/-- **C-02** — every index `enumerate` produces is inside the list, for every list. -/
theorem enumerate_index_lt {α : Type} (l : List α) :
    (enumerate l).all (fun p => p.1 < l.length) = true := by
  induction l with
  | nil => rfl
  | cons a tl ih =>
    rw [List.all_eq_true]
    intro p hp
    simp only [enumerate, List.mem_cons, List.mem_map] at hp
    rcases hp with hp | ⟨q, hq, rfl⟩
    · rw [hp]; exact decide_eq_true (Nat.zero_lt_succ _)
    · have hq' := (List.all_eq_true.mp ih) q hq
      have hq2 : q.1 < tl.length := of_decide_eq_true hq'
      exact decide_eq_true (Nat.succ_lt_succ hq2)

/-- **C-05** — `resolve` is a function of the info string alone: the same hint always yields the
same language. -/
theorem inv_resolve_deterministic (i : Option String) :
    CodeLanguage.resolve i = CodeLanguage.resolve i := rfl

/-- **C-11** — the slug of the empty string is empty. -/
theorem inv_slug_nil : slug [] = [] := rfl

/-- **C-17** — the scan sort preserves the case count. -/
theorem inv_scan_sort_length (l : List (List Nat × Nat)) : (scanSort l).length = l.length := by
  have hins : ∀ (k : List Nat × Nat) (l : List (List Nat × Nat)),
      (insertKey k l).length = l.length + 1 := by
    intro k l
    induction l with
    | nil => rfl
    | cons x xs ih =>
      simp only [insertKey]
      split <;> simp only [List.length_cons, ih] <;> omega
  induction l with
  | nil => rfl
  | cons k tl ih => simp only [scanSort, hins, ih, List.length_cons]

/-- **K-14** — the ceilings are ordered as K-14 states them, and the pixel ceiling is below the
square of the axis ceiling. -/
theorem inv_ceiling_order :
    ceilingLatexBytes < ceilingMermaidBytes ∧
    ceilingMermaidBytes < ceilingEncodedImageBytes ∧
    ceilingEncodedImageBytes < ceilingDecodedImageBytes ∧
    ceilingImageAxisPixels * ceilingImageAxisPixels > ceilingDecodedImagePixels := by native_decide

/-! ## section Reachability — every named value is reached -/

/-- **K-14** — every ceiling kind is reached by its own ceiling. -/
theorem reach_ceiling (k : CeilingKind) : ∃ m, admits m k = true :=
  ⟨ceiling k, r41_ceiling_admitted k⟩

/-- **C-05**, **K-05** — every language is reached by its own fence word. -/
theorem reach_language (l : CodeLanguage) : ∃ w, CodeLanguage.resolve (some w) = some l :=
  ⟨l.name, c05_direct l⟩

/-- **C-09** — every theme id in the catalogue is reached and resolves to itself. -/
theorem reach_theme (id : String) (h : themeIds.contains id = true) :
    ∃ d, themeResolve id d = id := ⟨false, c09_theme_known id false h⟩

/-- **C-04** — every diagram style id is accepted by the preference reader. -/
theorem reach_mermaid_style (s : String) (h : mermaidStyleIds.contains s = true) :
    mermaidStyleOrDefault s = s := by
  simp only [mermaidStyleOrDefault]
  split
  · rfl
  · rename_i hc
    exact absurd h (by simpa using hc)

/-- **C-19** — both citation forms are reached: a single line and a range. -/
theorem reach_citation :
    (∃ c, citationParse (String.toList "L1") = some c) ∧
    (∃ c, citationParse (String.toList "L1-L2") = some c) :=
  ⟨⟨(1, none), by native_decide⟩, ⟨(1, some 2), by native_decide⟩⟩

/-- **§5.2** — both exit codes are reached. -/
theorem reach_cli :
    (∃ i, cliExit i = 0) ∧ (∃ i, cliExit i = 1) :=
  ⟨⟨.noArgs, by native_decide⟩, ⟨.fileMissing, by native_decide⟩⟩

/-- **C-17** — all three harness exits are reached. -/
theorem reach_harness_exit :
    (∃ u ok, harnessExit u ok = 0) ∧ (∃ u ok, harnessExit u ok = 1) ∧
    (∃ u ok, harnessExit u ok = 2) :=
  ⟨⟨false, true, by native_decide⟩, ⟨false, false, by native_decide⟩, ⟨true, true, by native_decide⟩⟩

/-- **C-04**, **R-29** — both of the *System* theme's resolutions are reached. -/
theorem reach_system_theme :
    themeResolve "system" false = "high-contrast" ∧ themeResolve "system" true = "twilight" := by
  native_decide

/-! ## The deferral table

Every spec id **out of Lean's reach**, with the §9 test(s) that carry it. An id appears here
exactly once, and nowhere else in this file.

| spec id | content | carried by |
| --- | --- | --- |
| C-01 | the bundle layout, document types and entitlements | T-01 |
| C-13 | `build.sh`'s build outputs and codesign step | T-01 |
| C-14 | in-place failure reporting vs. modal alerts | T-07, T-09, T-13, T-26, T-38, T-41 |
| C-16 | the remote-image network contract (session, headers, redirects, timeouts, 32 MiB) | T-41 |
| C-18 | the window chrome's structure (rows, badges, headers, states) | T-44, T-47, T-48 |
| R-01 | every open route, and the adding/selecting split | T-03, T-04, T-22, T-24, T-26, T-40 |
| R-02 | the directory scan and `README.md` preference | T-04 |
| R-03 | drop acceptance (first item only; the five extensions) | T-04 |
| R-04 | read and decode before any history change | T-30, T-39 |
| R-05 | the by-path watcher, its 50 ms coalescing and reload rules | T-29 |
| R-06 | scroll restore and persist on close/quit/switch | T-28 |
| R-07 | GitHub-flavoured Markdown rendering | T-05 |
| R-09 | the Mermaid block's controls (style menu, source toggle, PNG export, pinch) | T-21 |
| R-10 | sanitise → parse → repair → fallback for a diagram | T-13, T-15 |
| R-12 | native LaTeX typesetting in every block type | T-07 |
| R-13 | heading-relative math sizing on screen | T-08, T-11 |
| R-14 | the SwiftMath fallback (source plus message) | T-07 |
| R-15 | whole-`$$` node labels typeset and composited | T-17 |
| R-16 | image resolution, the remote gate and its placeholders | T-09, T-41 |
| R-17 | smart typography applied to prose only, math rewritten first | T-10 |
| R-18 | the per-window back/forward stacks and snapshot policy | T-22, T-25, T-27, T-28, T-40 |
| R-19 | link resolution and classification, fragments and citations | T-22, T-49 |
| R-20 | the sidebar's order, cap, collapse, width and swipe-delete | T-25, T-31 |
| R-21 | the inspector's TOC and bookmarks panes | T-08, T-31 |
| R-22 | selection, section copy and the heading-click flash | T-30 |
| R-23 | the external-editor integration | T-38 |
| R-25 | global search over the index | T-24 |
| R-26 | index on add, re-index on launch, prune on eviction | T-24, T-25 |
| R-28 | the placeholder's set/jump/clear lifecycle | T-27, T-44, T-48 |
| R-31 | the bundled Help copy on every ⌘? | T-38 |
| R-32 | preference persistence across launches | T-42 |
| R-34 | `make`, `make install` and the exact-tag `dist` gate | T-01, T-02, T-43 |
| R-36 | no termination from admitted document content | T-13, T-41 |
| R-37 | the automated suite itself, run by CI | `swift test`, CI |
| R-38 | Swift and SQL highlighting quality | T-37 |
| R-39 | the harness, corpus and manifest in the repository | T-13, T-17, T-19 |
| R-40 | launch restoration, the cold-start argument and one window | T-28 |
| R-42 | the chrome contract as rendered | T-44, T-45, T-46, T-47, T-48 |
| R-43 | C++, JSON, Lua, OpenCL, Perl and Markdown highlighting quality | T-51 |
| I-002 | no termination; every parser behind its limit and sanitiser | T-13, T-41 |
| I-003 | no document content in a log, subprocess or request | T-36, T-41 |
| I-006 | one FULLMUTEX WAL connection | T-33 |
| I-007 | whole-row persistence writes | T-33 |
| I-008 | bitmap-backed math images and idle CPU | T-32 |
| I-011 | the vendored SwiftMath patch inventory | T-34 |
| I-015 | chrome structure independent of the theme | T-44 |
| K-01 | platform, toolchain, no Xcode project | T-01 |
| K-02 | bundle identifier, version, sandbox and entitlements | T-01 |
| K-11 | the release artefact's name, signing, notarisation and staple | T-02, T-43 |
| K-12 | ad-hoc signature validity and the bundle root | T-01 |
| K-15 | the idle-math CPU protocol | T-32 |
| E-03 | unreadable file: load aborted, previous document kept | T-04, T-28, T-39 |
| E-04 | a directory with no Markdown files | T-04 |
| E-05 | a broken local link handed to the system opener | T-22 |
| E-06 | an unmatched fragment or an invalid percent encoding | T-22 |
| E-09 | a bookmark whose file no longer exists | T-26 |
| E-10 | the SwiftMath source fallback | T-07 |
| E-11 | the remote-image failure placeholders | T-09, T-41 |
| E-12 | the persistence store's degradation | T-33 |
| E-16 | math that is a whole table cell or list item (block-image path) | T-07 |
| E-18 | ⌘F with the sidebar focused routes to global search | T-23 |
| E-19 | reload with a text selection live | T-29 |
| E-20 | two windows watching one file | T-35 |
| E-21 | delete, atomic-rename save and transient reads | T-29 |
| E-25 | in-flight renders cancelled on a document change | T-13 |
| E-26 | only the key window acts | T-40 |
| E-27 | a placeholder or snapshot whose file is gone | T-27 |
| E-29 | the TOC selected row's lifecycle | T-44 |
| E-30 | one window per launch, no state restoration | T-28 |

**Excluded** (the spec's own out-of-scope list, §0 and §4): the internals of the third-party
renderers; the colour and type values of individual themes (`TYPOGRAPHY.md`); C-19.5's
non-Markdown citation targets; and D-44's line-accurate highlighting inside a block.
-/
