/-
Model.lean — the transcription.

This file is **leg 1 of the trust boundary**: `mdv6/Core`'s pure, deterministic functions written
as total Lean functions, with **injected seams where the Swift code has effects**. Lean never
reads or executes the Swift files; the correspondence between them is the table below, and it is
**manual** (bridged empirically, not formally). What Lean proves is leg 2 — the *model's*
contract, for all inputs. The process layer (real file descriptors, AppKit, tree-sitter, SQLite,
the network, timing) is leg 3, carried by the `swift test` suite and the C-17 harness.

## Correspondence table — every source line

The table covers **every line** of every `mdv6/Core` file: files transcribed in full, files
transcribed in part (with the omitted lines and their reason), and files deliberately **not
modelled** (with the empirical witness that carries them). Source line counts are those of the
files at the commit this proof was written against.

| Source | Model element | Coverage |
| --- | --- | --- |
| `ParsedDocument.swift` (182 ln) | `ParsedDocument.*`, `TOCHeading` | **full**: `normalizeLineEndings`, `split` (rules 1–8 incl. the fence/math-fence/blank state machine and `blockLines`/`lineCount`), `parseBlocks`, `parseTOC`, `atxLevel`, `isFence`, `isMathFence`, `isGFMTable`, `isBlank`, `leadingNonSpace`, `trimNewlines` |
| `HeadingSlug.swift` (27 ln) | `HeadingSlug.slug` | **full** |
| `SmartTypography.swift` (96 ln) | `SmartTypography.smarten`, `isThematicBreak` | **full** (the inline-code / link-URL / `<…>` spans are the same three exclusions) |
| `Sections.swift` (90 ln) | `Sections.sectionRange`, `sectionMarkdown`, `stripInlineMarkdown`, `replaceLinks`, `stripUnderscorePairs` | **full** |
| `Anchors.swift` (41 ln) | `Anchors.fingerprint`, `fingerprintsEqual`, `resolveBookmarkAnchor`, `scrollRestorable` | **full except** the Unicode *grapheme-cluster* unit of the 80-cluster bound: the model's unit is the character (see *Deviations*), the cluster semantics carried by T-26 |
| `FTSQuery.swift` (25 ln) | `FTSQuery.make` | **full** |
| `LineCitation.swift` (55 ln) | `LineCitation.parse`, `number`, `startLine`, `block` | **full** |
| `CodeLanguage.swift` (64 ln) | `CodeLanguage`, `resolve`, `isPromptAware`, `isPrompted`, `stripPrompts`, `label`, `firstWord` | **full** |
| `MathMarkdown.swift` (367 ln) | `MathMarkdown.spans`, `findDollarClose`, `findInlineClose`, `atLineEnd`, `plainText`, `latexToPlain`, `plainConvert`, `plainCommand`, `plainArgument`, `symbols`, `url`, `hostOf`, `headingLevel` | **partial**: `rewrite`'s *own-paragraph blank-line splicing* is modelled as the `ownParagraph` **predicate** on a span (which is the placement rule C-07.1 states), not as the literal `"\n\n"` splice into a Swift `String` — the splice's rendering consequence is carried by T-46. `base64url`/`base64urlDecode`/`decode(url:)`/`registerOwnParagraph`/`isOwnParagraph` are **not modelled**: they are `Foundation` base64 and a global URL registry (T-07/T-46) |
| `MathSymbols.swift` (80 ln) | `MathSymbols.registeredSymbols` (counts by kind), `preprocess` | **partial**: the twelve C-07.2(b) *regex* rewrites are pinned as the ordered table in `Spec.commandRewrites` and their application is **not modelled** (regex semantics is not in Lean core) — carried by T-07 |
| `MDVMermaidPipeline.swift` (400 ln) | `Mermaid.sanitize`, `dropFrontMatter`, `renameXYSeries`, `normalizeColors`, `expandParallelograms`, `stripFormattingTags`, `mergeStateDescriptions`, `displaySize`, `rasterWidth`, `documentThemeMix`, `mixPercent`, `unsupportedType` | **partial**: `prepare`/`rasterize` (AppKit/ELK/CoreText) are **not modelled** (T-13/T-17/T-18); `remapX`'s interior interpolation and `labelWidth` (CoreText measurement) are **not modelled** (T-19) |
| `MermaidRepairs.swift` (217 ln) | `MermaidRepairs.normalizeOwnership`, `splitBr`, `rowGrowth`, `remapEndpoints` | **partial**: `applyStateStyles`, `repairSequence`'s gap widening/note enclosure, and all of `drawSequenceExtras` (CoreText) are **not modelled** (T-19/T-20) |
| `MathImageCache.swift` (100 ln) | `MathImageCache.cacheLimit`, `typesetCeiling` | **partial**: SwiftMath typesetting, the bitmap bake and the LRU are **not modelled** (T-07/T-17/T-32) |
| `Preferences.swift` (84 ln) | `Preferences.keys`, `clampWidth`, `clampHeight`, `readScale`, `mermaidStyleOrDefault` | **full except** the `UserDefaults` reads/writes themselves (T-42) |
| `HistoryManager.swift` (113 ln) | `HistoryCodec.keys`, `HistoryCodec.decodeFails`, `History.addPath`, `History.removePath` | **partial**: `UserDefaults`/`Database` I/O and the re-index queue are **not modelled** (T-25/T-33) |
| `BookmarkTitle.swift` (25 ln) | `BookmarkTitle.title`, `truncateClusters` | **full except** the cluster unit (see *Deviations*) — T-26 |
| `FindHighlight.swift` (110 ln) | `FindHighlight.countOccurrences`, `matches`, `label`, `tint`, `shouldInlineHighlight`, `inlineText` | **partial**: `highlightedAttributedString` (AttributedString runs) is **not modelled** (T-23) |
| `ColumnWidth.swift` (26 ln) | `ColumnWidth.column`, `rasterWidth` | **full** (points as integers; the §7.2 example's 768/732 are reproduced) |
| `ZoomStep.swift` (26 ln) | `ZoomStep.apply`, `clampOnRead`, `hudPercent`, `roundHalfAwayTenths` | **full** (factors in hundredths) |
| `ContentLimits.swift` (47 ln) | `ContentLimits.ceiling`, `admits`, `admitsImage` | **full** |
| `RenderMetrics.swift` (164 ln) | `RenderMetrics.ink`, `inkWeightHolds`, `pixelMismatch`, `rhythmBand`, `centreOffset`, `isInk` | **partial**: the CoreGraphics bitmap plumbing (`Bitmap.init(image:crop:onWhite:)`, `inkBands`, `inkBounds`) is **not modelled** (T-13/T-17/T-45) |
| `Diagnostics.swift` (27 ln) | `Diagnostics.logLine`, `Event` | **full except** the `NSLog` sink and the test hook (T-36) |
| `ThemeManager.swift` (354 ln) | `ThemeCatalog.resolve`, `themeIds`, `smartTypographyRefusers`, `CodePalette.color` | **partial**: the palette values, `FontRegistration`, `Resources`, `SystemAppearance`, `RGBA` colour conversion are **not modelled** (T-11/T-12/T-44) |
| `HarnessCases.swift` (370 ln) | `Harness.scanSort`, `scanKey`, `exitFor`, `manifestVersion` | **partial**: rendering, PNG comparison and metric evaluation are **not modelled** (T-13/T-17/T-19) |
| `bin/mdv6` (shell) | `Cli.exit` | **partial**: the shell itself is **not modelled** (T-03); the §5.2 exit map is |
| every other `mdv6/Core` file (`ArticleTheme`, `ArticleView`, `AppModel`, `BookmarksManager`, `ChromeModel`, `CodeBlockChrome`, `CodeRenderer`, `Database`, `DocumentRenderer`, `DocumentRootView`, `DocumentSession`, `EditorLauncher`, `FileSystem`, `FileWatcher`, `HelpManager`, `HistoryManager`'s I/O, `ImageLoading`, `ImageProviders`, `LineCitation`'s session use, `MathViews`, `MathImageCache`'s bake, `MDVMermaidDiagramView`, `MermaidMathNodes`, `PipelineProbe`, `PlaceholderStore`, `RenderMetrics`' bitmaps, `SessionClock`, `SidebarViews`, `ThemeManager`'s palettes, `WindowAccessor`, `mdv6App`) | — | **not modelled**: SwiftUI/AppKit view trees, the SQLite connection, the watcher, the session state machine, the network loader, CoreText/tree-sitter/SwiftMath/ELK. Each is a §11 row whose witness is the §9 test named in `Theorems.lean`'s deferral table |

## Deviations, stated once

1. **Strings are `List Char`.** Swift `String` is a grapheme-cluster collection; the model uses
   code points. Where the source counts *extended grapheme clusters* (C-08/K-09's 80, R-27's 60)
   the model's unit is the code point: the model proves the *bound structure* (at most 80/60
   units, no leading or trailing separator, single separators) and the cluster semantics stays
   with T-26. Where the source lower-cases with full Unicode `lowercased()`, the model uses
   `Char.toLower`; the two agree on ASCII, and the non-ASCII cases are T-26's.
2. **Numbers are integers in a fixed unit** (see `Spec.lean`): hundredths for zoom factors,
   thousandths for em factors, points for lengths. The model therefore proves the spec's
   arithmetic exactly; `Double` rounding is a rendering detail.
3. **Effects are seams.** Every Swift function that reads a file, the clock, the database, a
   parser or the screen is replaced by a value the theorems quantify over (a `List String` of
   lines, an `Int` mtime, a ceiling `Kind`, …). No model function is `IO`.
-/
import Mdv6Proof.Mdv6.Spec

namespace Mdv6.Model

open Mdv6.Spec

/-! ## helpers -/

/-- `Char.isWhitespace` (Swift `Character.isWhitespace`). -/
def isWs (c : Char) : Bool := c.isWhitespace

/-- Space or tab — Swift's `" \t"` in `leadingNonSpace` and `trimmingCharacters(in: .whitespaces)`. -/
def isSp (c : Char) : Bool := c == ' ' || c == '\t'

/-- Prefix test on code-point lists (`String.hasPrefix`). -/
def isPrefix : List Char → List Char → Bool
  | [], _ => true
  | _ :: _, [] => false
  | a :: as, b :: bs => a == b && isPrefix as bs

/-- Substring test on code-point lists (`String.contains`). -/
def containsSub (p : List Char) : List Char → Bool
  | [] => p.isEmpty
  | s@(_ :: tl) => isPrefix p s || containsSub p tl

/-- The length of the leading run of `c`. -/
def runLength (c : Char) : List Char → Nat
  | [] => 0
  | d :: tl => if d == c then 1 + runLength c tl else 0

/-- Position-indexed list (`Array.enumerated`). -/
def enumerate {α : Type} : List α → List (Nat × α)
  | [] => []
  | a :: tl => (0, a) :: (enumerate tl).map (fun p => (p.1 + 1, p.2))

/-- Each element twice (the `#rgb` → `#rrggbb` expansion). -/
def dupe : List Char → List Char
  | [] => []
  | c :: tl => c :: c :: dupe tl

/-- `String.intercalate` on code-point lists. -/
def intercalateC (sep : List Char) : List (List Char) → List Char
  | [] => []
  | [x] => x
  | x :: tl => x ++ sep ++ intercalateC sep tl

/-- `String.trimmingCharacters(in: .whitespaces)` — spaces and tabs only, not newlines. -/
def trimWs (cs : List Char) : List Char :=
  (cs.dropWhile isSp).reverse.dropWhile isSp |>.reverse

/-- Collapse every whitespace run to one U+0020 and strip the ends (C-07.3's last step). -/
def collapseWs (cs : List Char) : List Char :=
  let rec go (acc : List Char) (inRun : Bool) : List Char → List Char
    | [] => acc.reverse
    | c :: tl => if isWs c then go (if inRun then acc else ' ' :: acc) true tl else go (c :: acc) false tl
  let r := go [] true cs
  (r.dropWhile (· == ' ')).reverse.dropWhile (· == ' ') |>.reverse

/-! ## C-02 — `ParsedDocument` -/

/-- C-02 rule 8's `blockLines` entry: a half-open 1-based source-line range. -/
abbrev LineRange := Nat × Nat

/-- One single-line ATX `#`–`###` heading (C-02 rule 7). -/
structure TOCHeading where
  level : Nat
  text : List Char
  slugText : List Char
  blockIndex : Nat
deriving DecidableEq, Repr

/-- C-02 rule 6: `\r\n` and lone `\r` are treated as `\n` before splitting. -/
def normalizeLineEndings : List Char → List Char
  | [] => []
  | '\r' :: '\n' :: tl => '\n' :: normalizeLineEndings tl
  | '\r' :: tl => '\n' :: normalizeLineEndings tl
  | c :: tl => c :: normalizeLineEndings tl

/-- `String.split(separator: "\n", omittingEmptySubsequences: false)` — an empty input yields `[]`. -/
def splitOnNewline (cs : List Char) : List String :=
  let rec go (cur : List Char) : List Char → List String → List String
    | [], acc => (String.ofList cur.reverse :: acc).reverse
    | '\n' :: tl, acc => go [] tl (String.ofList cur.reverse :: acc)
    | c :: tl, acc => go (c :: cur) tl acc
  match cs with
  | [] => []
  | _ => go [] cs []

/-- Rule 8: a trailing newline adds no empty final line. -/
def dropTrailingEmpty (ls : List String) : List String :=
  match ls.reverse with
  | "" :: tl => tl.reverse
  | _ => ls

/-- The normalised source lines the splitter runs on. -/
def sourceLines (cs : List Char) : List String :=
  dropTrailingEmpty (splitOnNewline (normalizeLineEndings cs))

/-- `String.trimmingCharacters(in: .whitespacesAndNewlines)`-free rule-5 trim: strip `\n` at both ends. -/
def trimNewlines (cs : List Char) : List Char :=
  (cs.dropWhile (· == '\n')).reverse.dropWhile (· == '\n') |>.reverse

/-- C-02 rule 2/3: the block's first non-space characters. -/
def leadingNonSpace (line : List Char) : List Char := line.dropWhile isSp

/-- C-02 rule 1: a blank line is only whitespace. -/
def isBlank (line : List Char) : Bool := line.all isWs

/-- The result of C-02's one-pass split: blocks, their half-open 1-based ranges, and the line count. -/
structure SplitResult where
  blocks : List String
  lines : List LineRange
  lineCount : Nat
deriving DecidableEq, Repr

/-- C-02 rules 1–8 in one pass, over the normalised lines. The `\r\n` normalisation is
`normalizeLineEndings`; the block trimming is rule 5. -/
def splitLines (input : List String) : SplitResult :=
  let rec go (cur : List String) (start : Option Nat) (fence : Option String) (inMath : Bool)
      (blocks : List String) (ranges : List LineRange) : Nat → List String → SplitResult
    | _, [] =>
      let joined := trimNewlines (String.toList (String.intercalate "\n" cur))
      let (blocks', ranges') :=
        if joined.isEmpty then (blocks, ranges)
        else match start with
             | some s => (blocks ++ [String.ofList joined], ranges ++ [(s, s + cur.length)])
             | none => (blocks, ranges)
      { blocks := blocks', lines := ranges', lineCount := input.length }
    | i, line :: tl =>
      let ln := String.toList line
      match fence with
      | some marker =>
        let closed := isPrefix (String.toList marker) (leadingNonSpace ln)
        go (cur ++ [line]) start (if closed then none else fence) inMath blocks ranges (i + 1) tl
      | none =>
        if inMath then
          go (cur ++ [line]) start none (if containsSub (String.toList "$$") ln then false else true)
            blocks ranges (i + 1) tl
        else if isBlank ln then
          let joined := trimNewlines (String.toList (String.intercalate "\n" cur))
          let (blocks', ranges') :=
            if joined.isEmpty then (blocks, ranges)
            else match start with
                 | some s => (blocks ++ [String.ofList joined], ranges ++ [(s, s + cur.length)])
                 | none => (blocks, ranges)
          go [] none none false blocks' ranges' (i + 1) tl
        else
          let head := leadingNonSpace ln
          let start' := match start with | some _ => start | none => some i
          if isPrefix (String.toList "```") head then
            go (cur ++ [line]) start' (some "```") false blocks ranges (i + 1) tl
          else if isPrefix (String.toList "~~~") head then
            go (cur ++ [line]) start' (some "~~~") false blocks ranges (i + 1) tl
          else if isPrefix (String.toList "$$") head &&
                  !containsSub (String.toList "$$") (head.drop 2) then
            go (cur ++ [line]) start' none true blocks ranges (i + 1) tl
          else
            go (cur ++ [line]) start' none false blocks ranges (i + 1) tl
  go [] none none false [] [] 1 input

/-- C-02 rule 7's `atxLevel`: level 1…3 when the text starts with `# `, `## ` or `### `. -/
def atxLevel (text : List Char) : Option Nat :=
  if isPrefix (String.toList "# ") text then some 1
  else if isPrefix (String.toList "## ") text then some 2
  else if isPrefix (String.toList "### ") text then some 3
  else none

/-- Rule 2: a block whose first non-space characters are ` ``` ` or `~~~`. -/
def isFence (block : List Char) : Bool :=
  let head := leadingNonSpace block
  isPrefix (String.toList "```") head || isPrefix (String.toList "~~~") head

/-- Rule 3: first line is `$$` alone (no second `$$` on that line) and the block spans >1 line. -/
def isMathFence (block : List Char) : Bool :=
  let firstLine := (block.takeWhile (· != '\n'))
  let head := leadingNonSpace firstLine
  isPrefix (String.toList "$$") head && !containsSub (String.toList "$$") (head.drop 2)
    && block.contains '\n'

/-- R-24: a GFM table — first line contains `|`, second line only `-`, `:`, `|`, space. -/
def isGFMTable (block : List Char) : Bool :=
  let lines := splitOnNewline block |>.map String.toList
  match lines with
  | l0 :: l1 :: _ =>
    l0.contains '|' && (let second := trimWs l1
                        second.isEmpty = false && second.contains '-' &&
                        second.all (fun c => c == '-' || c == ':' || c == '|' || c == ' '))
  | _ => false

/-- C-02: the split of `raw` into blocks, their line map, the line count and the TOC. -/
def parseBlocks (input : List Char) : List String := (splitLines (sourceLines input)).blocks

/-- The first line of a block (Swift's `split(maxSplits: 1).first`). -/
def firstLineOf (block : List Char) : List Char := block.takeWhile (· != '\n')

/-! ## C-11 — `headingSlug` -/

/-- C-11: lower-case; keep letters and digits; keep `-`/`_` when something precedes them; drop every
other non-whitespace character; **every** whitespace run becomes one `-` when something precedes it;
strip trailing `-`/`_`. -/
def slugStep (acc : List Char × Bool) (ch : Char) : List Char × Bool :=
  let (out, inRun) := acc
  if isWs ch then
    if inRun then (out, true) else ((if out.isEmpty then out else out ++ ['-']), true)
  else if ch.isAlpha || ch.isDigit then (out ++ [ch], false)
  else if ch == '-' || ch == '_' then ((if out.isEmpty then out else out ++ [ch]), false)
  else (out, false)

def slugCore (s : List Char) : List Char :=
  let out := s.foldl slugStep ([], false) |>.1
  out.reverse.dropWhile (fun c => c == '-' || c == '_') |>.reverse

/-- C-11: `slug` — lower-case first, then `slugCore`. -/
def slug (s : List Char) : List Char := slugCore (s.map Char.toLower)

/-! ## C-10 — `smartenMarkdown` -/

/-- C-10: a thematic-break line — three or more `-`, `*` or `_` (optionally space-separated) and
nothing else. -/
def isThematicBreak (block : List Char) : Bool :=
  let trimmed := trimWs block
  match trimmed.head? with
  | none => false
  | some first =>
    if !(first == '-' || first == '*' || first == '_') then false
    else
      let stripped := trimmed.filter (· != ' ')
      stripped.length ≥ 3 && stripped.all (· == first)

/-- C-10: the opening-quote predicate — an opening quote when the preceding character is absent,
whitespace, or one of `( [ { < “ ‘ — – - /`. -/
def opensQuote (prev : Option Char) : Bool :=
  match prev with
  | none => true
  | some p => isWs p || (String.toList "([{<“‘—–-/").contains p

/-- The first `>` and what follows it. -/
def takeUntilGt : List Char → Option (List Char × List Char)
  | [] => none
  | '>' :: rest => some ([], rest)
  | c :: rest => (takeUntilGt rest).map (fun p => (c :: p.1, p.2))

/-- A run of exactly `n` backticks closes; returns what follows the closing run. -/
def findRunClose (n : Nat) (cs : List Char) : Option (List Char) :=
  let rec go (fuel : Nat) (rest : List Char) : Option (List Char) :=
    match fuel with
    | 0 => none
    | f + 1 =>
      match rest with
      | [] => none
      | c :: tl =>
        if c == '`' then
          let m := runLength '`' (c :: tl)
          if m == n then some ((c :: tl).drop m) else go f ((c :: tl).drop m)
        else go f tl
  go (cs.length + 1) cs

/-- The link/image URL part `](` … matching `)`: the number of characters consumed from the `(`. -/
def linkSpanEnd : List Char → Nat → Nat → Option Nat
  | [], _, _ => none
  | c :: tl, depth, k =>
    if c == '(' then linkSpanEnd tl (depth + 1) (k + 1)
    else if c == ')' then (if depth == 1 then some (k + 1) else linkSpanEnd tl (depth - 1) (k + 1))
    else linkSpanEnd tl depth (k + 1)

/-- C-10 `smartenMarkdown`: the block unchanged if it is a fence, a GFM table or a thematic-break
line; otherwise the quote/dash/ellipsis transforms outside inline code, link URLs and `<…>` spans. -/
def smarten (block : List Char) : List Char :=
  if isFence block || isGFMTable block || isThematicBreak block then block
  else
    let rec go (fuel : Nat) (prevOrig prevEmit : Option Char) (cs : List Char) : List Char :=
      match fuel with
      | 0 => cs
      | f + 1 =>
        match cs with
        | [] => []
        | c :: tl =>
          if c == '`' then
            let n := runLength '`' (c :: tl)
            let rest := (c :: tl).drop n
            match findRunClose n rest with
            | some rest' =>
              let consumed := (c :: tl).take ((c :: tl).length - rest'.length)
              consumed ++ go f consumed.getLast? consumed.getLast? rest'
            | none => (c :: tl).take n ++ go f (some '`') (some '`') rest
          else if c == ']' && tl.head? == some '(' then
            match linkSpanEnd tl 0 0 with
            | some k =>
              let consumed := c :: tl.take k
              consumed ++ go f consumed.getLast? consumed.getLast? (tl.drop k)
            | none => c :: go f (some c) (some c) tl
          else if c == '<' then
            match takeUntilGt tl with
            | some (mid, rest') =>
              if mid.contains '\n' then c :: go f (some c) (some c) tl
              else (c :: (mid ++ ['>'])) ++ go f (some '>') (some '>') rest'
            | none => c :: go f (some c) (some c) tl
          else if c == '-' then
            match tl with
            | d :: rest =>
              if d == '-' && rest.head? == some '-' && (rest.drop 1).head? != some '-' then
                '—' :: go f (some '-') (some '—') (tl.drop 2)
              else if d == '-' && rest.head? != some '-' then
                let after := rest.head?
                match prevOrig with
                | some b =>
                  if (b.isAlpha || b.isDigit) &&
                     (match after with | some a => a.isAlpha || a.isDigit | none => false) then
                    '–' :: go f (some '-') (some '–') (tl.drop 1)
                  else if b == ' ' && after == some ' ' then
                    '—' :: go f (some '-') (some '—') (tl.drop 1)
                  else '-' :: '-' :: go f (some '-') (some '-') (tl.drop 1)
                | none => '-' :: '-' :: go f (some '-') (some '-') (tl.drop 1)
              else
                let n := 1 + runLength '-' tl
                if n ≥ 3 then
                  let consumed := c :: tl.take (n - 1)
                  consumed ++ go f consumed.getLast? consumed.getLast? (tl.drop (n - 1))
                else '-' :: go f (some c) (some c) tl
            | [] => '-' :: go f (some c) (some c) tl
          else if c == '.' && tl.take 2 == ['.', '.'] then
            '…' :: go f (some '.') (some '…') (tl.drop 2)
          else if c == '"' then
            (if opensQuote prevEmit then '“' else '”') ::
              go f (some c) (some (if opensQuote prevEmit then '“' else '”')) tl
          else if c == '\'' then
            (if opensQuote prevEmit then '‘' else '’') ::
              go f (some c) (some (if opensQuote prevEmit then '‘' else '’')) tl
          else c :: go f (some c) (some c) tl
    go (block.length + 1) none none block

/-! ## C-12 — `sectionRange` and `stripInlineMarkdown` -/

/-- C-12: blocks `[i, j)` where `j` is the next TOC heading with level ≤ the level of `i`, or the
block count. -/
def sectionRange (blocks : List String) (toc : List TOCHeading) (i : Nat) : Nat × Nat :=
  match toc.find? (fun h => h.blockIndex == i) with
  | none => (i, min (i + 1) blocks.length)
  | some h =>
    (i, match toc.find? (fun t => t.blockIndex > i && t.level ≤ h.level) with
        | some t => t.blockIndex
        | none => blocks.length)

/-- C-12 copy output: the section's blocks joined with `\n\n`. -/
def sectionMarkdown (blocks : List String) (toc : List TOCHeading) (i : Nat) : List Char :=
  let r := sectionRange blocks toc i
  String.toList (String.intercalate "\n\n" (blocks.drop r.1 |>.take (r.2 - r.1)))

/-- Split at the first occurrence of `c`, returning (before, from-the-char-onward). -/
def splitAtChar (c : Char) : List Char → Option (List Char × List Char)
  | [] => none
  | x :: tl => if x == c then some ([], x :: tl) else (splitAtChar c tl).map (fun p => (x :: p.1, p.2))

/-- C-12 step (1): the trailing `#`s of the heading body, and the surrounding whitespace is
trimmed. Transcribed from the source's while-loop (a trailing `#` is removed; a trailing space is
removed only when the character before it is `#`). -/
def trimTrailingHashes (s : List Char) : List Char :=
  let rec go : List Char → List Char
    | [] => []
    | last :: tl =>
      if last == '#' then go tl
      else if last == ' ' then (match tl with | '#' :: _ => go tl | _ => last :: tl)
      else last :: tl
  (go s.reverse).reverse

/-- C-12 step (2): `[text](url)` → `text`. -/
def replaceLinks (s : List Char) : List Char :=
  let rec matchLink : List Char → Option (List Char × List Char)
    | '[' :: tl =>
      match splitAtChar ']' tl with
      | some (inner, ']' :: tl2) =>
        (match tl2 with
         | '(' :: _ => (splitAtChar ')' tl2).map (fun p => (inner, p.2.drop 1))
         | _ => none)
      | _ => none
    | _ => none
  let rec go (fuel : Nat) (rest : List Char) (acc : List Char) : List Char :=
    match fuel with
    | 0 => acc ++ rest
    | f + 1 =>
      match rest with
      | [] => acc
      | c :: tl =>
        if c == '[' then
          match matchLink rest with
          | some (inner, rest') => go f rest' (acc ++ inner)
          | none => go f tl (acc ++ ['['])
        else go f tl (acc ++ [c])
  go (s.length + 1) s []

/-- C-12 step (3): both underscores of an `_…_` pair whose opening `_` is not preceded by a letter
or digit; word-internal underscores are kept. -/
def stripUnderscorePairs (s : List Char) : List Char :=
  let cs := s
  let rec findClose (fuel j : Nat) : Nat :=
    match fuel with
    | 0 => j
    | f + 1 =>
      match cs[j]? with
      | none => j
      | some d =>
        if d == '_' && cs[j + 1]? == some '_' then findClose f (j + 2)
        else if d == '_' && (match cs[j - 1]? with | some p => !isWs p | none => true) then j
        else findClose f (j + 1)
  let rec go (fuel i : Nat) (drop : List Nat) : List Nat :=
    match fuel with
    | 0 => drop
    | f + 1 =>
      match cs[i]? with
      | none => drop
      | some c =>
        if c == '_' && cs[i + 1]? == some '_' then go f (i + 2) drop
        else if c == '_' then
          let prevOK := i == 0 || (match cs[i - 1]? with | some p => !(p.isAlpha || p.isDigit) | none => true)
          if prevOK && (match cs[i + 1]? with | some n => !isWs n | none => false) then
            let j := findClose (cs.length + 1) (i + 1)
            if j < cs.length then go f (j + 1) (i :: j :: drop) else go f (i + 1) drop
          else go f (i + 1) drop
        else go f (i + 1) drop
  let dropped := go (cs.length + 1) 0 []
  ((enumerate cs).filter (fun p => !dropped.contains p.1)).map (·.2)

/-- C-12 step (4): escapes are kept as the escaped character; `*` and a lone backtick are dropped;
`__` is dropped. -/
def stripMarkupChars (s : List Char) : List Char :=
  let rec go : List Char → List Char
    | [] => []
    | c :: [] => if c == '\\' then [c] else if c == '*' || c == '`' then [] else [c]
    | c :: (d :: tl') =>
      if c == '\\' then
        (if (String.toList "*_`#[]\\").contains d then d :: go (d :: tl') else c :: go (d :: tl'))
      else if c == '*' || c == '`' then go (d :: tl')
      else if c == '_' && d == '_' then go tl'
      else c :: go (d :: tl')
  go s

/-- C-12: `stripInlineMarkdown`, in the pinned order (1) trailing `#`s, (2) links, (3) `_…_` pairs,
(4) the remaining markup characters. -/
def stripInlineMarkdown (input : List Char) : List Char :=
  let s1 := trimWs (trimTrailingHashes input)
  let s2 := replaceLinks s1
  let s3 := stripUnderscorePairs s2
  trimWs (stripMarkupChars s3)

/-! ## C-08 — `Anchors` -/

/-- Split at every whitespace code point, discarding empty pieces. -/
def splitWs (cs : List Char) : List (List Char) :=
  let rec go (cur : List Char) : List Char → List (List Char) → List (List Char)
    | [], acc => if cur.isEmpty then acc else cur.reverse :: acc
    | c :: tl, acc =>
      if isWs c then go [] tl (if cur.isEmpty then acc else cur.reverse :: acc)
      else go (c :: cur) tl acc
  (go [] cs []).reverse

/-- C-08: split at every Unicode whitespace scalar, discard empty pieces, join with U+0020, apply
locale-independent lowercase, retain the first 80 units (K-09). -/
def fingerprint (block : List Char) : List Char :=
  (intercalateC [' '] (splitWs block)).map Char.toLower |>.take fingerprintClusters.toNat

/-- C-08: equality is code-point-wise, never canonical. -/
def fingerprintsEqual (a b : List Char) : Bool := a == b

/-- C-08: the first block whose fingerprint equals the stored one; else `storedIndex` clamped to
`[0, count-1]`; else 0. -/
def resolveBookmarkAnchor (blocks : List String) (storedIndex : Nat) (fp : List Char) : Nat :=
  if blocks.isEmpty then 0
  else
    let searched := if fp.isEmpty then none
      else ((enumerate blocks).find? (fun p => fingerprintsEqual (fingerprint (String.toList p.2)) fp)).map (·.1)
    match searched with
    | some i => i
    | none => min storedIndex (blocks.length - 1)

/-- C-08, E-08, K-06: scroll restoration validity — the mtime is within the 1 s tolerance and the
index is in bounds. -/
def scrollRestorable (storedMtime fileMtime index count : Int) : Bool :=
  (if storedMtime - fileMtime ≥ 0 then storedMtime - fileMtime else fileMtime - storedMtime)
      ≤ scrollMtimeToleranceSeconds
    && index ≥ 0 && index < count

/-! ## C-03 — `FTSQuery` -/

/-- C-03: split on whitespace; drop `" ( ) : * ^` from each token; discard empties; wrap every
survivor as `"token"*`; join with spaces. `none` when no token survives (E-24). -/
def ftsMake (input : List Char) : Option (List Char) :=
  let tokens := ((splitWs input).map (fun t => t.filter (fun c => !ftsDroppedChars.contains c))).filter (fun t => !t.isEmpty)
  if tokens.isEmpty then none
  else some (intercalateC [' '] (tokens.map (fun t => ['"'] ++ t ++ ['"', '*'])))

/-! ## C-19 — `LineCitation` -/

/-- C-19.1: one run of ASCII digits with no leading zero, at most nine of them. -/
def parseNumber (rest : List Char) : Option (Nat × List Char) :=
  let run := rest.takeWhile (fun c => c.val < 128 && c.isDigit)
  match run with
  | [] => none
  | h :: _ =>
    if h == '0' || run.length > lineCitationMaxDigits.toNat then none
    else some (run.foldl (fun a d => a * 10 + (d.val.toNat - 48)) 0, rest.drop run.length)

/-- C-19.1: the anchored, case-insensitive grammar, applied to the already-decoded fragment. -/
def citationParse (fragment : List Char) : Option (Nat × Option Nat) :=
  match fragment with
  | lead :: rest =>
    if lead == 'L' || lead == 'l' then
      match parseNumber rest with
      | none => none
      | some (v, rest') =>
        if rest'.isEmpty then some (v, none)
        else if rest'.head? == some '-' then
          let rest'' := rest'.drop 1
          let rest''' := match rest''.head? with
            | some m => if m == 'L' || m == 'l' then rest''.drop 1 else rest''
            | none => rest''
          match parseNumber rest''' with
          | some (v2, rest4) => if rest4.isEmpty then some (v, some v2) else none
          | none => none
        else none
    else none
  | [] => none

/-- C-19.2: the resolved start line — `min(first, last)` when the fragment names two numbers. -/
def citationStartLine (c : Nat × Option Nat) : Nat := c.2.map (fun b => min c.1 b) |>.getD c.1

/-- C-19.3 / C-02 rule 8 / E-31: the block a citation targets — the last block whose first source
line is at or before the resolved start line, else the first block; `none` for no blocks. -/
def citationBlock (c : Nat × Option Nat) (ranges : List LineRange) : Option Nat :=
  if ranges.isEmpty then none
  else
    let target := (enumerate ranges).foldl
      (fun acc p => if p.2.1 ≤ citationStartLine c then some p.1 else acc) none
    some (target.getD 0)

/-! ## C-05 — `CodeLanguage` -/

/-- C-05, K-05, R-38, R-43: the seventeen highlighted languages. -/
inductive CodeLanguage where
  | c | go | rust | bash | javascript | yaml | toml | python | ruby | swift | sql
  | cpp | json | lua | opencl | perl | markdown
deriving DecidableEq, Repr

/-- The `CodeLanguage` cases in declaration order. -/
def CodeLanguage.all : List CodeLanguage :=
  [.c, .go, .rust, .bash, .javascript, .yaml, .toml, .python, .ruby, .swift, .sql,
   .cpp, .json, .lua, .opencl, .perl, .markdown]

/-- The language's fence word (`CodeLanguage.rawValue`). -/
def CodeLanguage.name : CodeLanguage → String
  | .c => "c" | .go => "go" | .rust => "rust" | .bash => "bash" | .javascript => "javascript"
  | .yaml => "yaml" | .toml => "toml" | .python => "python" | .ruby => "ruby" | .swift => "swift"
  | .sql => "sql" | .cpp => "cpp" | .json => "json" | .lua => "lua" | .opencl => "opencl"
  | .perl => "perl" | .markdown => "markdown"

/-- The C-05 alias table (alias → language). -/
def CodeLanguage.aliases : List (String × CodeLanguage) :=
  [ ("js", .javascript), ("jsx", .javascript), ("javascriptreact", .javascript), ("node", .javascript),
    ("sh", .bash), ("zsh", .bash), ("shell", .bash),
    ("py", .python), ("python3", .python),
    ("rb", .ruby), ("yml", .yaml), ("rs", .rust), ("golang", .go),
    ("h", .c), ("objective-c", .c), ("objc", .c),
    ("sqlite", .sql), ("postgresql", .sql), ("postgres", .sql), ("mysql", .sql), ("plsql", .sql), ("tsql", .sql),
    ("c++", .cpp), ("cplusplus", .cpp), ("cc", .cpp), ("cxx", .cpp), ("cp", .cpp),
    ("hpp", .cpp), ("hxx", .cpp), ("hh", .cpp), ("metal", .cpp), ("msl", .cpp),
    ("cl", .opencl), ("opencl-c", .opencl),
    ("pl", .perl), ("perl5", .perl),
    ("md", .markdown), ("gfm", .markdown) ]

/-- C-05: the raw first word of the info string, lower-cased. -/
def firstWord (info : Option String) : Option String :=
  info.bind (fun s => (splitWs (String.toList s)).head?.map (fun w => String.ofList (w.map Char.toLower)))

/-- C-05: lower-case the info string, keep its first word; direct names, then aliases; anything else
→ `none` (plain). -/
def CodeLanguage.resolve (info : Option String) : Option CodeLanguage :=
  match firstWord info with
  | none => none
  | some w =>
    match CodeLanguage.all.find? (fun l => l.name == w) with
    | some l => some l
    | none => (CodeLanguage.aliases.find? (fun p => p.1 == w)).map (·.2)

/-- C-05, R-08: the prompt-aware test — a separate test on the raw first word. -/
def CodeLanguage.isPromptAware (info : Option String) : Bool :=
  match firstWord info with
  | none => false
  | some w => promptAwareFenceWords.contains w

/-- R-08: a prompt line starts with `$ ` or `# `. -/
def isPromptLine (line : List Char) : Bool :=
  isPrefix ['$', ' '] line || isPrefix ['#', ' '] line

/-- R-08: at least half of the non-empty lines start with `$ ` or `# `. -/
def CodeLanguage.isPrompted (code : List Char) : Bool :=
  let lines := (splitOnNewline code).map String.toList |>.filter (fun l => !l.all isWs)
  if lines.isEmpty then false
  else 2 * (lines.filter isPromptLine).length ≥ lines.length

/-- R-08 *Copy Without Prompts*: the leading `$ `/`# ` removed from each prompted line, every other
line copied unchanged. -/
def CodeLanguage.stripPrompts (code : List Char) : List Char :=
  String.toList (String.intercalate "\n"
    ((splitOnNewline code).map (fun l => let cs := String.toList l
                                         if isPromptLine cs then String.ofList (cs.drop 2) else l)))

/-- C-05: the block label — the raw first word lower-cased, or `text`. -/
def CodeLanguage.label (info : Option String) : String := (firstWord info).getD "text"

/-! ## C-07.1 — `MathMarkdown`: span detection -/

/-- One math span found in a prose block. `start`/`stop` are code-point offsets into the block;
`latex` excludes the delimiters; `display` is `$$…$$` vs `$…$` (K-08); `ownParagraph` is a `$$…$$`
whose opener is at line start and closer at line end (C-07.1's placement rule). -/
structure MathSpan where
  start : Nat
  stop : Nat
  latex : List Char
  display : Bool
  ownParagraph : Bool
deriving DecidableEq, Repr

/-- C-07.1: the position just after a span is at line end when only spaces precede a `\n` or the
end of input. -/
def atLineEnd : List Char → Bool
  | [] => true
  | c :: tl => if c == ' ' then atLineEnd tl else c == '\n'

/-- The `$$` closer: the next `$$` that is not escaped and not across a backtick (which makes the
span fail). Returns (latex, what follows the closer). -/
def findDollarClose (cs : List Char) : Option (List Char × List Char) :=
  let rec go (fuel : Nat) (acc : List Char) (rest : List Char) : Option (List Char × List Char) :=
    match fuel with
    | 0 => none
    | f + 1 =>
      match rest with
      | [] => none
      | c :: tl =>
        if c == '\\' then
          match tl with
          | [] => none
          | d :: tl' => go f (d :: c :: acc) tl'
        else if c == '`' then none
        else if c == '$' then
          match tl with
          | '$' :: tl' => some (acc.reverse, tl')
          | _ => go f (c :: acc) tl
        else go f (c :: acc) tl
  go (cs.length + 1) [] cs

/-- The inline `$` closer: a `$` preceded by non-whitespace and not followed by a digit; a backtick
or a failed candidate makes the span fail. -/
def findInlineClose (cs : List Char) : Option (List Char × List Char) :=
  let rec go (fuel : Nat) (acc : List Char) (rest : List Char) : Option (List Char × List Char) :=
    match fuel with
    | 0 => none
    | f + 1 =>
      match rest with
      | [] => none
      | c :: tl =>
        if c == '\\' then
          match tl with
          | [] => none
          | d :: tl' => go f (d :: c :: acc) tl'
        else if c == '`' then none
        else if c == '$' then
          let latex := acc.reverse
          let prevOK := match latex.getLast? with | none => true | some p => !isWs p
          let nextOK := match tl with | [] => true | d :: _ => !d.isDigit
          if prevOK && nextOK then some (latex, tl) else none
        else go f (c :: acc) tl
  go (cs.length + 1) [] cs

/-- C-07.1's scan: fenced blocks are never rewritten; `\$` is literal; inline code spans are
skipped; `$$…$$` and `$…$` spans are found per the delimiter rules; an empty `$$` pair is literal. -/
def spansFrom (i : Nat) (lineStart : Bool) (cs : List Char) : List MathSpan :=
  let rec go (fuel : Nat) (i : Nat) (lineStart : Bool) (cs : List Char) : List MathSpan :=
    match fuel with
    | 0 => []
    | f + 1 =>
      match cs with
      | [] => []
      | c :: tl =>
        if c == '\\' then
          match tl with
          | [] => []
          | _ :: tl' => go f (i + 2) false tl'
        else if c == '`' then
          let n := runLength '`' (c :: tl)
          let rest := (c :: tl).drop n
          match findRunClose n rest with
          | some rest' => go f (i + n + (rest.length - rest'.length)) false rest'
          | none => go f (i + n) false rest
        else if c == '$' then
          match tl with
          | '$' :: tl' =>
            match findDollarClose tl' with
            | some (latex, rest') =>
              let consumed := tl'.length - rest'.length
              if latex.all isWs then go f (i + 2 + consumed) false rest'
              else
                let own := lineStart && atLineEnd rest'
                { start := i, stop := i + 2 + consumed, latex := latex, display := true,
                  ownParagraph := own } :: go f (i + 2 + consumed) false rest'
            | none => go f (i + 2) false tl'
          | _ =>
            match tl.head? with
            | none => go f (i + 1) false tl
            | some d =>
              if isWs d || d == '$' then go f (i + 1) false tl
              else
                match findInlineClose tl with
                | some (latex, rest') =>
                  let consumed := tl.length - rest'.length
                  { start := i, stop := i + 1 + consumed, latex := latex, display := false,
                    ownParagraph := false } :: go f (i + 1 + consumed) false rest'
                | none => go f (i + 1) false tl
        else
          go f (i + 1) (if c == '\n' then true else lineStart && c == ' ') tl
  if isFence cs then [] else go (cs.length + 1) i lineStart cs

/-- C-07.1: the math spans of a prose block. -/
def spans (cs : List Char) : List MathSpan := spansFrom 0 true cs

/-! ## C-07.3 — `MathMarkdown.plainText` -/

/-- C-07.3: the Unicode superscript forms. -/
def superscripts : List (Char × Char) :=
  [('0','⁰'),('1','¹'),('2','²'),('3','³'),('4','⁴'),('5','⁵'),('6','⁶'),('7','⁷'),('8','⁸'),('9','⁹'),
   ('+','⁺'),('-','⁻'),('n','ⁿ'),('i','ⁱ')]

/-- C-07.3: the Unicode subscript forms. -/
def subscripts : List (Char × Char) :=
  [('0','₀'),('1','₁'),('2','₂'),('3','₃'),('4','₄'),('5','₅'),('6','₆'),('7','₇'),('8','₈'),('9','₉'),
   ('+','₊'),('-','₋'),('i','ᵢ'),('j','ⱼ'),('n','ₙ'),('k','ₖ'),('x','ₓ')]

/-- C-07.3's symbol table: command name → Unicode. -/
def symbols : List (String × String) :=
  [ ("alpha","α"),("beta","β"),("gamma","γ"),("delta","δ"),("epsilon","ε"),("varepsilon","ε"),("zeta","ζ"),("eta","η"),
    ("theta","θ"),("vartheta","ϑ"),("iota","ι"),("kappa","κ"),("lambda","λ"),("mu","μ"),("nu","ν"),("xi","ξ"),("pi","π"),
    ("varpi","ϖ"),("rho","ρ"),("varrho","ϱ"),("sigma","σ"),("varsigma","ς"),("tau","τ"),("upsilon","υ"),("phi","ϕ"),
    ("varphi","φ"),("chi","χ"),("psi","ψ"),("omega","ω"),
    ("Gamma","Γ"),("Delta","Δ"),("Theta","Θ"),("Lambda","Λ"),("Xi","Ξ"),("Pi","Π"),("Sigma","Σ"),("Upsilon","Υ"),
    ("Phi","Φ"),("Psi","Ψ"),("Omega","Ω"),
    ("leq","≤"),("le","≤"),("geq","≥"),("ge","≥"),("neq","≠"),("ne","≠"),("approx","≈"),("equiv","≡"),("sim","∼"),
    ("simeq","≃"),("cong","≅"),("propto","∝"),("ll","≪"),("gg","≫"),("prec","≺"),("succ","≻"),("leqslant","⩽"),("geqslant","⩾"),
    ("gtrsim","≳"),("lesssim","≲"),("doteq","≐"),("triangleq","≜"),("models","⊨"),("vDash","⊨"),("Vdash","⊩"),
    ("parallel","∥"),("nparallel","∦"),("perp","⊥"),("mid","∣"),("nmid","∤"),
    ("times","×"),("div","÷"),("pm","±"),("mp","∓"),("cdot","·"),("cdots","⋯"),("ldots","…"),("dots","…"),("dotsc","…"),
    ("dotsb","⋯"),("vdots","⋮"),("ddots","⋱"),("ast","∗"),("star","⋆"),("circ","∘"),("bullet","•"),("oplus","⊕"),
    ("otimes","⊗"),("odot","⊙"),("sum","∑"),("prod","∏"),("coprod","∐"),("int","∫"),("iint","∬"),("iiint","∭"),
    ("oint","∮"),("partial","∂"),("nabla","∇"),("infty","∞"),("sqrt","√"),("surd","√"),("wedge","∧"),("vee","∨"),
    ("land","∧"),("lor","∨"),("lnot","¬"),("neg","¬"),("setminus","∖"),("bigcup","⋃"),("bigcap","⋂"),
    ("to","→"),("rightarrow","→"),("leftarrow","←"),("leftrightarrow","↔"),("Rightarrow","⇒"),("Leftarrow","⇐"),
    ("Leftrightarrow","⇔"),("implies","⇒"),("impliedby","⇐"),("iff","⇔"),("mapsto","↦"),("longrightarrow","⟶"),
    ("longleftarrow","⟵"),("uparrow","↑"),("downarrow","↓"),("hookrightarrow","↪"),("hookleftarrow","↩"),
    ("nearrow","↗"),("searrow","↘"),("swarrow","↙"),("nwarrow","↖"),("rightharpoonup","⇀"),("leftharpoonup","↼"),
    ("rightleftharpoons","⇌"),("leadsto","⇝"),("rightsquigarrow","⇝"),("longmapsto","⟼"),("twoheadrightarrow","↠"),
    ("in","∈"),("notin","∉"),("ni","∋"),("subset","⊂"),("supset","⊃"),("subseteq","⊆"),("supseteq","⊇"),
    ("subsetneq","⊊"),("supsetneq","⊋"),("nsubseteq","⊈"),("nsupseteq","⊉"),("cup","∪"),("cap","∩"),("emptyset","∅"),
    ("varnothing","∅"),("forall","∀"),("exists","∃"),("nexists","∄"),("therefore","∴"),("because","∵"),
    ("mathbb{R}","ℝ"),("mathbb{N}","ℕ"),("mathbb{Z}","ℤ"),("mathbb{Q}","ℚ"),("mathbb{C}","ℂ"),
    ("aleph","ℵ"),("hbar","ℏ"),("hslash","ℏ"),("ell","ℓ"),("Re","ℜ"),("Im","ℑ"),("wp","℘"),("angle","∠"),
    ("degree","°"),("prime","′"),("checkmark","✓"),("square","□"),("Box","□"),("blacksquare","■"),("bigstar","★"),
    ("langle","⟨"),("rangle","⟩"),("lfloor","⌊"),("rfloor","⌋"),("lceil","⌈"),("rceil","⌉"),("lvert","|"),("rvert","|"),
    ("lVert","‖"),("rVert","‖"),("quad"," "),("qquad","  "),(","," "),(";"," "),(":"," "),("!",""),(" "," "),
    ("{","{"),("}","}"),("%","%"),("$","$"),("&","&"),("#","#"),("_","_"),("backslash","\\") ]

/- C-07.3's converter: a recursive descent over the LaTeX with a fuel bound (the source's
index-based `PlainConverter`). -/
mutual
  def plainConvert (fuel : Nat) (stop : Option Char) (cs : List Char) : List Char × List Char :=
    match fuel with
    | 0 => ([], cs)
    | f + 1 =>
      match cs with
      | [] => ([], [])
      | c :: tl =>
        if some c == stop then ([], tl)
        else if c == '{' then
          let (o1, r1) := plainConvert f (some '}') tl
          let (o2, r2) := plainConvert f stop r1
          (o1 ++ o2, r2)
        else if c == '}' then plainConvert f stop tl
        else if c == '\\' then
          let (o1, r1) := plainCommand f tl
          let (o2, r2) := plainConvert f stop r1
          (o1 ++ o2, r2)
        else if c == '^' || c == '_' then
          let (arg, r1) := plainArgument f tl
          let table := if c == '^' then superscripts else subscripts
          let out := if !arg.isEmpty && arg.all (fun x => (table.lookup x).isSome)
                     then arg.map (fun x => (table.lookup x).getD x) else c :: arg
          let (o2, r2) := plainConvert f stop r1
          (out ++ o2, r2)
        else
          let (o2, r2) := plainConvert f stop tl
          (c :: o2, r2)
  def plainArgument (fuel : Nat) (cs : List Char) : List Char × List Char :=
    match fuel with
    | 0 => ([], cs)
    | f + 1 =>
      match cs with
      | [] => ([], [])
      | c :: tl =>
        if c == '{' then plainConvert f (some '}') tl
        else if c == '\\' then plainCommand f tl
        else ([c], tl)
  def plainCommand (fuel : Nat) (cs : List Char) : List Char × List Char :=
    match fuel with
    | 0 => ([], cs)
    | f + 1 =>
      match cs with
      | [] => ([], [])
      | c :: tl =>
        let name := if c.isAlpha then (c :: tl).takeWhile Char.isAlpha else [c]
        let rest := if c.isAlpha then (c :: tl).dropWhile Char.isAlpha else tl
        let nm := String.ofList name
        if nm == "frac" || nm == "dfrac" || nm == "tfrac" then
          let (a, r1) := plainArgument f rest
          let (b, r2) := plainArgument f r1
          (a ++ ['/'] ++ b, r2)
        else if nm == "sqrt" then
          let (deg, r1) := match rest with
            | '[' :: tl2 => (tl2.takeWhile (· != ']'), (tl2.dropWhile (· != ']')).drop 1)
            | _ => ([], rest)
          let (a, r2) := plainArgument f r1
          ((if deg.isEmpty then ['√'] else deg ++ ['√']) ++ a, r2)
        else if plainTextWrappers.contains nm then
          if nm == "left" || nm == "right" then
            match rest with
            | [] => ([], [])
            | '\\' :: tl2 => plainCommand f tl2
            | d :: tl2 => (if d == '.' then [] else [d], tl2)
          else if nm == "displaystyle" then ([], rest)
          else plainArgument f rest
        else
          match symbols.find? (fun p => p.1 == nm) with
          | some p => (String.toList p.2, rest)
          | none => (name, rest)
end

/-- C-07.3: one LaTeX string (no delimiters) to its Unicode approximation, whitespace collapsed. -/
def latexToPlain (latex : List Char) : List Char :=
  collapseWs (plainConvert (latex.length + 1) none latex).1

/-- C-07.3: every math span in `s` replaced by its Unicode approximation; text outside spans
untouched. -/
def plainText (s : List Char) : List Char :=
  let sp := spans s
  let rec go (i : Nat) (sp : List MathSpan) : List Char :=
    match sp with
    | [] => s.drop i
    | x :: tl => (s.drop i).take (x.start - i) ++ latexToPlain x.latex ++ go x.stop tl
  go 0 sp

/-! ## C-07.1 — the URL -/

/-- C-07.1: `base64url` is RFC 4648 §5 without `=` padding — the app's own step is the alphabet
substitution and the `=` removal; the base64 encoding itself is Foundation's (the seam). -/
def base64urlPost (cs : List Char) : List Char :=
  (cs.map (fun c => if c == '+' then '-' else if c == '/' then '_' else c)).filter (· != '=')

/-- `String(format: "%.1f", …)` for a value in tenths. -/
def formatTenths (t : Int) : List Char :=
  String.toList (toString (t / 10) ++ "." ++ toString (t % 10))

/-- C-07.1's URL: `mdv6-math://<host>/<base64url(latex)>?s=<size, 1 decimal>&c=<RRGGBBAA>`; the host
is decided by the delimiter alone. `encode` is the Foundation base64 seam. -/
def mathUrl (encode : List Char → List Char) (latex : List Char) (display : Bool)
    (sizeTenths : Int) (colorHex : List Char) : List Char :=
  String.toList (mathScheme ++ "://" ++ (if display then mathHostDisplay else mathHostInline) ++ "/")
    ++ base64urlPost (encode latex)
    ++ String.toList "?s=" ++ formatTenths sizeTenths ++ String.toList "&c=" ++ colorHex

/-- C-07.1: `rewrite`'s reference form — each span replaced by `![](url)`. The own-paragraph
blank-line splice is the `ownParagraph` predicate (see the correspondence table). -/
def rewriteRefs (encode : List Char → List Char) (block : List Char) (sizeTenths : Int)
    (colorHex : List Char) : List Char :=
  let sp := spans block
  let rec go (i : Nat) (sp : List MathSpan) : List Char :=
    match sp with
    | [] => block.drop i
    | x :: tl =>
      (block.drop i).take (x.start - i)
        ++ String.toList "![](" ++ mathUrl encode x.latex x.display sizeTenths colorHex
        ++ String.toList ")" ++ go x.stop tl
  go 0 sp

/-- R-13: the ATX heading level (1…6) of a block whose first line is `#…# text`. -/
def headingLevel (block : List Char) : Option Nat :=
  let trimmed := block.dropWhile (· == ' ')
  let n := runLength '#' trimmed
  if n ≥ 1 && n ≤ 6 && (trimmed.drop n).head? == some ' ' then some n else none

/-! ## C-06.1 — the Mermaid source sanitiser -/

/-- Rule 1: a leading `---` … `---` YAML front-matter block is dropped. -/
def dropFrontMatter (source : List Char) : List Char :=
  let lines := splitOnNewline source
  match lines with
  | first :: rest =>
    if trimWs (String.toList first) == String.toList "---" then
      match (enumerate rest).find? (fun p => trimWs (String.toList p.2) == String.toList "---") with
      | some p => String.toList (String.intercalate "\n" (rest.drop (p.1 + 1)))
      | none => source
    else source
  | [] => source

/-- Rule 2: `line "name" [...]`/`bar "name" [...]` → `line [...]`/`bar [...]`. -/
def renameXYSeriesLine (line : List Char) : List Char :=
  let indent := line.takeWhile isWs
  let rest := line.dropWhile isWs
  let kw := if isPrefix (String.toList "line") rest then some "line"
            else if isPrefix (String.toList "bar") rest then some "bar" else none
  match kw with
  | none => line
  | some k =>
    let afterKw := rest.drop k.length
    let afterWs := afterKw.dropWhile isWs
    if afterWs.length == afterKw.length then line      -- `\s+` requires at least one space
    else match afterWs with
      | '"' :: tl =>
        match tl.dropWhile (· != '"') with
        | '"' :: tl2 =>
          let afterName := tl2.dropWhile isWs
          if afterName.head? == some '[' then indent ++ String.toList k ++ [' '] ++ afterName else line
        | _ => line
      | _ => line

/-- Rule 3's value expansion: `#rgb`/`#rgba` doubled, or a mapped CSS colour name; anything else
passes through (`none`). -/
def expandColorValue (value : List Char) : Option (List Char) :=
  match value with
  | '#' :: digits =>
    if digits.length == 3 || digits.length == 4
    then some ('#' :: dupe digits)
    else none
  | _ => (cssColorMap.find? (fun p => p.1 == String.ofList value)).map (fun p => String.toList p.2)

/-- Rule 3's keyword match at a position: `fill|stroke|color`, optional space, `:`, optional space. -/
def matchColorKey (prev : Option Char) (cs : List Char) : Option (List Char × List Char) :=
  if (match prev with | some p => p.isAlpha || p.isDigit | none => false) then none
  else
    let tryKey (k : String) : Option (List Char × List Char) :=
      if isPrefix (String.toList k) cs then
        let after := cs.drop k.length
        let afterWs := after.dropWhile isWs
        match afterWs with
        | ':' :: tl =>
          let tl2 := tl.dropWhile isWs
          some (String.toList k ++ after.take (after.length - afterWs.length) ++ [':']
                  ++ tl.take (tl.length - tl2.length), tl2)
        | _ => none
      else none
    match tryKey "fill" with
    | some r => some r
    | none => match tryKey "stroke" with
              | some r => some r
              | none => tryKey "color"

/-- Rule 3: on `style`/`classDef`/`linkStyle` lines, expand `#rgb`/`#rgba` and map the listed names;
other names pass through. -/
def normalizeColorsLine (line : List Char) : List Char :=
  let head := trimWs line
  if !(isPrefix (String.toList "style ") head || isPrefix (String.toList "classDef ") head
       || isPrefix (String.toList "linkStyle ") head) then line
  else
    let rec go (fuel : Nat) (prev : Option Char) (cs : List Char) (acc : List Char) : List Char :=
      match fuel with
      | 0 => acc ++ cs
      | f + 1 =>
        match cs with
        | [] => acc
        | c :: tl =>
          match matchColorKey prev cs with
          | some (keyText, valueAndRest) =>
            let value := valueAndRest.takeWhile (fun x => x.isAlpha || x.isDigit || x == '#')
            match expandColorValue value with
            | some r => go f (value.getLast?) (valueAndRest.drop value.length) (acc ++ keyText ++ r)
            | none => go f (some c) tl (acc ++ [c])
          | none => go f (some c) tl (acc ++ [c])
    go (line.length + 1) none line []

/-- Rule 5: `id[/text/]` and `id[\text\]` → `id[text]`. -/
def expandParallelogramsLine (line : List Char) : List Char :=
  let rec go (fuel : Nat) (cs : List Char) (acc : List Char) : List Char :=
    match fuel with
    | 0 => acc ++ cs
    | f + 1 =>
      match cs with
      | [] => acc
      | '[' :: d :: tl =>
        if d == '/' || d == '\\' then
          let upToClose := tl.takeWhile (fun x => x != '[' && x != ']')
          let rest := tl.drop upToClose.length
          match rest with
          | ']' :: tl3 =>
            match upToClose.getLast? with
            | some e =>
              if e == '/' || e == '\\' then
                let inner := upToClose.dropLast
                if inner.contains '[' || inner.contains ']' then go f tl (acc ++ ['['])
                else go f tl3 (acc ++ ['['] ++ inner ++ [']'])
              else go f tl (acc ++ ['['])
            | none => go f tl (acc ++ ['['])
          | _ => go f tl (acc ++ ['['])
        else go f (cs.drop 1) (acc ++ ['['])
      | c :: tl => go f tl (acc ++ [c])
  go (line.length + 1) line []

/-- Rule 6: the length of a formatting tag at the start of `cs`, or `none`. Case-insensitive, with
optional attributes and an optional `/`, matching the source's regex. -/
def matchFormattingTag (cs : List Char) : Option Nat :=
  let lowerName (s : String) : List Char := (String.toList s)
  let ciPrefix (name : List Char) (s : List Char) : Bool :=
    (name.zip (s.take name.length)).all (fun p => p.1 == Char.toLower p.2) && name.length ≤ s.length
  let afterSlash (n : Nat) : List Char → Option Nat
    | s =>
      let rec tryNames : List String → Option Nat
        | [] => none
        | n' :: rest =>
          let name := lowerName n'
          if ciPrefix name s then
            let r1 := s.drop name.length
            let r2 := if (match r1 with | c :: _ => isWs c | [] => false)
                      then r1.dropWhile (fun c => c != '<' && c != '>') else r1
            let (ok, used) := match r2 with
              | '>' :: _ => (true, 0)
              | '/' :: '>' :: _ => (true, 1)
              | _ => (false, 0)
            if ok then some (n + name.length + (r1.length - r2.length) + used + 1) else tryNames rest
          else tryNames rest
      tryNames strippedFormattingTags
  match cs with
  | '<' :: tl =>
    match tl with
    | '/' :: tl2 => afterSlash 2 tl2
    | _ => afterSlash 1 tl
  | _ => none

/-- Rule 6: strip the inline formatting tags (open and close), keeping their content; `<br/>` is
left alone. -/
def stripFormattingTags (line : List Char) : List Char :=
  let rec go (fuel : Nat) (cs : List Char) (acc : List Char) : List Char :=
    match fuel with
    | 0 => acc ++ cs
    | f + 1 =>
      match cs with
      | [] => acc
      | c :: tl =>
        match matchFormattingTag cs with
        | some k => go f (cs.drop k) acc
        | none => go f tl (acc ++ [c])
  go (line.length + 1) line []

/-- One state diagram's folded description (C-06.1 rule 4). -/
structure StateDesc where
  id : String
  texts : List String
  indent : List Char
deriving DecidableEq, Repr

/-- Rule 4: in a stateDiagram, every `ID: text` line for an ID folds into one
`state "a<br/>b" as ID` alias inserted after the header. -/
def mergeStateDescriptions (lines : List String) : List String :=
  match (enumerate lines).find? (fun p => !(trimWs (String.toList p.2)).isEmpty) with
  | none => lines
  | some h =>
    if !isPrefix (String.toList "stateDiagram") (trimWs (String.toList h.2)) then lines
    else
      let rec go (fuel : Nat) (i : Nat) (descs : List StateDesc) (kept : List String)
          : List StateDesc × List String :=
        match fuel with
        | 0 => (descs, kept)
        | f + 1 =>
          match lines[i]? with
          | none => (descs, kept)
          | some line =>
            if i > h.1 then
              match splitAtChar ':' (String.toList line) with
              | some (idPart, _ :: textPart) =>
                let id := trimWs idPart
                let text := trimWs textPart
                if !id.isEmpty && id.all (fun c => c.isAlpha || c.isDigit || c == '_')
                   && (match id.head? with | some c => c.isAlpha || c == '_' | none => false) then
                  let indent := (String.toList line).takeWhile isWs
                  if (descs.find? (fun d => d.id == String.ofList id)).isSome then
                    go f (i + 1)
                      (descs.map (fun d => if d.id == String.ofList id
                                           then { d with texts := d.texts ++ [String.ofList text] }
                                           else d)) kept
                  else
                    go f (i + 1)
                      (descs ++ [{ id := String.ofList id, texts := [String.ofList text],
                                   indent := indent }]) kept
                else go f (i + 1) descs (kept ++ [line])
              | _ => go f (i + 1) descs (kept ++ [line])
            else go f (i + 1) descs (kept ++ [line])
      let (descs, kept) := go (lines.length + 1) 0 [] []
      if descs.isEmpty then lines
      else
        let aliases := descs.map (fun d =>
          String.ofList (d.indent ++ String.toList ("state \"" ++ String.intercalate "<br/>" d.texts
                                                    ++ "\" as " ++ d.id)))
        (kept.take (h.1 + 1)) ++ aliases ++ (kept.drop (h.1 + 1))

/-- C-06.1 rules 1…6 in this order. -/
def sanitize (source : List Char) : List Char :=
  let s1 := dropFrontMatter source
  let s2 := String.toList (String.intercalate "\n" ((splitOnNewline s1).map (fun l => String.ofList (renameXYSeriesLine (String.toList l)))))
  let s3 := String.toList (String.intercalate "\n" ((splitOnNewline s2).map (fun l => String.ofList (normalizeColorsLine (String.toList l)))))
  let s4 := String.toList (String.intercalate "\n" (mergeStateDescriptions (splitOnNewline s3)))
  let s5 := String.toList (String.intercalate "\n" ((splitOnNewline s4).map (fun l => String.ofList (expandParallelogramsLine (String.toList l)))))
  String.toList (String.intercalate "\n" ((splitOnNewline s5).map (fun l => String.ofList (stripFormattingTags (String.toList l)))))

/-- E-02, D-04: the diagram type the library lacks (the sanitised source's first word). -/
def unsupportedType (source : List Char) : Bool :=
  let firstWordOf := (splitOnNewline (sanitize source)).map (fun l => trimWs (String.toList l))
    |>.find? (fun l => !l.isEmpty && !isPrefix (String.toList "%%") l)
  match firstWordOf with
  | none => false
  | some l =>
    let w := String.ofList ((l.takeWhile (fun c => !isWs c && c != '-' && c != ':')).map Char.toLower)
    unsupportedDiagramTypes.contains w

/-! ## C-06.2/C-06.3 — repairs, sizes and the document theme -/

/-- E-01, C-06.2: a node listed in several subgraphs belongs to the **last** one (pure form, on id
lists in declaration order). -/
def normalizeOwnership (nodeIds : List (List String)) : List (List String) :=
  let lastOwner (id : String) : Nat :=
    ((enumerate nodeIds).filter (fun p => p.2.contains id)).foldl (fun _ p => p.1) 0
  (enumerate nodeIds).map (fun p => p.2.filter (fun id =>
    match (enumerate nodeIds).find? (fun q => q.2.contains id) with
    | some _ => lastOwner id == p.1
    | none => true))

/-- C-06.2: `<br>` → newline in notes, → space in actor labels. -/
def splitBr (s : List Char) : List (List Char) :=
  (splitOnNewline (String.toList (String.intercalate "\n" ((splitOnNewline s).map (fun l =>
    String.ofList (String.toList l))))))
    |>.map (fun l => trimWs (String.toList l))

/-- C-06.2: an `n`-line message row is grown by `(n−1)×13 + 4` pt. -/
def rowGrowth (n : Int) : Int := (n - 1) * sequenceLabelPitchPt + sequenceRowGrowthBasePt

/-- C-06.2: the piecewise-linear x remap outside the actor range — `x ≤ first` shifts by the head
delta; `x ≥ last` by the tail delta. -/
def remapEndpoint (old new : List Int) (x : Int) : Option Int :=
  match old, new with
  | [], _ => none
  | _, [] => none
  | [o], [n] => if x ≤ o then some (x + (n - o)) else some x
  | o :: _, n :: _ =>
    let lastO := old.getLast!
    let lastN := new.getLast!
    if x ≤ o then some (x + (n - o))
    else if x ≥ lastO then some (x + (lastN - lastO))
    else none

/-- I-005, R-11: the display size — whole points, never wider than natural, at least 1 pt. -/
def displaySize (naturalW naturalH width : Int) : Int × Int :=
  let w := max 1 (min width naturalW)
  let h := max 1 (naturalH * w / naturalW)
  (w, h)

/-- R-11, K-07: `⌊min(natural, max(w_col − 36, 1))⌋` — whole points, bounded below by 1 pt. -/
def mermaidRasterWidth (natural column : Int) : Int :=
  min natural (max (column - mermaidInsetPt) rasterMinWidthPt)

/-- C-06.3: a mix in hundredths — `a` toward `b` by `t` percent (the byte rounding is the
renderer's). -/
def mixPercent (a b t : Int) : Int := a * (100 - t) + b * t

/-- C-06.3: the *Document* theme's node-surface mix percentage for a theme. -/
def documentSurfacePercent (isDark : Bool) : Int :=
  if isDark then documentSurfaceDarkPercent else documentSurfaceLightPercent

/-! ## C-04 — `Preferences` -/

/-- C-04: the twelve preference keys and their defaults (from `Spec.preferenceKeys`). -/
def preferenceKeyList : List String := preferenceKeys.map (·.1)

/-- C-04, K-04: the inspector width, clamped to `[180, 520]`. -/
def clampWidth (w : Int) : Int := min (max w inspectorWidthMinPt) inspectorWidthMaxPt

/-- K-04: the bookmarks pane height, clamped at use to at least 120 pt. -/
def clampHeight (h : Int) : Int := max h bookmarksMinHeightPt

/-- C-04, R-30: `mdv6_font_scale` is clamped on read; an absent value is the default 1.0. -/
def readScale (v : Option Int) : Int :=
  match v with
  | none => zoomDefaultHundredths
  | some s => min (max s zoomMinHundredths) zoomMaxHundredths

/-- C-04: an unknown `mdv6.mermaid.style` reads as `document`. -/
def mermaidStyleOrDefault (s : String) : String :=
  if mermaidStyleIds.contains s then s else mermaidStyleDefaultId

/-! ## K-04, R-30 — `ZoomStep` -/

/-- R-30: `roundHalfAway(10s)/10` for `s` in hundredths — the result in tenths. -/
def roundHalfAwayTenths (n : Int) : Int :=
  if n ≥ 0 then (n + 5) / 10 else -(((-n) + 5) / 10)

/-- R-30: `s' = clamp(roundHalfAway(10s)/10 + d, 0.60, 2.50)`, in hundredths. -/
def zoomApply (stored delta : Int) : Int :=
  min (max (roundHalfAwayTenths stored * 10 + delta) zoomMinHundredths) zoomMaxHundredths

/-- R-30: the HUD shows `⌊100 s' + 0.5⌋ %` — for `s'` in hundredths this is exactly the hundredths
count. -/
def zoomHudPercent (s : Int) : Int := s

/-! ## K-14 — `ContentLimits` -/

/-- K-14's seven ceilings. -/
inductive CeilingKind where
  | document | mermaid | latex | encodedImage | decodedImageBytes | decodedImagePixels | imageAxis
deriving DecidableEq, Repr

/-- K-14: the ceiling for each measured quantity, in binary units. -/
def ceiling : CeilingKind → Int
  | .document => ceilingDocumentBytes
  | .mermaid => ceilingMermaidBytes
  | .latex => ceilingLatexBytes
  | .encodedImage => ceilingEncodedImageBytes
  | .decodedImageBytes => ceilingDecodedImageBytes
  | .decodedImagePixels => ceilingDecodedImagePixels
  | .imageAxis => ceilingImageAxisPixels

/-- K-14: content **at** the ceiling is admitted; content above it follows E-28. -/
def admits (measure : Int) (k : CeilingKind) : Bool := measure ≤ ceiling k

/-- K-14 for a decoded image: both axes, the pixel count and the decoded byte count. -/
def admitsImage (w h bytesPerPixel : Int) : Bool :=
  w ≥ 0 && h ≥ 0 && w ≤ ceilingImageAxisPixels && h ≤ ceilingImageAxisPixels
    && w * h ≤ ceilingDecodedImagePixels
    && w * h * max bytesPerPixel 1 ≤ ceilingDecodedImageBytes

/-! ## §7.2, K-13 — `ColumnWidth` -/

/-- §7.2: `w_col = min(w_area − w_side − w_insp, w_max) − 2p − 2b`, where a shown pane's width
includes its handle (pass 0 for a hidden pane) and `none` means no cap. -/
def columnWidth (area sidebar inspector : Int) (maxWidth : Option Int) (p : Int) : Int :=
  let side := if sidebar > 0 then sidebar + paneHandlePt else 0
  let insp := if inspector > 0 then inspector + paneHandlePt else 0
  let available := area - side - insp
  let capped := match maxWidth with | some m => min available m | none => available
  capped - 2 * p - 2 * blockPaddingPt

/-- R-11, K-07: `⌊min(natural, max(w_col − 36, 1))⌋` — whole points, at least 1 pt. -/
def columnRasterWidth (natural column : Int) : Int :=
  min natural (max (column - mermaidInsetPt) rasterMinWidthPt)

/-! ## §7.1 and C-17 — `RenderMetrics` -/

/-- §7.1: `ink(P) = (1/|D|) Σ_{p∈D} (255 − g(p))` for the luminance list `luma`. -/
def inkSum (luma : List Int) : Int :=
  (luma.filter (fun g => g < inkThresholdLuma)).foldl (fun a g => a + (255 - g)) 0

/-- §7.1: `|D|`, the inked pixel count. -/
def inkedCount (luma : List Int) : Int := (luma.filter (fun g => g < inkThresholdLuma)).length

/-- §7.1, I-009: `ink(node) ≥ 0.9 · ink(doc)`, as an exact integer comparison; an empty `D` on
either side is a failure. -/
def inkWeightHolds (nodeSum nodeCount docSum docCount : Int) : Bool :=
  nodeCount > 0 && docCount > 0 && 10 * nodeSum * docCount ≥ 9 * docSum * nodeCount

/-- C-17: the mismatch fraction `q = |D| / N` as an exact pair. -/
def pixelMismatch (d n : Int) : Int × Int := (d, n)

/-- C-17: the comparison passes when `q ≤ 0.001`, i.e. `1000·|D| ≤ N`; `N = 0` is a failure. -/
def pixelPass (d n : Int) : Bool := n > 0 && 1000 * d ≤ n

/-- K-16, I-014: the inter-block ink gap `g` lies in the band `v ≤ g ≤ v + 0.6 f`, exactly, in
tenths. -/
def rhythmBandHolds (v f g : Int) : Bool := 10 * v ≤ 10 * g && 10 * g ≤ 10 * v + 6 * f

/-- K-16, T-46: the signed distance between the ink box's centre and the column's centre. -/
def centreOffset (boxMid width : Int) : Int := boxMid - width / 2

/-! ## C-09, R-29 — `ThemeCatalog` -/

/-- R-29: `system` → `high-contrast` in Light, `twilight` in Dark; C-04: an unknown id resolves to
`high-contrast`. -/
def themeResolve (id : String) (isDarkAppearance : Bool) : String :=
  if id == systemThemeId then (if isDarkAppearance then systemDarkThemeId else systemLightThemeId)
  else if themeIds.contains id then id
  else unknownThemeFallbackId

/-! ## C-17 — `HarnessCases` -/

/-- C-17: the discovery order — the UTF-8 bytes of the relative path, then the fence index. -/
def bytesLt : List Nat → List Nat → Bool
  | [], [] => false
  | [], _ => true
  | _, [] => false
  | x :: xs, y :: ys => if x = y then bytesLt xs ys else x < y

/-- C-17: the scan key comparison. -/
def scanKeyLt (a b : List Nat × Nat) : Bool :=
  if a.1 = b.1 then a.2 < b.2 else bytesLt a.1 b.1

/-- Insertion sort by the C-17 key (a stand-in for `Array.sorted`; the model only needs the order). -/
def insertKey (k : List Nat × Nat) : List (List Nat × Nat) → List (List Nat × Nat)
  | [] => [k]
  | x :: tl => if scanKeyLt k x then k :: x :: tl else x :: insertKey k tl

/-- C-17: the cases in the pinned order. -/
def scanSort : List (List Nat × Nat) → List (List Nat × Nat)
  | [] => []
  | k :: tl => insertKey k (scanSort tl)

/-- C-17: the harness exit for an invocation. -/
def harnessExit (usage ok : Bool) : Int :=
  if usage then harnessExitUsage else if ok then harnessExitOk else harnessExitFailure

/-! ## R-33, §5.2 — `bin/mdv6`'s exit map -/

/-- §5.2's invocations, as the exit map's input. -/
inductive CliInvocation where
  | noArgs | filesAllExist | fileMissing | stdin | help | version | bundleMissing
deriving DecidableEq, Repr

/-- R-33, §5.2: the exit map — 0 except a missing argument or a bundle that cannot be located. -/
def cliExit : CliInvocation → Int
  | .noArgs => cliExitOk
  | .filesAllExist => cliExitOk
  | .fileMissing => cliExitError
  | .stdin => cliExitOk
  | .help => cliExitOk
  | .version => cliExitOk
  | .bundleMissing => cliExitError

/-! ## R-35 — `Diagnostics` -/

/-- R-35: the closed event set — the only diagnostics the application emits. -/
inductive DiagnosticEvent where
  | storeFailure (detail : String)
  | fontRegistrationFailure (detail : String)
  | editorLaunchFailure (detail : String)

/-- R-35: the line shape of each event; every line is prefixed `[mdv6]`. -/
def logLine : DiagnosticEvent → String
  | .storeFailure d => "[mdv6] persistence store failure: " ++ d
  | .fontRegistrationFailure d => "[mdv6] font registration failed: " ++ d
  | .editorLaunchFailure d => "[mdv6] external editor launch failed: " ++ d

/-! ## C-15, R-20, I-013 — `HistoryManager` -/

/-- C-15: a value that fails to decode yields an empty history. -/
def decodeFails : List String := []

/-- R-20, I-013: the adding route — the row moves to (or is inserted at) the top, then the oldest
rows past the cap are evicted. -/
def historyAdd (entries : List String) (path : String) : List String :=
  (path :: entries.filter (fun p => p != path)).take historyCap.toNat

/-- R-20: swipe-delete removes the row. -/
def historyRemove (entries : List String) (path : String) : List String :=
  entries.filter (fun p => p != path)

/-! ## R-27 — `BookmarkTitle` -/

/-- R-27, K-06: the title rule — the nearest TOC heading within the 40-block look-back, else the
block's first line stripped and truncated to 60 units, else `(line n)`, else `(empty)`. -/
def bookmarkTitle (blocks : List String) (toc : List TOCHeading) (index : Nat) : List Char :=
  if blocks.isEmpty then String.toList "(empty)"
  else
    let i := min index (blocks.length - 1)
    let lowest := i - min i bookmarkLookBackBlocks.toNat
    let heading := (toc.filter (fun h => h.blockIndex ≤ i && h.blockIndex ≥ lowest)).foldl
      (fun acc h => match acc with
        | none => some h
        | some a => if h.blockIndex > a.blockIndex then some h else some a) none
    match heading with
    | some h => h.text
    | none =>
      match blocks[i]? with
      | none => String.toList "(empty)"
      | some blk =>
        let fl := trimWs (stripInlineMarkdown (firstLineOf (String.toList blk)))
        if fl.isEmpty then String.toList ("(line " ++ toString (i + 1) ++ ")")
        else fl.take bookmarkTitleClusters.toNat

/-! ## R-24, E-17 — `FindHighlight` -/

/-- Flatten a list of lists. -/
def flatten {α : Type} : List (List α) → List α
  | [] => []
  | l :: tl => l ++ flatten tl

/-- The suffix after the first occurrence of `q` in `s`. -/
def findSub (q : List Char) : List Char → Option (List Char)
  | [] => if q.isEmpty then some [] else none
  | s@(_ :: tl) => if isPrefix q s then some (s.drop q.length) else findSub q tl

/-- R-24: non-overlapping, case-insensitive occurrences, counted from the end of the previous one;
an empty query has none. -/
def countOccurrences (query block : List Char) : Nat :=
  if query.isEmpty then 0
  else
    let rec go (fuel : Nat) (s : List Char) (c : Nat) : Nat :=
      match fuel with
      | 0 => c
      | f + 1 => match findSub (query.map Char.toLower) s with
                 | none => c
                 | some rest => go f rest (c + 1)
    go (block.length + 1) (block.map Char.toLower) 0

/-- R-24: every occurrence over every block, in document order, as (block index, occurrence). -/
def findMatches (query : List Char) (blocks : List String) : List (Nat × Nat) :=
  flatten ((enumerate blocks).map (fun p =>
    (List.range (countOccurrences query (String.toList p.2))).map (fun k => (p.1, k))))

/-- R-24: the bar's label — "$n$ of $m$" or "No matches". -/
def findLabel (current count : Nat) : String :=
  if count == 0 then "No matches" else toString (current + 1) ++ " of " ++ toString count

/-- E-17: a code fence, a `$$` math fence, a GFM table, or any block containing `![` is tinted as a
whole; every other block is inline-highlighted. -/
def shouldInlineHighlight (block : List Char) : Bool :=
  !(isFence block) && !(isMathFence block) && !(isGFMTable block)
    && !(containsSub (String.toList "![") block)

/-- R-24's line-level rewrite: leading `#`, `>` and ordered-list markers stripped, `-`/`*`/`+`
bullets shown as `•`. -/
def inlineTextLine (line : List Char) : List Char :=
  let indent := line.takeWhile isSp
  let s := line.dropWhile isSp
  let s1 := if s.head? == some '#' then (s.dropWhile (· == '#')).dropWhile (· == ' ') else s
  let rec stripQuotes (fuel : Nat) (s : List Char) : List Char :=
    match fuel with
    | 0 => s
    | f + 1 => if s.head? == some '>' then stripQuotes f ((s.drop 1).dropWhile (· == ' ')) else s
  let s2 := stripQuotes (s1.length + 1) s1
  let s3 := match (enumerate s2).find? (fun p => !p.2.isDigit) with
    | some p =>
      if p.1 > 0 && (p.2 == '.' || p.2 == ')')
         && (match s2[p.1 + 1]? with | some c => c == ' ' | none => false)
      then s2.drop (p.1 + 2) else s2
    | none => s2
  let s4 := if isPrefix (String.toList "- ") s3 || isPrefix (String.toList "* ") s3
               || isPrefix (String.toList "+ ") s3
            then String.toList "• " ++ s3.drop 2 else s3
  indent ++ s4

/-- R-24: the block re-rendered as inline text. -/
def inlineText (block : List Char) : List Char :=
  String.toList (String.intercalate "\n"
    ((splitOnNewline block).map (fun l => String.ofList (inlineTextLine (String.toList l)))))

/-! ## C-02 rule 7 — `parseTOC` and the whole document -/

/-- C-02 rule 7: `#`/`##`/`###` single-line ATX headings outside fences, first line only; `text` and
`slugText` come from the heading body. -/
def parseTOC (blocks : List String) : List TOCHeading :=
  (enumerate blocks).filterMap (fun p =>
    let block := String.toList p.2
    if isFence block then none
    else
      let trimmed := trimWs block
      match atxLevel trimmed with
      | none => none
      | some level =>
        let body := (firstLineOf trimmed).drop (level + 1)
        let stripped := stripInlineMarkdown body
        some { level := level, text := plainText stripped, slugText := stripped, blockIndex := p.1 })

/-- **I-001** — the whole `ParsedDocument` as one total, pure function: it takes the raw text and
nothing else (no environment, clock, theme or network), so the same bytes always give the same
blocks, line map, count and TOC. The typing is the proof. -/
def parseDocument (raw : List Char) : SplitResult × List TOCHeading :=
  let sr := splitLines (sourceLines raw)
  (sr, parseTOC sr.blocks)

end Mdv6.Model
