# Specification Review Report

> **Reviewed document:** `SPEC.md`, v0.14.3 (2026-09-27), as committed in `937a351`.
> **Review:** ninth review; finding ids continue from F-172 (the eighth review, F-149…F-172, is recorded in the document's revision history as v0.14.1).
> **Scope of this review:** (1) verification that every F-149…F-172 resolution, D-54, and the v0.14.3 `raw-html-images.md` changes landed as stated; (2) a fresh four-pass review of the whole document, weighted toward the text added in v0.14.1–v0.14.3, because that is the least-reviewed material.
> **Method:** the four passes of the review method, a mechanical id walk (every referenced id is declared; no new duplicate declarations — the six duplicates the walk reports, R-35, C-18, C-19, E-31, T-49 and T-50, are the same pre-v0.14 prose mentions it reported before), a phrase-level check that each resolution's text is present, and a check of the §9 fixtures against the oracles that cite them (`test-docs/syntax.md` and `test-docs/math.md`, which T-53 runs).

---

## 1. Executive Summary

**Overall maturity: Level 3 (implementation-grade).** Every eighth-review finding is resolved in the text, both HIGH ones (F-149 no-window, F-151 web-view interaction) included. The v0.14 delta now meets the rest of the document's bar: the seams the last review found are closed with explicit exceptions in the rows that own the rules.

**Implementation readiness:** `READY WITH MINOR FIXES`.

**Findings:** 9 — 0 CRITICAL, 0 HIGH, 4 MEDIUM, 5 LOW. All nine are in text added by v0.14.1–v0.14.3, and none reopens an earlier finding. They share one cause: **a rule added in one row whose reach goes beyond that row**. C-22.2's new inline-placement rule catches inline math. R-44's `Frontmatter` title overrides R-27 without R-27 knowing. T-53's new oracles were written without running them against their own fixtures.

**Most important strengths**

- **Resolutions are placed where a reader of the owning rule will find them.** R-06, R-08, R-11/K-07 and E-26 each carry their own exception, so the F-153-class conflicts are gone. Three findings below are the same class recurring in newer text, which shows the pattern is worth checking mechanically.
- **The test oracles are now computable.** `--print-pdf` emits per-block kind, rectangles, images and formula rectangles; T-53's eight assertions each say what to compare. The two that fail (F-175, F-176) fail precisely *because* they are precise enough to run against a fixture.
- **Reference images now exist for every v0.14 surface.** There are five, each captured from the original with the capture method stated. §9.7 is candid about what each one is normative for: the print image is pre-pagination, and the raw-HTML image is stitched.
- **Departures from the original are fenced off:** D-47, D-48, D-50, D-51, D-54, and the fixture's *departs from the original* section.

**Most important weaknesses**

- **C-22.2's inline-placement rule reaches inline math** (F-173). It then contradicts R-12's baseline behaviour and the limitation D-02 accepts.
- **Two T-53 oracles fail on their own fixtures** (F-175, F-176): `syntax.md`'s strikethrough, task-list and footnote markup, and `math.md`'s deliberately invalid LaTeX.
- **R-27/R-28 do not know about R-44's block-0 rules** (F-174).

## 2. Overall Maturity

**Level 3.** A strong coding agent can build the whole specification — the v0.14 features included — without a material semantic question. The findings below are corrections to reach, scope or test oracles. Each has a one-sentence resolution, and none changes the product.

The document is not Level 4. It has kernel-checked models of its pure contracts (`proof_from_spec/`, `proof/`), but those models predate v0.14, including C-12's new step (0) and C-20's recognition rules. Level 4 would require them to be current.

## 3. Findings Summary

| ID | Severity | Location | Title |
| -- | -------- | -------- | ----- |
| F-173 | MEDIUM | C-22.2, R-12, D-02 | The inline-placement rule covers inline math and contradicts R-12/D-02 |
| F-174 | MEDIUM | R-27, R-28, C-18.9, R-44 | R-44 overrides the bookmark anchor and title rules without R-27/R-28 saying so |
| F-175 | MEDIUM | T-53 (1), C-12, `test-docs/syntax.md` | The vector-text oracle fails on `syntax.md`'s GFM markup |
| F-176 | MEDIUM | T-53 (2), C-21.4, E-10, `test-docs/math.md` | The vector-formula oracle fails on `math.md`'s rejected LaTeX |
| F-177 | LOW | C-21.2, I-014 | "The screen's gap for that pair" names no theme and is unpinned for most pairs |
| F-178 | LOW | R-01, E-38 | A window created on demand, then the action is cancelled or fails |
| F-179 | LOW | R-24, R-44 | The verbatim header view does not say whether the fence lines show; a header-only document has no ⌘D anchor |
| F-180 | LOW | §9.6, §9.7, T-59 | T-59 is compared to a reference image but not observed; a raster is cited as evidence of vector output |
| F-181 | LOW | Front matter *Status* | The Status line has become a second revision history |

## 4. Detailed Findings

### F-173 — The inline-placement rule covers inline math and contradicts R-12/D-02

**Severity:** MEDIUM

**Location:** C-22.2 (*Inline placement*), R-12, R-13, D-02, C-07.1

**Observation**

v0.14.3 added to C-22.2: "an inline image — `<img>` or Markdown — sits on the text baseline, its bottom edge on the baseline of its line". C-07.1 rewrites every inline `$…$` into a Markdown inline image (`![](mdv6-math://inline/…)`), so the rule, read literally, also governs inline math. For math the correct placement is the **formula's** baseline, with descenders below the text baseline. The as-built placement is different again: D-02 records that math sits `descent` points above the baseline, an accepted limitation with a one-line fix waiting in the vendored MarkdownUI.

**Why it matters**

The rule pins math to the wrong target. An implementer who applies D-02's fix (now easy, since MarkdownUI is vendored, D-49) violates C-22.2. One who follows C-22.2 raises every descender, which is worse than D-02's state.

**Potential consequence**

Two builds place inline math differently, and a T-07/T-59 reviewer cannot tell which one is right.

**Recommended resolution**

Scope the rule: "an inline image other than a math span (C-07.1) — `<img>` or Markdown — sits on the text baseline…; inline math is placed per R-12 and D-02." Add D-02 to C-22.2's citations.

### F-174 — R-44 overrides the bookmark anchor and title rules without R-27/R-28 saying so

**Severity:** MEDIUM

**Location:** R-27, R-28, C-18.9, R-44 (*Block 0 as a header*)

**Observation**

R-44 (v0.14.1) says a hidden header "is never the ⌘D / ⌘⇧0 anchor — the next block is taken instead", and that a block-0 bookmark or placeholder "is titled `Frontmatter`, never by the header's first line (R-27)". R-27's own title rule still reads "titled by the nearest TOC heading … else the block's **first line** with inline Markdown stripped …". Its anchor rule still reads "the topmost block whose frame intersects the viewport", and neither sentence has an exception. C-18.9 shows the placeholder row "titled by the R-27 title rule".

There is also a gap in the override. A **header-only** document with the header hidden has no "next block", and R-27's `(empty)` title is reserved for "the document has no blocks", which this document does not satisfy.

**Why it matters**

This is F-153's class of defect, two `MUST`s at the same level that disagree, recurring in the text that resolved F-158. A reader implementing R-27 alone titles the bookmark `---`.

**Potential consequence**

Bookmarks titled `---`. For a header-only document, either a crash-prone empty anchor or an inconsistent title.

**Recommended resolution**

Add to R-27: "— except as R-44 provides for block 0 (not the anchor while hidden; titled `Frontmatter`)". Mirror it in R-28 and in C-18.9's placeholder sentence. In R-44, add: "a document whose only block is a hidden header has no anchor: ⌘D and ⌘⇧0 beep". Extend T-52 with the header-only case.

### F-175 — The vector-text oracle fails on `syntax.md`'s GFM markup

**Severity:** MEDIUM

**Location:** T-53 assertion (1), C-12, `test-docs/syntax.md` (lines 7, 18–19, 44)

**Observation**

T-53 (1) requires "the whitespace-split tokens of every `prose` block's C-12-stripped source" to appear, in order, in PDFKit's extracted text. C-12 does not strip:

- `~~` (line 7: `~~strikethrough~~` prints as `strikethrough`);
- task-list markers `[ ]` / `[x]` (lines 18–19, which print as checkbox glyphs);
- footnote references `[^1]` and definitions (lines 7 and 44, which print as a superscript and a numbered note);
- list bullets `-` / `*`, blockquote `>`, and table pipes, none of which print as those characters.

All of these are in `syntax.md`, the fixture T-53 names. A conforming build therefore fails T-53 (1).

**Why it matters**

An oracle that a correct build fails is worse than none. It trains the verifier to ignore T-53.

**Potential consequence**

T-53 is reported red on every build, or it is "fixed" by weakening the checker ad hoc.

**Recommended resolution**

Define the oracle's normalisation explicitly: tokens of the C-12-stripped source after also removing `~~`, a leading list, quote, task or ordered-list marker per line, table pipes and delimiter rows, and footnote references and definitions. Or restrict (1) to a purpose-built fixture of plain paragraphs and headings (e.g. `test-docs/rhythm.md`, which T-53 (4) already uses), and move GFM coverage to the screen tests (T-05).

### F-176 — The vector-formula oracle fails on `math.md`'s rejected LaTeX

**Severity:** MEDIUM

**Location:** T-53 assertion (2), C-21.4, E-10, `test-docs/math.md` (§ *Errors*, line 49 on)

**Observation**

T-53 (2) requires that no rectangle in any block's `formulas` list intersects an entry of that block's `images`, i.e. every formula prints as glyphs. `math.md`'s *Errors* section deliberately contains LaTeX that SwiftMath rejects (`\frac{a`, `\notacommand`).

- For a rejected **inline** span, C-21.4 draws the span's rendering, and for a rejected span that rendering is E-10's source-text fallback, which the typesetting cache produces as a **bitmap** (the original's `fallbackImage` is baked).
- For a rejected **standalone** span, C-21.4 keeps the Markdown path, which embeds the same bitmap.

Either way an image intersects the span's rectangle, and T-53 (2) fails on a correct build.

**Why it matters**

The same oracle defect as F-175, in the assertion that proves R-45's strongest claim.

**Potential consequence**

T-53 is red on every build, or the rejected spans are quietly dropped from the fixture — and E-10's print behaviour then goes untested.

**Recommended resolution**

Pick one:

- **(a)** Exclude spans SwiftMath rejects from (2), and add a (2b): each rejected span's source text is present in the block's extracted text (the E-10 fallback printed as text, which is also better output).
- **(b)** Keep (2) universal, and require C-21.4 to print an E-10 fallback as text rather than as a baked image.

(a) matches the original; (b) is stricter. Record the choice in D-47.

### F-177 — "The screen's gap for that pair" names no theme and is unpinned for most pairs

**Severity:** LOW

**Location:** C-21.2, I-014, K-16, K-17

**Observation**

C-21.2 (v0.14.1) sets the printed gap to "$s_p$ times the **screen's** inter-block gap for that pair at zoom 1". It does not say under which theme. I-017 implies the print theme (`high-contrast`), but the row should say so. I-014 and K-16 pin the screen gap only for heading and paragraph pairs. For pairs involving code, tables, diagrams, lists, math or frontmatter, "the screen's gap" is whatever the screen implementation happens to produce, so the printed value is defined only relative to another build's output. T-53 (4) checks `rhythm.md` alone, which contains only the pinned pairs.

**Recommended resolution**

Say "under the print theme". For the unpinned pairs, either pin a rule (for example, $\max(\text{bottom}_i, \text{top}_{i+1})$ of the theme's element margins, with a fence or table counting as a paragraph) or state that those gaps are implementation freedom within the K-16 band.

### F-178 — A window created on demand, then the action is cancelled or fails

**Severity:** LOW

**Location:** R-01 (*No document window*), E-38

**Observation**

E-38 creates a window before ⌘O, a bookmark, ⌘0 or ⌘? acts. It does not say what happens when the action then produces nothing: the ⌘O panel is cancelled, ⌘0 has no placeholder (it beeps), or the bookmark's file is missing (E-09 beep). One reading leaves an `EMPTY` window behind; another closes it again. For ⌘O the order is also open: window first, or panel first and a window only on a choice.

**Recommended resolution**

Create the window **only when the action has a file to load**. ⌘O shows an application-modal panel first; ⌘0 and bookmarks check the target file first, and beep without a window when it is missing.

### F-179 — The verbatim header view does not say whether the fence lines show; a header-only document has no ⌘D anchor

**Severity:** LOW

**Location:** R-24 (frontmatter clause), R-44

**Observation**

R-24 shows a matched header "verbatim, its source lines as written". It is not stated whether the fence lines (`---`/`+++`, and `...` for YAML) are among those lines. They are part of block 0's source (C-02 rule 9), so a query for `---` matches there, and the count $m$ depends on the answer. The header-only ⌘D gap is folded into F-174.

**Recommended resolution**

State that the verbatim view shows block 0 exactly, fence lines included, so what is displayed is what $m$ counts.

### F-180 — T-59 is compared to a reference image but not observed; a raster is cited as evidence of vector output

**Severity:** LOW

**Location:** §9.6, §9.7, T-59

**Observation**

1. v0.14.3 made T-59 compare against `reference/ORIGINAL-RAW-HTML-IMAGES.png`, but §9.6's observed set (T-44, T-47, T-48, T-49, T-52, T-53 manual half, T-54, T-58) does not include T-59. §9.6's own rule is that a comparison against a reference is an observation.
2. §9.7 says `ORIGINAL-PRINT-MATH.png` is normative for "vector formulas". A 144 ppi raster cannot show whether a formula was vector; T-53 (2) is the evidence for that.

**Recommended resolution**

Add T-59 to §9.6's observed set. In §9.7, replace "vector formulas" with "formula placement and size".

### F-181 — The Status line has become a second revision history

**Severity:** LOW

**Location:** front matter, *Status* (line 3, ~1,070 words on one line)

**Observation**

Each version since v0.8 prepends its changelog to *Status*, which now narrates v0.14.3 back to v0.8 in one blockquote line. The revision history at the end already records every change in more detail, and the front matter's job is to state the current status.

**Recommended resolution**

Reduce *Status* to the current version, its date, a one-sentence summary, and the status-marker legend (*not yet realised*, **open defect**, *verification pending*), leaving the per-version narrative to the revision history.

## 5. Requirements Review

Requirements are observable and precise. The F-149…F-172 resolutions are all present, and each sits in the row that owns the rule it changes. The two remaining requirement-level conflicts are F-173 (C-22.2 against R-12/D-02) and F-174 (R-44 against R-27/R-28). Both are the pattern the last review named, and both are fixed with one clause each. No requirement is missing.

## 6. Interface and Data-Contract Review

The interfaces are complete:

- `--print-pdf` now reports kind, rectangles, images and formula rectangles, which is enough to compute T-53's assertions.
- C-06.5 states the web view's host integration: context menu, wheel, first responder, selection, logging and inspectability.
- C-22.1 skips quoted `>`.
- C-09 declares the fields C-09.1 reads.
- The manifest's `expect` includes `web`.

**Visual surface.** Every v0.14 surface now has a reference image, and every settable v0.14 feature has an affordance row. The hidden header's states are specified in R-44. Visual-surface completeness returns to 5, less the T-59 observation gap (F-180).

## 7. State and Failure Review

The zero-window state is specified (R-01, E-38), and §3.1 names how the lifecycle restarts. The one remaining gap is what an on-demand window does when its action is cancelled (F-178). *Close All* now cancels in-flight loads (E-36). Failure semantics for print, the web path and `<img>` are unchanged from the last review and complete.

## 8. Determinism and Algorithm Review

C-06.1 rule 0 is defined by reference to C-06.4's skip rule, so dispatch and stripping cannot drift apart. C-20.1's zero-row rule makes recognition depend on C-20.2's reduction. That is deterministic, and T-52 tests it. C-12's step (0) is ordered, and it precedes the steps whose order F-141 made normative. The only unpinned value is the non-heading printed gap (F-177).

## 9. Edge-Case Review

v0.14.1 added E-38 and extended E-32, E-33 and E-36; v0.14.3 added the block-level and inline missing-image pair and the local-server remote case to the fixture. The remaining boundaries are:

- a header-only document and ⌘D (F-174);
- cancelled on-demand actions (F-178);
- fence lines in the verbatim header view (F-179);
- rejected LaTeX in print (F-176).

## 10. Non-Functional Requirement Review

No change since the last review. K-17…K-19 pin the constants. The number of live web views is still implementation freedom.

## 11. Security and Trust-Boundary Review

Strengthened since the last review:

- mermaid is initialised with `logLevel: 'fatal'` in a non-inspectable web view;
- R-35 and T-36 cover WebKit's content process;
- the web view refuses every load beyond its page;
- the fixture's remote case no longer calls a third-party URL.

`mdv6/mermaid.LICENSE.txt` now exists, assembled from the published licence, the bundle's own notices, and DOMPurify's licence, with its sources recorded in C-13. No findings.

## 12. Observability and Provenance Review

Provenance is strong. Every reference image records the build (`68aa008`), the theme, the pointer state, the capture method and the scale. The print image records that it is pre-pagination, and the raw-HTML image records that it is stitched. D-54 records an observation made during capture. No findings.

## 13. Testing and Verification Review

Every requirement has a test, and every pure contract has a unit half. The two defects are oracles that fail against their own fixtures (F-175, F-176). This is the failure mode F-129 and F-107 were about, and it is caught only by running an oracle against its fixture before shipping it. One observed-set omission remains (F-180). Negative and departure cases are well represented, and the fixture now separates the original's behaviour from the spec's departures.

## 14. Metrics and Evaluation Review

No new metric. C-21.1's rationale is now correct (the $860/768$ factor is stated), and the formula is unchanged.

## 15. Traceability Review

- The chain is complete, and E-38 and D-54 have §11 and *Affects* entries.
- The *Affects* cells of D-46 and D-50 name the ids their prose constrains.
- F-173 should add D-02 to C-22.2's citations.
- F-174 should add R-27 and R-28 to R-44's cross-references.

## 16. Internal-Consistency Review

Two normative conflicts: F-173 and F-174. Everything else the last review flagged is consistent now.

## 17. Architecture Review

No change; the architecture supports every requirement. No findings.

## 18. Implementation-Agent Readiness

**YES — WITH MINOR CLARIFICATIONS.**

There are no blocking questions. The clarifications an implementer would ask for are:

- where inline math sits (F-173);
- how a hidden or header-only block 0 affects ⌘D (F-174);
- whether an on-demand window survives a cancelled action (F-178).

A verifier would additionally need T-53's oracles repaired (F-175, F-176) before T-53 can pass on a conforming build.

## 19. Quality Scorecard

| Dimension | Score |
| --------- | ----: |
| Scope clarity | 5 |
| Terminology | 4 |
| Requirement precision | 4 |
| Interface completeness | 5 |
| Visual-surface completeness | 5 |
| Data-contract completeness | 4 |
| State/lifecycle definition | 4 |
| Algorithm precision | 4 |
| Failure semantics | 5 |
| Edge-case coverage | 4 |
| Non-functional requirements | 4 |
| Security specification | 5 |
| Observability/provenance | 5 |
| Testability | 3 |
| Evaluation/metrics | 5 |
| Traceability | 4 |
| Internal consistency | 4 |
| Architecture consistency | 5 |
| Implementation readiness | 4 |

Changes since the eighth review:

- **Up:** interface completeness, visual surface, failure semantics, observability, internal consistency, architecture and implementation readiness, each recovering what the v0.14 delta had cost.
- **State/lifecycle** returns to 4 with the zero-window rule.
- **Testability** stays at 3, because T-53's two broken oracles (F-175, F-176) mean the print tests cannot yet pass on a correct build.

## 20. Remediation Plan

### P0 — Blocking

None.

### P1 — Important

1. **F-173** — scope C-22.2's inline placement to non-math images, and cite R-12/D-02. *(one clause)*
2. **F-174** — add the R-44 exception to R-27, R-28 and C-18.9; say that a header-only document with the header hidden has no ⌘D anchor; extend T-52. *(three clauses, one test clause)*
3. **F-175, F-176** — fix T-53's oracles: either normalise the token oracle for GFM markup or restrict it to `rhythm.md`; exclude rejected LaTeX from (2) and add (2b), or require E-10 fallbacks to print as text. Record the choice in D-47. *(two assertions)*

### P2 — Improvement

4. **F-177** — say "under the print theme" in C-21.2, and pin the rule for gaps between non-heading pairs, or declare it implementation freedom.
5. **F-178** — create the on-demand window only when the action has a file to load.
6. **F-179** — state that the verbatim header view shows the fence lines.
7. **F-180** — add T-59 to §9.6's observed set; change "vector formulas" in §9.7 to "formula placement and size".
8. **F-181** — reduce *Status* to the current state.

No redesign is recommended.

## 21. Final Verdict

```text
Specification maturity:
Level 3

Implementation readiness:
READY WITH MINOR FIXES

Primary blocker:
NONE

Most important improvement:
Scope C-22.2's inline-placement rule away from inline math, carry R-44's block-0 rules into R-27/R-28, and make T-53's vector-text and vector-formula oracles pass on their own fixtures — after which the print tests can go green on a conforming build.
```
