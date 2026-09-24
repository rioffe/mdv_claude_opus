# SPEC_MODEL_FINDINGS — mdv6

Spec-precision gaps found by building the spec's own Lean model
([`proof_from_spec/`](../../proof_from_spec/)), not by reading the document. Each finding is
backed by a kernel-checked witness named below; `cd proof_from_spec && lake build` exits 0 with
zero warnings on all of them.

**What this file is not.** It is not a verdict on any implementation — there is no implementation
under discussion here, only the model of `SPEC.md` v0.13. The model certifies the *spec*: that its
tables are renderable as a total function, that the claims it makes about itself hold for all
inputs, and that every case it does not pin has a stated witness. Leg C — the empirical leg — is
absent by construction.

**Nothing in `SPEC.md` was edited.** These are reports; `spec-proposal` / `spec-writing` decide.

Numbering continues the spec's review sequence: the last applied review finding was **F-138**
(v0.12.1), so the first finding here is **F-139**.

---

## F-139 · G-2 · P1 — the CSS colour map is named but not pinned

**Anchor:** C-06.1 rule 3 (§4). **Witness:** `f139_color_map_unpinned`.

The rule says: *"map these CSS colour names … to hex: `white black red green …`"* and then
enumerates 46 names (44 colours plus `transparent` and `none`). It pins the **domain** and no value
in the **image**: no hex is given for `white`, for `green` (CSS `green` is `#008000`, not the
naïve `#00ff00`), for `gray`/`grey` (equal or distinct values?), or for any other name.

The model records this honestly rather than inventing a table: `colorPinned` admits every value for
every name, and `namedColorHex` — the model's only total realisation — returns `none` everywhere.
The witness also checks the count (`cssColorNames.length = 46`).

**Why it matters.** Two conforming implementations may render `style X fill:white` differently, and
the spec's own stated *reason* for the rule ("3-digit hex and names render **black**") is satisfied
by any mapping. T-15 ("renders with clean labels and light-grey/white fills") cannot discriminate
either.

**Proposed resolution.** Pin the values — either by reference ("the SVG 1.1 named colours as in the
CSS Color Module Level 3 keyword table") or by a table in the rule. If the intent is the as-built
implementation's table, cite it; if the intent is *any* resolvable hex, say that, and drop T-15's
colour assertion.

---

## F-140 · G-1 · P1 — §3.1's lifecycle table is partial, and two reachable cells are silent

**Anchor:** §3.1, R-05, R-40. **Witness:** `f140_lifecycle_silent_cells`.

§3.1's table is a *transition relation*, not a function: 5 states × 12 events = 60 cells, of which
the table and Figure 3.1 name 18. The model transcribes it as `lifecycle : DocState → LifeEvent →
Option DocState`, where `none` means "the spec states no outcome for this cell" — an invented
outcome was never an option. The witness shows silence is not confined to `CLOSED`:

* `lifecycle .empty (.deleteDisplayedRow false) = none` — R-40's own state. A launch whose history
  head is unreadable enters `EMPTY` **and keeps the row** ("an initial history-head row remains in
  history"). The reader can then swipe-delete that row. §3.1's `EMPTY` row lists only one leave:
  "any open route (R-01) → LOADING". Whether the window stays `EMPTY`, beeps, or does something
  else is unstated.
* `lifecycle .reloading .fileChangedOnDisk = none` — R-05 states the coalescing rule ("a burst
  yields at most **two** reloads") but not what the *state machine* does with an event delivered
  while `RELOADING`. The `RELOADING` row's only leave is "content swapped → `VIEWING`".

Twelve further cells are silent for reasons that are *not* gaps — they are unreachable from a state
§3.1 puts the application in with that event (a launch while `VIEWING`, a watcher event while
`EMPTY`, a load outcome while `RELOADING`). The model cannot tell an unreachable cell from an
unstated one: both are `none`. That is the finding's second half — the table's *domain* is stated
(5 states) and its *relation* is not.

**Proposed resolution.** Either (a) state §3.1 as a total function by adding the missing two cells
(the cheapest: "deleting the last row while `EMPTY` leaves the window `EMPTY` with no rows" and "an
event during `RELOADING` is coalesced into the pending reload"), or (b) say explicitly that the
table is partial and that a cell it does not name is unspecified — which is honest but leaves T-28
and T-29 unable to assert anything about them.

---

## F-141 · G-2 · P2 — `stripInlineMarkdown`'s removals have no pinned order

**Anchor:** C-12 (§4). **Witness:** `f141_strip_order_observable`.

C-12 lists what `stripInlineMarkdown` removes — "trailing `#`s, `**`, `__`, backticks, unescaped
`*`, **both** underscores of an `_…_` emphasis pair …, and reduces `[text](url)` to `text`" — in a
single sentence, with no order and no statement that the order is immaterial. It is not: the
witness shows `**a**b` collapsing to `ab` under the model's order (the spec's own listing order)
while a different order over the same removals leaves it unchanged.

The order is observable in the TOC (C-02 rule 7 uses this function for `TOCHeading.text` and
`slugText`) and in every bookmark title (R-27).

**Proposed resolution.** State the order (the listing order is a reasonable reading), or state that
the removals are independently idempotent over the block classes the function is applied to. Either
way, T-08's assertions about `Draft notes` and `snake_case` do not cover the interaction.

---

## F-142 · G-2 · P2 — "uses its first line only" vs "single-line ATX only"

**Anchor:** C-02 rule 7 and the `ParsedDocument` field comment; R-22. **Witness:**
`f142_heading_multiline_block`.

Two clauses of the same spec disagree about what makes a block a TOC heading:

* C-02 rule 7: *"`tocHeadings` contains each block whose trimmed text starts with `# `, `## `, or
  `### ` and is not a fence, **using its first line only**"* — which admits a multi-line block;
* `ParsedDocument`'s own field comment: *"level 1…3, **single-line ATX only**"*.

A block whose first line is `# Title` and whose second line is body text is a heading under the
first reading and not under the second. The witness shows the model taking rule 7's literal
reading: such a block yields a TOC entry with the same level and slug as the one-line form.

**Proposed resolution.** Pick one. The literal reading of rule 7 makes `# Title` + body text a
heading whose *section* (C-12) starts one block early, which is a behavioural difference, not a
wording one.

---

## F-143 · G-2 · P1 — the TOC's `text` keeps the ATX marker

**Anchor:** C-12, C-02 rule 7; contradicted by T-08. **Witness:** `f143_toc_text_keeps_marker`.

C-02 rule 7 says `text` is *"the line with inline Markdown stripped (C-12 rules)"*, and C-12's
`stripInlineMarkdown` removes **trailing** `#`s — nothing removes the **leading** `# ` that makes
the line a heading. A literal reading therefore leaves the marker in the TOC:

```
theorem f143_toc_text_keeps_marker :
    (tocOf ["# Sibling"]).map (fun h => h.text) = [some "# Sibling"]
```

But T-08 asserts the TOC shows `Heading with Σ in it` and `π at h2 size, a/b too` — and the step
that removes the marker is nowhere in the spec. Every TOC row, and every heading-derived bookmark
title (R-27), is affected.

**Proposed resolution.** Add the marker to C-12's removals (a leading `# ` and the `#`-only forms),
or state that the *view* strips it — the current wording makes the view's behaviour unstateable.

---

## F-144 · G-2 · P2 — a quote's direction is "chosen from the preceding character"

**Anchor:** C-10 (§4). **Witness:** `f144_quote_direction_unpinned`.

C-10 says `"` and `'` become *"directional quotes chosen from the preceding character"* and pins no
mapping. The model chooses the natural one (absent or whitespace ⇒ opening, otherwise closing) and
the witness exhibits the flip on a single input character:

```
rewriteRun "a \"b" = ['a', ' ', '“', 'b']      -- after a space: opening
rewriteRun "a\"b"   = ['a', '”', 'b']          -- after a letter: closing
```

Which characters open and which close is a complete table in any implementation (after `(`? after
a digit? at a paragraph start?) and the spec fixes none of it.

**Proposed resolution.** Pin the predicate — "opening when the preceding character is absent,
whitespace, or one of `([{“‘`" is the conventional rule — or cite the as-built behaviour.

---

## F-145 · G-2 · P2 — C-10 defines a GFM table by example, R-24 defines it exactly

**Anchor:** C-10 vs R-24. **Witness:** `f145_table_definition_diverges`.

C-10's early return names *"a `|---|` separator row"*; R-24 defines the same notion precisely:
*"a GFM table (first line contains `|`, second line consists only of `-`, `:`, `|`, space)"*. The
two predicates differ — the witness shows a block (`a|b` / `-|-`) that R-24's definition accepts
and that contains no `|---|` substring at all.

The model uses R-24's exact definition for both uses. A reader implementing C-10 from its example
would not.

**Proposed resolution.** Cite R-24 from C-10 ("the GFM-table test of R-24"), so the two cannot
drift.

---

## F-146 · G-3a · P1 — C-07.1's span *scan* has no witness

**Anchor:** C-07.1 (§4). **Witness:** `f146_scan_unwitnessed` (an exhibit, not a proof of absence).

C-07.1 pins three things about a math span: its **acceptance** (an opening `$` followed by
non-whitespace; a closing `$` preceded by non-whitespace and not followed by a digit; no bare `$`;
no backtick crossing; `\$` literal), its **placement** (own paragraph when at line start and end),
and the URL it rewrites to. It says nothing about the **scan** that finds candidates: the
precedence of `$$` over `$`, how a `$` that opens and never closes is treated, whether a `$$` span
may contain a single `$`, and whether the scan runs per block or per source line.

The model does not contain the scan either — only the acceptance conditions — so this is a genuine
**G-3a**: a requirement with no proof and *no planned test*. T-07 exercises `test-docs/math.md`'s
"must NOT become math" section, which fixes the observed cases; it does not witness the rule.

**Proposed resolution.** State the scan's order and its unterminated-span rule in C-07.1, and add a
T-id for it (or extend T-07's list of proved ids to name C-07.1's scan clause).

---

## F-147 · G-2 · P2 — "drop the characters from each token" is stronger than "they are not syntax"

**Anchor:** C-03 (§4). **Witness:** `f147_token_collision`.

C-03's query construction *"drop[s] the characters `" ( ) : * ^` from each token"*. The model reads
that literally (`stripFtsChars` filters those characters anywhere in a token), and the witness
shows the consequence: `a"b` and `ab` become the same FTS term, so a query cannot distinguish a
document containing `a"b` from one containing `ab`.

The rule's evident intent is narrower — the six characters are FTS5 syntax and must not be
interpreted — but as written it also *deletes* them, which changes the matched text.

**Proposed resolution.** Say which is meant: either "the characters are escaped/neutralised" (then
they survive in the term) or "the characters are removed" (then say so, and note the collision as
accepted). T-24's assertions do not cover a token containing one of the six.

---

## Summary

| finding | class | severity | anchor | witness |
| --- | --- | --- | --- | --- |
| F-139 | G-2 · over-strong / under-stated pin | P1 | C-06.1 rule 3 | `f139_color_map_unpinned` |
| F-140 | G-1 · silent case | P1 | §3.1, R-05, R-40 | `f140_lifecycle_silent_cells` |
| F-141 | G-2 · unpinned rule order | P2 | C-12 | `f141_strip_order_observable` |
| F-142 | G-2 · two readings | P2 | C-02 rule 7 | `f142_heading_multiline_block` |
| F-143 | G-2 · unpinned step | P1 | C-12, C-02 rule 7 | `f143_toc_text_keeps_marker` |
| F-144 | G-2 · unpinned mapping | P2 | C-10 | `f144_quote_direction_unpinned` |
| F-145 | G-2 · definition drift | P2 | C-10 vs R-24 | `f145_table_definition_diverges` |
| F-146 | G-3a · unwitnessed | P1 | C-07.1 | `f146_scan_unwitnessed` |
| F-147 | G-2 · stronger than intended | P2 | C-03 | `f147_token_collision` |

One G-1 (a silent case), seven G-2 (pin precision), one G-3a (unwitnessed). No P0: the model found
no contradiction among the spec's constants, and no invariant the spec asserts about itself failed.
The three spec sentences the model *did* set out to check and that hold for all inputs are the CLI's
closed exit set (`cli_exit_closed`), its diagnostics contract (`cli_stderr_contract`,
`cli_stdout_contract`), and the lifecycle's closed state set (`lifecycle_closed_state_set`).