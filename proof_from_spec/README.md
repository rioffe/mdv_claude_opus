# mdv6 — spec model

Lean 4 formalization of what [`SPEC.md`](../SPEC.md) v0.13 *says* — its normative tables as a pure
total function, with the spec's own claims about itself kernel-checked.

> **There is no implementation.** This certifies the spec, not a system. The spec's §9 tests are
> planned, not run.

## The trust boundary, first

Lean proves the **model** — a pure Lean function. It never proves a document, and here there is no
program at all. The bridge has three legs and this project builds only the middle one:

| leg | claims | evidence |
| --- | --- | --- |
| **A. Transcription** | the model is a faithful transcription of the spec's normative tables | **manual** — the correspondence table at the head of `Mdv6Spec/Mdv6/Model.lean`, anchor by anchor; made *checkable* (not proven) by the row theorems in `section Rows` |
| **B. Lean (this project)** | the model satisfies the claims the spec makes about itself — for all inputs | `lake build` — 202 kernel-checked declarations |
| **C. Empirical** | the *system* the spec describes behaves as specified | **does not exist** — no implementation; the spec's §9 tests are *planned*, never run |

A green `lake build` here means the spec is internally consistent, total over the input space it
enumerates, and has a witness plan for everything it does not pin. It does **not** mean anything has
been built correctly.

## Layout

```
proof_from_spec/
├── lean-toolchain              leanprover/lean4:v4.34.0
├── lakefile.toml               project mdv6_spec, library Mdv6Spec
├── lake-manifest.json          packages: [] — zero dependencies
├── Mdv6Spec.lean               root module (imports the three concern modules)
└── Mdv6Spec/Mdv6/
    ├── Spec.lean               the normative side
    ├── Model.lean              the transcription
    └── Theorems.lean           the proof
```

* **`Spec.lean` — the spec side.** 226 declarations: 130 pinned constants (the §5.2 exit map and
  its two diagnostics; the K-04 zoom range and pane clamps; K-10/K-13's article and column numbers;
  C-09's nine themes and the three that refuse smart typography; C-04's twelve preference keys;
  C-05's seventeen fence words and the alias table; C-06.1's 46 CSS colour names, tag list and
  style-line keywords; C-07's wrappers and script sets; C-08/K-06/K-09's anchor numbers; K-06's
  timings; K-14's and C-16's ceilings; C-17's exits and pixel tolerance; §7.1's ink threshold;
  R-01/R-02/R-03's route and extension sets; C-15's JSON keys; C-03's dropped characters and
  ordering keys; C-19.1's grammar and its accepted/rejected examples; §3.1's states; C-02's
  markers), each quoting the spec's normative text, plus 96 `Facts` lemmas — closed `decide`-able
  checks that the spec's own claims about those constants are mutually consistent (distinctness,
  ordering, ASCII-ness, no CR/LF, the K-13 worked arithmetic, alias disjointness, §7.2's
  handle rule).
* **`Model.lean` — the model.** The spec's tables as a pure, total function: `Input` (one
  constructor per group of spec rows; a row stated for "any" input carries that input as a field),
  `Result` (the observable cells), and `outcome : Input → Option Result` where **`none` means the
  spec states no outcome for this input** — never an invented outcome. The spec's partial cells
  (`TocHeading.text`, the fingerprint's 80-cluster truncation, C-06.1's colour values, R-27's
  60-cluster truncation, C-07.1's scan) are carried by `Prop`-valued pins that the invariant
  theorems take as hypotheses: the hypotheses are the spec, not the model. The correspondence table
  at the head of the file is leg A.
* **`Theorems.lean` — the proof.** 202 declarations in six sections: `Rows` (transcription, one
  theorem per spec row — see the tautology rule below), `Invariants` (the claims quantified over
  the whole input space: the CLI's closed exit set and its diagnostics contracts, §3.1's closed
  state set, I-001's environment independence, I-004's determinism, the K-04/R-11/C-04/K-14/C-07.1
  closure and monotonicity facts), `Reachability` (every exit code, state, route kind, fragment
  kind, ceiling kind and harness exit reached), `Findings` (one witness per spec-precision gap),
  and the closing tables: **the deferral table** (every ID out of Lean's reach, with the planned
  §9 test that will carry it), **the §9 witness plan** (all 51 T-ids), **the excluded table** (the
  cases the spec puts out of scope by name) and **the decision table** (D-01…D-45, provenance
  only).

## Commands

```sh
cd proof_from_spec
lake build            # checks every proof — exit 0, zero warnings
```

## What "proven" means here

The `Rows` section is **transcription**: each theorem there is the model's own definition written
down a second time at the spec row's input, and it carries a doc comment saying so. Those theorems
exist so that the ID-to-declaration join is complete — every spec row has a declaration an audit can
read — not because they are evidence about the spec.

Every declaration outside `Rows` discharges a spec sentence that is **not** the definition of the
thing it is about: a claim over the whole input space, a closed set the spec names, a reachability
claim, or a claim about the input space itself. Its doc comment names the sentence.

## The tag discipline

Each declaration is preceded, ending at most one line above its head, by a doc comment whose first
line opens a **bold span** containing every spec ID the declaration discharges. Bold means
*discharged*; unbolded IDs are prose. Decision IDs (`D-nn`) are provenance and are excluded from the
join; parenthetical test IDs are informational pointers.

Audited mechanically (`grep -rhoE '\*\*[^*]+\*\*' Mdv6Spec/ | tr -d '*' | grep -oE '[RCIKE]-[0-9]+'`):

* **124** requirement IDs in `SPEC.md`; **77** are tagged as discharged, and the scope map in
  `Theorems.lean`'s header lists exactly that set;
* the remaining **47** each appear in the deferral table with a real, planned T-id;
* all **51** T-ids appear in the §9 witness plan; all **45** D-ids in the decision table;
* no ID is in none of the three places.

## Scope

| class | count | what |
| --- | --- | --- |
| proven | 77 ids | the pure contracts with an enumerable input space: §5.2, §3.1, C-02, C-03, C-04, C-05, C-06.1, C-07.1/C-07.2, C-08, C-10, C-11, C-12, C-15, C-16, C-17, C-19, R-01…R-04, R-08, R-11, R-17…R-20, R-24, R-27, R-30, R-33, R-40, and the edge cases those reach |
| structural | 2 ids | I-001 (no environment parameter — a typing fact, tagged), I-004 (determinism — a typing fact, tagged) |
| deferred | 47 ids | the process, GUI, network, persistence and build layers, each naming its planned §9 test |
| excluded | 8 rows | the spec's own out-of-scope list (§0's non-goals, §4's renderer/theme carve-outs, C-19.5, D-44) |
| provenance only | 45 ids | D-01…D-45 |

## Findings

Nine spec-precision gaps, each with a kernel-checked witness — see
[`docs/reviews/SPEC_MODEL_FINDINGS.md`](../docs/reviews/SPEC_MODEL_FINDINGS.md):

* **F-139 · G-2 · P1** — C-06.1 rule 3 names 46 CSS colour names and pins no hex value
  (`f139_color_map_unpinned`);
* **F-140 · G-1 · P1** — §3.1's lifecycle table is partial; two reachable cells have no stated
  outcome, and twelve more are silent because they are unreachable
  (`f140_lifecycle_silent_cells`);
* **F-141 · G-2 · P2** — `stripInlineMarkdown`'s removals have no pinned order, and the order is
  observable (`f141_strip_order_observable`);
* **F-142 · G-2 · P2** — "uses its first line only" (rule 7) vs "single-line ATX only" (the field
  comment) (`f142_heading_multiline_block`);
* **F-143 · G-2 · P1** — the TOC's `TOCHeading.text` keeps the ATX marker under a literal reading of
  C-12, contradicting T-08 (`f143_toc_text_keeps_marker`);
* **F-144 · G-2 · P2** — a quote's direction is "chosen from the preceding character", unpinned
  (`f144_quote_direction_unpinned`);
* **F-145 · G-2 · P2** — C-10 defines a GFM table by example, R-24 defines it exactly, and the two
  predicates differ (`f145_table_definition_diverges`);
* **F-146 · G-3a · P1** — C-07.1's span *scan* (as opposed to its acceptance conditions) has no
  proof and no planned test (`f146_scan_unwitnessed`);
* **F-147 · G-2 · P2** — "drop the characters from each token" deletes them, so `a"b` and `ab`
  collide in the index (`f147_token_collision`).

`SPEC.md` was not edited to make any proof close: the model reads the spec, it does not negotiate
with it.