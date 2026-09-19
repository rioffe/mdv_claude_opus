# Detailed implementation plan — W8: line citations

> Executable brief for one wave. Read §1 (the ids it discharges), §2 (entry preconditions) and §3
> (deliverables) before editing anything. §4 is the work list, test-first. §6 is the gate, §9 the
> exit criteria. The plan is not a results log; the gate output and the commit carry the evidence.

## 1. Ids discharged

| Family | Ids |
| --- | --- |
| Requirement | **R-18** (the line-citation clause: a position move, no back snapshot), **R-19** (the ordered fragment kinds: line citation → C-11 slug → E-06) |
| Contract | **C-02** rule 8 (`blockLines`, `lineCount`), **C-19** (C-19.1 grammar, C-19.2 normalisation, C-19.3 resolution + flash, C-19.4 interaction, C-19.5 scope) |
| Invariant | **I-004** (the map derives from the same split that produced `blocks`, computed once per load) |
| Edge | **E-31** (past `lineCount`, gap, before the first block, `#L0`), **E-06** (the no-op path a non-citation fragment keeps) |
| Test | **T-50** (scripted: the map and the resolution, added in v0.12.1), **T-49** (its headless half: dispatch, scroll target, snapshot policy, flash) |
| Decisions | **D-44** (block granularity), **D-41** (a citation does not select the TOC row), **C-18.8**/**E-29** (the same, stated where the row lives) |

Out of scope by the spec itself: **C-19.5** — a citation whose target is not one of the R-19
Markdown extensions (`md`, `markdown`, `mdown`) takes the system-opener branch and never reaches
this code. T-49's flash *appearance* is observed on screen (§9.6), not asserted here; the
`flashedRange` value that drives it is asserted.

## 2. Entry preconditions

1. `SPEC.md` is v0.12.1, sha256 `16c9d43727e15c959c7c8deb802160b508d6588364042b7aacf879251c61d4da`
   (measured 2026-09-19 with `shasum -a 256`), committed at `ebb6acd`. The seventh review
   (`SPEC_REVIEW_REPORT.md`, F-126..F-138) is applied — no unresolved P0/P1.
2. `swift build` and `swift test` are green on the starting tree; `speccheck check … --judge mock
   --strict` reports `169/173 passing, 0 dangling, 0 stale, 4 uncited` — the four uncited are
   exactly C-19, E-31, T-49, T-50, which this wave exists to close.
3. Present and unchanged: `ParsedDocument.parseBlocks` (C-02), `DocumentSession.handleLink`
   (R-19), `slugTarget`, `headingSlug` (C-11), `copySection`'s flash (`flashedRange` +
   `SessionClock`), `SessionTests`' harness (`TestClock`, `FileSystem.fake(files:)`,
   `AppModel.bootstrap(supportDir:defaultsSuite:fileSystem:)`).
4. `test-docs/links-sibling.md` is the fixture T-49 names: 11 lines, `# Sibling` on 1, a paragraph
   on 3, `## Second heading` on 5, a paragraph on 7, `## Third heading` on 9, a blank on 10, a
   paragraph on 11. It MUST NOT be edited by this wave.

## 3. Deliverables (file by file, with the shape that is frozen)

### 3.1 `mdv6/Core/ParsedDocument.swift` (edit)

```swift
public struct ParsedDocument: Equatable {
    public let raw: String
    public let blocks: [String]
    public let blockLines: [Range<Int>]   // C-02 rule 8: half-open 1-based source lines
    public let lineCount: Int             // C-02 rule 8: lines after rule 6 normalisation
    public let tocHeadings: [TOCHeading]
}

/// C-02 rules 1–8 in one pass: the blocks, their half-open 1-based line ranges, and the line count.
public static func split(_ input: String) -> (blocks: [String], lines: [Range<Int>], lineCount: Int)
```

`parseBlocks` MUST become a thin wrapper over `split` so the two cannot drift (I-004: one split
per load, `blocks[i]` is exactly `raw`'s lines `lines[i]` with rule 5's trimming). `Equatable`
stays keyed on `raw`.

### 3.2 `mdv6/Core/LineCitation.swift` (new)

```swift
/// C-19.1: a line citation parsed from a link fragment (`#L10`, `#L10-L12`, `#l10-12`, `#L10-12`).
public struct LineCitation: Equatable, Sendable {
    public let first: Int          // the fragment's first number
    public let last: Int?          // the second, when the fragment names a range
    public init(first: Int, last: Int?)
    /// C-19.2: the resolved start line, `min(first, last)`; the end is informational only.
    public var startLine: Int
    /// C-19.1: the anchored, case-insensitive grammar; nil for anything else (including `#L0`, `#L00`).
    public static func parse(_ fragment: String) -> LineCitation?
}

/// C-19.3 / C-02 rule 8 / E-31: the target block for a resolved start line.
/// The last index whose `blockLines[i].lowerBound <= line`; the first block when none does (a line
/// before the first block); nil only when the document has no blocks.
public func lineCitationBlock(_ citation: LineCitation, in document: ParsedDocument) -> Int?
```

The grammar is `^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$`, case-insensitive, applied to the
fragment **after** R-19's single percent-decode. `parse` takes the already-decoded fragment.

### 3.3 `mdv6/Core/DocumentSession.swift` (edit)

- `handleLink`: test the decoded fragment as a `LineCitation` **before** `slugTarget`, in both the
  same-document and the cross-file branch (R-19 precedence). A line citation MUST NOT push a
  snapshot on a same-document jump (R-18), MUST NOT set `tocSelectedBlock` (C-19.4/C-18.8/E-29),
  and MUST take over an in-progress flash.
- New `private func flashBlocks(_ range: Range<Int>)` extracted from `copySection`, used by both
  (K-06's 0.6 s, restarting).
- D-44: the flash range is the single target block, `i..<i+1`.

### 3.4 `Tests/mdv6Tests/LineCitationTests.swift` (new)

T-50 and the C-19.1/C-19.2 grammar and C-19.3/E-31 resolution cases. Cites `C-02`, `C-19`,
`E-31`, `T-50`.

### 3.5 `Tests/mdv6Tests/SessionTests.swift` (edit)

T-49's headless half on the existing fixture harness. Cites `R-18`, `R-19`, `C-19`, `E-06`,
`E-29`, `T-49`.

### 3.6 `README.md` (edit, Phase 2)

One paragraph under the navigation/links surface: the `#L…` form, what it does, and its C-19.5
scope limit.

## 4. Work items (test first, then the delta, then the evidence)

| # | Red (test written first) | Green (minimal code) | Evidence |
| --- | --- | --- | --- |
| W8-01 | `LineCitationTests.testBlockLinesAreHalfOpenAndCounted` — T-50: a heading + two-line paragraph + blank-separated paragraph + unclosed fence at EOF; CRLF copy identical; a trailing newline not counted; a leading-blank-line document. | `ParsedDocument.split` + the `parseBlocks` wrapper + the two stored fields. | the test's assertions on `blockLines`/`lineCount` |
| W8-02 | `testLineCitationGrammar` — C-19.1: `#L10`, `#L10-L12`, `#l10-l12`, `#L10-12` parse; `#L`, `#L0`, `#L00`, `#L10C5`, `#Ll0`, `#L-5`, `#L10-` do not. | `LineCitation.parse`. | the parse/ nil table |
| W8-03 | `testRangeNormalisation` + `testResolution` — C-19.2/C-19.3/E-31: `#L9-L7` → start 7; a line in a block; a line in the removed gap → the preceding block; past `lineCount` → the last block; a line before the first block → the first block; an empty document → nil. | `startLine` + `lineCitationBlock`. | the resolution table over the `links-sibling.md` line map |
| W8-04 | `SessionTests.testLineCitationSameDocument` — T-49/R-19/R-18/C-19.4: a same-document `#L1` scrolls (`scrollTarget`), flashes `flashedRange`, pushes **no** snapshot (`canGoBack` false), leaves `tocSelectedBlock` nil. | the same-document branch of `handleLink`. | the session's published state |
| W8-05 | `testLineCitationCrossFile` — R-19: `links-sibling.md#L7-L9` loads the file as an adding route, suppresses R-06 restoration, scrolls and flashes; a `#L12` past the target's `lineCount` flashes its last block (E-31); `#L0` is an E-06 no-op that does not navigate. | the cross-file branch. | history row + `currentEntry` + `scrollTarget` |
| W8-06 | `testCitationDoesNotSelectTOCRow` — E-29/C-18.8: a slug fragment landing on a TOC heading selects the row; a line citation landing on the same heading does not. | the `tocSelectedBlock` assignments (or their absence). | both assertions in one test |
| W8-07 | `testFlashRestartsAndExpires` — C-19.3/K-06: two clicks in succession leave one live flash; after 0.6 s on the `TestClock` it clears. | `flashBlocks` extraction. | the clock-driven `flashedRange` |
| W8-08 | README (Phase 2, no test). | the paragraph. | the README text |

## 5. Test plan

- Where: `Tests/mdv6Tests` (the §9.0 **Unit** group for T-50 and `SessionTests` for T-49's model
  half). No render test: the flash's appearance is §9.6's observed half, not asserted.
- Every test cites its spec ids literally in the `///` doc comment (speccheck reads them).
- Assertions are on observable state: `document.blockLines`, `lineCount`, the parse result,
  `scrollTarget`, `flashedRange`, `canGoBack`, `tocSelectedBlock`, `currentEntry`.
- Determinism: `TestClock` drives the 0.6 s flash; no wall-clock sleeps.

## 6. Gate (copy-pasteable, with expected results)

```bash
swift build                                   # exit 0, no warnings
swift test                                    # exit 0, zero failures, no skipped test
swift test --xunit-output junit.xml           # regenerates junit.xml + junit-swift-testing.xml
speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit-testing.xml \
    --judge mock --strict --out build/speccheck
# expected: C-19, E-31, T-49, T-50 no longer UNCITED; 0 dangling; 0 stale
```

Plus the observed half (§9.6 / skill Phase 3.2b): run the built app on `test-docs/links-sibling.md`
with a citation link, click it, and confirm the scroll and the flash on screen.

## 7. Traceability

| Spec id | Where realized | Verified by |
| --- | --- | --- |
| C-02 rule 8 | `ParsedDocument.split`, `blockLines`, `lineCount` | T-50 |
| C-19 | `LineCitation`, `lineCitationBlock`, `DocumentSession.handleLink` | T-49, T-50 |
| E-31 | `lineCitationBlock` (clamp, first-block fallback) | T-50 |
| R-18, R-19 | `DocumentSession.handleLink` | T-49 |
| E-29, C-18.8 | `DocumentSession.handleLink` (no assignment) | T-49 |

The §11 rows for C-19, E-31, T-49, T-50 lose `*not yet realised*` in the same commit; T-49's row
in the §11 note moves from *not yet realised* to plain.

## 8. Traps for this slice

1. **Half-open off-by-one.** A block on source lines 5–7 is `5..<8`. A line equal to a block's
   `upperBound` belongs to the *next* block. The gap case (`line 10` in the fixture, between a
   heading on 9 and a paragraph on 11) must resolve to the heading, not the paragraph.
2. **Precedence.** The citation test must precede `slugTarget` or a heading slugged `l10` would
   win. R-19 orders it explicitly; T-22's clause says so.
3. **`#L0`.** The grammar's `[1-9][0-9]*` is the guard. Do not "fix" it to `[0-9]+` and filter
   afterwards — that is the v0.12 defect F-128.
4. **Decode once.** `handleLink` already computes `decodedFragment` with exactly one
   percent-decode. `LineCitation.parse` takes that decoded string; decoding again would break
   `%4C10`-style input.
5. **No snapshot, no TOC selection.** `pushSameDocumentSnapshot()` and `tocSelectedBlock = ...`
   are the two calls the slug path makes and the citation path must not (C-19.4).
6. **`install()` clears the flash.** A cross-file citation must set `flashedRange` *after*
   `open(...)` returns, since `install` sets it to nil.
7. **Empty document.** `document?.blocks.isEmpty` → no target → scroll to 0, flash nothing
   (C-19.3).
8. **One flash at a time.** Reuse the single `flashTimer` and cancel before rescheduling
   (C-19.4).

## 9. Exit criteria and handoff

- The gate's commands reach their stated results; `speccheck --judge mock --strict` no longer
  lists C-19, E-31, T-49, T-50 as uncited; 0 dangling, 0 stale.
- T-49's observed half recorded in `SPEC_BUILD_REPORT.md` (or `VERIFICATION PENDING` with the
  environmental reason).
- The commit message names W8 and the spec ids it discharges.
- Handoff to Phase 2/3: README updated; §11 rows de-marked; `SPEC_BUILD_REPORT.md` carries the
  wave ledger row (gate command, real exit code, commit sha).