# Specification Review Report

> **Reviewed document:** `SPEC.md`, v0.12 (2026-09-19), 955 lines, as committed in `ff8cde7`. Line numbers below are that revision's; v0.12.1 applied every finding and renumbered the file.
> **Review:** seventh review; finding ids continue from F-125 (the sixth review, F-114..F-125, is recorded in the document's revision history).
> **Scope of this review:** the whole specification. The v0.12 delta (C-19, C-02 rule 8, the R-19/E-06/T-22/T-49 edits, D-44, the §11 rows) is audited clause by clause, because it is the newest and least-reviewed material; the rest is re-checked for consistency with it.
> **Method:** the four passes of the review method — comprehension, local precision, cross-consistency, implementation simulation — plus the mechanical id walk (`tools/speccheck.sh` / `speccheck check`, which reports `0 dangling, 0 stale`; its `3 uncited` are the three unrealised v0.12 ids).

---

## 1. Executive Summary

**Overall maturity: Level 3 (implementation-grade).** The pre-v0.12 document meets the readiness bar: an implementer can build it and a verifier can test it, with almost no semantic inference left. The v0.12 addition is **not** at that bar. It introduces a direct normative contradiction, an internal grammar/behaviour mismatch, and a test whose fixture makes its own stated expectation false.

**Implementation readiness:** `READY WITH MINOR FIXES` for the system as a whole; `NOT READY` for C-19 until F-126, F-128 and F-129 are resolved.

**Findings:** 13 — 1 CRITICAL, 3 HIGH, 5 MEDIUM, 4 LOW. Twelve of the thirteen are in material new in v0.12; the document's pre-existing content produced no new defect of HIGH severity or above.

**Most important strengths**

- The traceability chain (intent → requirement → contract → invariant → test → evidence) is complete and machine-checked; ids resolve with no dangling references.
- Normative numbers are stated as formulas with defined symbols and pinned degenerate cases (§7.1 ink, §7.2 column width, K-16 rhythm band), and the tests cite the formulas rather than a golden produced by the implementation.
- The rendered surface is specified as behaviour, not delegated: §5.5/C-18 gives region layout, element inventory, per-element states, metrics (K-16) and reference images, with a §9.6 rule that a conformance report without an observed test is *verification pending*. This is the exception that most specs of this shape get wrong.
- Oracle independence holds for the visual surface: T-44/T-45/T-46 compare against a reference image or a measured quantity the spec states, not against the build's own prior output.

**Most important weaknesses**

- **The v0.12 fragment work did not propagate to the rows that already used the word "fragment."** R-18, R-21/C-18.8, E-22 and E-29 speak of "a `#fragment` link" with one meaning; C-19 makes the term cover two kinds with different effects. The result is one unsatisfiable pair of `MUST`s (F-126) and a family of ambiguous ones (F-127).
- **C-19.1's grammar and its prose disagree about `#L0`**, and the disagreement changes the observable result from "nothing happens" to "scroll to the end of the document and flash" (F-128).
- **T-49 is written against a fixture that does not produce the state it asserts** — the cited line is a blank line, so the citation resolves to the heading above it, not to "the paragraph containing line 10" (F-129). This is exactly the class of error the spec's own review culture (F-107, the ink-row/margin discovery) is designed to catch: an expectation asserted without measuring the fixture.
- **The three new ids carry no status marker.** The document's stated discipline marks specified-but-unbuilt work; §11's note still reads "At v0.11 every row is plain" (F-132).

---

## 2. Overall Maturity

**Level 3 — Implementation-grade.**

A competent coding agent can implement the pre-v0.12 specification with minimal semantic inference, and conformance is objectively testable for the major surfaces (scripted build/launcher/render/Mermaid/persistence tests plus observed chrome tests against reference images). It is not Level 4: verification is not mechanically closed end-to-end — several acceptance criteria are manual by design, and the newest feature is currently self-contradictory. It is well above Level 2: the ambiguities that remain are localized and enumerated below rather than pervasive.

---

## 3. Findings Summary

| ID | Severity | Location | One-line summary |
| -- | -------- | -------- | ---------------- |
| F-126 | CRITICAL | R-18 vs R-19 / C-19.4 | Two `MUST`s disagree on whether a same-document line-citation jump pushes a back snapshot. |
| F-127 | HIGH | C-19.1, C-19.4 vs E-22, E-29, C-18.8, R-18 | "Fragment" now covers two kinds with different effects; four existing rows are ambiguous. |
| F-128 | HIGH | C-19.1 vs C-19.1 prose, E-06, E-31 | The grammar accepts `#L0`; the prose and edge rows reject it — divergent observable behaviour. |
| F-129 | HIGH | T-49 vs `test-docs/links-sibling.md` | The cited line 10 is blank; the citation resolves to the heading, not the paragraph the test asserts. |
| F-130 | MEDIUM | C-02 rule 8, C-19.3, E-31 | Resolution undefined for a line preceding the first block (leading blank lines). |
| F-131 | MEDIUM | C-02 `ParsedDocument`, rule 8 | `blockLines` boundary convention (inclusive vs exclusive) is stated three ways. |
| F-132 | MEDIUM | §11 note, C-19/E-31/T-49 rows | New unrealised ids carry no *not yet realised* marker; §11's blanket note hides it. |
| F-133 | MEDIUM | C-19 scope vs R-19 classification | Citations into non-Markdown files never reach C-19; the canonical `Foo.swift#L412-L418` case silently falls to the system opener. |
| F-134 | MEDIUM | §9.4, §9.6 | T-49's scripted assertions sit in a manual group; its visual flash is absent from the §9.6 observed set. |
| F-135 | LOW | K-06 | The 0.6 s constant is labelled "Heading-copy flash"; C-19 gives it a second use. |
| F-136 | LOW | §5.5 | C-19 is placed inside the section titled "Window chrome". |
| F-137 | LOW | C-19.3, D-44 | "exactly as a TOC row does" is misleading; D-44's *Affects* column omits the rows it forces to change. |
| F-138 | LOW | T-49 | The fixture for the "document with no blocks" assertion is not named. |

---

## 4. Detailed Findings

### F-126 — Two `MUST`s disagree on the back-snapshot of a same-document citation

**Severity: CRITICAL**

**Location:** §2.3 R-18 (line 69) vs §2.3 R-19 (line 70) and §5.5 C-19.4 (line 538).

**Observation**

R-18 states, without qualification:

> A same-document jump from a `#fragment` link (R-19) or TOC row (R-21) MUST push a snapshot and clear the forward stack.

R-19, as amended in v0.12, states:

> […] a same-document line fragment MUST NOT push a snapshot or select a TOC row […]
>
> a same-document line fragment MUST NOT push a snapshot on a same-document jump

(repeated in C-19.4: "MUST NOT push a back snapshot on a same-document jump").

A line citation *is* a `#fragment` link handled by R-19 — that is precisely how R-19 now routes it. R-18 has not been amended, and no precedence rule exists between the two rows.

**Why it matters**

The two rows cannot both be satisfied for the same event. An implementer must guess which row wins, and the guess is observable: it decides whether ⌘← returns to the pre-click position after a citation jump.

**Potential consequence**

Two conforming builds behave differently on every same-document citation click. T-49 asserts the R-19 behaviour ("**without** pushing a back snapshot"), so the T-49 run distinguishes them — but the specification, not the test, must settle it.

**Recommended resolution**

Amend R-18's clause to name the kind it means, e.g.:

> A same-document jump from a **slug** `#fragment` link (R-19 (2)), a **line-citation** `#fragment` link (R-19 (1)) or a TOC row (R-21) MUST push a snapshot […], **except** that a line-citation jump — a position move, not a choice (C-19.4) — MUST NOT.

This is a one-clause edit and removes the contradiction in favour of the behaviour C-19 already specifies.

---

### F-127 — "Fragment" now denotes two kinds with different effects, and four existing rows still assume one

**Severity: HIGH**

**Location:** C-19.1/C-19.4 (lines 520, 538) vs E-22 (line 626), E-29 (line 633), C-18.8 (line 509), R-18 (line 69).

**Observation**

C-19.1 defines a **line fragment** (`^L…$`) as a second kind of fragment, dispatched before slug comparison (R-19). Four existing normative rows speak of "a `#fragment`" as a single kind:

- **E-22**: "`#fragment` whose target is an h4–h6 heading […] Fragment: no-op — only `#`–`###` single-line ATX headings are targets." If `#L10` is aimed at a document whose line 10 is an h4 heading, is the click a no-op (E-22) or does it scroll and flash (C-19.3)?
- **E-29**: "a cross-file `#fragment` (R-19) that lands on a TOC heading selects that row." If a line citation lands on a TOC heading block, does the row select? C-19.4 says a line citation MUST NOT select a TOC row; E-29's "`#fragment`" is unqualified.
- **C-18.8** says the selected row is the one "chosen […] by a same-document fragment link […] that lands on a TOC heading", with the same ambiguity.

C-19.4's negative clauses ("MUST NOT select a TOC row", "MUST NOT push a snapshot") are stated as absolutes but collide with rows that grant exactly those effects to "a fragment".

**Why it matters**

Each collision resolves in a different direction depending on which row an implementer reads first. The behaviours diverge visibly: whether the TOC highlights, and whether ⌘← is armed.

**Potential consequence**

A citation that lands on a `##` heading selects or does not select that TOC row depending on the build; the same citation into an h4 heading does nothing in one build and flashes in another.

**Recommended resolution**

Introduce one disambiguating term and use it in every affected row — e.g. **slug fragment** for the C-11 form and **line citation** for the C-19 form — and state the precedence once, in R-19 (already: line form wins when it parses). Then amend E-22, E-29, R-21 and C-18.8 to say "slug fragment", and let C-19.4 own the line-citation behaviour outright.

---

### F-128 — The C-19.1 grammar accepts `#L0` while the same row's prose rejects it

**Severity: HIGH**

**Location:** C-19.1 (line 526) vs E-06 (line 610), E-31 (line 635).

**Observation**

C-19.1 gives the grammar

```
^L([0-9]+)(?:-(?:L)?([0-9]+))?$        case-insensitive, anchored
```

`[0-9]+` matches `0`, so `#L0` **matches the grammar**. The same paragraph then says:

> A fragment that does not match this pattern in full (including `#L`, `#L0`, …) is **not** a line fragment […]
>
> `#L0` is not a citation: line numbers start at 1.

E-31 repeats that `#L0` "is not a citation (C-19.1) and falls through to E-06", and E-06 says "A fragment that matches C-19.1's grammar is a line citation and never reaches this row (E-31)". So E-06 and E-31 also contradict each other on this input, under the grammar as written.

**Why it matters**

The two readings produce opposite, user-visible outcomes, and this is the one input where the resolution rule is destructive:

- *Reading A (regex is authoritative):* `#L0` parses with $a = 0$; no block has $\text{lowerBound} \le 0$; the implementer applies C-02 rule 8's "resolve to the last block" clamp → scroll to the **end** of the document and flash the last block.
- *Reading B (prose is authoritative):* `#L0` is not a citation → slug match → unmatched → E-06 no-op.

**Potential consequence**

A malformed citation navigates to the wrong end of the document, or silently does nothing, depending on which sentence the implementer implemented.

**Recommended resolution**

Make the grammar state what the prose means, and delete the ambiguity at its source:

```
^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$      case-insensitive, anchored
```

Then E-06's "matches C-19.1's grammar" clause, E-31's first sentence, and C-02 rule 8's "not covered" clause all agree without further edits. (Alternatively keep `[0-9]+` and add a mandatory post-parse guard $a \ge 1$; the regex form is preferable because it is the one an implementer transcribes.)

---

### F-129 — T-49 asserts a state its own fixture does not produce

**Severity: HIGH**

**Location:** §9.4 T-49 (line 722) vs `test-docs/links-sibling.md` (11 lines).

**Observation**

T-49 requires:

> `[cite](links-sibling.md#L10-L12)` loads the sibling, scrolls **the paragraph containing line 10** to the top of the viewport, and flashes that one block […]
>
> A citation past the sibling's `lineCount` **and one naming a line inside the removed blank-line gap** both scroll to and flash the **last** block (E-31) […]

The fixture is:

```
1  # Sibling
2  (blank)
3  Paragraph one of the sibling, linked from [links.md](links.md).
4  (blank)
5  ## Second heading
6  (blank)
7  Paragraph under the second heading.
8  (blank)
9  ## Third heading
10 (blank)
11 Paragraph under the third heading.
```

Line 10 is **blank** — it is precisely an instance of "a line inside the removed blank-line gap". By C-02 rule 8 / C-19.3, line 10 resolves to the last block whose $\text{lowerBound} \le 10$: the `## Third heading` block (line 9). That is neither "the paragraph containing line 10" nor "the last block" (`Paragraph under the third heading.`, line 11). The two clauses of T-49 are therefore both false for this fixture, and mutually inconsistent besides. A second problem in the same sentence: the fixture has 11 lines, so the `-L12` end of the citation is past `lineCount` — harmless under C-19.2 (the end is informational), but it means the "past `lineCount`" assertion cannot use this citation.

**Why it matters**

T-49 is the acceptance criterion for the entire v0.12 feature. As written it fails against a correct implementation, and its failure would be misread as an implementation defect.

**Potential consequence**

A build that implements C-19 exactly correctly is marked non-conforming; or, worse, the implementer "fixes" the resolution rule to match the test and breaks the gap-clamp rule.

**Recommended resolution**

Either (a) change the fixture — insert a blank line after line 3 so that line 10 falls inside `Paragraph under the second heading.` — and re-derive every cited number from `nl -ba`, or (b) change the citation to `#L11` and state that line 10 is the gap case ("scrolls to and flashes `## Third heading`, the block preceding the gap"). Whichever is chosen, cite the fixture's line numbering explicitly in T-49 so the next editor can re-verify it.

---

### F-130 — Resolution is undefined for a line that precedes the first block

**Severity: MEDIUM**

**Location:** C-02 rule 8 (line 216), C-19.3 (line 536), E-31 (line 635).

**Observation**

C-02 rule 8 resolves an uncovered line to "the **last** block whose range starts at or before it". C-19.3 restates this and adds:

> A resolution that finds no block (**an empty document**) scrolls to the top and flashes nothing.

E-31 covers "a line citation into a document with no blocks". Neither addresses a non-empty document whose first source line is not in any block — a document beginning with blank lines, e.g.:

```
1 (blank)
2 (blank)
3 # Title
```

A citation to `#L1` has no block with $\text{lowerBound} \le 1$. Rule 8's clause is unsatisfiable; C-19.3's parenthetical attributes the no-block case only to empty documents; E-31's list ("past `lineCount`, inside a gap, `#L0`") does not include it.

**Why it matters**

The input is ordinary (leading blank lines are common in files that begin with a comment or front matter), and the rule that was written to make every line resolvable does not cover it.

**Potential consequence**

Implementers diverge between "scroll to the first block and flash it" and "scroll to the top and flash nothing".

**Recommended resolution**

Add the case to E-31 and make rule 8 total: "when no block starts at or before the line — a line before the first block — the target is the **first** block; only a document with no blocks at all scrolls to the top and flashes nothing." Alternatively, treat "no block satisfies the predicate" uniformly as the empty-document behaviour and say so in rule 8.

---

### F-131 — `blockLines`' boundary convention is stated three incompatible ways

**Severity: MEDIUM**

**Location:** §4 C-02 `ParsedDocument` (line 200), rule 8 (line 216), C-19.3 (line 536).

**Observation**

Three statements describe the same type:

1. The field comment: `blockLines: [Range<Int>] // 1-based, inclusive-exclusive source lines per block`.
2. Rule 8: "`blockLines[i]` is the range of **1-based** source line numbers that block `i` **occupies**" and "`blocks[i]` is exactly `raw`'s lines `blockLines[i]`, with rule 5's trimming applied only inside the block text".
3. C-19.3: the target is the last $i$ with $\text{blockLines}[i].\text{lowerBound} \le a'$.

Statement 1 says the upper bound is exclusive; statement 2's "exactly … with trimming applied" is self-contradictory (if trimming is applied, the block is not exactly those lines) and does not settle whether the upper bound is the last occupied line or one past it. A block occupying source lines 5–7 is legitimately storable as `5..<8` or as `5..<7`; the two differ by one in every containment test and in the gap logic of rule 8.

**Why it matters**

Off-by-one in the map is the classic defect for this feature, and one plausible reading silently mis-resolves every citation whose line is a block's last line.

**Potential consequence**

`#L7` resolves to the following block (or to the same block) depending on the convention chosen.

**Recommended resolution**

State the convention once, explicitly, in rule 8, and make rule 8 the single owner of the definition: "`blockLines[i]` is half-open: $\text{lowerBound}$ is the block's first source line (1-based) and $\text{upperBound}$ is one past its last. `blocks[i]` equals `raw`'s lines `blockLines[i]` after rule 5's trimming." Drop the field's duplicate comment or make it point at rule 8.

---

### F-132 — The three new ids are unrealised but carry no status marker

**Severity: MEDIUM**

**Location:** §11 note (line 756), rows C-19 (820), E-31 (881), T-49 (211).

**Observation**

The front matter and §11 define a status discipline:

> *not yet realised* marks specified work with no implementation

§11 then states:

> **At v0.11 every row is plain:** the v0.8 *not yet realised* and **open defect** rows were built and fixed […]

At v0.12, `C-19`, `E-31` and `T-49` are specified with no implementation and no verifying test — independently confirmed by the tool walk, which reports them `UNCITED` (`3 uncited; 0 dangling, 0 stale`). They are `PASSING`-shaped plain rows, and the blanket "every row is plain" sentence actively asserts the opposite of their state.

**Why it matters**

A reader (or an agent) using §11 to decide what is built will conclude that line citations exist. The discipline exists precisely to prevent that, and v0.12's own revision entry (which describes C-19 as "specified") is not where a reader looks per-id.

**Potential consequence**

A conformance claim that the citation feature works, with no code behind it.

**Recommended resolution**

Mark the three rows *not yet realised* and replace the blanket sentence with the current state, e.g.: "Every row is plain except C-19, E-31 and T-49 (*not yet realised*, added in v0.12)." Update it when the build lands.

---

### F-133 — C-19 does not state that non-Markdown targets are out of its scope

**Severity: MEDIUM**

**Location:** C-19 (lines 518–538) vs R-19 classification (line 70), E-05 (line 609).

**Observation**

R-19's classification sends every destination whose extension is not `md`/`markdown`/`mdown` to the system opener. The canonical GitHub citation is `[Foo.swift L412–418](Foo.swift#L412-L418)` — a **code** file. Such a link never reaches `handleLink`'s in-app branch, so C-19 never runs; the click is handed to the opener, which may do nothing or open an editor. C-19 does not say this, and neither the status line nor D-44's *Alternatives* column records it as a deliberate boundary of the feature.

**Why it matters**

The feature's motivating use case is citation into source files. An implementer reading C-19 alone would reasonably build line resolution that is unreachable for exactly those links, and a reader would reasonably expect `Foo.swift#L412` to work.

**Potential consequence**

The feature ships and appears not to work for the links the reader cares about most, with no row explaining why.

**Recommended resolution**

Add one sentence to C-19 (or D-44) pinning the boundary: line citations apply only to in-app destinations, i.e. the R-19 Markdown extensions; a citation whose target extension is anything else follows R-19's system-opener classification (E-05) and C-19 does not apply. If citations into code files are wanted, that is a separate scope decision (a read-only source view), not an omission to be papered over.

---

### F-134 — T-49's scripted content sits in a manual group and its visual assertion is outside the observed set

**Severity: MEDIUM**

**Location:** §9.5 (T-49 sat at the end of the "Robustness and resources (scripted)" table), T-49 (line 722), §9.6 (line 726), §9.0 group table (line 650).

**Observation**

T-49 asserts two quite different things: a rendered, timed visual effect (scroll position, a 0.6 s flash) and purely internal map values ("The separated `blockLines`/`lineCount` maps are asserted directly for a document whose blocks are …"). It sits at the end of §9.5, a section labelled *scripted*, while §9.0 routes T-49 to the **UI / manual** group — so the deterministic half is filed under a section that is supposed to run in `swift test` and cannot run it, and the visual half is filed as manual without being owned by §9.6. The map assertions are deterministic and belong to the scripted suites (`Tests/mdv6Tests`), in the spirit of the §9.0 grouping that puts pure contracts there. Separately, §9.6 enumerates the tests whose outcome a conformance report MUST include as observed (T-44, T-47, T-48) because they are visual; T-49's flash is equally visual, and the flash is the only part of the feature a scripted test cannot check.

**Why it matters**

The spec's own §9.0 table exists to route each criterion to a runnable mechanism. Misrouting the scripted half makes it look unverifiable in CI; omitting the flash from §9.6 lets a report claim "verification pending"-free conformance without anyone having seen the highlight — the exact failure D-40 was written to prevent.

**Potential consequence**

The deterministic half is not run automatically, and the visual half is never observed.

**Recommended resolution**

Split T-49: keep the click/scroll/flash assertions in §9.4 (manual) and move the `blockLines`/`lineCount` assertions into a scripted test under §9.0's "Pure/Fixture" group; add T-49's flash to §9.6's observed set.

---

### F-135 — The 0.6 s constant is labelled for one of its two uses

**Severity: LOW**

**Location:** K-06 (line 574).

**Observation**

K-06 reads "Heading-copy flash: 0.6 s". C-19.3 introduces a second consumer of the same duration ("**flash** that single block … for the R-22 duration ($0.6\,\mathrm{s}$)") and R-22 owns the original. The constant's label now names a use rather than the quantity.

**Why it matters**

Trivial, but the constants table is the place an implementer looks to confirm the value; a label that names only one use invites a second constant being introduced for the citation flash.

**Potential resolution**

Relabel to "Block flash (heading copy R-22, line citation C-19.3): 0.6 s".

---

### F-136 — C-19 is placed inside the "Window chrome" section

**Severity: LOW**

**Location:** §5.5 (line 486 heading), C-19 (line 518).

**Observation**

`§5.5`'s heading is `### C-18 Window chrome (§5.5, normative structure)`. C-19 follows `C-18.10` under that same heading, so a contract about link-fragment semantics is nested in the window-chrome section. C-19 is a navigation/behaviour contract of the same family as C-11 or C-12.

**Why it matters**

Organization only; nothing normative depends on it. It does affect how a reader or a checker attributes §5.5's scope, and §5.5 is explicitly described as the chrome section in the front matter's scope paragraph.

**Potential resolution**

Give C-19 its own heading at the §4 level (beside C-11/C-12, which own fragments and text), or promote it to a §5.6 heading. Either keeps the id and content unchanged.

---

### F-137 — C-19.3's analogy and D-44's dependency list are imprecise

**Severity: LOW**

**Location:** C-19.3 (line 536), D-44 (line 931).

**Observation**

Two small imprecisions:

1. C-19.3 says the citation scrolls "exactly as a TOC row does (R-21)". A TOC row does three things — push a snapshot, select the row, scroll — and C-19.4 removes two of them. "Exactly as" is the opposite of what is meant; "the same scroll as a TOC row, without the snapshot or the selection (C-19.4)" is the accurate comparison.
2. D-44's *Affects* column lists `R-19, C-02 rule 8, C-19, E-06, E-31, T-22, T-49` but omits R-18 and E-29/C-18.8 — the rows F-126 and F-127 show must change.

**Why it matters**

Both are reading aids; the second one matters because the *Affects* column is how a future editor finds the rows a decision touches.

**Potential resolution**

Reword C-19.3's clause; extend D-44's *Affects* column once F-126/F-127 are applied.

---

### F-138 — T-49 does not name the fixture for its empty-document assertion

**Severity: LOW**

**Location:** T-49 (line 722).

**Observation**

> A citation into a document with no blocks scrolls to the top and flashes nothing.

No fixture is named. §9.4's sibling tests name their files; the zero-byte `.md` used by T-39 exists but is not referenced here.

**Why it matters**

The assertion is not reproducible as written.

**Potential resolution**

Name the fixture (e.g. the zero-byte `.md` of T-39) or state that the test creates an empty document.

---

## 5. Requirements Review

Requirements are, with the v0.12 exception, observable obligations rather than aspirations: each names the trigger, the input, the result and the failure. R-01's split into adding/selecting routes, R-04's decode-before-add ordering, R-05's burst-coalescing bound ("at most two reloads") and R-19's resolve-then-classify structure are all testable as written. No requirement in §2 is a goal statement.

The v0.12 material weakens this in one place: R-19's new clause and C-19.4 state effects negatively against rows (R-18, R-21/C-18.8, E-22, E-29) that grant those same effects to "a fragment", so the *combined* requirement set for a single click is contradictory rather than observable (F-126, F-127).

## 6. Interface and Data-Contract Review

**Visual surface (scorecard: complete).** §5.5/C-18 is the strongest part of the document. Every pane has region layout, an element inventory, per-element states (empty/hovered/selected/current/missing/collapsed), metrics in K-16, and reference images cited by C-18.0; the *visibility test* is answered for the two features most often left invisible elsewhere — R-28's placeholder is required to be the first bookmarks-pane row, and the hovered-block stripe is given its own row. §9.6 supplies the observed-test rule and the oracle is external (reference image/measurement/person). No finding.

**Data contracts.** C-08's fingerprint and `resolve`, C-15's JSON, C-03's FTS schema and K-14's ceilings are precise, with degenerate cases stated. The v0.12 addition is the weak point: `blockLines` enters `ParsedDocument` with three inconsistent boundary statements (F-131) and a resolution rule that is not total (F-130).

**Interfaces.** §5.1's menu table, §5.2's CLI table (including the "first missing argument" and bundle-not-found rows) and §5.3's release table are complete and state their error paths.

## 7. State and Failure Review

The §3.1 lifecycle is complete, and the mermaid diagram is explicitly illustrative with the table normative — the correct arrangement; the diagram's edges all trace to table rows. Failure semantics are the document's strong suit: E-03 (unreadable file keeps the previous document), E-21 (transient/zero-byte read), E-25 (in-flight render cancellation) and C-14's "report in place, never modally, except two modal cases" form a coherent model. The v0.12 gaps are the two resolution holes (F-128's destructive clamp and F-130's unsat­isfiable predicate) and the contradictory snapshot rule (F-126).

## 8. Determinism and Algorithm Review

Normative algorithms are deterministic and pinned: C-02's split rules (including the CRLF normalisation and the deliberate CommonMark deviations marked E-23), C-06.1/6.2's ordered sanitiser and repairs, C-07.1's delimiter rules, C-10's smartening exclusions, C-11's GitHub slug rule, C-03's query construction and total result order. Rounding and tie-breaking are specified where they matter (R-30's round-half-away, C-03's dual path tie-break, C-17's channel threshold and $q$ bound). C-19.2's range normalisation via $\min(a,b)$ is deterministic and correctly reverses a mis-ordered range. The determinism gap is C-19.1's `#L0` (F-128), where two implementations read the same rule to different values.

## 9. Edge-Case Review

The edge-case table is unusually complete for this system: 31 rows covering unreadable files, missing fragments, math-that-is-not-math, glyph-less math, duplicate headings slug collisions, oversized content, and window lifecycle. Four v0.12-relevant boundaries are covered: past-`lineCount` and gap lines (E-31), `#L0` (E-31, but see F-128), empty document (C-19.3), and non-citation fragments (E-06). Missing: a line before the first block (F-130), and non-Markdown targets (F-133).

## 10. Non-Functional Requirement Review

Measurable and testable: K-15's idle-CPU protocol (warm-up, population, median and nearest-rank p95 thresholds) and T-32; K-14's byte/pixel ceilings with E-28; K-07's cache sizes; K-06's latency and tolerance constants; I-008's bitmap-backed requirement. Security and privacy are specified as boundary conditions rather than prose: C-16's header-free ephemeral session, R-35/I-003's no-document-bytes-out invariant, and the §0 trust-boundary statement. No finding.

## 11. Security and Trust-Boundary Review

The trust boundary is stated (§0) and enforced by rows: K-14 before every third-party parser, C-06.1/C-07.2 sanitisers, I-002's no-termination invariant, R-41's ordered pre-checks, and C-16's redirect/type/size gates. The application never executes document content. v0.12 adds no new trust surface — line numbers are document-derived integers used only for index arithmetic — and C-19's resolution cannot be used to read outside the target file. No finding.

## 12. Observability and Provenance Review

R-35's "nothing document-derived is logged" is a deliberate constraint, and the three permitted diagnostics are enumerated. Provenance of *state* is good: history rows, indexed content with `file_mtime`, bookmarks with fingerprints, scroll positions with mtime, and a `schema_version` with a transactional `migrate()`. §11 maps every id to its realisation and test, and the front matter carries an explicit review/version history. The v0.12 rows break provenance in the one place it is cheap: their status (F-132).

## 13. Testing and Verification Review

Major requirements are testable; acceptance criteria are precise; the invariant set is verifiable (I-009 and I-014 are given measured oracles with tolerances, not vibes). The oracle-independence test passes: §9.6's expected result is a reference image or a person, and the harness's pixel metric is defined by C-17 with a stated tolerance, not by an implementation-produced golden. The `MDV6_SUPPORT_DIR` / `MDV6_DEFAULTS_SUITE` isolated-store rule keeps observed tests from touching the reader's state.

The v0.12 test is the exception and is the reason this review is not a blanket pass: T-49 fails the *test test* (two competent testers would disagree only because the fixture is wrong — F-129) and is misrouted between scripted and manual (F-134).

## 14. Metrics and Evaluation Review

Every metric is a formula with defined symbols and a stated degenerate value: $\mathrm{ink}(P)$ with $\mathrm{ink}(P)=0$ when $D=\varnothing$; $w_{\mathrm{col}}$ with the 1 pt raster floor; the K-16 rhythm band $v \le g \le v + 0.6f$ with $v$ and $f$ defined and the $\max(\text{bottom}_i,\text{top}_{i+1})$ combination stated; C-17's threshold and mismatch fraction. Worked examples agree with their formulas — K-13's $860 - 80 - 12 = 768$ pt and the corresponding 732 pt raster match §7.2 at the K-10 defaults, and T-18 cites the same number. No finding.

## 15. Traceability Review

The chain is complete and mechanically walked: `speccheck check` reports `0 dangling, 0 stale`, so every id cited is declared and every declared id is cited by at least one row. §11's "where realised" names this repository's files for every row. The three v0.12 ids resolve in §11 but point at code that does not exist yet and tests that do not exist — correct for specified work, but unmarked (F-132, F-137).

## 16. Internal-Consistency Review

This is where v0.12 fails. Cross-checking the new clauses against the rows that already owned the concepts they extend produced:

- the R-18 ↔ R-19/C-19.4 contradiction (F-126);
- the C-19.1 regex ↔ its own prose ↔ E-06 ↔ E-31 disagreement about `#L0` (F-128);
- the "fragment" overload affecting E-22, E-29, R-21 and C-18.8 (F-127);
- `blockLines`' three boundary statements (F-131);
- §11's "every row is plain" against three rows that are not (F-132).

Nothing in the pre-v0.12 document was found to contradict itself in this pass.

## 17. Architecture Review

The architecture supports the requirements. §3.2's per-block pipeline is a faithful map of the constraints: math rewriting before smartening (§3.2 and R-17 agree), sanitiser before parser (I-002), cache keys including every input that changes output (C-05, C-11's cache key, R-11's three-part key). Dependency direction is one-way into the third-party renderers, each behind an owned repair layer. C-19 is architecturally honest about its own limit: it states that block granularity is the smallest addressable unit and why, rather than implying line-accurate highlighting is available (D-44). That is the correct treatment; the defect is the inconsistency of the clauses around it, not the design.

## 18. Implementation-Agent Readiness

**Verdict: `READY WITH MINOR FIXES`** for the specification as a whole; **`NO — MATERIAL QUESTIONS REMAIN`** for C-19/T-49.

Minimum blocking questions, all answerable by the edits above:

1. Does a same-document line-citation jump push a back snapshot — R-18 says yes for "a `#fragment` link", C-19.4/R-19 say no? (F-126)
2. Is `#L0` a citation (scroll + flash) or not (E-06 no-op) — the grammar and the prose disagree? (F-128)
3. Does a line citation that lands on a TOC heading select the TOC row? (F-127, with E-29/R-21/C-18.8)
4. Which source line does `#L10-L12` against `links-sibling.md` target — the test's stated paragraph, or the heading the rule produces? (F-129)
5. Is `blockLines[i].upperBound` the block's last line or one past it? (F-131)

## 19. Quality Scorecard

| Dimension | Score |
| --------- | ----: |
| Scope clarity | 5 |
| Terminology | 3 |
| Requirement precision | 4 |
| Interface completeness | 4 |
| Visual-surface completeness | 5 |
| Data-contract completeness | 3 |
| State/lifecycle definition | 4 |
| Algorithm precision | 4 |
| Failure semantics | 5 |
| Edge-case coverage | 4 |
| Non-functional requirements | 5 |
| Security specification | 5 |
| Observability/provenance | 4 |
| Testability | 4 |
| Evaluation/metrics | 5 |
| Traceability | 3 |
| Internal consistency | 3 |
| Architecture consistency | 5 |
| Implementation readiness | 3 |

Seven dimensions score 5; the four 3s (terminology, data contracts, traceability, internal consistency) are each depressed by the same single cause — the v0.12 delta — which is why the remediation below is short and mechanical.

## 20. Remediation Plan

### P0 — Blocking

1. **F-126** — amend R-18 to exclude a line-citation jump from the snapshot rule. *(one clause)*
2. **F-128** — change C-19.1's grammar to `[1-9][0-9]*`, or add the mandatory $a \ge 1$ guard; then E-06 and E-31 agree without further edits. *(one regex)*
3. **F-129** — re-derive T-49's cited line from `nl -ba test-docs/links-sibling.md` and fix the fixture or the expectation, naming the resolved block explicitly. *(one clause plus a fixture line)*

### P1 — Important

4. **F-127** — introduce "slug fragment" / "line citation" and apply it in E-22, E-29, C-18.8, R-18. *(four rows)*
5. **F-130** — make C-02 rule 8's resolution total for a line before the first block, and add the case to E-31. *(one clause, two rows)*
6. **F-131** — state the half-open convention once in C-02 rule 8; reduce the field comment to a pointer. *(two clauses)*
7. **F-132** — mark C-19, E-31, T-49 *not yet realised*; replace §11's blanket sentence with the current state. *(three rows plus one sentence)*
8. **F-133** — pin C-19's scope to in-app destinations and record the non-Markdown boundary in D-44. *(one sentence)*
9. **F-134** — split T-49's scripted half into a `mdv6Tests` case and add the flash to §9.6's observed set. *(one test row, one sentence)*

### P2 — Improvement

10. **F-135, F-136, F-137, F-138** — relabel K-06's constant; move C-19 out of the §5.5 heading; reword C-19.3's TOC analogy and extend D-44's *Affects*; name T-49's empty-document fixture.

No redesign is recommended. Every finding above is an edit to text the v0.12 change should have carried with it.

## 21. Final Verdict

```text
Specification maturity:
Level 3

Implementation readiness:
READY WITH MINOR FIXES

Primary blocker:
R-18 and R-19/C-19.4 state contradictory rules for whether a same-document line-citation jump pushes a back snapshot.

Most important improvement:
Amend R-18, tighten the C-19.1 grammar to reject `#L0`, and re-derive T-49's citation from the actual line numbering of its fixture — after which the v0.12 addition meets the same implementation-grade bar as the rest of the document.
```