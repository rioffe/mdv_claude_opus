/-
Mdv6Spec.Mdv6.Model
===================

The **transcription**: `SPEC.md` v0.13's normative tables as a pure, total Lean
function. This file is leg A of the trust boundary, stated honestly here.

## Leg A — the correspondence table (manual, not proven)

Lean cannot read a document. The model below is a row-by-row transcription of the
spec's tables; the join between the two is the table in this comment, and it is
*checkable* (not proven) by the row theorems in `Theorems.lean`.

| spec anchor | model element |
| --- | --- |
| §5.2 CLI invocation table (R-33) | `Input.cliInvocation`, `cliOutcome`; row theorems `cli_noArgs` … `cli_bundle_missing` |
| §5.2 bundle search order | `Spec.bundleSearchOrder` (data); precedence by the `bundleFound` field, not a modelled search |
| §3.1 document lifecycle table + Figure 3.1 | `DocState`, `LifeEvent`, `lifecycle` |
| §3.1 `CLOSED` terminal | `closedIsTerminal` — the spec's own word; the pin `lifePinned` |
| C-02 rules 1–8 (R-04, I-004) | `splitRaw`, `feedLine`, `flushBlock`, `SplitState` |
| C-02 rule 6 | `normalizeEndings`, `splitLines`, `lineCountOf` |
| C-02 rule 7 | `headingOf`, `tocOf`; `TocHeading.text` is `Option` (C-07.3 deferred) |
| C-02 rule 8 / C-19.3 / E-31 | `resolveLine` |
| E-23 fence edge cases | `opensFence`, `opensMathFence`, `closesMathFence` |
| R-19 resolution + classification | `Destination`, `linkDecision` |
| R-19 / C-19.1 fragment kinds | `fragmentOf`, `citationParse` |
| C-19.2 range normalisation | `citationStart` |
| C-19.4 no snapshot, no TOC row | `navPush` with `NavEvent.lineCitationJump` |
| C-19.5 non-Markdown targets | the *excluded* table in `Theorems.lean` |
| C-11 slug (I-010, D-17) | `slug`, `slugCore` |
| C-12 section range | `sectionRangeOf` |
| C-12 `stripInlineMarkdown` | `stripInlineMd`, `dropBracketLinks` (the rule order is unpinned — F-141) |
| C-10 smart typography (R-17, I-012) | `smarten`, `segments`, `rewriteRun` |
| C-10 removals | `dropPair`, `dropAll`, `dropUnescaped`, `dropEmphUnderscore`, `stripTrailingHashes` |
| R-24 GFM-table definition; E-17 tint set | `isGfmTableBlock`, `isFenceBlock`, `isMathFenceBlock`, `findTintsWholeBlock` |
| C-08 normalisation (K-09) | `normalizeFingerprint`; the 80-cluster truncation is deferred (`truncateClusters`) |
| C-08 resolve + E-08 | `resolveAnchor`, `scrollRestores` |
| C-03 query construction (K-09) | `ftsQuery`, `ftsPerformsSearch`, `stripFtsChars` |
| C-03 snippet/ordering | `Spec.ftsSnippet*`, `Spec.ftsOrderKeys` (data only; the SQL itself is not modelled — no SQL in Lean) |
| C-05 language resolution | `resolveLanguage`; the alias tables are `Spec.directFenceWords`/`Spec.fenceAliases` |
| R-08 prompt-aware set | `isPromptAware` |
| C-06.1 rules 1, 2, 4, 5, 6 | `dropFrontMatter`, `dropSeriesName`, `mergeStateDescriptions`, `normalizeParallelograms`, `stripTags` |
| C-06.1 rule 3 hex expansion | `expandShortHex`; the **name→hex** map is unpinned by the spec (F-139) → `namedColorHex = none` |
| C-06.2 layout repairs | **not modelled**: ELK/sequence geometry has no enumerable input space reachable in Lean; carried by T-17/T-19/T-20 |
| C-07.1 acceptance (Pandoc `tex_math_dollars`) | `validInlineSpan`, `validDisplaySpan` |
| C-07.1 placement | `ownParagraphSpan` |
| C-07.2 unit (b) rewrites | `mathRewrite` |
| C-07.2 unit (a) registered symbols | `Spec.registeredSymbols` (data only; registration is SwiftMath's) |
| C-07.3 plain text | **deferred** (Unicode tables; carried by T-08) |
| R-30 zoom (K-04, D-37) | `zoomStep`, `zoomPercent`, `clampFontScale` |
| C-04 defaults and fallbacks (T-42) | `prefTheme`, `prefBoolFallback`, `clampInspectorWidth`, `clampBookmarksHeight` |
| §7.2 column width (K-13) | `columnWidth` |
| R-11 / K-07 raster width | `rasterWidth` |
| R-27 bookmark title (K-06) | `bookmarkTitle`, `nearestHeading` |
| R-01 routes | `Route`, `routeKind`, `routeReorders`, `openEventHistory` |
| R-02 directory scan (E-04) | `dirPick` |
| R-03 drop acceptance | `acceptDrop` |
| R-18 snapshot policy | `NavEvent`, `navPush`, `navClearsForward`, `navInApp`, `routeName` |
| R-20 / I-013 / K-03 | `historyInsert` |
| C-15 decode failure | `historyDecodeFails`, `historyDecodeOk` |
| K-14 ceilings + E-28 | `ceilingOf`, `ceilingAdmits` |
| C-16 policy + E-11 | `RemoteEvent`, `remoteAdmits` |
| C-17 exits and pixel metric | `harnessExit`, `pixelPasses` |
| §7.1 ink metric (I-009) | `inkPasses` |
| E-02 fallback | `mermaidRenders` |
| E-09 / E-27 | `navigationAttempt` |

Two deliberate modeling limits, stated so they cannot be mistaken for fidelity:

* the `]` of a `](url)` link part is left unprotected by `segments` — every C-10
  rewrite rule leaves `]` unchanged, so I-012's guarantee holds in substance for
  the `(`…`)` run that carries the URL;
* `dirPick` compares case-insensitively with `String.toLower` rather than ICU's
  localised comparison; the spec's "case-insensitive localized comparison of the
  filename" is deferred with C-07.3's Unicode work.

Not modelled at all, with the reason — nothing in this model's input space reaches
them: the SwiftUI surface (§5.1, C-18, K-16, I-015), the render pipeline's view
tree (§3.2, I-005, I-014), the persistence layer's SQL and transactions (§3.3,
I-006, I-007), FSEvents timing (R-05), the network stack as mechanism (C-16's
session, cookies, timeouts), the build and release pipeline (§5.3, C-13, K-01,
K-02, K-11, K-12), the CLI's bundle *search* (R-33's order), and the third-party
renderers below their contracts. Each is carried by a §9 test in the deferral
table of `Theorems.lean`.

## The devices

* `Input` — one constructor per group of spec rows; a row stated for "any" input
  carries that input as a field, never a family of constructors.
* `Result` — the observable cells the spec names.
* `outcome : Input → Option Result` — `none` means **the spec states no outcome for
  this input**. Never an invented outcome.
* the pins — `Prop`s stating what the spec permits where a cell is partial.
-/
import Mdv6Spec.Mdv6.Spec

namespace Mdv6Spec.Mdv6.Model

open Mdv6Spec.Mdv6.Spec

/-! ## 0. String helpers -/

/-- `isWs c` — the spec's "whitespace scalar". -/
def isWs (c : Char) : Bool := c.isWhitespace

/-- Trim whitespace from both ends (over `List Char`, avoiding `String.Slice`). -/
def trimWs (s : String) : String :=
  String.ofList ((s.toList.dropWhile isWs).reverse.dropWhile isWs).reverse

/-- C-02 rule 5's "leading/trailing newlines of a block are trimmed" — newlines
only, so an indented code block keeps its indentation. -/
def trimNl (s : String) : String :=
  String.ofList ((s.toList.dropWhile (fun c => c == '\n')).reverse.dropWhile (fun c => c == '\n')).reverse

/-- Trim whitespace from the left. -/
def trimLeftWs (s : String) : String := String.ofList (s.toList.dropWhile isWs)

/-- C-02 rule 6: `\r\n` and lone `\r` are treated as `\n`. -/
def normalizeEndings (s : String) : String := (s.replace "\r\n" "\n").replace "\r" "\n"

/-- Every line of `s`, after rule 6 normalisation. -/
def splitLines (s : String) : List String := (normalizeEndings s).splitOn "\n"

/-- C-02 rule 8's `lineCount`: a trailing `\n` does not create a final empty line. -/
def lineCountOf (s : String) : Nat :=
  let ls := splitLines s
  match ls.reverse with
  | "" :: rest => rest.length
  | _ => ls.length

/-- `splitWs s` — split at whitespace scalars, dropping empty pieces. -/
def splitWs (s : String) : List String :=
  let rec go : List Char → String → List String → List String
    | [], cur, acc => (if cur.isEmpty then acc else cur :: acc).reverse
    | c :: cs, cur, acc =>
        if isWs c then (if cur.isEmpty then go cs "" acc else go cs "" (cur :: acc))
        else go cs (String.push cur c) acc
  go s.toList "" []

/-- `firstWord s` — C-05's "keep its first word" of a fence info string. -/
def firstWord (s : String) : String := (splitWs s).head?.getD ""

/-- `hasSub s sub` — `sub` occurs in `s`. -/
def hasSub (s : String) (sub : String) : Bool :=
  let t := sub.toList
  let rec go : List Char → Bool
    | [] => t.isEmpty
    | c :: cs => if t.isPrefixOf (c :: cs) then true else go cs
  go s.toList

/-- `prefixOf pre s` — `pre` is a prefix of `s`. -/
def prefixOf (pre s : String) : Bool := pre.toList.isPrefixOf s.toList

/-- `startsWithS pre s` — `pre` is a prefix of `s`. -/
def startsWithS (pre s : String) : Bool := pre.toList.isPrefixOf s.toList

/-- `endsWithS suf s` — `suf` is a suffix of `s`. -/
def endsWithS (suf s : String) : Bool := suf.toList.reverse.isPrefixOf s.toList.reverse

/-- C-02 rule 1: a blank line (only whitespace) ends the current block. -/
def isBlank (l : String) : Bool := trimWs l = ""

/-- Whether the character before an `_` is a letter or digit (word-internal
underscore). -/
def prevIsWordChar (prev : Option Char) : Bool :=
  match prev with
  | some p => p.isAlphanum
  | none => false

/-- C-12 rule 3 (v0.13.1): drop both underscores of an `_…_` pair whose opening `_`
is not preceded by a letter or digit; keep word-internal underscores; a `__` run is
left to rule 4's scan, which owns it. -/
def dropEmphUnderscore (cs : List Char) : List Char :=
  let rec go : List Char → Option Char → Bool → List Char
    | [], _, _ => []
    | '_' :: '_' :: rest, _, isOpen => go rest (some '_') isOpen
    | c :: rest, prev, isOpen =>
        if c == '_' then
          if isOpen then go rest (some c) false
          else if prevIsWordChar prev then c :: go rest (some c) false
          else go rest (some c) true
        else c :: go rest (some c) isOpen
  go cs none false

/-- C-12 rule 4 (v0.13.1): the left-to-right scan that drops the `**` pairs, every
backtick, every `_` of a `__` pair, and every unescaped `*`, keeping the escaped
character alone when it follows a backslash. -/
def scanStrip : List Char → List Char
  | [] => []
  | '\\' :: c :: cs =>
      if escapableChars.contains c then c :: scanStrip cs else '\\' :: c :: scanStrip cs
  | '*' :: cs => scanStrip cs
  | '`' :: cs => scanStrip cs
  | '_' :: '_' :: cs => scanStrip cs
  | c :: cs => c :: scanStrip cs

/-- C-12 rule 1 (v0.13.1): trailing `#`s are dropped and the surrounding whitespace is
trimmed. -/
def stripTrailingHashes (s : String) : String :=
  trimWs (String.ofList (s.toList.reverse.dropWhile (fun c => c == '#' || c == ' ')).reverse)

/-- `natOfDigits cs` — the value of a digit string (0 when empty). -/
def natOfDigits (cs : List Char) : Nat := cs.foldl (fun n c => n * 10 + (c.toNat - 48)) 0

/-- The segmentation scan's state. `mode`: 0 normal, 1 in code span, 2 in URL,
3 in angle span, 4 in a pending backtick run, 5 just after `]`. -/
structure SegState where
  mode : Nat
  run : Nat
  depth : Nat
  cur : List Char
  curB : Bool
  acc : List (Bool × String)
  deriving Repr

/-- Flush the current segment, starting a new one whose protection flag is `b`. -/
def segFlushTo (st : SegState) (b : Bool) : SegState :=
  if st.cur.isEmpty then { st with curB := b }
  else { st with cur := [], curB := b, acc := (st.curB, String.ofList st.cur.reverse) :: st.acc }

/-- Push a character into the current segment. -/
def segPush (st : SegState) (c : Char) : SegState := { st with cur := c :: st.cur }

/-- Scan the argument `c` as in normal mode; never recurses. -/
def segStep0 (st : SegState) (c : Char) : SegState :=
  if c == '`' then segPush (segFlushTo st true) c |> fun s => { s with mode := 4, run := 1 }
  else if c == ']' then segPush (segFlushTo st false) c |> fun s => { s with mode := 5 }
  else if c == '<' then segPush (segFlushTo st true) c |> fun s => { s with mode := 3 }
  else segPush st c

/-- One character into the segmentation scan (C-10's protected runs). -/
def segStep (st : SegState) (c : Char) : SegState :=
  match st.mode with
  | 0 => segStep0 st c
  | 1 =>
      if c == '`' then segPush st c |> fun s => { s with run := s.run + 1 }
      else if st.run == st.depth then segStep0 { segFlushTo st false with run := 0 } c
      else segPush { st with run := 0 } c
  | 2 =>
      if c == '(' then segPush st c |> fun s => { s with depth := s.depth + 1 }
      else if c == ')' then
        (if st.depth ≤ 1 then segFlushTo (segPush st c) false
         else segPush st c |> fun s => { s with depth := s.depth - 1 })
      else segPush st c
  | 3 => if c == '>' then segFlushTo (segPush st c) false else segPush st c
  | 4 =>
      if c == '`' then segPush st c |> fun s => { s with run := s.run + 1 }
      else segPush { st with mode := 1, depth := st.run, run := 0 } c
  | 5 => if c == '(' then segPush (segFlushTo st true) c |> fun s => { s with mode := 2, depth := 1 }
         else segStep0 { segFlushTo st false with mode := 0 } c
  | _ => segPush st c

/-- C-10's segmentation of a block into protected and unprotected runs. -/
def segments (block : String) : List (Bool × String) :=
  let st := block.toList.foldl segStep ⟨0, 0, 0, [], false, []⟩
  (((st.curB, String.ofList st.cur.reverse) :: st.acc).reverse).filter (fun p => !p.2.isEmpty)

/-- The folding state of C-10's literal rewrites: the emitted characters
(reversed), a pending run of dashes or dots with the character *before* it, and the
source character immediately preceding the current one. -/
structure RewState where
  out : List Char
  pendingChar : Char
  pending : Nat
  before : Option Char      -- the *source* character before the current run
  prevSrc : Option Char     -- the source character immediately before the current one
  prevOut : Option Char     -- the last character emitted
  deriving Repr

/-- Whether a list's head is a letter or digit (C-10's `--` between letters or
digits). -/
def headIsAlnum : List Char → Bool
  | [] => false
  | d :: _ => d.isAlphanum

/-- Whether the preceding character is absent or whitespace. -/
def optIsWs : Option Char → Bool
  | none => true
  | some c => isWs c

/-- C-10 (v0.13.1): a quote opens when the preceding **emitted** character is absent,
whitespace, or one of `Spec.quoteOpeners` (F-144). -/
def quoteOpens : Option Char → Bool
  | none => true
  | some c => isWs c || quoteOpeners.contains c

/-- The last character of a list, or a fallback when it is empty. -/
def lastOf (l : List Char) (d : Option Char) : Option Char :=
  match l.reverse with
  | [] => d
  | c :: _ => some c

/-- Whether an optional character is a letter or digit. -/
def optIsAlnum : Option Char → Bool
  | some c => c.isAlphanum
  | none => false

/-- C-10's resolution of a run of `n` identical `-` or `.` characters, given the
source character before the run and the character that ends it (`none` at the end of
a run of text).

* a run of three or more dashes is an em dash;
* a run of exactly two dashes is an en dash when both neighbours are letters or
  digits, an em dash when both neighbours are spaces (the spec's ` -- ` rule, whose
  spaces are already in the output), and is otherwise left verbatim — so CLI flags
  survive;
* a run of exactly three or more dots is an ellipsis, longer runs keeping their
  extra dots. -/
def resolveRun (c : Char) (n : Nat) (before after : Option Char) : List Char :=
  if n == 0 then []
  else if c == '-' then
    (if 3 ≤ n then ['—']
     else if n == 2 then
       (if optIsAlnum before && optIsAlnum after then ['–']
        else if before = some ' ' && after = some ' ' then ['—']
        else ['-', '-'])
     else ['-'])
  else
    (if 3 ≤ n then '…' :: List.replicate (n - 3) '.' else List.replicate n '.')

/-- One character into C-10's literal rewrites. -/
def rewStep (st : RewState) (c : Char) : RewState :=
  if c == '-' || c == '.' then
    (if 0 < st.pending && st.pendingChar == c then
      { st with pending := st.pending + 1, prevSrc := some c }
     else
      { st with
        out := resolveRun st.pendingChar st.pending st.before st.prevSrc ++ st.out
        pendingChar := c
        pending := 1
        before := st.prevSrc
        prevSrc := some c })
  else
    let flushed := resolveRun st.pendingChar st.pending st.before (some c)
    let prevNow := lastOf flushed st.prevOut
    let emitted :=
      if c == '"' then (if quoteOpens prevNow then ['“'] else ['”'])
      else if c == '\'' then (if quoteOpens prevNow then ['‘'] else ['’'])
      else [c]
    { st with
      out := emitted ++ flushed ++ st.out
      pending := 0
      pendingChar := '-'
      prevSrc := some c
      prevOut := lastOf emitted st.prevOut }

/-- C-10's literal rewrites for one unprotected run: `---` → em dash, ` -- ` →
spaced em dash, letter/digit-adjacent `--` → en dash, `...` → ellipsis, and
directional quotes chosen from the preceding character. -/
def rewriteRun (cs : List Char) : List Char :=
  let st := cs.foldl rewStep ⟨[], '-', 0, none, none, none⟩
  (resolveRun st.pendingChar st.pending st.before none ++ st.out).reverse

/-- C-12: `[text](url)` → `text`. The scanner's state: 0 normal, 1 in `[`, 2 after
`]`, 3 in the URL. -/
structure LinkState where
  mode : Nat
  depth : Nat
  hold : List Char
  out : List Char
  deriving Repr

/-- One character into C-12's bracket-link reduction. -/
def linkStep (st : LinkState) (c : Char) : LinkState :=
  match st.mode with
  | 0 => if c == '[' then { st with mode := 1, hold := [] } else { st with out := c :: st.out }
  | 1 => if c == ']' then { st with mode := 2 } else { st with hold := c :: st.hold }
  | 2 =>
      if c == '(' then { st with mode := 3, depth := 1 }
      else { st with mode := 0, out := c :: ']' :: st.hold ++ ('[' :: st.out) }
  | 3 =>
      if c == '(' then { st with depth := st.depth + 1 }
      else if c == ')' then
        (if st.depth ≤ 1 then { st with mode := 0, out := st.hold ++ st.out }
         else { st with depth := st.depth - 1 })
      else st
  | _ => { st with out := c :: st.out }

/-- C-12: reduce `[text](url)` to `text`. -/
def dropBracketLinks (s : String) : String :=
  let st := s.toList.foldl linkStep ⟨0, 0, [], []⟩
  let fin :=
    if st.mode == 1 then { st with out := ']' :: st.hold ++ ('[' :: st.out) }
    else if st.mode == 2 then { st with out := ']' :: st.hold ++ ('[' :: st.out) }
    else if st.mode == 3 then { st with out := st.hold ++ st.out }
    else st
  String.ofList fin.out.reverse

/-- C-12's `stripInlineMarkdown` (v0.13.1), in the order the spec now pins (F-141):
(1) trailing `#`s with the surrounding whitespace trimmed, (2) `[text](url)` →
`text`, (3) the `_…_` pairs, (4) the removal scan, (5) the surrounding whitespace
trimmed again. -/
def stripInlineMd (s : String) : String :=
  let s2 := dropBracketLinks (stripTrailingHashes s)
  let s3 := dropEmphUnderscore s2.toList
  trimWs (String.ofList (scanStrip s3))

/-- C-11's `slug` core scan. -/
def slugCore : List Char → List Char → Bool → List Char
  | [], acc, _ => acc
  | c :: cs, acc, wsRun =>
      if isWs c then
        (if acc.isEmpty then slugCore cs acc true
         else if wsRun then slugCore cs acc true
         else slugCore cs ('-' :: acc) true)
      else if c.isAlphanum then slugCore cs (c.toLower :: acc) false
      else if c == '-' || c == '_' then
        (if acc.isEmpty then slugCore cs acc false else slugCore cs (c :: acc) false)
      else slugCore cs acc false

/-- C-11's `slug`. -/
def slug (s : String) : String :=
  let acc := slugCore s.toList [] false
  String.ofList (acc.dropWhile (fun c => c == '-' || c == '_')).reverse

/-- C-02 rule 2 / E-23: the fence marker a line opens, if any. -/
def opensFence (line : String) : Option String :=
  let t := trimLeftWs line
  fenceMarkers.find? (fun m => t.startsWith m)

/-- C-02 rule 3: `$$` first, with no second `$$` on the same line. -/
def opensMathFence (line : String) : Bool :=
  let t := trimLeftWs line
  t.startsWith "$$" && !hasSub (String.ofList (t.toList.drop 2)) "$$"

/-- C-02 rule 3: a math fence closes at the next line containing `$$`. -/
def closesMathFence (line : String) : Bool := hasSub line "$$"

/-- R-24's GFM table: first line contains `|`, second consists only of `-`, `:`,
`|`, space. -/
def isGfmTableBlock (b : String) : Bool :=
  match b.splitOn "\n" with
  | l1 :: l2 :: _ =>
      hasSub l1 "|" && (!l2.isEmpty && l2.toList.all (fun c => c == '-' || c == ':' || c == '|' || isWs c))
  | _ => false

/-- C-02: a block whose first line opens a fence. -/
def isFenceBlock (b : String) : Bool :=
  (opensFence ((b.splitOn "\n").head?.getD "")).isSome

/-- C-02 rule 3: a block whose first line opens a math fence. -/
def isMathFenceBlock (b : String) : Bool :=
  opensMathFence ((b.splitOn "\n").head?.getD "")

/-- C-10: a thematic-break line. -/
def isThematicBreak (l : String) : Bool :=
  let t := trimWs l
  t.length ≥ 3 && (t.toList.all (fun c => c == '-' || c == '*' || c == '_')) &&
    (t.toList.eraseDups.length == 1)

/-- R-24 / E-17: a matching block is tinted whole when it is a code fence, a `$$`
math fence, a GFM table, or contains `![`. -/
def findTintsWholeBlock (b : String) : Bool :=
  isFenceBlock b || isMathFenceBlock b || isGfmTableBlock b || hasSub b "!["

/-- C-10's `smartenMarkdown`. A fence, a thematic-break line or a GFM table block is
returned unchanged; otherwise the unprotected runs are rewritten. -/
def smarten (block : String) : String :=
  if isFenceBlock block || isThematicBreak block || isGfmTableBlock block then block
  else
    String.ofList
      ((segments block).foldl
        (fun acc p => acc ++ (if p.1 then p.2.toList else rewriteRun p.2.toList)) [])

/-- C-08's fingerprint normalisation. The 80-cluster truncation (K-09) is applied
after this and is deferred — see `truncateClusters`. -/
def normalizeFingerprint (block : String) : String :=
  String.intercalate " " ((splitWs block).map String.toLower)

/-- K-09: the truncation to `n` clusters concatenates the first `n` pieces. The
segmentation itself (UAX #29) is deferred. -/
def truncateClusters (n : Nat) (clusters : List String) : String :=
  String.ofList ((clusters.take n).foldl (fun acc s => acc ++ s.toList) [])

/-- C-03: drop the six characters from a token. -/
def stripFtsChars (tok : String) : String :=
  String.ofList (tok.toList.filter (fun c => !ftsDroppedChars.contains c))

/-- C-03: query construction. -/
def ftsQuery (q : String) : String :=
  String.intercalate " "
    ((splitWs q).filterMap (fun t =>
      let t' := stripFtsChars t
      if t'.isEmpty then none else some ("\"" ++ t' ++ "\"*")))

/-- C-03 / E-24: a query with no surviving tokens performs no search. -/
def ftsPerformsSearch (q : String) : Bool := !(ftsQuery q).isEmpty

/-- C-05: language resolution — lowercase, first word; direct name, else alias,
else plain (`none`). -/
def resolveLanguage (hint : String) : Option String :=
  let w := (firstWord hint).toLower
  if directFenceWords.contains w then some w else fenceAliases.lookup w

/-- R-08: the prompt-aware test, on the *raw* first word lower-cased. -/
def isPromptAware (hint : String) : Bool := promptAwareWords.contains ((firstWord hint).toLower)

/-- C-06.1 rule 1's helper: drop lines through the closing `---`. -/
def dropToClose (ls : List String) : List String :=
  match ls with
  | [] => []
  | l :: rest => if trimWs l == "---" then rest else dropToClose rest

/-- C-06.1 rule 1: drop a leading YAML front-matter block. -/
def dropFrontMatter (ls : List String) : List String :=
  match ls with
  | first :: rest => if trimWs first == "---" then dropToClose rest else ls
  | [] => []

/-- C-06.1 rule 2: drop a quoted series name after `line`/`bar`. -/
def dropSeriesName (l : String) : String :=
  let t := trimLeftWs l
  let go (kw : String) : String :=
    if t.startsWith (kw ++ " ") then
      let rest := String.ofList (t.toList.drop (kw.length + 1))
      if prefixOf "\"" rest then
        let after := (rest.toList.drop 1).dropWhile (fun c => c != '"')
        kw ++ " " ++ trimLeftWs (String.ofList (match after with | [] => [] | _ :: tl => tl))
      else t
    else t
  if t.startsWith "line " then go "line"
  else if t.startsWith "bar " then go "bar"
  else l

/-- C-06.1 rule 3: `#rgb` → `#rrggbb`, `#rgba` → `#rrggbbaa`. -/
def expandShortHex (s : String) : String :=
  if s.startsWith "#" then
    let body := s.toList.drop 1
    if body.all isHexDigit && (body.length == 3 || body.length == 4) then
      "#" ++ String.ofList (body.flatMap (fun c => [c, c]))
    else s
  else s

/-- C-06.1 rule 3 (v0.13.1): the hex value of a CSS colour name — the pinned SVG 1.1
keyword table, case-insensitively. F-139 was that the spec named the 46 names and no
value; the values are now normative, so this is a total lookup and not an unpinned
cell. -/
def namedColorHex (name : String) : Option String := cssColorValues.lookup name.toLower

/-- C-06.1 rule 4: fold every `ID: text` description line for an ID into one alias
`state "a<br/>b" as ID`, the aliases inserted after the header line. -/
def mergeStateDescriptions (src : String) : String :=
  let ls := src.splitOn "\n"
  let isDesc (l : String) : Option (String × String) :=
    let t := trimWs l
    let id := String.ofList (t.toList.takeWhile (fun c => c != ':'))
    match t.toList.dropWhile (fun c => c != ':') with
    | ':' :: rest =>
        let txt := trimWs (String.ofList rest)
        if id.isEmpty || txt.isEmpty then none
        else if id.toList.all (fun c => c.isAlphanum || c == '_' || c == '-') then some (id, txt)
        else none
    | _ => none
  let descs := ls.filterMap isDesc
  let ids := descs.foldl (fun acc p => if acc.contains p.1 then acc else acc ++ [p.1]) []
  let aliases := ids.map (fun id =>
    let texts := descs.filterMap (fun p => if p.1 == id then some p.2 else none)
    "state \"" ++ String.intercalate "<br/>" texts ++ "\" as " ++ id)
  let kept := ls.filter (fun l => (isDesc l).isNone)
  match kept with
  | h :: t => String.intercalate "\n" (h :: aliases ++ t)
  | [] => String.intercalate "\n" aliases

/-- C-06.1 rule 5: `id[/text/]` and `id[\\text\\]` → `id[text]`. -/
def normalizeParallelograms (src : String) : String :=
  let bs := "\\"
  let s1 := src.replace ("[" ++ "/") "["
  let s2 := s1.replace ("/" ++ "]") "]"
  let s3 := s2.replace ("[" ++ bs) "["
  s3.replace (bs ++ "]") "]"

/-- C-06.1 rule 6: strip the inline formatting tags, keeping their content. -/
def stripTags (src : String) : String :=
  strippedTags.foldl
    (fun s t => (s.replace ("<" ++ t ++ ">") "").replace ("</" ++ t ++ ">") "") src

/-- C-06.1's sanitiser, rules 1–6 in the spec's order. -/
def sanitizeMermaid (src : String) : String :=
  let s := String.intercalate "\n" (dropFrontMatter (src.splitOn "\n"))
  let s := String.intercalate "\n" ((s.splitOn "\n").map dropSeriesName)
  let s := normalizeParallelograms s
  let s := stripTags s
  mergeStateDescriptions s

/-- C-07.1: an inline span is accepted when it does not cross a backtick, its
closing `$` is preceded by non-whitespace, and it is not followed by a digit. -/
def validInlineSpan (body : List Char) (after : List Char) (crossesBacktick : Bool) : Bool :=
  !crossesBacktick &&
    (match body.reverse with | [] => false | c :: _ => !isWs c) &&
    (match after with | [] => true | d :: _ => !d.isDigit)

/-- C-07.1: an empty `$$` pair is literal. -/
def validDisplaySpan (body : String) : Bool := !body.isEmpty

/-- C-07.1's placement rule. -/
def ownParagraphSpan (atLineStart atLineEnd : Bool) : Bool := atLineStart && atLineEnd

/-- `dropN n cs` — `cs` with its first `n` characters removed. -/
def dropN : Nat → List Char → List Char
  | 0, cs => cs
  | _, [] => []
  | n + 1, _ :: t => dropN n t

/-- The length of the backtick run at the head of a list. -/
def backtickRunLen : List Char → Nat
  | '`' :: cs => backtickRunLen cs + 1
  | _ => 0

/-- C-07.1: skip an inline code span — the opener run of `n` backticks, then
everything up to a run of exactly `n` (or to the end when it never closes), so no
candidate inside code is ever a span. -/
def skipCodeSpan (n : Nat) : Nat → List Char → List Char
  | 0, cs => cs
  | _, [] => []
  | f + 1, cs =>
      match cs with
      | [] => []
      | '`' :: rest =>
          let run := backtickRunLen rest + 1
          if run == n then dropN (n - 1) rest else skipCodeSpan n f (dropN (run - 1) rest)
      | _ :: rest => skipCodeSpan n f rest

/-- C-07.1's display-body scan: consume up to the closing `$$`, honouring `\`
escapes and aborting (returning `none`) at a backtick — a candidate that reaches a
backtick before its closer is not a span. -/
def scanDisplayBody : List Char → Option (List Char × List Char)
  | [] => none
  | '`' :: _ => none
  | '\\' :: d :: cs =>
      (match scanDisplayBody cs with
       | none => none
       | some (b, r) => some ('\\' :: d :: b, r))
  | '$' :: '$' :: cs => some ([], cs)
  | c :: cs =>
      (match scanDisplayBody cs with
       | none => none
       | some (b, r) => some (c :: b, r))

/-- C-07.1's inline-body scan: the same, closing on a single `$`. -/
def scanInlineBody : List Char → Option (List Char × List Char)
  | [] => none
  | '`' :: _ => none
  | '\\' :: d :: cs =>
      (match scanInlineBody cs with
       | none => none
       | some (b, r) => some ('\\' :: d :: b, r))
  | '$' :: cs => some ([], cs)
  | c :: cs =>
      (match scanInlineBody cs with
       | none => none
       | some (b, r) => some (c :: b, r))

/-- C-07.1's scan (v0.13.1), which F-146 was that the spec did not state. `fuel`
bounds the walk; `scanMathSpans` supplies the block's length plus one, and each step
consumes at least one character. Returns `(isDisplay, latex)` in document order. -/
def scanMathFuel : Nat → List Char → List (Bool × String)
  | 0, _ => []
  | _, [] => []
  | f + 1, '\\' :: _ :: cs => scanMathFuel f cs
  | f + 1, '`' :: cs =>
      let n := backtickRunLen cs + 1
      scanMathFuel f (skipCodeSpan n (n + cs.length + 1) cs)
  | f + 1, '$' :: '$' :: cs =>
      (match scanDisplayBody cs with
       | none => scanMathFuel f cs
       | some (b, r) =>
           if b.all isWs then scanMathFuel f r
           else (true, String.ofList b) :: scanMathFuel f r)
  | f + 1, '$' :: c :: cs =>
      if isWs c then scanMathFuel f (c :: cs)
      else
        (match scanInlineBody (c :: cs) with
         | none => scanMathFuel f (c :: cs)
         | some (b, r) =>
             if validInlineSpan b r false then (false, String.ofList b) :: scanMathFuel f r
             else scanMathFuel f (c :: cs))
  | f + 1, _ :: cs => scanMathFuel f cs

/-- C-07.1's scan of a whole block: `$$` is tested before `$` at each position, an
escape is skipped verbatim, a candidate that reaches a backtick or the end before its
closer is not a span, and an all-whitespace `$$…$$` body is literal. -/
def scanMathSpans (block : String) : List (Bool × String) :=
  scanMathFuel (block.length + 1) block.toList

/-- C-07.2 unit (b): the command rewrites, in the spec's order. -/
def mathRewrite (s : String) : String :=
  let s := (s.replace "\\operatorname*{" "\\mathrm{").replace "\\operatorname{" "\\mathrm{"
  let s := (s.replace "\\dfrac" "\\frac").replace "\\tfrac" "\\frac"
  let s := s.replace "\\boldsymbol" "\\bm"
  let s := s.replace "\\bmod" "\\;\\mathrm{mod}\\;"
  let s := s.replace "\\not=" "\\neq"
  let s := s.replace "\\coloneqq" ":="
  let s := (s.replace "align*" "align").replace "equation*" "equation"
  let s := (s.replace "gather*" "gather").replace "multline*" "multline"
  let s := (s.replace "\\begin{align}" "\\begin{aligned}").replace "\\end{align}" "\\end{aligned}"
  let s := (s.replace "\\begin{multline}" "\\begin{gather}").replace "\\end{multline}" "\\end{gather}"
  let s := (s.replace "\\begin{equation}" "").replace "\\end{equation}" ""
  s

/-- R-30 / D-37: one zoom step, the round-half-away rule applied to a factor
already stored in tenths, then the clamp. -/
def zoomStep (s : Nat) (dir : Bool) : Nat :=
  let applied := if dir then s + zoomStepTenths else s - zoomStepTenths
  max zoomTenthsMin (min zoomTenthsMax applied)

/-- R-30: the HUD shows $\lfloor 100 s' + 0.5 \rfloor$ %, `s'` in tenths. -/
def zoomPercent (s : Nat) : Nat := (s * zoomPercentNumerator + 5) / 10

/-- C-04: an unknown theme id resolves to the default. -/
def prefTheme (stored : Option String) : String :=
  match stored with
  | some id => if themeIds.contains id then id else themeDefaultId
  | none => themeDefaultId

/-- C-04 / K-04: `mdv6_font_scale` clamped on read. -/
def clampFontScale (n : Nat) : Nat := max zoomTenthsMin (min zoomTenthsMax n)

/-- C-04 / K-04: inspector width clamped to `[180, 520]`. -/
def clampInspectorWidth (n : Nat) : Nat := max inspectorMinPt (min inspectorMaxPt n)

/-- C-04 / K-04: the bookmarks-pane height, clamped at use (≥ 120 pt). -/
def clampBookmarksHeight (n : Nat) : Nat := max bookmarksMinPt n

/-- C-04: a stored value of the wrong type falls back to the default. -/
def prefBoolFallback (stored : Option Bool) (d : Bool) : Bool := stored.getD d

/-- §7.2: $w_{\mathrm{col}} = \min(w_{\mathrm{area}} - w_{\mathrm{side}} -
w_{\mathrm{insp}}, w_{\max}) - 2p - 2b$; a hidden pane contributes 0, a shown pane
its width plus its 8 pt drag handle. -/
def columnWidth (area : Nat) (side insp : Option Nat) (maxWidth : Option Nat) (pad : Nat) : Nat :=
  let sideW := match side with | some w => w + paneHandlePt | none => 0
  let inspW := match insp with | some w => w + paneHandlePt | none => 0
  let avail := area - sideW - inspW
  (match maxWidth with | some m => min avail m | none => avail) - 2 * pad - 2 * blockPaddingPt

/-- R-11 / K-07: $\lfloor \min(\text{natural}, \max(w_{\mathrm{col}} - 36, 1))
\rfloor$ pt. -/
def rasterWidth (natural col : Nat) : Nat := min natural (max (col - rasterInsetPt) rasterMinPt)

/-! ## 1. The observable cells -/

/-- §3.1's five document states. -/
inductive DocState where
  | empty | loading | viewing | reloading | closed
  deriving DecidableEq, Repr

/-- §3.1's events. -/
inductive LifeEvent where
  | launchEmptyHistory
  | launchWithHistory
  | openRoute
  | loadOk
  | loadUnreadable (priorDoc : Bool)
  | fileChangedOnDisk
  | pathDeleted
  | transientReadRejected
  | deleteDisplayedRow (otherRowsRemain : Bool)
  | windowClose
  deriving DecidableEq, Repr

/-- R-01's two route kinds. -/
inductive RouteKind where
  | adding | selecting
  deriving DecidableEq, Repr

/-- R-01's routes. -/
inductive Route where
  | openPanel | openInNewWindow | launchServices | drop | link
  | bookmark | placeholder | directoryScan
  | historyRow | searchHitInHistory | back | forward | deleteCurrentRow
  deriving DecidableEq, Repr

/-- R-18's navigation events. -/
inductive NavEvent where
  | loadDifferentFile (route : Route)
  | back | forward
  | slugFragmentJump | tocRow | lineCitationJump | findStep
  | reopenCurrentPath
  | rowRemoved
  deriving DecidableEq, Repr

/-- R-19's destination classification. -/
inductive Destination where
  | localMarkdown | localNonMarkdown | missingLocal | otherScheme
  deriving DecidableEq, Repr

/-- R-19's fragment kinds, tested in this order. -/
inductive FragKind where
  | lineCitation | slugFragment | noFragment
  deriving DecidableEq, Repr

/-- K-14's named ceilings. -/
inductive CeilingKind where
  | document | mermaid | latex | encodedImage | decodedPixels | decodedBytes | imageAxis
  deriving DecidableEq, Repr

/-- C-16's and E-11's circumstances. -/
inductive RemoteEvent where
  | preferenceOff
  | redirects (n : Nat)
  | nonHttpTarget
  | connectTimeout (seconds : Nat)
  | resourceTimeout (seconds : Nat)
  | bodyOverCeiling (bytes : Nat)
  | status (code : Nat)
  | mediaType (ok : Bool)
  | decodeFailed
  | dimensions (w h bytes : Nat)
  deriving DecidableEq, Repr

/-- C-02 rule 7's heading. `text` is `Option` because C-07.3's math-to-Unicode
conversion is deferred: `none` means the heading line carries a math span, so the
spec's `text` cell is not determined by the modelled part of the spec. -/
structure TocHeading where
  level : Nat
  text : Option String
  slugText : String
  blockIndex : Nat
  deriving DecidableEq, Repr

/-- C-02's `ParsedDocument`. -/
structure SplitResult where
  blocks : List String
  blockLines : List (Nat × Nat)
  lineCount : Nat
  toc : List TocHeading
  deriving DecidableEq, Repr

/-- §5.2's four observable columns. -/
structure CliResult where
  action : String
  stdout : String
  stderr : String
  exit : UInt8
  deriving DecidableEq, Repr

/-- One observation per contract. -/
inductive Result where
  | cli (r : CliResult)
  | state (s : DocState)
  | split (r : SplitResult)
  | text (s : String)
  | maybeText (s : Option String)
  | frag (kind : FragKind) (start : Nat) (stop : Option Nat)
  | index (i : Nat)
  | maybeIndex (i : Option Nat)
  | num (n : Nat)
  | flag (b : Bool)
  | lang (l : Option String) (promptAware : Bool)
  | range (a b : Nat)
  | entries (ps : List String)
  | route (k : RouteKind) (reorders : Bool)
  | link (inApp opens : Bool)
  | pushed (push clears inApp : Bool)
  | search (performs : Bool) (query : String)
  | navact (navigates beeps : Bool)
  | title (source text : String)
  | tints (whole : Bool)
  deriving DecidableEq, Repr

/-- R-27: the nearest TOC heading at or within the previous 40 blocks. -/
def nearestHeading (toc : List TocHeading) (i : Nat) : Option TocHeading :=
  (toc.filter (fun h => h.blockIndex ≤ i && i - h.blockIndex ≤ headingLookBack)).reverse.head?

/-- R-27's title rule. Returns the title's source and its text. -/
def bookmarkTitle (blocks : List String) (toc : List TocHeading) (hovered : Option Nat)
    (topVisible : Nat) : String × String :=
  if blocks.isEmpty then ("empty", titleEmpty)
  else
    let i := min (hovered.getD topVisible) (blocks.length - 1)
    match nearestHeading toc i with
    | some h => ("nearest-toc-heading", h.text.getD h.slugText)
    | none =>
        let firstLine := ((blocks[i]?.getD "")).splitOn "\n" |>.head?.getD ""
        let stripped := trimWs (stripInlineMd firstLine)
        if stripped.isEmpty then
          ("line-index", titleLinePrefix ++ Nat.repr (i + 1) ++ titleLineSuffix)
        else ("stripped-first-line", stripped)

/-- R-01: a route's kind. -/
def routeKind (r : Route) : RouteKind :=
  match r with
  | .historyRow | .searchHitInHistory | .back | .forward | .deleteCurrentRow => .selecting
  | _ => .adding

/-- R-01: an adding route moves the row to the top and indexes it; a selecting
route does neither. -/
def routeReorders (r : Route) : Bool := routeKind r == .adding

/-- R-01: a multi-URL open event adds every path in the order received; the last is
displayed, so the stored list (most recent first) is the reverse. -/
def openEventHistory (paths : List String) : List String := paths.reverse

/-- R-02: the directory scan's choice — the file's *name*: `README.md` by
case-insensitive stem match when present, else the first in case-insensitive order;
`none` when there is no Markdown file. -/
def dirPick (entries : List (String × Bool)) : Option String :=
  let ok := entries.filterMap (fun p =>
    if p.2 && !startsWithS "." p.1 &&
        directoryScanExtensions.any (fun e => endsWithS ("." ++ e) p.1.toLower)
    then some p.1
    else none)
  let sorted := ok.mergeSort (fun a b => a.toLower ≤ b.toLower)
  match sorted.find? (fun n => startsWithS (readmeStem.toLower ++ ".") n.toLower) with
  | some n => some n
  | none => sorted.head?

/-- R-03: a drop is accepted only for the droppable extensions. -/
def acceptDrop (name : String) : Bool :=
  droppableExtensions.any (fun e => endsWithS ("." ++ e) name.toLower)

/-- R-01's route name, as `Spec.addingRoutes`/`Spec.selectingRoutes` spell it. -/
def routeName (r : Route) : String :=
  match r with
  | .openPanel => "open-panel"
  | .openInNewWindow => "open-in-new-window"
  | .launchServices => "launch-services"
  | .drop => "drop"
  | .link => "link"
  | .bookmark => "bookmark"
  | .placeholder => "placeholder"
  | .directoryScan => "directory-scan"
  | .historyRow => "history-row"
  | .searchHitInHistory => "search-hit-in-history"
  | .back => "back"
  | .forward => "forward"
  | .deleteCurrentRow => "delete-current-row"

/-- R-18: whether an event pushes a back snapshot. -/
def navPush (ev : NavEvent) : Bool :=
  match ev with
  | .loadDifferentFile r => !(nonPushingRoutes.contains (routeName r))
  | .back | .forward => true
  | .slugFragmentJump | .tocRow => true
  | .lineCitationJump | .findStep | .reopenCurrentPath | .rowRemoved => false

/-- R-18: whether an event clears the forward stack. -/
def navClearsForward (ev : NavEvent) : Bool :=
  match ev with
  | .lineCitationJump | .findStep | .reopenCurrentPath | .rowRemoved => false
  | _ => true

/-- R-18 / C-19.4: whether an event moves within a document. -/
def navInApp (ev : NavEvent) : Bool :=
  match ev with
  | .reopenCurrentPath => false
  | _ => true

/-- R-20 / I-013 / K-03: history after a route. -/
def historyInsert (entries : List String) (path : String) (kind : RouteKind) : List String :=
  match kind with
  | .selecting => entries
  | .adding => (path :: entries.filter (fun p => p != path)).take historyCap

/-- C-15: a history value that does not decode yields an empty history. -/
def historyDecodeFails (_entries : List String) : List String := []

/-- C-15: a history value that decodes yields its entries. -/
def historyDecodeOk (entries : List String) : List String := entries

/-- K-14: the ceiling for a named kind. -/
def ceilingOf (kind : CeilingKind) : Nat :=
  match kind with
  | .document => ceilingDocumentBytes
  | .mermaid => ceilingMermaidBytes
  | .latex => ceilingLatexBytes
  | .encodedImage => ceilingEncodedImageBytes
  | .decodedPixels => ceilingDecodedPixels
  | .decodedBytes => ceilingDecodedBytes
  | .imageAxis => ceilingImageAxis

/-- K-14 / E-28: content at the ceiling is admitted; above it is rejected. -/
def ceilingAdmits (kind : CeilingKind) (size : Nat) : Bool := size ≤ ceilingOf kind

/-- C-16 / E-11: the remote-image policy. -/
def remoteAdmits (ev : RemoteEvent) : Bool :=
  match ev with
  | .preferenceOff => false
  | .redirects n => n ≤ remoteMaxRedirects
  | .nonHttpTarget => false
  | .connectTimeout seconds => seconds ≤ remoteConnectTimeoutSeconds
  | .resourceTimeout seconds => seconds ≤ remoteResourceTimeoutSeconds
  | .bodyOverCeiling bytes => bytes ≤ remoteBodyCeilingBytes
  | .status code => 200 ≤ code && code < 300
  | .mediaType ok => ok
  | .decodeFailed => false
  | .dimensions w h bytes =>
      w ≤ ceilingImageAxis && h ≤ ceilingImageAxis && w * h ≤ ceilingDecodedPixels &&
      bytes ≤ ceilingDecodedBytes

/-- C-17: the harness exit code for a case. -/
def harnessExit (caseFailure usage : Bool) : UInt8 :=
  if usage then harnessExitUsage
  else if caseFailure then harnessExitCaseFailure
  else harnessExitSuccess

/-- C-17: the pixel comparison passes when $q \le 0.001$, i.e. $1000\,|D| \le N$;
`N = 0` is a failure. -/
def pixelPasses (differing total : Nat) : Bool :=
  total != 0 && differing * pixelMismatchDenominator ≤ total * pixelMismatchNumerator

/-- §7.1 / I-009: the ink comparison passes when the node's ink is at least 0.9×
the document's and neither crop is empty. -/
def inkPasses (nodeInk docInk : Nat) : Bool :=
  0 < nodeInk && 0 < docInk && 10 * nodeInk ≥ inkRatioTenths * docInk

/-- E-02: a Mermaid source renders, or falls back per R-10. -/
def mermaidRenders (unsupported parseFailed : Bool) : Bool := !unsupported && !parseFailed

/-- E-09 / E-27: opening a bookmark, snapshot or placeholder whose file is missing
beeps and navigates nowhere. -/
def navigationAttempt (fileExists : Bool) : Bool × Bool := (fileExists, !fileExists)

/-! ## 2. The input space -/

/-- The splitter's mode. -/
inductive SplitMode where
  | normal | fence (marker : String) | math
  deriving DecidableEq, Repr

/-- The splitter's carried state. -/
structure SplitState where
  mode : SplitMode
  cur : List String
  curLower : Nat
  curUpper : Nat
  out : List String
  ranges : List (Nat × Nat)
  deriving Repr

/-- The model's input space: one constructor per group of spec rows. -/
inductive Input where
  /-- **§5.2** — the launcher's whole table. `args` is each argument with its
  existence on disk; `bundleFound` is the bundle step, which runs first. -/
  | cliInvocation (args : List (String × Bool)) (bundleFound : Bool)
  /-- **§3.1** — a lifecycle cell. -/
  | life (st : DocState) (ev : LifeEvent)
  /-- **C-02** — the split of one raw document. -/
  | splitOf (raw : String)
  /-- **C-19.1 / R-19** — the kind a fragment is, and its parse. -/
  | fragmentOf (frag : String)
  /-- **C-19.2** — range normalisation. -/
  | citationStartOf (a : Nat) (b : Option Nat)
  /-- **C-19.3 / E-31** — line → block resolution. -/
  | lineResolveOf (blockLines : List (Nat × Nat)) (line : Nat)
  /-- **R-19** — classification of a click's destination. -/
  | linkKindOf (d : Destination)
  /-- **C-11** — the slug of a string. -/
  | slugOf (s : String)
  /-- **C-12** — the section range of a document's heading levels. -/
  | sectionOf (levels : List Nat) (i : Nat)
  /-- **C-12** — inline stripping. -/
  | stripInlineOf (s : String)
  /-- **C-10** — smart typography of one block. -/
  | smartenOf (block : String)
  /-- **R-24 / E-17** — whether a matching block is tinted whole. -/
  | tintOf (block : String)
  /-- **C-08** — the fingerprint normalisation of a block. -/
  | fingerprintOf (block : String)
  /-- **C-08 / E-08** — anchor resolution. -/
  | anchorOf (blocks : List String) (storedIndex : Nat) (fp : String)
  /-- **C-08 / E-08** — whether a scroll position is restored. -/
  | scrollOf (blocks : List String) (storedIndex : Nat) (fp : String)
      (storedMtime nowMtime : Nat)
  /-- **C-03 / E-24** — query construction and whether a search is performed. -/
  | queryOf (q : String)
  /-- **C-05 / R-08 / R-38 / R-43** — language resolution and prompt-awareness. -/
  | langOf (hint : String)
  /-- **C-06.1 rule 1** — YAML front matter. -/
  | frontMatterOf (src : String)
  /-- **C-06.1 rule 2** — xychart series names. -/
  | xychartOf (src : String)
  /-- **C-06.1 rule 3** — `#rgb`/`#rgba` expansion. -/
  | hexExpandOf (s : String)
  /-- **C-06.1 rule 3** — a CSS colour name's hex value. -/
  | colorNameOf (name : String)
  /-- **C-06.1 rule 4** — state descriptions folded into aliases. -/
  | stateDescsOf (src : String)
  /-- **C-06.1 rule 5** — parallelograms. -/
  | parallelogramOf (src : String)
  /-- **C-06.1 rule 6** — inline formatting tags. -/
  | tagsOf (src : String)
  /-- **C-07.1** — whether a candidate inline span is accepted. -/
  | inlineSpanOf (body : List Char) (after : List Char) (crossesBacktick : Bool)
  /-- **C-07.1** — whether a candidate display span is accepted. -/
  | displaySpanOf (body : String)
  /-- **C-07.1** — a display span's placement. -/
  | placementOf (atLineStart atLineEnd : Bool)
  /-- **C-07.2 unit (b)** — the command rewrites. -/
  | mathRewriteOf (s : String)
  /-- **R-30 / K-04 / D-37** — one zoom step. `dir` is `true` for ⌘=. -/
  | zoomStepOf (s : Nat) (dir : Bool)
  /-- **R-30** — the HUD percentage. -/
  | zoomPercentOf (s : Nat)
  /-- **C-04** — the theme a stored value resolves to. -/
  | prefThemeOf (stored : Option String)
  /-- **C-04** — `mdv6_font_scale` clamped on read. -/
  | clampScaleOf (n : Nat)
  /-- **C-04 / K-04** — inspector width clamp. -/
  | clampInspectorOf (n : Nat)
  /-- **C-04 / K-04** — bookmarks-pane height clamp. -/
  | clampBookmarksOf (n : Nat)
  /-- **C-04** — a boolean preference's fallback. -/
  | prefBoolOf (stored : Option Bool) (d : Bool)
  /-- **§7.2 / K-13** — the column width. -/
  | columnOf (area : Nat) (side insp : Option Nat) (maxWidth : Option Nat) (pad : Nat)
  /-- **R-11 / K-07** — the raster width. -/
  | rasterOf (natural col : Nat)
  /-- **R-27** — the bookmark title rule. -/
  | bookmarkTitleOf (blocks : List String) (toc : List TocHeading) (hovered : Option Nat)
      (topVisible : Nat)
  /-- **R-01** — the kind of a route. -/
  | routeOf (r : Route)
  /-- **R-01** — a multi-URL open event's history. -/
  | openEventOf (paths : List String)
  /-- **R-02 / E-04** — the directory scan's choice. -/
  | dirPickOf (entries : List (String × Bool))
  /-- **R-03** — drop acceptance. -/
  | dropAcceptOf (name : String)
  /-- **R-18** — the snapshot policy of a navigation event. -/
  | navPushOf (ev : NavEvent)
  /-- **R-20 / I-013 / K-03** — history after a route. -/
  | historyOf (entries : List String) (path : String) (kind : RouteKind)
  /-- **C-15** — a history value that does not decode. -/
  | historyDecodeFailsOf (entries : List String)
  /-- **C-15** — a history value that decodes. -/
  | historyDecodeOkOf (entries : List String)
  /-- **K-14 / E-28** — a ceiling test. -/
  | ceilingOf (kind : CeilingKind) (size : Nat)
  /-- **C-16 / E-11** — the remote-image policy. -/
  | remoteOf (ev : RemoteEvent)
  /-- **C-17** — the harness exit code for a case. -/
  | harnessExitOf (caseFailure usage : Bool)
  /-- **C-17** — the pixel metric. -/
  | pixelOf (differing total : Nat)
  /-- **§7.1 / I-009** — the ink-weight comparison. -/
  | inkOf (nodeInk docInk : Nat)
  /-- **E-02** — whether a Mermaid source renders or falls back. -/
  | mermaidOf (unsupported parseFailed : Bool)
  /-- **E-09 / E-27** — opening something whose file is missing. -/
  | openMissingOf (fileExists : Bool)
  deriving DecidableEq, Repr

/-! ## 3. The transcription's leaf functions -/

/-- §5.2: the first argument that does not exist, if any. Only the first is
reported; later arguments are not checked. -/
def firstMissing (args : List (String × Bool)) : Option String :=
  (args.find? (fun p => !p.2)).map (fun p => p.1)

/-- §5.2: the launcher's behaviour. -/
def cliOutcome (args : List (String × Bool)) (bundleFound : Bool) : CliResult :=
  if !bundleFound then ⟨"locate bundle (fails)", "", cliBundleMissingMessage, cliExitFailure⟩
  else
    match args with
    | [] => ⟨"open <app>", "", "", cliExitSuccess⟩
    | [("-", _)] => ⟨"mktemp -t mdv6-stdin, then open", "", "", cliExitSuccess⟩
    | [("-h", _)] => ⟨"usage", "", "", cliExitSuccess⟩
    | [("--help", _)] => ⟨"usage", "", "", cliExitSuccess⟩
    | [("--version", _)] => ⟨"print bundle version", "1.0.0", "", cliExitSuccess⟩
    | _ =>
        match firstMissing args with
        | some p => ⟨"abort, nothing opened", "", cliMissingFilePrefix ++ p, cliExitFailure⟩
        | none => ⟨"open -a <app> <paths…>", "", "", cliExitSuccess⟩

/-- §3.1's transition table and Figure 3.1; `none` where the spec states no
transition. `CLOSED`'s silence is the spec's own word *terminal* — see
`closedIsTerminal`. -/
def lifecycle : DocState → LifeEvent → Option DocState
  | .empty, .launchEmptyHistory => some .empty
  | .empty, .launchWithHistory => some .loading
  | .empty, .openRoute => some .loading
  | .empty, .deleteDisplayedRow _ => some .empty
  | .empty, .windowClose => some .closed
  | .loading, .openRoute => some .loading
  | .loading, .loadOk => some .viewing
  | .loading, .loadUnreadable true => some .viewing
  | .loading, .loadUnreadable false => some .empty
  | .loading, .windowClose => some .closed
  | .viewing, .openRoute => some .loading
  | .viewing, .fileChangedOnDisk => some .reloading
  | .viewing, .pathDeleted => some .viewing
  | .viewing, .transientReadRejected => some .viewing
  | .viewing, .deleteDisplayedRow true => some .loading
  | .viewing, .deleteDisplayedRow false => some .empty
  | .viewing, .windowClose => some .closed
  | .reloading, .loadOk => some .viewing
  | .reloading, .fileChangedOnDisk => some .reloading
  | .reloading, .windowClose => some .closed
  | _, _ => none

/-- §3.1: `CLOSED` is terminal: no event leaves it. -/
def closedIsTerminal : Prop := ∀ ev, lifecycle .closed ev = none

/-- §3.1 (v0.13.1): the cells the table names — the state-and-event pairs the
application can be in. The table is total, so a pair this predicate rejects is
*unreachable*, which is why `lifecycle` may return `none` there (F-140). -/
def lifeReachable : DocState → LifeEvent → Bool
  | .empty, .launchEmptyHistory => true
  | .empty, .launchWithHistory => true
  | .empty, .openRoute => true
  | .empty, .deleteDisplayedRow _ => true
  | .empty, .windowClose => true
  | .loading, .openRoute => true
  | .loading, .loadOk => true
  | .loading, .loadUnreadable _ => true
  | .loading, .windowClose => true
  | .viewing, .openRoute => true
  | .viewing, .fileChangedOnDisk => true
  | .viewing, .pathDeleted => true
  | .viewing, .transientReadRejected => true
  | .viewing, .deleteDisplayedRow _ => true
  | .viewing, .windowClose => true
  | .reloading, .loadOk => true
  | .reloading, .fileChangedOnDisk => true
  | .reloading, .windowClose => true
  | _, _ => false

/-- The splitter's initial state. -/
def splitInit : SplitState := ⟨.normal, [], 0, 0, [], []⟩

/-- C-02 rule 5 + rule 1: end the current block, trim it, drop it when empty. -/
def flushBlock (st : SplitState) : SplitState :=
  if st.cur.isEmpty then st
  else
    let blk := trimNl (String.intercalate "\n" st.cur.reverse)
    if blk.isEmpty then { st with cur := [] }
    else
      { st with
        cur := []
        out := blk :: st.out
        ranges := (st.curLower, st.curUpper + 1) :: st.ranges }

/-- One line into the splitter (C-02 rules 1–4). -/
def feedLine (st : SplitState) (i : Nat) (line : String) : SplitState :=
  let push : SplitState :=
    { st with
      cur := line :: st.cur
      curUpper := i
      curLower := if st.cur.isEmpty then i else st.curLower }
  match st.mode with
  | .normal =>
      match opensFence line with
      | some m => { push with mode := .fence m }
      | none =>
          if opensMathFence line then { push with mode := .math }
          else if isBlank line then flushBlock st
          else push
  | .fence m => if (trimLeftWs line).startsWith m then { push with mode := .normal } else push
  | .math => if closesMathFence line then { push with mode := .normal } else push

/-- C-02 rule 7: the heading a block contributes. -/
def headingOf (b : String) : Option (Nat × String) :=
  let t := trimLeftWs ((b.splitOn "\n").head?.getD "")
  if t.startsWith "### " then some (3, t)
  else if t.startsWith "## " then some (2, t)
  else if t.startsWith "# " then some (1, t)
  else none

/-- C-02 rule 7: the TOC entry a block contributes, if any. -/
def tocEntryOf (blocks : List String) (i : Nat) : Option TocHeading :=
  match blocks[i]? with
  | none => none
  | some b =>
      (match headingOf b with
       | none => none
       | some (lvl, line) =>
           let body := String.ofList (line.toList.drop (lvl + 1))
           some { level := lvl
                , text := if hasSub body "$" then none else some (stripInlineMd body)
                , slugText := stripInlineMd body
                , blockIndex := i })

/-- C-02 rule 7: the TOC headings of the split. -/
def tocOf (blocks : List String) : List TocHeading :=
  (List.range blocks.length).filterMap (tocEntryOf blocks)

/-- C-02's split. -/
def splitRaw (raw : String) : SplitResult :=
  let ls := splitLines raw
  let st := (List.zip (List.range ls.length) ls).foldl
    (fun st p => feedLine st (p.1 + 1) p.2) splitInit
  let st := flushBlock st
  { blocks := st.out.reverse
  , blockLines := st.ranges.reverse
  , lineCount := lineCountOf raw
  , toc := tocOf st.out.reverse }

/-- C-19.1: the leading digit run, requiring a 1–9 first digit; returns the value
and the rest. -/
def takeLineDigits (cs : List Char) : Option (Nat × List Char) :=
  let d := cs.takeWhile (fun c => c.isDigit)
  if d.isEmpty || d.head? == some '0' then none
  else some (natOfDigits d, cs.drop d.length)

/-- C-19.1: an optional leading `L` in the second position of a range. -/
def dropLeadL : List Char → List Char
  | 'l' :: t => t
  | cs => cs

/-- C-19.1: the optional second number of a range. -/
def citationSecond (start : Nat) (more : List Char) : Option (Nat × Option Nat) :=
  match takeLineDigits (dropLeadL more) with
  | none => none
  | some (b, rest2) => if rest2.isEmpty then some (start, some b) else none

/-- C-19.1: the tail after the first number. -/
def citationTail (start : Nat) (after : List Char) : Option (Nat × Option Nat) :=
  match after with
  | [] => some (start, none)
  | '-' :: more => citationSecond start more
  | _ => none

/-- C-19.1's grammar as a parse: `L` digits, optionally `-` (`L`)? digits, anchored
and case-insensitive; the leading digit excludes `0`. -/
def citationParse (frag : String) : Option (Nat × Option Nat) :=
  match frag.toLower.toList with
  | 'l' :: rest =>
      (match takeLineDigits rest with
       | none => none
       | some (start, after) => citationTail start after)
  | _ => none

/-- R-19: the fragment kind, tested in the spec's order (the line form wins). -/
def fragmentKind (frag : String) : FragKind :=
  if frag.isEmpty then .noFragment
  else match citationParse frag with
    | some _ => .lineCitation
    | none => .slugFragment

/-- C-19.2: the resolved start line. -/
def citationStart (a : Nat) (b : Option Nat) : Nat :=
  match b with
  | some b => min a b
  | none => a

/-- C-19.3 / C-02 rule 8 / E-31: the last index whose `lowerBound ≤ line`, else the
first block; `0` for a document with no blocks. -/
def resolveLine (blockLines : List (Nat × Nat)) (line : Nat) : Nat :=
  (blockLines.filter (fun r => r.1 ≤ line)).length - 1

/-- R-19: the navigation decision for a destination. -/
def linkDecision (d : Destination) : Bool × Bool :=
  match d with
  | .localMarkdown => (true, false)
  | _ => (false, true)

/-- C-08: resolve an anchor. -/
def resolveAnchor (blocks : List String) (storedIndex : Nat) (fp : String) : Nat :=
  match blocks.findIdx? (fun b => normalizeFingerprint b == fp) with
  | some i => i
  | none => if blocks.isEmpty then 0 else min storedIndex (blocks.length - 1)

/-- C-08 / E-08: a scroll position is restored only when the anchor resolves, the
mtime is within 1 s, and the index is in bounds. -/
def scrollRestores (blocks : List String) (storedIndex : Nat) (fp : String)
    (storedMtime nowMtime : Nat) : Bool :=
  let mtimeOk :=
    if storedMtime ≤ nowMtime then nowMtime - storedMtime ≤ mtimeToleranceSeconds
    else storedMtime - nowMtime ≤ mtimeToleranceSeconds
  blocks.any (fun b => normalizeFingerprint b == fp) && mtimeOk && storedIndex < blocks.length

/-- C-12: `section(headingAt i)` = blocks `[i, j)` where `j` is the index of the next
TOC heading with level ≤ `i`'s, or the block count. `levels` gives each block's
heading level (`0` for a non-heading block). -/
def sectionRangeOf (levels : List Nat) (i : Nat) : Nat × Nat :=
  let lvl := levels[i]?.getD 0
  if lvl == 0 then (i, i + 1)
  else
    let rest := (List.range levels.length).filter
      (fun k => k > i && levels[k]?.getD 0 != 0 && levels[k]?.getD 0 ≤ lvl)
    match rest.head? with
    | some j => (i, j)
    | none => (i, levels.length)

/-! ## 5. `outcome` — the transcription, total, with `none` as silence -/

/-- The spec's tables as a total function. `none` = the spec states no outcome for
this input. -/
def outcome : Input → Option Result
  | .cliInvocation args found => some (.cli (cliOutcome args found))
  | .life st ev => (lifecycle st ev).map .state
  | .splitOf raw => some (.split (splitRaw raw))
  | .fragmentOf frag =>
      (match citationParse frag with
       | some (a, b) => some (.frag .lineCitation a b)
       | none => some (.frag (if frag.isEmpty then .noFragment else .slugFragment) 0 none))
  | .citationStartOf a b => some (.num (citationStart a b))
  | .lineResolveOf bls line => some (.index (resolveLine bls line))
  | .linkKindOf d =>
      let (inApp, opensSystem) := linkDecision d
      some (.link inApp opensSystem)
  | .slugOf s => some (.text (slug s))
  | .sectionOf levels i => some (.range (sectionRangeOf levels i).1 (sectionRangeOf levels i).2)
  | .stripInlineOf s => some (.text (stripInlineMd s))
  | .smartenOf b => some (.text (smarten b))
  | .tintOf b => some (.tints (findTintsWholeBlock b))
  | .fingerprintOf b => some (.text (normalizeFingerprint b))
  | .anchorOf blocks idx fp => some (.index (resolveAnchor blocks idx fp))
  | .scrollOf blocks idx fp a b => some (.flag (scrollRestores blocks idx fp a b))
  | .queryOf q => some (.search (ftsPerformsSearch q) (ftsQuery q))
  | .langOf hint => some (.lang (resolveLanguage hint) (isPromptAware hint))
  | .frontMatterOf src =>
      some (.text (String.intercalate "\n" (dropFrontMatter (src.splitOn "\n"))))
  | .xychartOf src =>
      some (.text (String.intercalate "\n" ((src.splitOn "\n").map dropSeriesName)))
  | .hexExpandOf s => some (.text (expandShortHex s))
  | .colorNameOf name => some (.maybeText (namedColorHex name))
  | .stateDescsOf src => some (.text (mergeStateDescriptions src))
  | .parallelogramOf src => some (.text (normalizeParallelograms src))
  | .tagsOf src => some (.text (stripTags src))
  | .inlineSpanOf body after x => some (.flag (validInlineSpan body after x))
  | .displaySpanOf body => some (.flag (validDisplaySpan body))
  | .placementOf s e => some (.flag (ownParagraphSpan s e))
  | .mathRewriteOf s => some (.text (mathRewrite s))
  | .zoomStepOf s dir => some (.num (zoomStep s dir))
  | .zoomPercentOf s => some (.num (zoomPercent s))
  | .prefThemeOf stored => some (.text (prefTheme stored))
  | .clampScaleOf n => some (.num (clampFontScale n))
  | .clampInspectorOf n => some (.num (clampInspectorWidth n))
  | .clampBookmarksOf n => some (.num (clampBookmarksHeight n))
  | .prefBoolOf stored d => some (.flag (prefBoolFallback stored d))
  | .columnOf area side insp maxW pad => some (.num (columnWidth area side insp maxW pad))
  | .rasterOf natural col => some (.num (rasterWidth natural col))
  | .bookmarkTitleOf blocks toc hovered top =>
      let (src, txt) := bookmarkTitle blocks toc hovered top
      some (.title src txt)
  | .routeOf r => some (.route (routeKind r) (routeReorders r))
  | .openEventOf paths => some (.entries (openEventHistory paths))
  | .dirPickOf entries => some (.maybeText (dirPick entries))
  | .dropAcceptOf name => some (.flag (acceptDrop name))
  | .navPushOf ev => some (.pushed (navPush ev) (navClearsForward ev) (navInApp ev))
  | .historyOf entries path kind => some (.entries (historyInsert entries path kind))
  | .historyDecodeFailsOf es => some (.entries (historyDecodeFails es))
  | .historyDecodeOkOf es => some (.entries (historyDecodeOk es))
  | .ceilingOf kind size => some (.flag (ceilingAdmits kind size))
  | .remoteOf ev => some (.flag (remoteAdmits ev))
  | .harnessExitOf cf us => some (.cli ⟨"", "", "", harnessExit cf us⟩)
  | .pixelOf d n => some (.flag (pixelPasses d n))
  | .inkOf node doc => some (.flag (inkPasses node doc))
  | .mermaidOf un pf => some (.flag (mermaidRenders un pf))
  | .openMissingOf fileExists =>
      some (.navact (navigationAttempt fileExists).1 (navigationAttempt fileExists).2)

/-! ## 7. The pins

`inputPinned` states what the spec permits where a cell is only partially
determined. The invariant theorems take these as hypotheses: **the hypotheses are
the spec, not the model.** -/

/-- §3.1's `CLOSED` row says *terminal*: `none` there is a statement, not a gap. -/
def lifePinned (st : DocState) (r : Option DocState) : Prop := st = .closed → r = none

/-- C-02's partial cell: `TocHeading.text` is `none` exactly when the heading line
carries a math span (C-07.3 deferred). -/
def splitPinned (r : SplitResult) : Prop :=
  ∀ (i : Nat) (h : TocHeading), r.toc[i]? = some h →
    (h.text = none ↔ ∃ (b : String), r.blocks[i]? = some b ∧
      hasSub ((b.splitOn "\n").head?.getD "") "$")

/-- C-08's partial cell: the fingerprint is the normalisation followed by the
80-cluster truncation, whose segmentation (UAX #29) is deferred. -/
def fingerprintPinned (block : String) (r : String) : Prop :=
  ∃ clusters, truncateClusters fingerprintClusters clusters = r ∧
    (clusters.foldl (fun acc s => acc ++ s.toList) []).length ≤ (normalizeFingerprint block).length

/-- R-27's partial cell: the fallback title is the stripped first line truncated to
60 extended grapheme clusters (K-06); the truncation is deferred. -/
def titlePinned (blocks : List String) (i : Nat) (r : String) : Prop :=
  ∃ clusters, truncateClusters titleClusters clusters = r ∧
    r.toList.isPrefixOf
      ((blocks[i]?.getD "").splitOn "\n" |>.head?.getD "" |> trimWs |> stripInlineMd).toList

/-- C-06.1 rule 3's cell (v0.13.1): the value is pinned to the SVG 1.1 keyword table,
so the pin is equality with the lookup — F-139's gap (names without values) is
closed. -/
def colorPinned (name : String) (r : Option String) : Prop := r = cssColorValues.lookup name

/-- C-07.1's cell (v0.13.1): the acceptance conditions, the placement, and — since
F-146 — the scan itself (`scanMathSpans`). The pin is that a candidate is accepted
exactly when the conditions hold. -/
def mathPinned (body : List Char) (after : List Char) (x r : Bool) : Prop :=
  r = validInlineSpan body after x

/-! ## 8. Purity, and the enumerated sets the finite checks quantify over -/

/-- The environment a render could in principle depend on. The model has no such
parameter: `runE` exists only so that I-001 can be stated and proved. -/
structure Env where
  theme : String := ""
  zoom : Nat := 10
  width : Nat := 860
  backingScale : Nat := 2
  remoteImages : Bool := false
  deriving DecidableEq, Repr

/-- I-001: the model's entry point with the environment as an ignored parameter. -/
def runE (_e : Env) (i : Input) : Option Result := outcome i

/-- §3.1's five states, enumerated so the finite checks can quantify over all of
them without a `Fintype` instance. -/
def docStates : List DocState := [.empty, .loading, .viewing, .reloading, .closed]

/-- §3.1's events, enumerated (the two `Bool`-carrying constructors at both
values). -/
def lifeEvents : List LifeEvent :=
  [ .launchEmptyHistory, .launchWithHistory, .openRoute, .loadOk, .loadUnreadable true
  , .loadUnreadable false, .fileChangedOnDisk, .pathDeleted, .transientReadRejected
  , .deleteDisplayedRow true, .deleteDisplayedRow false, .windowClose ]

/-- K-14's seven ceiling kinds, enumerated. -/
def allCeilingKinds : List CeilingKind :=
  [.document, .mermaid, .latex, .encodedImage, .decodedPixels, .decodedBytes, .imageAxis]

end Mdv6Spec.Mdv6.Model
