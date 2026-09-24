# SPEC_MODEL_FINDINGS — mdv6

Spec-precision gaps found by building the spec's own Lean model
([`proof_from_spec/`](../../proof_from_spec/)) — and their resolutions.

**Status: all nine applied to `SPEC.md` in v0.13.1** (2026-09-24). This file is now the record of
what each gap was, what the amended spec says instead, and the kernel-checked witness that closes it:
`cd proof_from_spec && lake build` exits 0 with zero warnings, and every witness named below is one of
its 597 declarations.

**What this file is not.** It is not a verdict on any implementation — the model certifies the
*spec*. Leg C (the empirical leg) is absent by construction: the spec's §9 tests are planned, not
run. And `SPEC.md` was amended *because the maintainer asked for these gaps to be closed*, not to
make a proof go through: each resolution is the behaviour the as-built implementation already had
(`mdv6/Core/*.swift`), now stated. The model was then re-verified against the amended spec.

Numbering continues the spec's review sequence: the last applied review finding was **F-138**
(v0.12.1), so the first finding here is **F-139**.

| finding | class | severity | anchor | resolution in v0.13.1 | closure witness |
| --- | --- | --- | --- | --- | --- |
| F-139 | G-2 · under-stated pin | P1 | C-06.1 rule 3 | the 46 colour names now carry their SVG 1.1 values | `f139_color_map_pinned` |
| F-140 | G-1 · silent case | P1 | §3.1, R-05, R-40 | the two reachable cells are named; the table is declared total | `f140_lifecycle_total` |
| F-141 | G-2 · unpinned rule order | P2 | C-12 | the five-step removal order is stated | `f141_strip_order_pinned` |
| F-142 | G-2 · two readings | P2 | C-02 rule 7 | rule 7 and the field comment agree on the first-line reading | `f142_heading_multiline_block` |
| F-143 | G-2 · unpinned step | P1 | C-02 rule 7 | `text`/`slugText` come from the heading **body** | `f143_toc_text_strips_marker` |
| F-144 | G-2 · unpinned mapping | P2 | C-10 | the opening-quote predicate is stated | `f144_quote_direction_pinned` |
| F-145 | G-2 · definition drift | P2 | C-10 vs R-24 | C-10 cites R-24's exact table test | `f145_table_definition_aligned` |
| F-146 | G-3a · unwitnessed | P1 | C-07.1 | the span **scan** is stated (T-07's C-07 citation now covers it) | `f146_scan_stated`, `scan_e07_forms` |
| F-147 | G-2 · stronger than intended | P2 | C-03 | the drop is documented as deletion, with the collision accepted | `f147_token_collision` |

---

## F-139 · G-2 · P1 — the CSS colour map was named but not pinned

**Was.** C-06.1 rule 3 said *"map these CSS colour names … to hex"* and enumerated 46 names (44
colours plus `transparent` and `none`), pinning the **domain** and no value in the **image**: no hex
for `white`, for `green` (CSS `green` is `#008000`, not `#00ff00`), for `gray`/`grey`, or for any
other name. Two conforming builds could render `style X fill:white` differently, and T-15's "light-grey/white
fills" could not discriminate.

**Now.** Rule 3 is followed by the value paragraph: the SVG 1.1 colour keywords, 44 pairs plus
`transparent`/`none` → `#00000000`. The list is exhaustive.

**Witness.** `f139_color_map_pinned` checks the whole table: 46 entries, every name resolving to its
pinned value (case-insensitively, so `GREEN` → `#008000`), `grey` → `#808080`, and a name outside
the list (`rebeccapurple`) resolving to nothing. The model's `colorPinned` is now equality with the
lookup, not `True`.

---

## F-140 · G-1 · P1 — §3.1's lifecycle table was partial

**Was.** 5 states × 12 events = 60 cells, of which the table and Figure 3.1 named 18. Two of the
unnamed ones were reachable from a state §3.1 puts the application in:

* `EMPTY` with R-40's retained unreadable head — the reader can swipe-delete that row, and §3.1's
  `EMPTY` row listed only "any open route → `LOADING`";
* `RELOADING` — R-05's coalescing rule says "a burst yields at most **two** reloads" without saying
  what the state machine does with the second.

Twelve further cells were silent because they are unreachable (a launch while `VIEWING`, a watcher
event while `EMPTY`, …), and the model could not tell an unreachable cell from an unstated one: both
were `none`.

**Now.** The two cells are named — deleting a retained row while `EMPTY` leaves the window `EMPTY`
with the row removed; a further watcher event during `RELOADING` is processed exactly as one during
`VIEWING` — and the sentence after Figure 3.1 declares the table **total**, so an unlisted pair is
*unreachable*.

**Witness.** `f140_lifecycle_total` asserts both new cells and the closure of the whole relation:
`lifecycle` returns a state exactly on the cells `lifeReachable` names, over the enumerated cross
product. The residual `none`s are now provably the table's unreachable pairs.

---

## F-141 · G-2 · P2 — `stripInlineMarkdown`'s removals had no pinned order

**Was.** One sentence listed what is removed — trailing `#`s, `**`, `__`, backticks, unescaped `*`,
`_…_` pairs, `[text](url)` → `text` — with no order and no statement that the order is immaterial.

**Now.** C-12 states the five steps: (1) trailing `#`s with the surrounding whitespace trimmed;
(2) `[text](url)` → `text`; (3) the `_…_` pairs, with a `__` run left to step 4; (4) the left-to-right
scan that drops `**`, every backtick, every `_` of a `__` pair and every unescaped `*`, honouring a
backslash escape; (5) the surrounding whitespace trimmed again.

**Witness.** `f141_strip_order_pinned` — the model applies the stated order: `# Title ##` → `# Title`
(step 1), `[t](u) _e_` → `t e` (2 then 3), `__a__` → `a` (3 skips, 4 owns), `_Draft_ notes` →
`Draft notes`, `a\*b` → `a*b` (the escape), `snake_case` unchanged (word-internal). The model's
`dropEmphUnderscore` was corrected in the same change to leave a `__` run alone, which is what step 3
now says.

---

## F-142 · G-2 · P2 — "uses its first line only" vs "single-line ATX only"

**Was.** C-02 rule 7 admitted a block whose *first line* is an ATX heading, whatever follows; the
`tocHeadings` field comment said "single-line ATX only". The two readings differ for
`# Title` + body text in one block.

**Now.** Rule 7 states it outright — a block MAY span more than one line and only its first line
carries the marker — and the field comment reads "level 1…3, from each block's first line (rule 7)".
The first-line reading is the one the as-built `parseTOC` takes.

**Witness.** `f142_heading_multiline_block` — `tocOf ["# Title\nbody text"]` and
`tocOf ["# Title"]` agree in level and slug, and the multi-line block contributes exactly one entry.

---

## F-143 · G-2 · P1 — the TOC's `text` kept the ATX marker

**Was.** Rule 7 said `text` was "the line with inline Markdown stripped", and C-12 removes only
*trailing* `#`s, so a literal reading left the leading `# ` in `TOCHeading.text` — while T-08 asserts
the TOC shows the bare heading text and R-27 derives bookmark titles from it.

**Now.** Rule 7 says `text` and `slugText` are computed from the heading **body**: the first line
with its leading `#` run and the single space after it removed. The as-built `parseTOC` does exactly
this (`dropFirst(level + 1)`).

**Witness.** `f143_toc_text_strips_marker` — `tocOf ["# Sibling"]` gives
`text = some "Sibling"`, `slugText = "Sibling"`, and `slug "Sibling" = "sibling"` (so a GitHub
`#sibling` fragment still resolves).

---

## F-144 · G-2 · P2 — a quote's direction was "chosen from the preceding character"

**Was.** C-10 fixed no mapping, so `(` vs a digit vs a paragraph start was each implementation's
choice.

**Now.** C-10 states the predicate: a quote **opens** when the preceding character is absent,
whitespace, or one of `( [ { < “ ‘ — – - /`, and closes otherwise.

**Witness.** `f144_quote_direction_pinned` — `a "b` → `a “b`, `a"b` → `a”b`, and
`a --- "b"` → `a — “b”`, which is *why* the set names `—`: the predicate is over the **emitted**
stream, and the dash run is flushed before the quote is decided. The model carries the source
character (for the dash-run neighbours) and the emitted character (for the quote) separately.

---

## F-145 · G-2 · P2 — C-10 defined a GFM table by example, R-24 defined it exactly

**Was.** C-10's early return named "a `|---|` separator row"; R-24 defined the same notion as "first
line contains `|`, second line consists only of `-`, `:`, `|`, space". The two predicates differ —
`a|b` / `-|-` is a table under R-24's reading and contains no `|---|` at all.

**Now.** C-10 says "is a GFM table by **R-24's test**", so the spec holds one predicate.

**Witness.** `f145_table_definition_aligned` — the separating case is accepted by the shared test,
and no `|---|` substring is required.

---

## F-146 · G-3a · P1 — C-07.1's span *scan* had no witness

**Was.** C-07.1 pinned a candidate span's **acceptance** and its **placement** and said nothing about
the **scan** that finds candidates: the precedence of `$$` over `$`, the fate of an unclosed `$`,
whether a span may cross a line break. No §9 test carried it — a G-3a, unverifiable by construction.

**Now.** C-07.1 states the scan: the block is scanned left to right with `$$` tested before `$`; a
backslash and the character after it are skipped verbatim; a candidate that reaches a backtick or the
end before its closer is **not** a span (the opener stays literal and the scan resumes after the
opener's run); an all-whitespace `$$…$$` body is literal; the scan runs over the whole block, so a
display span may cross line breaks. T-07 already proves C-07, so the clause now has a witness.

**Witness.** `f146_scan_stated` covers each clause (`$$` precedence, the escape, the backtick abort,
the unterminated opener, the empty body, the code span, the multi-line display), and
`scan_e07_forms` covers E-07's literal forms including `$$ $5 and $ $$`. The model gained
`scanMathSpans`.

---

## F-147 · G-2 · P2 — "drop the characters from each token" is stronger than intended

**Was.** C-03's rule reads as a filter, so it also *deletes* the six characters: `a"b` and `ab`
become the same FTS term, and a query cannot distinguish the two documents.

**Now.** C-03 records the consequence explicitly — "dropping is **deletion, not escaping** … this is
accepted, because the six characters are FTS5 syntax and every survivor is a quoted literal prefix".
The as-built `FTSQuery.make` filters, so this is the behaviour that was always meant; the spec now
says so.

**Witness.** `f147_token_collision` — the documented collision, asserted.

---

## What the model found and the spec *kept*

The run also confirmed three sentences the spec asserts about itself, for every input, with no change
needed: the CLI's closed exit set (`cli_exit_closed`), its stderr and stdout contracts
(`cli_stderr_contract`, `cli_stdout_contract`), §3.1's closed state set
(`lifecycle_closed_state_set`), and the closure/monotonicity family
(`zoom_step_closed`, `raster_inset_floor`, `clamp_scale_closed`, `ceiling_monotone`,
`math_backtick_rejected`, `resolve_line_in_bounds`, `heading_level_closed`, `pref_theme_closed`).
No P0 was found: the spec's constants are mutually consistent and no invariant it asserts about
itself failed.