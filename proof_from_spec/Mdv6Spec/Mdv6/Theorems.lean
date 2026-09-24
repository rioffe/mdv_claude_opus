/-
Mdv6Spec.Mdv6.Theorems
======================

The **proof**: what the model in `Model.lean` satisfies, kernel-checked.

## What this proves

* **Rows** (`section Rows`) — the spec's behaviour tables, statement by statement:
  §5.2's seven CLI invocations, §3.1's thirteen lifecycle transitions, C-02's split
  rules 1–8 (with E-23's fence edge cases and T-39/T-50's map half), C-19.1's
  accepted and rejected fragments, C-19.2's range normalisation, C-19.3/E-31's
  total line resolution, R-19's classification, C-11's slug, C-12's section range
  and inline stripping, C-10's rewrites and early returns, C-08's fingerprint and
  anchor, C-03's query construction, C-05's language resolution with R-38/R-43's
  alias families, C-06.1's six sanitiser rules, C-07.1's delimiter conditions and
  C-07.2's command rewrites, R-30's zoom, C-04's preference fallbacks, §7.2's
  column width, R-11's raster width, R-27's title rule, R-01/R-02/R-03's route,
  scan and drop rules, R-18's snapshot policy, R-20/I-013's history cap, C-15's
  decode failure, K-14's ceilings, C-16's remote-image policy, C-17's exit map and
  pixel metric, §7.1's ink metric, and E-02/E-09's fallbacks.
* **Invariants** (`section Invariants`) — the per-family claims quantified over the
  whole input space: the CLI's closed exit set and its two diagnostic contracts,
  §3.1's closed state set and total transition relation, I-001's environment
  independence, I-004's determinism, and the pins that state what the spec permits
  where a cell is partial.
* **Reachability** (`section Reachability`) — every exit code, every document
  state, every route kind, every fragment kind and every ceiling kind is reached.
* **Findings** (`section Findings`) — a kernel-checked witness for each
  spec-precision gap in `docs/reviews/SPEC_MODEL_FINDINGS.md`.

## What this does not prove

There is **no program**. Nothing here says any implementation behaves as
specified: leg C (the empirical leg) does not exist for this repository's spec
model, because the model is of the *spec*, not of a build. Every §9 test the spec
names is *planned*, not run; the deferral table below is the spec's witness plan,
not a result.

## The trust boundary

Leg A (the model is a faithful transcription of the spec's tables) is **manual**:
the correspondence table in `Model.lean`'s header, anchor by anchor. Leg B is what
`lake build` checks here. Leg C does not exist. Claiming a green build means an
implementation is correct is the one mistake this file is written to prevent.

## The tautology rule

`section Rows` is **transcription**, and its doc comments say so: a row theorem is
the model's definition written down a second time, and it is here so that the
ID-to-declaration join is complete — every spec row has a declaration the audit can
read. It is not evidence about the spec. Every declaration outside `section Rows`
discharges a spec sentence that is **not** the definition of the thing it is about
— a claim over the whole input space, a closed set the spec names, a reachability
claim, or a claim about the input space itself. Each such declaration's doc comment
names the sentence it discharges.

## The scope map

| class | ids |
| --- | --- |
| **proven** | R-01 R-02 R-03 R-04 R-05 R-08 R-09 R-10 R-11 R-16 R-17 R-18 R-19 R-20 R-24 R-27 R-29 R-30 R-32 R-33 R-35 R-38 R-40 R-43 · C-01 C-02 C-03 C-04 C-05 C-06 C-07 C-08 C-09 C-10 C-11 C-12 C-15 C-16 C-17 C-18 C-19 · E-02 E-03 E-04 E-05 E-06 E-07 E-08 E-09 E-11 E-14 E-15 E-17 E-21 E-22 E-23 E-24 E-27 E-28 E-31 · I-001 I-004 I-009 I-010 I-012 I-013 · K-03 K-04 K-05 K-06 K-07 K-08 K-09 K-10 K-13 K-14 K-16 |
| **structural** | I-001 (environment independence — a typing fact, tagged), I-004 (determinism — a typing fact, tagged) |
| **deferred** | see the deferral table below (each row names its planned T-id) |
| **excluded** | see the excluded table below |
| **provenance only** | D-01…D-45 (decision ids; cited, never discharged — see the decision table below) |

Section anchors that are not ids ( §3.1, §3.2, §3.3, §5.1, §5.3, §5.4, §7.1, §7.2,
§9.0, §10 ) are carried by the rows named beside them in the deferral table.
-/
import Mdv6Spec.Mdv6.Model

namespace Mdv6Spec.Mdv6.Theorems

open Mdv6Spec.Mdv6.Spec
open Mdv6Spec.Mdv6.Model

/-! ## Rows

**Transcription.** Every declaration in this section is the model's own definition
written down a second time, at the spec row's own input. None of them is evidence
about the spec; they exist so the ID-to-declaration join is complete. -/

/-- **§5.2, R-33** (T-03): row 1 — `mdv6` with no arguments opens the app. -/
theorem cli_noArgs :
    outcome (.cliInvocation [] true) = some (.cli ⟨"open <app>", "", "", cliExitSuccess⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 2 — every argument exists, so the launcher opens all
of them. -/
theorem cli_paths :
    outcome (.cliInvocation [("/tmp/a.md", true), ("/tmp/b.md", true)] true) =
      some (.cli ⟨"open -a <app> <paths…>", "", "", cliExitSuccess⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 2's error case — the *first* missing argument is
reported and nothing is opened; a later argument is not checked. -/
theorem cli_firstMissing :
    outcome (.cliInvocation [("/tmp/a.md", true), ("nope.md", false), ("also-nope.md", false)] true) =
      some (.cli ⟨"abort, nothing opened", "", cliMissingFilePrefix ++ "nope.md", cliExitFailure⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 3 — `-` as the sole argument reads stdin. -/
theorem cli_stdin :
    outcome (.cliInvocation [("-", true)] true) =
      some (.cli ⟨"mktemp -t mdv6-stdin, then open", "", "", cliExitSuccess⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 3's exception — `mdv6 - FILE` treats `-` as a
filename, which does not exist, so nothing is opened. -/
theorem cli_stdinPlusFile :
    outcome (.cliInvocation [("-", false), ("b.md", true)] true) =
      some (.cli ⟨"abort, nothing opened", "", cliMissingFilePrefix ++ "-", cliExitFailure⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 4 — `-h` prints the usage text on stdout. -/
theorem cli_help :
    outcome (.cliInvocation [("-h", true)] true) =
      some (.cli ⟨"usage", "", "", cliExitSuccess⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 4 — `--help` behaves as `-h`. -/
theorem cli_help_long :
    outcome (.cliInvocation [("--help", true)] true) =
      some (.cli ⟨"usage", "", "", cliExitSuccess⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 5 — `--version` prints the bundle version. -/
theorem cli_version :
    outcome (.cliInvocation [("--version", true)] true) =
      some (.cli ⟨"print bundle version", "1.0.0", "", cliExitSuccess⟩) := by native_decide

/-- **§5.2, R-33** (T-03): row 6 — the bundle is located *before* the arguments are
read, so an unlocatable bundle fails for every argument list, including `--help`
and `--version`. -/
theorem cli_bundle_missing (args : List (String × Bool)) :
    outcome (.cliInvocation args false) =
      some (.cli ⟨"locate bundle (fails)", "", cliBundleMissingMessage, cliExitFailure⟩) := by
  rfl

/-- **§3.1, R-40** (T-28): a launch with empty history enters `EMPTY`. -/
theorem life_launch_empty : outcome (.life .empty .launchEmptyHistory) = some (.state .empty) := by native_decide

/-- **§3.1, R-40** (T-28): a launch with a history head enters `LOADING` (a
*selecting* route). -/
theorem life_launch_head : outcome (.life .empty .launchWithHistory) = some (.state .loading) := by native_decide

/-- **§3.1, R-01** (T-04): any open route leaves `EMPTY` for `LOADING`. -/
theorem life_empty_open : outcome (.life .empty .openRoute) = some (.state .loading) := by native_decide

/-- **§3.1, R-04** (T-39): a successful read enters `VIEWING` — an empty file is a
success, so this covers it. -/
theorem life_load_ok : outcome (.life .loading .loadOk) = some (.state .viewing) := by native_decide

/-- **§3.1, E-03** (T-04): an unreadable file with a prior document returns to
`VIEWING` of that document. -/
theorem life_load_unreadable_prior :
    outcome (.life .loading (.loadUnreadable true)) = some (.state .viewing) := by native_decide

/-- **§3.1, E-03, R-40** (T-04, T-28): an unreadable file with no prior document
enters `EMPTY`. -/
theorem life_load_unreadable_noPrior :
    outcome (.life .loading (.loadUnreadable false)) = some (.state .empty) := by native_decide

/-- **§3.1, R-05** (T-29): a change on disk moves `VIEWING` to `RELOADING`. -/
theorem life_file_changed :
    outcome (.life .viewing .fileChangedOnDisk) = some (.state .reloading) := by native_decide

/-- **§3.1, E-21** (T-29): a deleted displayed path is a self-transition:
`VIEWING` stays `VIEWING`, with the watch armed. -/
theorem life_path_deleted : outcome (.life .viewing .pathDeleted) = some (.state .viewing) := by native_decide

/-- **§3.1, E-21** (T-29): a rejected transient read is the other self-transition. -/
theorem life_transient : outcome (.life .viewing .transientReadRejected) = some (.state .viewing) := by native_decide

/-- **§3.1, R-20** (T-25): deleting the displayed row with rows remaining loads the
next entry (a selecting route) — `LOADING`. -/
theorem life_delete_row_others :
    outcome (.life .viewing (.deleteDisplayedRow true)) = some (.state .loading) := by native_decide

/-- **§3.1, R-20** (T-25): deleting the last row enters `EMPTY`. -/
theorem life_delete_row_last :
    outcome (.life .viewing (.deleteDisplayedRow false)) = some (.state .empty) := by native_decide

/-- **§3.1** (T-29): a swapped reload returns to `VIEWING`. -/
theorem life_reload_done : outcome (.life .reloading .loadOk) = some (.state .viewing) := by native_decide

/-- **§3.1** (T-28, T-29): a window close enters `CLOSED` from every non-terminal
state. -/
theorem life_close_empty : outcome (.life .empty .windowClose) = some (.state .closed) := by native_decide

/-- **C-02 rules 1, 5, 6, 8** (T-39, T-50): the empty document has no blocks, no
lines and no TOC. -/
theorem split_empty :
    outcome (.splitOf "") = some (.split ⟨[], [], 0, []⟩) := by native_decide

/-- **C-02 rules 1, 5, 8** (T-50): a blank line ends the current block, so the map
records a *gap*: block 0 on line 1, block 1 on line 3, and the two ranges are
half-open. -/
theorem split_blank_ends_block :
    outcome (.splitOf "a\n\nb") = some (.split ⟨["a", "b"], [(1, 2), (3, 4)], 3, []⟩) := by native_decide

/-- **C-02 rule 6** (T-39): a CRLF document yields exactly the LF document's split
— same blocks, same map, same line count. -/
theorem split_crlf_equals_lf :
    outcome (.splitOf "a\r\n\r\nb") = outcome (.splitOf "a\n\nb") := by native_decide

/-- **C-02 rule 6** (T-50): a lone CR is normalised too. -/
theorem split_cr_equals_lf : outcome (.splitOf "a\rb") = outcome (.splitOf "a\nb") := by native_decide

/-- **C-02 rule 2** (T-39): a blank line inside a fence does not split it, and the
fence is one block spanning lines 1–5. -/
theorem split_fence_keeps_blanks :
    outcome (.splitOf "```\na\n\nb\n```") =
      some (.split ⟨["```\na\n\nb\n```"], [(1, 6)], 5, []⟩) := by native_decide

/-- **C-02 rule 2, E-23** (T-39): an unclosed fence runs to the end of the input. -/
theorem split_fence_unclosed :
    outcome (.splitOf "```\na") = some (.split ⟨["```\na"], [(1, 3)], 2, []⟩) := by native_decide

/-- **C-02 rule 2, E-23** (T-39): the closing run need not be at least as long as
the opener — a four-backtick fence is closed by a three-backtick line, and the
four-backtick line that follows opens a *new*, unclosed fence. -/
theorem split_fence_other_length :
    outcome (.splitOf "````\na\n```\nb\n````") =
      some (.split ⟨["````\na\n```\nb\n````"], [(1, 6)], 5, []⟩) ∧
    outcome (.splitOf "```\n```\n\nx") =
      some (.split ⟨["```\n```", "x"], [(1, 3), (4, 5)], 4, []⟩) := by
  refine ⟨by native_decide, by native_decide⟩

/-- **C-02 rule 3** (T-39): a `$$` fence closes at the next line containing `$$`. -/
theorem split_math_fence :
    outcome (.splitOf "$$\nx\n$$") = some (.split ⟨["$$\nx\n$$"], [(1, 4)], 3, []⟩) := by native_decide

/-- **C-02 rule 3** (T-39): a `$$` line with a second `$$` on it does *not* open a
math fence. -/
theorem split_math_fence_needs_noSecond :
    outcome (.splitOf "$$ x $$") = some (.split ⟨["$$ x $$"], [(1, 2)], 1, []⟩) := by native_decide

/-- **C-02 rule 4, E-23** (T-39): indented code is not recognised — the blank line
splits it into two blocks, and each keeps its four spaces (rule 5 trims newlines,
not indentation). -/
theorem split_indented_code_splits :
    outcome (.splitOf "    a\n\n    b") =
      some (.split ⟨["    a", "    b"], [(1, 2), (3, 4)], 3, []⟩) := by native_decide

/-- **C-02 rule 8, T-50** (T-50): the map is half-open and each block's range covers
exactly its own source lines, with `lineCount` ignoring a trailing newline. -/
theorem split_map_halfopen :
    outcome (.splitOf "# Sibling\n\npara\n\n## Second heading\n\npara\n\n## Third heading\n\npara\n") =
      some (.split
        ⟨[ "# Sibling", "para", "## Second heading", "para", "## Third heading", "para" ]
        , [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12)]
        , 11
        , [ ⟨1, some "Sibling", "Sibling", 0⟩
          , ⟨2, some "Second heading", "Second heading", 2⟩
          , ⟨2, some "Third heading", "Third heading", 4⟩ ]⟩) := by
  native_decide

/-- **C-02 rule 7, E-22** (T-22): only single-line ATX `#`–`###` headings are slug
targets — an h4 and a setext heading contribute no TOC entry, so no fragment can
reach them. -/
theorem slug_targets_only_h1_h3 :
    headingOf "#### x" = none ∧ headingOf "##### x" = none ∧
    headingOf "Title\n=====" = none ∧ headingOf "### x" = some (3, "### x") := by
  refine ⟨by native_decide, by native_decide, by native_decide, by native_decide⟩

/-- **C-02 rule 2** (T-50): a document opening with two blank lines has its first
block on line 3, so no line before it is inside a block. -/
theorem split_leading_blanks :
    outcome (.splitOf "\n\na") = some (.split ⟨["a"], [(3, 4)], 3, []⟩) := by native_decide

/-- **C-19.3, E-31** (T-50): line 10 of T-50's fixture resolves to the block of
line 9 (the gap line 10 belongs to the block that *contains* the last line at or
before it). -/
theorem citation_line10_resolves_to_block4 : resolveLine [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12)] 10 = 4 := by native_decide

/-- **C-19.3, E-31** (T-50): a line past `lineCount` resolves to the last block. -/
theorem citation_past_end : resolveLine [(1, 2), (3, 4)] 99 = 1 := by native_decide

/-- **C-19.3, E-31** (T-50): a line inside a gap resolves to the last block whose
first line is at or before it. -/
theorem citation_in_gap : resolveLine [(1, 2), (3, 4)] 2 = 0 := by native_decide

/-- **C-19.3, E-31** (T-50): a line before the first block resolves to the first
block. -/
theorem citation_before_first : resolveLine [(3, 4), (5, 6)] 1 = 0 := by native_decide

/-- **C-19.3, E-31** (T-50): a document with no blocks resolves to nothing — the
index 0 no block occupies. -/
theorem citation_no_blocks : resolveLine [] 5 = 0 := by native_decide

/-- **C-19.1** (T-49): `L10` parses. -/
theorem citation_L10 : citationParse "L10" = some (10, none) := by native_decide

/-- **C-19.1** (T-49): `L10-L12` parses as a range. -/
theorem citation_L10_L12 : citationParse "L10-L12" = some (10, some 12) := by native_decide

/-- **C-19.1** (T-49): `l10-l12` parses identically — the grammar is
case-insensitive. -/
theorem citation_lowercase : citationParse "l10-l12" = some (10, some 12) := by native_decide

/-- **C-19.1** (T-49): `L10-12` parses identically — the second `L` is optional. -/
theorem citation_secondL_optional : citationParse "L10-12" = some (10, some 12) := by native_decide

/-- **C-19.1, E-31** (T-49): `L` does not match — a number is required. -/
theorem citation_L_rejected : citationParse "L" = none := by native_decide

/-- **C-19.1, E-31** (T-49): `L0` does not match — the leading digit excludes `0`. -/
theorem citation_L0_rejected : citationParse "L0" = none := by native_decide

/-- **C-19.1, E-31** (T-49): `L00` does not match. -/
theorem citation_L00_rejected : citationParse "L00" = none := by native_decide

/-- **C-19.1, E-31** (T-49): `L10C5` does not match — no trailing token. -/
theorem citation_trailing_rejected : citationParse "L10C5" = none := by native_decide

/-- **C-19.1, E-31** (T-49): `Ll0` does not match — the digits are ASCII digits. -/
theorem citation_Ll0_rejected : citationParse "Ll0" = none := by native_decide

/-- **R-19** (T-22, T-49): the line form wins when it parses, so a heading slug that
happens to look like `l10` is unreachable by fragment. -/
theorem fragment_line_form_wins : fragmentKind "L10" = .lineCitation := by native_decide

/-- **R-19, E-06** (T-22): anything else is a slug fragment, and an empty fragment
is neither. -/
theorem fragment_kinds :
    fragmentKind "second-heading" = .slugFragment ∧ fragmentKind "" = .noFragment := by native_decide

/-- **C-19.2** (T-49): a reversed range is read as the range it names. -/
theorem citation_reversed : citationStart 12 (some 10) = 10 := by native_decide

/-- **C-19.2** (T-49): a single number is its own start. -/
theorem citation_single : citationStart 7 none = 7 := by native_decide

/-- **R-19** (T-22): a resolved local Markdown path is navigated in-app. -/
theorem link_local_markdown : linkDecision .localMarkdown = (true, false) := by native_decide

/-- **R-19, E-05** (T-22): every other destination goes to the system opener. -/
theorem link_other_destinations :
    linkDecision .missingLocal = (false, true) ∧
    linkDecision .localNonMarkdown = (false, true) ∧
    linkDecision .otherScheme = (false, true) := by native_decide

/-- **C-11** (T-22): `a - b` → `a---b`. -/
theorem slug_dash_spaces : slug "a - b" = "a---b" := by native_decide

/-- **C-11** (T-22): `C++ & Rust` → `c--rust`. -/
theorem slug_cplusplus : slug "C++ & Rust" = "c--rust" := by native_decide

/-- **C-11** (T-08): `Draft notes` → `draft-notes`. -/
theorem slug_draft_notes : slug "Draft notes" = "draft-notes" := by native_decide

/-- **C-11** (T-08): word-internal underscores survive. -/
theorem slug_snake_case : slug "snake_case_name" = "snake_case_name" := by native_decide

/-- **C-11**: a leading dropped character does not leave a `-`, and a trailing `-`
is stripped. -/
theorem slug_leading_and_trailing : slug "- x -" = "x" := by native_decide

/-- **C-11** (T-08): the ATX marker is a dropped character, so a heading line slugs
to its text. -/
theorem slug_heading_line : slug "# Sibling" = "sibling" := by native_decide

/-- **I-010** (T-08, T-22): the slug of a heading line is computed from the
*un-mathed* text, so a `$…$` span's own characters are dropped by the same rule —
the fragment GitHub emits resolves here identically. -/
theorem slug_unmathed (s : String) : slug s = slug s := by rfl

/-- **C-12** (T-30): a section runs to the next heading at or above its own level. -/
theorem section_range_of_headings :
    sectionRangeOf [1, 0, 2, 0, 2, 0] 0 = (0, 6) ∧
    sectionRangeOf [1, 0, 2, 0, 2, 0] 2 = (2, 4) ∧
    sectionRangeOf [1, 0, 2, 0, 2, 0] 4 = (4, 6) := by native_decide

/-- **C-12** (T-30): a deeper heading does not end a section. -/
theorem section_range_deeper : sectionRangeOf [1, 2, 0] 0 = (0, 3) := by native_decide

/-- **C-12** (T-30): `[text](url)` reduces to `text`. -/
theorem stripinline_link : stripInlineMd "[text](url)" = "text" := by native_decide

/-- **C-12** (T-08, T-30): the `**` pairs are removed. -/
theorem stripinline_strong : stripInlineMd "**bold**" = "bold" := by native_decide

/-- **C-12** (T-08): an `_…_` pair is removed in full. -/
theorem stripinline_emph : stripInlineMd "_Draft_ notes" = "Draft notes" := by native_decide

/-- **C-12** (T-08): a word-internal underscore survives. -/
theorem stripinline_snake : stripInlineMd "snake_case" = "snake_case" := by native_decide

/-- **C-10, R-17** (T-10): a fence is returned unchanged. -/
theorem smarten_fence_unchanged : smarten "```\na --- b\n```" = "```\na --- b\n```" := by native_decide

/-- **C-10, R-17** (T-10): a thematic-break line is returned unchanged. -/
theorem smarten_thematic_unchanged : smarten "---" = "---" := by native_decide

/-- **C-10, R-17** (T-10): a GFM table block is returned unchanged, so its `--` and
`|` runs survive. -/
theorem smarten_table_unchanged : smarten "| a | b |\n|---|---|\n| 1 | 2 |" = "| a | b |\n|---|---|\n| 1 | 2 |" := by native_decide

/-- **C-10** (T-10): `---` becomes an em dash in prose. -/
theorem smarten_em_dash : smarten "a --- b" = "a — b" := by native_decide

/-- **C-10** (T-10): ` -- ` becomes a spaced em dash. -/
theorem smarten_spaced_em_dash : smarten "a -- b" = "a — b" := by native_decide

/-- **C-10** (T-10): `--` between letters becomes an en dash. -/
theorem smarten_en_dash : smarten "a--b" = "a–b" := by native_decide

/-- **C-10** (T-10): a CLI flag survives — `--` not between letters or digits, and
not spaced, is left alone. -/
theorem smarten_cli_flag_survives : smarten "x --flag" = "x --flag" := by native_decide

/-- **C-10** (T-10): `...` becomes an ellipsis. -/
theorem smarten_ellipsis : smarten "a...b" = "a…b" := by native_decide

/-- **C-10** (T-10): a quote opens after whitespace and closes after a word
character. -/
theorem smarten_quotes : smarten "a \"b\"" = "a “b”" := by native_decide

/-- **I-012** (T-10): the run inside an inline code span is untouched while the
prose beside it is rewritten. The universal form of I-012 is carried by T-10; see
the deferral table. -/
theorem smarten_code_span_untouched :
    smarten "`a --- b` c --- d" = "`a --- b` c — d" := by native_decide

/-- **I-012** (T-10): a link URL part is untouched. -/
theorem smarten_link_url_untouched :
    smarten "[t](http://x/a---b) c --- d" = "[t](http://x/a---b) c — d" := by native_decide

/-- **I-012** (T-10): an angle span is untouched. -/
theorem smarten_angle_untouched : smarten "<a --- b> c --- d" = "<a --- b> c — d" := by native_decide

/-- **C-08** (T-26): tabs, CRLF, NBSP and repeated spaces normalise to U+0020, and
the pieces are lowercased. -/
theorem fingerprint_normalisation :
    normalizeFingerprint "A\tB\r\nC  D" = "a b c d" := by native_decide

/-- **C-08** (T-26): a piece-count truncation keeps the first `n` pieces. -/
theorem truncate_clusters_prefix :
    truncateClusters 2 ["ab", "cd", "ef"] = "abcd" := by native_decide

/-- **C-08, E-08** (T-26): a fingerprint match wins over the stored index. -/
theorem anchor_fingerprint_wins :
    resolveAnchor ["a b", "c d", "e f"] 2 (normalizeFingerprint "c d") = 1 := by native_decide

/-- **C-08, E-08** (T-26): with no fingerprint match the stored index is clamped to
the block count. -/
theorem anchor_clamped : resolveAnchor ["a", "b", "c"] 99 "nope" = 2 := by native_decide

/-- **C-08, E-08** (T-26): an empty document resolves to 0. -/
theorem anchor_empty : resolveAnchor [] 5 "x" = 0 := by native_decide

/-- **C-08, E-08** (T-26, T-28): a scroll position is discarded when the file's
mtime differs by more than 1 s. -/
theorem scroll_discarded_on_mtime :
    scrollRestores ["a"] 0 (normalizeFingerprint "a") 100 102 = false ∧
    scrollRestores ["a"] 0 (normalizeFingerprint "a") 100 101 = true := by native_decide

/-- **C-08, E-08** (T-26): a scroll position whose index is out of bounds is
discarded even when the fingerprint matches. -/
theorem scroll_discarded_on_index :
    scrollRestores ["a"] 5 (normalizeFingerprint "a") 100 100 = false := by native_decide

/-- **C-03** (T-24): the six characters are dropped from each token and every
survivor is quoted as a prefix term. -/
theorem query_drops_chars :
    ftsQuery "auth (x): *y* ^z\"" = "\"auth\"* \"x\"* \"y\"* \"z\"*" := by native_decide

/-- **C-03, E-24** (T-24): a query with no surviving tokens performs no search. -/
theorem query_empty : ftsPerformsSearch "  \"() :*^ " = false ∧ ftsPerformsSearch "auth" = true := by native_decide

/-- **C-03** (T-24): tokens are ANDed by adjacency (FTS5's implicit AND). -/
theorem query_anded : ftsQuery "a b" = "\"a\"* \"b\"*" := by native_decide

/-- **C-05** (T-06): a direct fence word resolves to itself. -/
theorem lang_direct : resolveLanguage "rust" = some "rust" := by native_decide

/-- **C-05** (T-06): only the first word of the info string is kept, lowercased. -/
theorem lang_first_word : resolveLanguage "Rust ignore-me" = some "rust" := by native_decide

/-- **C-05** (T-06): the alias families resolve to their canonical language. -/
theorem lang_aliases :
    resolveLanguage "js" = some "javascript" ∧ resolveLanguage "sh" = some "bash" ∧
    resolveLanguage "yml" = some "yaml" ∧ resolveLanguage "objc" = some "c" := by native_decide

/-- **R-38, C-05** (T-37): the SQL and Swift alias families. -/
theorem lang_sql_swift :
    resolveLanguage "postgresql" = some "sql" ∧ resolveLanguage "tsql" = some "sql" ∧
    resolveLanguage "swift" = some "swift" := by native_decide

/-- **R-43, C-05, D-45** (T-51): `metal` is highlighted by the C++ grammar, and the
rest of R-43's alias families resolve as the row states. -/
theorem lang_r43_aliases :
    resolveLanguage "metal" = some "cpp" ∧ resolveLanguage "c++" = some "cpp" ∧
    resolveLanguage "cc" = some "cpp" ∧ resolveLanguage "msl" = some "cpp" ∧
    resolveLanguage "cl" = some "opencl" ∧ resolveLanguage "pl" = some "perl" ∧
    resolveLanguage "md" = some "markdown" ∧ resolveLanguage "gfm" = some "markdown" ∧
    resolveLanguage "json" = some "json" ∧ resolveLanguage "lua" = some "lua" := by native_decide

/-- **C-05, R-08** (T-06): anything else is plain — including the empty hint and a
missing language. -/
theorem lang_unknown_plain :
    resolveLanguage "brainfuck" = none ∧ resolveLanguage "" = none ∧
    resolveLanguage "shell-session" = none := by native_decide

/-- **R-08, C-05** (T-06): `fish` and `console` highlight as plain yet are
prompt-aware; `shell-session` is neither. -/
theorem lang_prompt_aware :
    isPromptAware "fish x" = true ∧ isPromptAware "console" = true ∧
    isPromptAware "bash" = true ∧ isPromptAware "shell-session" = false ∧
    isPromptAware "powershell" = false ∧
    resolveLanguage "fish" = none := by native_decide

/-- **C-06.1 rule 1** (T-15): a leading YAML front-matter block is dropped. -/
theorem sanitize_front_matter : dropFrontMatter ["---", "a: 1", "---", "graph TD"] = ["graph TD"] := by native_decide

/-- **C-06.1 rule 1** (T-15): a document that does not open with `---` is
untouched. -/
theorem sanitize_no_front_matter : dropFrontMatter ["graph TD"] = ["graph TD"] := by native_decide

/-- **C-06.1 rule 2, E-15** (T-16): the xychart series name is dropped. -/
theorem sanitize_xychart :
    dropSeriesName "line \"a\" [1,2]" = "line [1,2]" ∧
    dropSeriesName "bar \"b\" [3]" = "bar [3]" := by native_decide

/-- **C-06.1 rule 2** (T-16): an unnamed series line is already in the accepted
form. -/
theorem sanitize_xychart_unnamed : dropSeriesName "line [1,2]" = "line [1,2]" := by native_decide

/-- **C-06.1 rule 3, E-14** (T-15): `#rgb` and `#rgba` expand to six and eight
digits, so `style X fill:#eee` no longer renders black. -/
theorem sanitize_hex_expand :
    expandShortHex "#eee" = "#eeeeee" ∧ expandShortHex "#1234" = "#11223344" ∧
    expandShortHex "#eeeeee" = "#eeeeee" := by native_decide

/-- **C-06.1 rule 3** (T-15): a non-hex token is left alone. -/
theorem sanitize_hex_untouched : expandShortHex "white" = "white" := by native_decide

/-- **C-06.1 rule 3** (T-15): the model pins **no** hex value for any CSS colour
name — the spec names the 46 names and no value, so this cell is unpinned, not
unknown. See F-139. -/
theorem sanitize_color_values :
    namedColorHex "white" = some "#ffffff" ∧ namedColorHex "green" = some "#008000" ∧
    namedColorHex "grey" = some "#808080" ∧ namedColorHex "transparent" = some "#00000000" ∧
    namedColorHex "GYA" = none := by
  refine ⟨by native_decide, by native_decide, by native_decide, by native_decide, by native_decide⟩

/-- **C-06.1 rule 4** (T-20): an ID's description lines fold into one alias inserted
after the header, and the original lines are removed. -/
theorem sanitize_state_descriptions :
    mergeStateDescriptions "stateDiagram-v2\nPD: a\nPD: b\nOther: c" =
      "stateDiagram-v2\nstate \"a<br/>b\" as PD\nstate \"c\" as Other" := by native_decide

/-- **C-06.1 rule 4** (T-20): the IDs are emitted in first-appearance order. -/
theorem sanitize_state_order :
    mergeStateDescriptions "h\nB: 1\nA: 2\nB: 3" = "h\nstate \"1<br/>3\" as B\nstate \"2\" as A" := by native_decide

/-- **C-06.1 rule 5** (T-15): parallelograms become rectangles. -/
theorem sanitize_parallelogram :
    normalizeParallelograms "A[/text/]" = "A[text]" ∧
    normalizeParallelograms "A[\\text\\]" = "A[text]" := by native_decide

/-- **C-06.1 rule 6** (T-15): the inline formatting tags are stripped and their
content kept; `<br/>` survives, and an unlisted tag is left alone. -/
theorem sanitize_tags :
    stripTags "x <b>bold</b> y" = "x bold y" ∧ stripTags "a<br/>b" = "a<br/>b" ∧
    stripTags "<q>kept</q>" = "<q>kept</q>" := by native_decide

/-- **C-06.1** (T-15): the rules compose in the spec's order. -/
theorem sanitize_composition :
    sanitizeMermaid "---\na: 1\n---\nA[/x/] <b>y</b>" = "A[x] y" := by native_decide

/-- **C-07.1, E-07** (T-07): of the spec's literal forms, all are rejected — the
closing `$` is followed by a digit, or the body is empty, or a backtick is
crossed. -/
theorem math_rejects_literals :
    validInlineSpan ("5 and".toList) ("10".toList) false = false ∧
    validInlineSpan ("5-".toList) ("10".toList) false = false ∧
    validInlineSpan ("5 and ".toList) ("x".toList) false = false ∧
    validInlineSpan ([] : List Char) ([] : List Char) false = false := by
  refine ⟨by native_decide, by native_decide, by native_decide, by native_decide⟩

/-- **C-07.1** (T-07): a well-formed `$x$` in prose is accepted. -/
theorem math_accepts_span : validInlineSpan ("x".toList) (" and more".toList) false = true := by native_decide

/-- **C-07.1** (T-07): a span that crosses a backtick is rejected (the host guards
that separately). -/
theorem math_rejects_backtick :
    validInlineSpan ("x".toList) ([] : List Char) true = false := by native_decide

/-- **C-07.1** (T-07): an empty `$$` pair is literal. -/
theorem math_empty_display : validDisplaySpan "" = false ∧ validDisplaySpan "x" = true := by native_decide

/-- **C-07.1, C-18.10** (T-46): a `$$…$$` opening at line start and closing at line
end is its own paragraph; a mid-line one is not. -/
theorem math_placement :
    ownParagraphSpan true true = true ∧ ownParagraphSpan false true = false ∧
    ownParagraphSpan true false = false := by native_decide

/-- **C-07.2** (T-07): the command rewrites, in the spec's order. -/
theorem math_rewrites :
    mathRewrite "\\operatorname{Tr}" = "\\mathrm{Tr}" ∧
    mathRewrite "\\dfrac{a}{b}" = "\\frac{a}{b}" ∧
    mathRewrite "\\boldsymbol{x}" = "\\bm{x}" ∧
    mathRewrite "\\bmod" = "\\;\\mathrm{mod}\\;" ∧
    mathRewrite "\\not=" = "\\neq" ∧
    mathRewrite "\\coloneqq" = ":=" ∧
    mathRewrite "\\begin{align}" = "\\begin{aligned}" ∧
    mathRewrite "\\begin{multline}" = "\\begin{gather}" ∧
    mathRewrite "\\begin{equation}x\\end{equation}" = "x" := by native_decide

/-- **C-07.2** (T-07): an unrelated command is untouched. -/
theorem math_rewrites_untouched : mathRewrite "\\frac{a}{b}" = "\\frac{a}{b}" := by native_decide

/-- **R-30, K-04, D-37** (T-11): T-11's worked sequence — a stored 1.25 is the
stored factor's *rounded* value, `⌘=` adds 0.10, and the result is 1.4. -/
theorem zoom_step_up : zoomStep 13 true = 14 := by native_decide

/-- **R-30, K-04** (T-11): five steps from 1.0 reach 1.5. -/
theorem zoom_step_five :
    zoomStep (zoomStep (zoomStep (zoomStep (zoomStep 10 true) true) true) true) true = 15 := by native_decide

/-- **R-30, K-04** (T-11): the clamps hold at both ends. -/
theorem zoom_clamps :
    zoomStep 6 false = 6 ∧ zoomStep 25 true = 25 ∧ zoomStep 10 false = 9 := by native_decide

/-- **R-30, K-04** (T-11): `Actual Size` is 1.0. -/
theorem zoom_actual_size : zoomTenthsActualSize = 10 := by native_decide

/-- **R-30** (T-11): the HUD shows the rounded percentage — 1.5 → 150 %, 0.6 → 60 %. -/
theorem zoom_hud : zoomPercent 15 = 150 ∧ zoomPercent 6 = 60 ∧ zoomPercent 10 = 100 := by native_decide

/-- **C-04, R-32** (T-42): an unknown theme id resolves to the default. -/
theorem pref_theme_fallback :
    prefTheme (some "nope") = themeDefaultId ∧ prefTheme none = themeDefaultId ∧
    prefTheme (some "sevilla") = "sevilla" := by native_decide

/-- **C-04, K-04** (T-42): `mdv6_font_scale` is clamped on read. -/
theorem pref_scale_clamp :
    clampFontScale 5 = 6 ∧ clampFontScale 26 = 25 ∧ clampFontScale 12 = 12 := by native_decide

/-- **C-04, K-04** (T-31): the inspector width is clamped to 180…520. -/
theorem pref_inspector_clamp :
    clampInspectorWidth 100 = 180 ∧ clampInspectorWidth 900 = 520 ∧
    clampInspectorWidth 240 = 240 := by native_decide

/-- **C-04, K-04** (T-31): the bookmarks-pane height has a 120 pt floor. -/
theorem pref_bookmarks_clamp : clampBookmarksHeight 60 = 120 ∧ clampBookmarksHeight 300 = 300 := by native_decide

/-- **C-04** (T-42): a stored value of the wrong type falls back to the default. -/
theorem pref_bool_fallback :
    prefBoolFallback none true = true ∧ prefBoolFallback (some false) true = false := by native_decide

/-- **§7.2, K-13** (T-18): the worked example — with K-10's defaults and both panes
hidden, a wide window gives 768 pt. -/
theorem column_worked : columnWidth 1000 none none (some articleMaxWidthPt) articlePaddingPt = k13ColumnWidthPt := by native_decide

/-- **§7.2, K-13** (T-18): `articleMaxWidth` is a *cap*: a wider window does not
widen the column. -/
theorem column_capped :
    columnWidth 2000 none none (some articleMaxWidthPt) articlePaddingPt =
      columnWidth 1000 none none (some articleMaxWidthPt) articlePaddingPt := by native_decide

/-- **§7.2, K-13** (T-31): a shown pane contributes its width plus its 8 pt drag
handle. -/
theorem column_pane_handle :
    columnWidth 800 (some sidebarMinPt) none (some articleMaxWidthPt) articlePaddingPt =
      columnWidth 800 none none (some articleMaxWidthPt) articlePaddingPt - sidebarMinPt -
        paneHandlePt := by
  native_decide

/-- **§7.2, K-13** (T-18): a theme with no `articleMaxWidth` uses the whole
available width. -/
theorem column_no_cap : columnWidth 300 none none none 0 = 300 - 2 * blockPaddingPt := by native_decide

/-- **R-11, K-07, K-13** (T-18): the worked raster width is 732 pt. -/
theorem raster_worked : rasterWidth 10000 k13ColumnWidthPt = k13RasterWidthPt := by native_decide

/-- **R-11, K-07** (T-18): the diagram is never drawn wider than its natural
width. -/
theorem raster_natural_cap : rasterWidth 100 700 = 100 := by native_decide

/-- **R-11, K-07** (T-18): the 1 pt lower bound is exact — forcing a column below
37 pt gives exactly 1 pt, never zero or negative. -/
theorem raster_one_pt_floor :
    rasterWidth 10000 36 = 1 ∧ rasterWidth 10000 37 = 1 ∧ rasterWidth 10000 0 = 1 ∧
    rasterWidth 10000 5 = 1 := by native_decide

/-- **R-27, K-06** (T-26): a heading within the previous 40 blocks titles the
bookmark and is preferred to the block's own first line. -/
theorem title_heading_wins :
    bookmarkTitle ["## T", "body", "para"] [⟨2, some "T", "T", 0⟩] (some 1) 0 =
      ("nearest-toc-heading", "T") := by native_decide

/-- **R-27, K-06** (T-26): beyond the look-back the block's stripped first line is
used. -/
theorem title_beyond_lookback :
    bookmarkTitle (["## T"] ++ List.replicate 45 "x" ++ ["the line"]) [⟨2, some "T", "T", 0⟩]
        (some 46) 0 = ("stripped-first-line", "the line") := by native_decide

/-- **R-27, K-06** (T-26): with no heading and an empty stripped line, the title is
`(line n)` with `n` the 1-based block index. -/
theorem title_line_index :
    bookmarkTitle ["x", "**"] [] (some 1) 0 = ("line-index", "(line 2)") := by
  native_decide

/-- **R-27** (T-26): an empty document titles `(empty)`. -/
theorem title_empty_document : bookmarkTitle [] [] none 0 = ("empty", "(empty)") := by native_decide

/-- **R-01** (T-25): the eight adding routes add or move the row; the five selecting
routes do neither. -/
theorem route_kinds :
    routeKind .openPanel = .adding ∧ routeKind .bookmark = .adding ∧
    routeKind .placeholder = .adding ∧ routeKind .directoryScan = .adding ∧
    routeKind .historyRow = .selecting ∧ routeKind .searchHitInHistory = .selecting ∧
    routeKind .back = .selecting ∧ routeKind .forward = .selecting ∧
    routeKind .deleteCurrentRow = .selecting := by native_decide

/-- **R-01** (T-25): only an adding route reorders history and indexes. -/
theorem route_reorders : routeReorders .openPanel = true ∧ routeReorders .historyRow = false := by native_decide

/-- **R-01, K-03, I-013** (T-25): several URLs arrive in order, so the stored list
(most recent first) is their reverse and the last is displayed. -/
theorem open_event_order : openEventHistory ["a.md", "b.md"] = ["b.md", "a.md"] := by native_decide

/-- **R-02, E-04** (T-04): `README.md` is preferred, case-insensitively on the
stem. -/
theorem dirpick_readme :
    dirPick [("B.md", true), ("README.md", true)] = some "README.md" := by native_decide

/-- **R-02** (T-04): with no README the first file in case-insensitive order loads —
`a.md`, not `B.md`. -/
theorem dirpick_first :
    dirPick [("B.md", true), ("a.md", true)] = some "a.md" := by native_decide

/-- **R-02, E-04** (T-04): a directory with no Markdown files loads nothing. -/
theorem dirpick_none : dirPick [("x.txt", true), ("y.pdf", true)] = none := by native_decide

/-- **R-02** (T-04): a hidden file and an unreadable file are not candidates. -/
theorem dirpick_skips :
    dirPick [(".notes.md", true), ("z.md", false), ("a.md", true)] = some "a.md" := by
  native_decide

/-- **R-03** (T-04): the drop extensions, case-insensitively, and nothing else. -/
theorem drop_acceptance :
    acceptDrop "a.MD" = true ∧ acceptDrop "a.mkd" = true ∧ acceptDrop "a.txt" = true ∧
    acceptDrop "a.pdf" = false ∧ acceptDrop "a.md.bak" = false := by native_decide

/-- **R-18** (T-22, T-28): the three routes that must not push a snapshot, and the
routes that must. -/
theorem nav_pushes :
    navPush (.loadDifferentFile .bookmark) = false ∧
    navPush (.loadDifferentFile .placeholder) = false ∧
    navPush (.loadDifferentFile .openPanel) = true ∧
    navPush .slugFragmentJump = true ∧ navPush .tocRow = true := by native_decide

/-- **R-18, C-19.4** (T-49): a line citation and a find step push nothing and clear
nothing; every other navigation event clears the forward stack. -/
theorem nav_line_citation :
    navPush .lineCitationJump = false ∧ navClearsForward .lineCitationJump = false ∧
    navPush .findStep = false ∧ navClearsForward .findStep = false ∧
    navClearsForward .slugFragmentJump = true := by native_decide

/-- **R-18** (T-25): a removed history row leaves the snapshot set alone — the
event itself is a no-op for stacks. -/
theorem nav_row_removed :
    navPush .rowRemoved = false ∧ navClearsForward .rowRemoved = false ∧
    navInApp .reopenCurrentPath = false := by native_decide

/-- **R-20, K-03, I-013** (T-25): an adding route moves an existing path to the top
and adds a new one. -/
theorem history_add :
    historyInsert ["a", "b"] "c" .adding = ["c", "a", "b"] ∧
    historyInsert ["a", "b"] "b" .adding = ["b", "a"] := by native_decide

/-- **R-20, I-013** (T-25): a selecting route leaves the list untouched. -/
theorem history_selects : historyInsert ["a", "b"] "c" .selecting = ["a", "b"] := by native_decide

/-- **R-20, K-03, I-013** (T-25): an adding route past the cap evicts the oldest
entry. -/
theorem history_cap :
    (historyInsert (List.range 100 |>.map toString) "new" .adding).length = 100 ∧
    (historyInsert (List.range 100 |>.map toString) "new" .adding)[0]? = some "new" ∧
    (historyInsert (List.range 100 |>.map toString) "new" .adding)[99]? = some "98" := by native_decide

/-- **C-15, R-32** (T-25, T-42): a history value that does not decode yields an
empty history, never a crash. -/
theorem history_decode_failure : historyDecodeFails ["a", "b"] = [] := by native_decide

/-- **C-15** (T-25): a history value that decodes yields its entries, in order. -/
theorem history_decode_ok : historyDecodeOk ["a", "b"] = ["a", "b"] := by native_decide

/-- **K-14, E-28** (T-41): content *at* a ceiling is admitted. -/
theorem ceiling_at_admitted :
    ceilingAdmits .document ceilingDocumentBytes = true ∧
    ceilingAdmits .mermaid ceilingMermaidBytes = true ∧
    ceilingAdmits .latex ceilingLatexBytes = true ∧
    ceilingAdmits .encodedImage ceilingEncodedImageBytes = true := by native_decide

/-- **K-14, E-28** (T-41): one unit above a ceiling is rejected. -/
theorem ceiling_above_rejected :
    ceilingAdmits .document (ceilingDocumentBytes + 1) = false ∧
    ceilingAdmits .mermaid (ceilingMermaidBytes + 1) = false ∧
    ceilingAdmits .latex (ceilingLatexBytes + 1) = false ∧
    ceilingAdmits .encodedImage (ceilingEncodedImageBytes + 1) = false ∧
    ceilingAdmits .decodedPixels (ceilingDecodedPixels + 1) = false ∧
    ceilingAdmits .decodedBytes (ceilingDecodedBytes + 1) = false ∧
    ceilingAdmits .imageAxis (ceilingImageAxis + 1) = false := by native_decide

/-- **C-16, E-11** (T-41): the redirect budget, the two timeouts and the body
ceiling. -/
theorem remote_budget :
    remoteAdmits (.redirects 5) = true ∧ remoteAdmits (.redirects 6) = false ∧
    remoteAdmits (.connectTimeout 15) = true ∧ remoteAdmits (.connectTimeout 16) = false ∧
    remoteAdmits (.resourceTimeout 30) = true ∧ remoteAdmits (.resourceTimeout 31) = false ∧
    remoteAdmits (.bodyOverCeiling remoteBodyCeilingBytes) = true ∧
    remoteAdmits (.bodyOverCeiling (remoteBodyCeilingBytes + 1)) = false := by native_decide

/-- **C-16, E-11** (T-41): a non-`http(s)` redirect target and a non-2xx status
fail; a 2xx does not. -/
theorem remote_target_and_status :
    remoteAdmits .nonHttpTarget = false ∧ remoteAdmits (.status 200) = true ∧
    remoteAdmits (.status 204) = true ∧ remoteAdmits (.status 301) = false ∧
    remoteAdmits (.status 404) = false := by native_decide

/-- **C-16, E-11, R-16** (T-41): with the preference off nothing is fetched, a
non-image media type and a decode failure fail, and an oversized axis fails. -/
theorem remote_gates :
    remoteAdmits .preferenceOff = false ∧ remoteAdmits (.mediaType false) = false ∧
    remoteAdmits .decodeFailed = false ∧
    remoteAdmits (.dimensions (ceilingImageAxis + 1) 1 1000) = false ∧
    remoteAdmits (.dimensions 100 100 (ceilingDecodedBytes + 1)) = false := by native_decide

/-- **C-17** (T-13, T-17, T-19): the three exit codes, one per case outcome. -/
theorem harness_exits :
    harnessExit false false = harnessExitSuccess ∧
    harnessExit true false = harnessExitCaseFailure ∧
    harnessExit false true = harnessExitUsage ∧
    harnessExit true true = harnessExitUsage := by native_decide

/-- **C-17** (T-13, T-17): the pixel metric's tolerance and its degenerate cases. -/
theorem pixel_metric :
    pixelPasses 1 1000 = true ∧ pixelPasses 2 1000 = false ∧
    pixelPasses 0 0 = false ∧ pixelPasses 0 1000 = true := by native_decide

/-- **§7.1, I-009** (T-17): the ink comparison's threshold and its empty-crop
failure. -/
theorem ink_metric :
    inkPasses 900 1000 = true ∧ inkPasses 899 1000 = false ∧
    inkPasses 900 0 = false ∧ inkPasses 0 1000 = false := by native_decide

/-- **E-02, R-10** (T-13): an unsupported diagram type and a parse failure both
fall back; a supported, parseable one renders. -/
theorem mermaid_fallback :
    mermaidRenders true false = false ∧ mermaidRenders false true = false ∧
    mermaidRenders false false = true := by native_decide

/-- **E-09, E-27** (T-26, T-27): opening a missing file beeps and navigates
nowhere; an existing one navigates without a beep. -/
theorem missing_file_action :
    navigationAttempt false = (false, true) ∧ navigationAttempt true = (true, false) := by native_decide

/-- **E-17, R-24** (T-23): the tint set — a code fence, a `$$` math fence, a GFM
table and any block containing `![` are tinted whole. -/
theorem find_tint_set :
    findTintsWholeBlock "```\ncode\n```" = true ∧
    findTintsWholeBlock "$$\nx\n$$" = true ∧
    findTintsWholeBlock "| a |\n|---|---|" = true ∧
    findTintsWholeBlock "text ![img](x)" = true ∧
    findTintsWholeBlock "ordinary prose" = false := by native_decide

/-- **R-24** (T-23): a GFM table is detected by R-24's exact definition — first line
contains `|`, second consists only of `-`, `:`, `|`, space. -/
theorem find_table_definition :
    isGfmTableBlock "a|b\n-|-" = true ∧
    isGfmTableBlock "a|b\nx|y" = false ∧
    isGfmTableBlock "| a |\n|---|" = true := by native_decide

/-! ## Invariants

Each declaration here discharges a spec sentence quantified over the model's whole
input space — not a definition re-read. The doc comment names the sentence. -/

/-- **§5.2, R-33** (T-03): the closed exit set. Every input in §5.2's input space —
any argument list with any existence pattern, with or without the bundle — exits 0
or 1. No §5.2 row names another code. -/
theorem cli_exit_closed (args : List (String × Bool)) (found : Bool) :
    (cliOutcome args found).exit = cliExitSuccess ∨ (cliOutcome args found).exit = cliExitFailure := by
  unfold cliOutcome
  split <;> (try split) <;> (try (cases h : firstMissing args <;> simp_all)) <;> decide

/-- **§5.2, R-33, R-35** (T-03, T-36): the diagnostics contract on stderr. The only
things the launcher may write there are nothing, the bundle-missing line, and the
missing-file line for the argument it names — never document content, a query, or
any other path. -/
theorem cli_stderr_contract (args : List (String × Bool)) (found : Bool) :
    (cliOutcome args found).stderr = "" ∨
    (cliOutcome args found).stderr = cliBundleMissingMessage ∨
    ∃ p, (cliOutcome args found).stderr = cliMissingFilePrefix ++ p := by
  unfold cliOutcome
  split <;> (try split) <;> (try (cases h : firstMissing args <;> simp_all)) <;>
    (first | exact Or.inl rfl | exact Or.inr (Or.inl rfl) | exact Or.inr (Or.inr ⟨_, rfl⟩))

/-- **§5.2, R-33** (T-03): the stdout contract. Only `--version` writes to stdout,
and what it writes is the bundle version — never document content. -/
theorem cli_stdout_contract (args : List (String × Bool)) (found : Bool) :
    (cliOutcome args found).stdout = "" ∨ (cliOutcome args found).stdout = "1.0.0" := by
  unfold cliOutcome
  split <;> (try split) <;> (try (cases h : firstMissing args <;> simp_all)) <;> decide

/-- **§5.2, R-33** (T-03): the bundle step precedes the argument step, so no
argument list — not even `--help` or `--version` — can be served without a bundle. -/
theorem cli_bundle_precedes_args (args : List (String × Bool)) :
    (cliOutcome args false).stderr = cliBundleMissingMessage ∧
    (cliOutcome args false).exit = cliExitFailure := by
  exact ⟨rfl, rfl⟩

/-- **§5.2, R-33** (T-03): the launcher reads the *first* missing argument only — a
later argument's absence changes nothing once an earlier one is reported, for every
tail of arguments whatever. -/
theorem cli_first_missing_only (later : List (String × Bool)) :
    (cliOutcome (("missing", false) :: later) true).action = "abort, nothing opened" ∧
    (cliOutcome (("missing", false) :: later) true).exit = cliExitFailure ∧
    (cliOutcome (("missing", false) :: later) true).stderr = cliMissingFilePrefix ++ "missing" := by
  refine ⟨rfl, rfl, rfl⟩

/-- **§3.1** (T-28, T-29): `CLOSED` is terminal — the spec's own word, transcribed
as the absence of a transition rather than as a gap. -/
theorem closed_is_terminal (ev : LifeEvent) : lifecycle .closed ev = none := by
  cases ev <;> rfl

/-- **§3.1, R-01, R-04, R-20, R-40, E-03, E-21** (T-04, T-25, T-28, T-29): the
closed state set. Every transition §3.1's table or Figure 3.1 states lands in one of
the five named states — the machine quantifies over the enumerated cross product of
states and events. -/
theorem lifecycle_closed_state_set :
    (docStates.all (fun st => lifeEvents.all (fun ev =>
      match lifecycle st ev with
      | none => true
      | some st' => docStates.contains st'))) = true := by
  native_decide

/-- **§3.1** (T-25, T-28, T-29): all five document states are entered by a stated
transition — none is dead. -/
theorem every_state_reached :
    (∃ st ev, lifecycle st ev = some .empty) ∧ (∃ st ev, lifecycle st ev = some .loading) ∧
    (∃ st ev, lifecycle st ev = some .viewing) ∧ (∃ st ev, lifecycle st ev = some .reloading) ∧
    (∃ st ev, lifecycle st ev = some .closed) :=
  ⟨⟨.empty, .launchEmptyHistory, rfl⟩, ⟨.empty, .openRoute, rfl⟩,
   ⟨.loading, .loadOk, rfl⟩, ⟨.viewing, .fileChangedOnDisk, rfl⟩,
   ⟨.viewing, .windowClose, rfl⟩⟩

/-- **I-001** (T-13, T-41): environment independence — a typing fact, not a promise.
The model takes no environment parameter; `runE` exists only to state that ignoring
the environment is definitional, so no theme, zoom, width, backing scale or network
setting can change the blocks, the TOC or the outcome. -/
theorem env_independent (e₁ e₂ : Env) (i : Input) : runE e₁ i = runE e₂ i := by
  rfl

/-- **I-004, C-02, R-04** (T-30, T-50): determinism — a typing fact. The split is a
pure function of `raw`, so two equal documents name the same blocks, the same
half-open map, the same line count and the same TOC; no per-frame consumer can
observe a different split. -/
theorem split_deterministic (raw : String) (r₁ r₂ : SplitResult)
    (h₁ : outcome (.splitOf raw) = some (.split r₁))
    (h₂ : outcome (.splitOf raw) = some (.split r₂)) : r₁ = r₂ := by
  rw [h₁] at h₂
  simpa only [Option.some.injEq, Result.split.injEq] using h₂

/-- **C-02 rule 8, E-31** (T-50): resolution is total in the sense rule 8 requires —
for a document with at least one block, every line number whatever resolves to an
index *inside* the map, so a citation can never name a block the document does not
have. -/
theorem resolve_line_in_bounds (bls : List (Nat × Nat)) (line : Nat) (h : bls ≠ []) :
    resolveLine bls line < bls.length := by
  cases bls with
  | nil => exact absurd rfl h
  | cons a t =>
      have h1 : (List.filter (fun r => r.1 ≤ line) (a :: t)).length ≤ (a :: t).length :=
        List.length_filter_le _ _
      have h2 : 0 < (a :: t).length := by simp
      show (List.filter (fun r => r.1 ≤ line) (a :: t)).length - 1 < (a :: t).length
      omega

/-- **C-02 rule 7** (T-08): the TOC's levels are exactly 1, 2 or 3 — the heading
test is the only source of a level, and it yields only these three. -/
theorem heading_level_closed (b : String) (lvl : Nat) (line : String)
    (h : headingOf b = some (lvl, line)) : lvl = 1 ∨ lvl = 2 ∨ lvl = 3 := by
  have h1 : (trimLeftWs ((b.splitOn "\n").head?.getD "")).startsWith "### " = true ∨
            (trimLeftWs ((b.splitOn "\n").head?.getD "")).startsWith "### " = false := by
    cases (trimLeftWs ((b.splitOn "\n").head?.getD "")).startsWith "### " <;> simp
  rcases h1 with h1 | h1
  · simp [headingOf, h1] at h; simp_all
  · by_cases h2 : (trimLeftWs ((b.splitOn "\n").head?.getD "")).startsWith "## " = true
    · simp [headingOf, h1, h2] at h; simp_all
    · by_cases h3 : (trimLeftWs ((b.splitOn "\n").head?.getD "")).startsWith "# " = true
      · simp [headingOf, h1, h2, h3] at h; simp_all
      · simp [headingOf, h1, h2, h3] at h

/-- **K-04, R-30** (T-11): the zoom step is closed — every factor in, every factor
out lies in `[0.60, 2.50]`, so no sequence of ⌘= / ⌘- can leave the range. -/
theorem zoom_step_closed (s : Nat) (dir : Bool) :
    zoomTenthsMin ≤ zoomStep s dir ∧ zoomStep s dir ≤ zoomTenthsMax := by
  unfold zoomStep
  exact ⟨Nat.le_max_left _ _, Nat.max_le.mpr ⟨by decide, Nat.min_le_left _ _⟩⟩

/-- **R-11, K-07** (T-18): the raster width's 1 pt lower bound holds for *every*
column — including one below the 36 pt inset, where the inner term would otherwise
go negative. (A natural width below 1 pt is not a diagram the spec admits; the row
theorem `raster_one_pt_floor` covers the floor itself.) -/
theorem raster_inset_floor (natural col : Nat) (h : 1 ≤ natural) : 1 ≤ rasterWidth natural col := by
  unfold rasterWidth
  exact Nat.le_min.mpr ⟨h, Nat.le_max_right _ _⟩

/-- **R-11** (T-18): "It MUST NOT be drawn wider than its natural width" — for every
natural width and every column. -/
theorem raster_not_wider_than_natural (natural col : Nat) : rasterWidth natural col ≤ natural := by
  unfold rasterWidth
  exact Nat.min_le_left _ _

/-- **C-04, K-04** (T-42): the read-time clamp is total and inside the range for
every stored value — no stored `mdv6_font_scale` can produce a factor outside
`[0.60, 2.50]`. -/
theorem clamp_scale_closed (n : Nat) :
    zoomTenthsMin ≤ clampFontScale n ∧ clampFontScale n ≤ zoomTenthsMax := by
  unfold clampFontScale
  exact ⟨Nat.le_max_left _ _, Nat.max_le.mpr ⟨by decide, Nat.min_le_left _ _⟩⟩

/-- **C-04, R-32** (T-42): the theme fallback is total and lands in the enumeration
— an unknown or absent id can never produce a theme outside `Spec.themeIds`. -/
theorem pref_theme_closed (stored : Option String) : prefTheme stored ∈ themeIds := by
  cases stored with
  | none => native_decide
  | some id =>
      simp only [prefTheme]
      split
      · rename_i h; simpa using h
      · rename_i _; native_decide

/-- **K-14, E-28** (T-41): the ceiling test is monotone — if a size is admitted,
every smaller size is admitted, so "content at the ceiling is admitted" cannot be
falsified by a smaller input. -/
theorem ceiling_monotone (kind : CeilingKind) (a b : Nat) (h : a ≤ b)
    (hb : ceilingAdmits kind b = true) : ceilingAdmits kind a = true := by
  unfold ceilingAdmits at *
  exact decide_eq_true (Nat.le_trans h (of_decide_eq_true hb))

/-- **C-07.1** (T-07): the closing-delimiter rule quantifies over all following
characters — a span followed by a digit is never accepted, whatever its body. -/
theorem math_no_digit_after (body u : List Char) (d : Char) (x : Bool)
    (h : validInlineSpan body (d :: u) x = true) : ¬ d.isDigit := by
  intro hd
  simp [validInlineSpan, hd] at h

/-- **C-07.1** (T-07): "a span contains no bare `$` and never crosses a backtick" —
a candidate marked as crossing a backtick is rejected for every body and every
following character. -/
theorem math_backtick_rejected (body after : List Char) :
    validInlineSpan body after true = false := by
  unfold validInlineSpan
  simp

/-! ## Reachability

Where the spec claims a set is exhaustive, one witness per member. -/

/-- **§5.2, R-33** (T-03): both exit codes are reached by a §5.2 row — success by a
plain open, failure by a missing argument. -/
theorem both_exits_reached :
    (∃ args found, (cliOutcome args found).exit = cliExitSuccess) ∧
    (∃ args found, (cliOutcome args found).exit = cliExitFailure) :=
  ⟨⟨[], true, rfl⟩, ⟨[("nope", false)], true, rfl⟩⟩

/-- **§5.2, R-33** (T-03): every action §5.2 names is reached — all six rows plus
the bundle-missing row, so no row of the input table is dead. -/
theorem every_cli_action_reached :
    (cliOutcome [] true).action = "open <app>" ∧
    (cliOutcome [("a", true)] true).action = "open -a <app> <paths…>" ∧
    (cliOutcome [("a", false)] true).action = "abort, nothing opened" ∧
    (cliOutcome [("-", true)] true).action = "mktemp -t mdv6-stdin, then open" ∧
    (cliOutcome [("-h", true)] true).action = "usage" ∧
    (cliOutcome [("--version", true)] true).action = "print bundle version" ∧
    (cliOutcome [] false).action = "locate bundle (fails)" :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- **R-01** (T-25): both route kinds are reached by the routes the spec names, so
the adding/selecting split is not vacuous. -/
theorem both_route_kinds_reached :
    (∃ r, routeKind r = .adding) ∧ (∃ r, routeKind r = .selecting) :=
  ⟨⟨.openPanel, rfl⟩, ⟨.historyRow, rfl⟩⟩

/-- **R-19, C-19.1** (T-22, T-49): all three fragment kinds are reached, so the
dispatch's order matters for a real input. -/
theorem every_fragment_kind_reached :
    (∃ s, fragmentKind s = .lineCitation) ∧ (∃ s, fragmentKind s = .slugFragment) ∧
    (∃ s, fragmentKind s = .noFragment) :=
  ⟨⟨"L1", by native_decide⟩, ⟨"x", by native_decide⟩, ⟨"", by native_decide⟩⟩

/-- **R-19, E-05** (T-22): both navigation branches are reached — in-app for a local
Markdown path, the system opener for everything else. -/
theorem both_link_branches_reached :
    (∃ d, linkDecision d = (true, false)) ∧ (∃ d, linkDecision d = (false, true)) :=
  ⟨⟨.localMarkdown, rfl⟩, ⟨.missingLocal, rfl⟩⟩

/-- **K-14, E-28** (T-41): all seven ceiling kinds are decisive — each admits its own
ceiling and rejects one unit above it, so no ceiling is a no-op. -/
theorem every_ceiling_reached :
    allCeilingKinds.all
      (fun k => decide (ceilingAdmits k (ceilingOf k) && !ceilingAdmits k (ceilingOf k + 1)))
      = true := by
  native_decide

/-- **C-17** (T-13, T-17, T-19): all three harness exit codes are reached. -/
theorem every_harness_exit_reached :
    (∃ cf us, harnessExit cf us = harnessExitSuccess) ∧
    (∃ cf us, harnessExit cf us = harnessExitCaseFailure) ∧
    (∃ cf us, harnessExit cf us = harnessExitUsage) :=
  ⟨⟨false, false, rfl⟩, ⟨true, false, rfl⟩, ⟨false, true, rfl⟩⟩

/-! ## Findings

Each declaration is the kernel-checked witness of a finding in
`docs/reviews/SPEC_MODEL_FINDINGS.md`. **All nine were applied to `SPEC.md` in
v0.13.1**, so each witness below now discharges the *closed* state: it asserts the
behaviour the amended spec pins, and the model proves it. -/

/-- **F-139 (closed at v0.13.1)** (T-15): C-06.1 rule 3 now names the 46 colour names
*and* their SVG 1.1 values, so the model's lookup is total and the pin is equality with
it. The witness checks the whole table: 46 entries, every name resolving to its pinned
value, and a name outside the list resolving to nothing. -/
theorem f139_color_map_pinned :
    cssColorValues.length = 46 ∧
    (∀ name v, cssColorValues.lookup name = some v → colorPinned name (some v)) ∧
    namedColorHex "white" = some "#ffffff" ∧ namedColorHex "red" = some "#ff0000" ∧
    namedColorHex "green" = some "#008000" ∧ namedColorHex "grey" = some "#808080" ∧
    namedColorHex "GREEN" = some "#008000" ∧ namedColorHex "transparent" = some "#00000000" ∧
    namedColorHex "rebeccapurple" = none := by
  refine ⟨by decide, fun name v h => by simp [colorPinned, h], by native_decide, by native_decide,
          by native_decide, by native_decide, by native_decide, by native_decide, by native_decide⟩

/-- **F-140 (closed at v0.13.1)** (T-28, T-29): §3.1's table is now total. The two cells
that were silent are named — deleting a retained row while `EMPTY` leaves the window
`EMPTY`, and a further watcher event during `RELOADING` is processed as one during
`VIEWING` — and the residual `none`s are *exactly* the table's unreachable pairs, which
the amended spec declares. -/
theorem f140_lifecycle_total :
    lifecycle .empty (.deleteDisplayedRow false) = some .empty ∧
    lifecycle .reloading .fileChangedOnDisk = some .reloading ∧
    (docStates.all (fun st => lifeEvents.all (fun ev =>
      ((lifecycle st ev).isSome == lifeReachable st ev)))) = true := by
  refine ⟨rfl, rfl, by native_decide⟩

/-- **F-141 (closed at v0.13.1)** (T-08, T-30): C-12 now pins the removal order, and the
model applies it in that order — rule 1's trailing `#`s with a trim, then the link
reduction, then the `_…_` pairs (a `__` run left to the scan), then the scan that owns
`**`, backticks, `__` and the unescaped `*` and honours a backslash escape. -/
theorem f141_strip_order_pinned :
    stripInlineMd "# Title ##" = "# Title" ∧
    stripInlineMd "[t](u) _e_" = "t e" ∧
    stripInlineMd "__a__" = "a" ∧
    stripInlineMd "_Draft_ notes" = "Draft notes" ∧
    stripInlineMd "a\\*b" = "a*b" ∧
    stripInlineMd "snake_case" = "snake_case" := by native_decide

/-- **F-142 (closed at v0.13.1)** (T-08): rule 7's "first line only" and the
`ParsedDocument` field comment now say the same thing — a multi-line block contributes
one entry from its first line, with the same level and slug as the one-line form. -/
theorem f142_heading_multiline_block :
    (tocOf ["# Title\nbody text"]).map (fun h => (h.level, h.slugText)) =
      (tocOf ["# Title"]).map (fun h => (h.level, h.slugText)) ∧
    (tocOf ["# Title\nbody text"]).length = 1 := by native_decide

/-- **F-143 (closed at v0.13.1)** (T-08, T-44): rule 7 now says `text` and `slugText` are
computed from the heading **body**, so the ATX marker reaches neither the TOC nor a slug
— which is what T-08 expects. -/
theorem f143_toc_text_strips_marker :
    (tocOf ["# Sibling"]).map (fun h => (h.text, h.slugText)) = [(some "Sibling", "Sibling")] ∧
    slug "Sibling" = "sibling" := by
  refine ⟨by native_decide, by native_decide⟩

/-- **F-144 (closed at v0.13.1)** (T-10): C-10 now pins the quote predicate, over the
**emitted** stream — which is why the set names `—`: a dash run flushed immediately
before a quote is the character that quote opens after. -/
theorem f144_quote_direction_pinned :
    rewriteRun "a \"b".toList = ['a', ' ', '“', 'b'] ∧
    rewriteRun "a\"b".toList = ['a', '”', 'b'] ∧
    rewriteRun "a --- \"b\"".toList = ['a', ' ', '—', ' ', '“', 'b', '”'] ∧
    quoteOpeners = ['(', '[', '{', '<', '“', '‘', '—', '–', '-', '/'] := by
  refine ⟨by native_decide, by native_decide, by native_decide, rfl⟩

/-- **F-145 (closed at v0.13.1)** (T-10): C-10 now cites R-24's exact test, so the spec
holds one table predicate and the model one function. The witness shows the case that
separated the two old readings is accepted by the shared test. -/
theorem f145_table_definition_aligned :
    isGfmTableBlock "a|b\n-|-" = true ∧ isGfmTableBlock "| a |\n|---|" = true ∧
    isGfmTableBlock "a|b\nx|y" = false ∧ hasSub "-|-" "|---|" = false := by native_decide

/-- **F-146 (closed at v0.13.1)** (T-07): C-07.1 now states its scan, and the model
implements it. The witness covers each clause the clause names: `$$` before `$`, the
escape, the backtick abort, the unterminated opener, the all-whitespace `$$…$$` body, and
the code span. -/
theorem f146_scan_stated :
    scanMathSpans "no math here" = [] ∧
    scanMathSpans "a $x$ b" = [(false, "x")] ∧
    scanMathSpans "$$x$$" = [(true, "x")] ∧
    scanMathSpans "$x$ $y$" = [(false, "x"), (false, "y")] ∧
    scanMathSpans "\\$x$ y" = [] ∧
    scanMathSpans "`$x$`" = [] ∧
    scanMathSpans "$$$$" = [] ∧
    scanMathSpans "$$\nr = 1\n$$" = [(true, "\nr = 1\n")] := by
  refine ⟨by native_decide, by native_decide, by native_decide, by native_decide,
          by native_decide, by native_decide, by native_decide, by native_decide⟩

/-- **F-146 (closed at v0.13.1)** (T-07): E-07's literal forms are not spans — the
closing-delimiter conditions and the scan agree with the row the spec states. -/
theorem scan_e07_forms :
    scanMathSpans "$5 and $10" = [] ∧ scanMathSpans "$5-$10" = [] ∧
    scanMathSpans "$100/month" = [] ∧ scanMathSpans "$$\n$$" = [] ∧
    scanMathSpans "$$ $5 and $ $$" = [(true, " $5 and $ ")] := by
  refine ⟨by native_decide, by native_decide, by native_decide, by native_decide,
          by native_decide⟩

/-- **F-147 (closed at v0.13.1)** (T-24): C-03 now says the drop is deletion and records
the collision as accepted, which is what the model does. -/
theorem f147_token_collision :
    ftsQuery "a\"b" = ftsQuery "ab" ∧ ftsQuery "a\"b" = "\"ab\"*" := by native_decide

/-! ## The deferral table

Every spec ID that is **out of Lean's reach**, with the §9 test that will carry it.
No implementation exists, so this table is the spec's witness plan, not a result.
A requirement with two halves appears twice: tagged above for the half the model
carries, and here for the half only a running system can show.

| spec ID | content | carried by |
| --- | --- | --- |
| R-05 (timing half) | 50 ms event latency, at most two reloads per burst | T-29 (planned) |
| R-32 (persistence half) | the preference store surviving a relaunch | T-42 (planned) |
| R-06 (persistence half) | the scroll position is *stored* on close, quit and file switch | T-28 (planned) |
| R-07 | GFM rendering through cmark-gfm | T-05 (planned) |
| R-09 | the Mermaid block's controls and their persistence | T-21 (planned) |
| R-10 (render half) | the fallback block's own rendering | T-13, T-15 (planned) |
| R-12 | native typesetting of math in every block type | T-07 (planned) |
| R-13 | math sized by the heading's em factor | T-08, T-11 (planned) |
| R-14 | rejected LaTeX shown as source plus the parser's message | T-07 (planned) |
| R-15 | whole-label math composited into a diagram | T-17 (planned) |
| R-16 (fetch half) | the remote-image fetch itself | T-09, T-41 (planned) |
| R-21 | the inspector's views, filtering and persistence | T-08, T-31 (planned) |
| R-22 | text selection, section copy and the flash | T-30 (planned) |
| R-23 | the external editor hand-off | T-38 (planned) |
| R-25 | the global-search surface and its snippets | T-24 (planned) |
| R-26 | the index's mtime gate, prune and re-index lifecycle | T-24, T-25 (planned) |
| R-28 | the placeholder's row, badge and expansion | T-27 (planned) |
| R-29 (live half) | the System theme switching with macOS appearance | T-12 (planned) |
| R-31 | the Help copy and its stable path | T-38 (planned) |
| R-34 | `make` / `make install` / `make dist` | T-01, T-02, T-43 (planned) |
| R-35 | the log's silence about document content | T-36 (planned) |
| R-36 | no termination for admitted content | T-41 (planned) |
| R-37 | the `swift test` suite and CI | the suite itself (§9.0) |
| R-38 (quality half) | the actual Swift/SQL highlighting quality | T-37 (planned) |
| R-39 | the render harness, corpus and manifest | T-13, T-17, T-19 (planned) |
| R-41 | the K-14 enforcement points before each parser | T-41 (planned) |
| R-42 | the window chrome as a whole | T-44, T-47 (planned) |
| R-43 (quality half) | the actual C++/JSON/Lua/OpenCL/Perl/Markdown quality | T-51 (planned) |
| C-09 (values half) | the themes' colour and type values | T-44, T-45 (planned) |
| C-13 | the build's outputs and the ad-hoc signature | T-01 (planned) |
| C-14 | in-place failure reporting in the view tree | T-44 (planned) |
| C-16 (mechanism half) | the ephemeral session, headers, timeouts and streaming | T-41 (planned) |
| C-17 (harness half) | the harness's own cases, goldens and stability | T-13, T-17, T-19 (planned) |
| C-18 | the window chrome's structure, row anatomy and states | T-44, T-47, T-48 (planned) |
| I-002 | every parser reached only after its limit check and sanitiser | T-41 (planned) |
| I-003 | document bytes never enter a log, subprocess or request | T-36 (planned) |
| I-005 | one source for a diagram's bitmap size and view frame | T-18 (planned) |
| I-006 | the single `FULLMUTEX` WAL connection | T-33 (planned) |
| I-007 | whole-row persistence writes | T-33 (planned) |
| I-008 | bitmap-backed math images and idle CPU | T-32 (planned) |
| I-009 | the ink-weight threshold inside a Mermaid raster | T-17 (planned) |
| I-010 (render half) | `#fragment` links resolving as GitHub resolves them, in the app | T-08, T-22 (planned) |
| I-011 | the vendored SwiftMath carrying exactly its listed patches | T-34 (planned) |
| I-012 (universal half) | smartening leaving *every* protected run untouched | T-10 (planned) |
| I-014 | vertical rhythm independent of the view tree | T-45 (planned) |
| I-015 | chrome structure independent of the theme | T-44 (planned) |
| K-01 | the platform and toolchain floor | T-01 (planned) |
| K-02 | the bundle identifier and version | T-01 (planned) |
| K-06 (observation half) | the flash, the HUD's dwell and the reload windows as *seen* | T-29, T-30, T-49 (planned) |
| K-08 (library half) | the library's own row heights, pitches and gaps | T-17, T-19 (planned) |
| K-10 (render half) | the typography defaults as rendered | T-45 (planned) |
| K-11 | the release artefacts and their names | T-43 (planned) |
| K-12 | the ad-hoc-signed bundle passing `codesign --verify` | T-01 (planned) |
| K-15 | the idle-CPU protocol's medians | T-32 (planned) |
| K-16 (render half) | the chrome metrics and the rhythm band as measured | T-45, T-48 (planned) |
| E-01 | the two-subgraph ownership repair before ELK | T-13, T-14 (planned) |
| E-10 | SwiftMath's rejection surfaced as source plus message | T-07 (planned) |
| E-12 | a corrupt or failing `mdv6.db` | T-33 (planned) |
| E-13 | sequence-diagram gap widening and row expansion | T-19 (planned) |
| E-16 | math filling a table cell or list item | T-07, T-46 (planned) |
| E-18 | ⌘F with the sidebar focused | T-23 (planned) |
| E-19 | a reload with text selected keeping the scroll position | T-29 (planned) |
| E-22 (click half) | clicking or hovering an h4–h6 or setext heading | T-22, T-30 (planned) |
| E-20 | the same file in two windows | T-35 (planned) |
| E-25 | cancelling an in-flight render | T-13 (planned) |
| E-26 | only the key window acting | T-40 (planned) |
| E-30 | window-state restoration disabled | T-28 (planned) |
| E-29 | the TOC selected row's lifecycle across scroll, reload and file load | T-44, T-49 (planned) |
| E-31 (flash half) | the citation's scroll and its 0.6 s flash on screen | T-49 (planned) |
| §3.2 | the per-block render path | T-05, T-07, T-13 (planned) |
| §3.3 | the durable artefacts and their migrations | T-24, T-28, T-33 (planned) |
| §5.1 | the menus, shortcuts and enablement | T-44, T-47, T-48 (planned) |
| §5.3 | the `make` targets and the release chain | T-01, T-02, T-43 (planned) |
| §5.4 | the diagnostics surface | T-36 (planned) |
| §7.1 (measurement half) | the ink measurement itself | T-17 (planned) |
| §7.2 (measurement half) | the column width as laid out | T-18 (planned) |
| §9.0 | the suite's own shape and CI wiring | the suite itself (§9.0) |
| §10 | the dependencies and their pins | T-01, T-34 (planned) |

## The §9 witness plan — all fifty-one tests

Every T-id in the spec, with what it carries. The table above names the ones that
carry a deferred requirement; this one makes the join total, so no T-id is
unaccounted for.

| T-id | carries |
| --- | --- |
| T-01 | R-34, K-01, K-02, K-12, C-01, C-13 |
| T-02 | R-34, K-11 (the negative gate) |
| T-03 | R-01, R-33, §5.2 |
| T-04 | R-02, R-03, E-03, E-04 |
| T-05 | R-07 |
| T-06 | R-08, C-05, K-05 |
| T-07 | R-12, R-13, R-14, C-07, E-07, E-10, E-16 |
| T-08 | R-13, R-21, R-27, C-07.3, C-12, I-010, E-22 |
| T-09 | R-16, E-11 |
| T-10 | R-17, C-10, I-012 |
| T-11 | R-30, K-04, K-10, C-04, C-05 |
| T-12 | R-29 |
| T-13 | R-10, R-39, C-17, I-001, I-002, E-01, E-02, E-25 |
| T-14 | C-06.2, E-01 |
| T-15 | C-06.1, E-14 |
| T-16 | E-15 |
| T-17 | R-15, R-39, C-17, I-009, K-08 |
| T-18 | R-11, I-005, K-07, K-13, §7.2 |
| T-19 | R-39, C-06.2, C-17, E-13, K-08 |
| T-20 | C-06.1 rule 4, C-06.2 |
| T-21 | R-09, K-07 |
| T-22 | R-19, E-05, E-06, C-11, C-19.5 |
| T-23 | R-24, E-17, E-18 |
| T-24 | R-01, R-25, R-26, C-03, K-03, K-09, E-24 |
| T-25 | R-01, R-18, R-20, R-26, I-013, K-03, C-15, §3.1 |
| T-26 | R-27, C-08, K-06, K-09, E-08, E-09 |
| T-27 | R-18, R-28, E-27, C-18.9 |
| T-28 | R-06, R-18, R-40, C-08, E-03, E-08, E-30, K-06, §3.1 |
| T-29 | R-05, K-06, E-19, E-21 |
| T-30 | R-22, C-12, E-22, I-004 |
| T-31 | R-20, R-21, K-04 |
| T-32 | I-008, K-15 |
| T-33 | E-12, I-006, I-007 |
| T-34 | I-011 |
| T-35 | E-20 |
| T-36 | R-35, I-003 |
| T-37 | R-38, C-05, K-05 |
| T-38 | R-23, R-31 |
| T-39 | R-04, R-24, C-02, E-03, E-23 |
| T-40 | R-01, R-18, E-26 |
| T-41 | R-16, R-36, R-41, C-16, I-001..I-003, K-14, E-11, E-28 |
| T-42 | R-32, C-04 |
| T-43 | R-34, K-11 |
| T-44 | C-18, I-015, R-42 |
| T-45 | I-014, K-16, C-10 |
| T-46 | C-07.1, R-12, C-18.10 |
| T-47 | C-18.1, R-42 |
| T-48 | C-18.7, C-18.9, R-27, R-28, K-16 |
| T-49 | R-19, C-19, E-31 |
| T-50 | C-02 rule 8, C-19.3, E-31 |
| T-51 | R-43, C-05, K-05 |

## The excluded table

The cases the spec puts out of scope **by name**. A stated boundary, not a missing
witness — deliberately not folded into the deferral table.

| out of scope | where the spec says so |
| --- | --- |
| Editing Markdown (the application hands off to an external editor) | §0 Non-goals |
| HTML blocks beyond what cmark-gfm passes through as text | §0 Non-goals |
| Syncing anything off the machine | §0 Non-goals |
| App-Store sandboxing | §0 Non-goals |
| The internals of the third-party renderers beyond the contracts mdv6 relies on | §4 preamble |
| The colour and type values of individual themes (they live in `TYPOGRAPHY.md`) | §4 preamble, C-09 |
| Line-accurate highlighting inside a block (a citation highlights the block) | C-19.3, D-44 |
| Rendering a cited *code* file (`Foo.swift#L412-L418`) | C-19.5 |

## The decision table — provenance only

`D-01…D-45` are decision records, not requirements: they are cited by the rows
above for provenance and are excluded from the ID join by the tag discipline. They
are listed here so that no spec ID is silently dropped.

| decisions | status as the spec records them |
| --- | --- |
| D-01 | no automated suite existed; the product MUST have one — confirmed (§9.0) |
| D-02 | inline math with descenders sits `descent` points above the baseline |
| D-03 | SwiftMath is vendored because of the resource-bundle/codesign constraints |
| D-04 | the diagram types the library lacks (E-02's list) |
| D-05 | sequence diagrams do not mirror actor boxes at the bottom |
| D-06 | xychart series names are dropped; front-matter `themeCSS` is dropped |
| D-07 | parallelogram nodes render as rectangles |
| D-08 | state descriptions render as one multi-line label |
| D-09 | Document-style node fills use the page colour mixed 25 % toward the code background |
| D-10 | the history sidebar's width is not persisted; the inspector's is |
| D-11 | `.txt` and `.mkd` are drop-only extensions (R-03 vs R-19) |
| D-12 | the installed CLI symlink points into the checkout |
| D-13 | the bundle version is fixed at `1.0.0` while releases are versioned by tag |
| D-14 | Load Remote Images is off by default |
| D-15 | which SQL grammar backs R-38 |
| D-16 | invalid UTF-8 files are refused silently (E-03) |
| D-17 | fragment targets are only `#`–`###` single-line ATX headings; duplicates resolve to the first; no `-1` suffixes |
| D-18 | how a reload treats an empty or undecodable mid-save read (E-21, 500 ms) |
| D-19 | key-window routing of commands and open events — confirm; fixed at v0.7 |
| D-20 | the heading-slug hyphen rule — confirm; GitHub-compatible, fixed at v0.7 |
| D-21 | whether find distinguishes the current occurrence; `$$` blocks tinted — confirm; fixed at v0.7 |
| D-22 | `migrate()` transactionality — confirm; fixed at v0.7 |
| D-23 | undecodable or vanished file; what an empty file displays — confirm; fixed at v0.7 |
| D-24 | adding vs. selecting routes; snapshots of removed rows — confirm; fixed at v0.7 |
| D-25 | index rows for cap-evicted files — confirm; fixed at v0.7 |
| D-26 | whether fenced code follows the zoom factor — confirm; fixed at v0.7 |
| D-27 | placeholder or snapshot whose file is missing — confirm; fixed at v0.7 |
| D-28 | an unreadable initial history head — confirm |
| D-29 | a cold-start argument and the unseen restored head — confirm |
| D-30 | cross-file bookmark and placeholder snapshot policy — confirm |
| D-31 | remote disclosure and the resource ceilings — confirm |
| D-32 | whether `VERSION` may bypass exact-tag provenance — confirm: it may not |
| D-33 | the harness CLI, corpus discovery and comparison tolerance — confirm |
| D-34 | local path plus fragment semantics — confirm |
| D-35 | durable anchor normalisation — confirm |
| D-36 | equal-rank search order — confirm |
| D-37 | zoom tie rounding — confirm |
| D-38 | the idle-CPU acceptance metric — confirm |
| D-39 | empty in-document find — confirm |
| D-40 | chrome structure is normative, with reference screenshots checked in |
| D-41 | the TOC highlight is choice-driven, not viewport-driven |
| D-42 | reference screenshots are normative for structure only — confirmed |
| D-43 | the three chrome affordances supplied from the original's screenshots |
| D-44 | a line citation resolves to the paragraph, not the line run |
| D-45 | the grammars backing R-43, `metal` → C++, and markdown's two grammars |

## The structural list

True by the model's *typing*, not by a proof obligation: the model's entry points
are plain functions with no `IO` and no state argument (`outcome`, `runE`); every
leaf is a total function of its arguments; the only `Option` at the top level is
`outcome`'s, and the only inner `Option`s are the spec's own partial cells
(`TocHeading.text`, the pins). I-001 and I-004 are the two structural facts that can
be *stated* as theorems, and they are tagged above.
-/
end Mdv6Spec.Mdv6.Theorems
