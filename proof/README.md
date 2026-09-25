# mdv6 proof — the Lean half of `mdv6Core`'s conformance evidence

Lean 4 formalization of the **observable contract** of the `mdv6Core` library target
([`mdv6/Core`](../mdv6/Core), the `Package.swift` target `mdv6Core`) — the specification is
[`SPEC.md`](../SPEC.md) v0.13.1.

## The trust boundary, first

Lean proves the **model** — a pure Lean function. It never reads or executes `mdv6/Core`. The
bridge has three legs, and this project builds only the middle one:

| leg | claims | evidence |
| --- | --- | --- |
| **A. Transcription** | the model is a faithful transcription of the Swift source | **manual** — the correspondence table at the head of `Mdv6Proof/Mdv6/Model.lean`, source file by source file, including the lines deliberately *not* modelled and the witness that carries each |
| **B. Lean (this project)** | the model satisfies the spec's contract **for all inputs** | `lake build` — kernel-checked theorems, zero warnings |
| **C. Empirical** | the *file* satisfies the process-level contract | the `swift test` suite (`Tests/mdv6Tests`, `Tests/mdv6RenderTests`) and the C-17 harness — the §9 tests named in `Theorems.lean`'s deferral table |

A green `lake build` here means the model's contract holds for every input. It says **nothing**
about the Swift files by itself: leg A is a person's reading, and leg C is the test suite's.

## Layout

- `Mdv6Proof/Mdv6/Spec.lean` — the **spec side**: every value `SPEC.md` pins as normative, stated
  once, with its unit named (zoom in hundredths, em factors in thousandths, byte ceilings in
  bytes) and every constant's doc comment quoting the spec. `section Facts` checks the spec's own
  claims about those constants — distinctness, ordering, the K-13 worked arithmetic, the §7.1
  ratio in lowest terms.
- `Mdv6Proof/Mdv6/Model.lean` — the **model**: a transcription of `mdv6/Core`'s pure,
  deterministic functions — the C-02 split and TOC, C-03's query, C-05's language resolution,
  C-06.1's sanitiser and C-06.2/C-06.3's repairs and mixes, C-07.1's delimiter scan and C-07.3's
  plain-text converter, C-08's fingerprint and resolution, C-10's smart typography, C-11's slug,
  C-12's sections, C-15's history list, C-17's scan order and pixel metric, C-19's citation
  grammar, and the pure halves of `Preferences`, `ZoomStep`, `ContentLimits`, `ColumnWidth`,
  `RenderMetrics`, `Diagnostics`, `ThemeCatalog`, `HarnessCases` and `bin/mdv6`'s exit map. The
  head of the file is the **correspondence table** (leg A) and the list of stated deviations.
- `Mdv6Proof/Mdv6/Theorems.lean` — **the proof**: `section Rows` (the spec's behaviour tables,
  row by row), `section Invariants` (the for-all-inputs claims), `section Reachability` (every
  named value is reached), and the closing **deferral table** mapping every id out of Lean's reach
  to the §9 test that carries it.

## Commands

```sh
cd proof
lake build            # checks every proof — exit 0, zero warnings
```

## What "proven" means here

`section Rows` is partly **transcription**: a theorem whose statement is the model's own
definition written down at the spec row's input (the C-02 split on a fixture, the sanitiser's
rules in order, the citation grammar's accepted forms). Those exist so that every spec row has a
declaration an audit can read against the row's text. The rest discharge sentences that are
**not** the definition of the thing they are about: the for-all-inputs bounds and closure facts
(the zoom range, the clamp ranges, the ceiling admits relation, the ink and pixel ratios, the
rhythm band), the exhaustiveness claims (every ceiling, language, theme and exit is reached), and
the table facts in `Spec.lean`.

What Lean certifies: the deterministic core's contract, for all inputs. What it does not: the
process layer — real file descriptors, the FSEvents watcher, AppKit/SwiftUI view trees, CoreText
and tree-sitter, SwiftMath typesetting, ELK layout, SQLite, the network loader, and the build and
release chain. Each of those is a row in the deferral table with its test.

## Scope

| class | count | what |
| --- | --- | --- |
| proven | 54 ids | C-02…C-12, C-15, C-17, C-19, R-08, R-11, R-24, R-27, R-29, R-30, R-33, R-35, R-41, K-03…K-10, K-13, K-14, K-16, E-01, E-02, E-07, E-08, E-13, E-14, E-15, E-17, E-22, E-23, E-24, E-28, E-31, I-004, I-005, I-009, I-010, I-012, I-013, I-014 — the pure contracts with an enumerable input space |
| structural | 1 id | I-001 (no environment parameter) — true by the model's typing, tagged where it lives |
| deferred | 69 ids | every other id, in the closing table with its §9 test |

Audited mechanically: `grep -rhoE '\*\*[^*]+\*\*' Mdv6Proof/ | tr -d '*' | grep -oE '[RCIKE]-[0-9]+' | sort -u`
gives the 55 tagged ids; the deferral table's 69 rows are disjoint from it, and together they are
exactly the specification's 124 requirement ids.

## Deviations, stated once

The model's strings are `List Char` (code points) where Swift counts extended grapheme clusters;
its numbers are integers in a fixed unit where Swift uses `Double`; and every effect is an
injected value rather than an `IO`. `Model.lean` states each deviation and names the test that
carries it.
