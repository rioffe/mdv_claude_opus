# Specification Review Report

> **Reviewed document:** `SPEC.md`, v0.14 (2026-09-27), 1179 lines, as committed in `7b6c373`. Line numbers below are that revision's.
> **Review:** eighth review; finding ids continue from F-148 (the last finding recorded in the document's revision history).
> **Scope of this review:** the whole specification, with the v0.14 delta audited clause by clause — R-44…R-51, C-05.1, C-06.4, C-06.5, C-09.1, C-20…C-22, I-016…I-018, K-17…K-19, E-32…E-37, T-52…T-62, D-46…D-53, and the amendments to R-01, R-09, R-10, R-16, R-24, R-26, R-34, C-02 rule 9, C-04, C-13, C-17, I-001, I-003, E-02, §3.1 and §3.2. The pre-v0.14 material is re-checked only for consistency with the delta.
> **Method:** the four passes of the review method (comprehension, local precision, cross-consistency, implementation simulation), plus a mechanical id walk: every id referenced in the document is declared, and v0.14 introduced no duplicate declaration. Two claims were checked against evidence outside the document: that the vendored library's parser drops `%%`-prefixed lines (it does; `.build/checkouts/beautiful-mermaid-swift/Sources/BeautifulMermaidSwift/Parser.swift:14`), and that `high-contrast`'s `articleMaxWidth` is the 860 pt default (it is; `mdv6/Core/ThemeManager.swift:90`).

---

## 1. Executive Summary

**Overall maturity: Level 3 (implementation-grade) for the pre-v0.14 document; the v0.14 delta is Level 2.** The v0.14 additions are detailed and mostly precise. The pure contracts in particular are specified tightly enough to unit-test: C-05.1's diff classifier, C-06.4's dispatch, C-20's recognition and row reduction, and C-22's rewrite and size function. The weaknesses are at the **seams**, where the new features meet rules written before they existed:

- the window-routing rule, which assumes a document window exists;
- the find, bookmark and rhythm rules, which assume every block draws something;
- R-08, which says every unknown fence is plain;
- R-06, which says every file switch persists a position;
- the web view, which brings its own context menu, scroll handling and first responder into a surface specified as all-native.

**Implementation readiness:** `READY WITH MINOR FIXES` for the pre-v0.14 system. `NOT READY` for the v0.14 rows until F-149 and F-151 are resolved.

**Findings:** 24 in total: 0 CRITICAL, 2 HIGH, 13 MEDIUM, 9 LOW. All are in, or caused by, the v0.14 delta.

**Most important strengths**

- The new pure functions are specified as algorithms, not as examples. An implementer can write `frontmatterSpan`, `frontmatterRows`, the C-05.1 classifier, the C-06.4 dispatcher and `RawHTMLImages.rewrite` from the text alone, and T-52/T-54/T-58/T-59 name unit cases for each.
- The trust-boundary change is handled honestly. The *Principle*, §0, I-001 and I-003 are amended rather than silently contradicted. D-46 records the exception, and it is **tighter** than the original: every non-page load is refused.
- Departures from the original are deliberate and recorded: D-50 (*Close All* empties every window) and D-51 (inline remote `<img>` is gated). Neither is presented as as-built behaviour.
- The status discipline holds. Every new id is marked *not yet realised*, and §11's opening sentence enumerates them. The previous review had to fix exactly this (F-132).

**Most important weaknesses**

- **No rule covers the state with zero document windows** (F-149). ⇧⌘W and the window close button can both produce it, and R-01's target-window definition then names nothing.
- **The web view's own interaction surface is unspecified** (F-151). R-09's block context menu, R-49's keyboard scrolling and the article's wheel scrolling all meet a `WKWebView` that, by default, answers these events itself.
- **Frontmatter is a block that may draw nothing, and several rules assume otherwise** (F-158, F-159). This affects the bookmark title, the topmost-visible anchor, the flash, the stripe, find's tint and the rhythm band.
- **Several pairs of `MUST`s now disagree**: R-08 vs R-50 (F-153), R-06 vs R-47 (F-154), E-26 vs *Close All* (F-155), and C-22.2 with itself (F-157).

## 2. Overall Maturity

**Level 3 for the document as a whole, held back from READY by the v0.14 delta.** The pre-v0.14 document keeps its implementation-grade status: none of the findings below changes a pre-v0.14 behaviour, except where a v0.14 row now contradicts it (F-153, F-154, F-155, F-156).

The delta is Level 2: implementable, but with two blocking semantic gaps (F-149, F-151) and a cluster of cross-rule contradictions. Each is a one- or two-clause fix. No redesign is indicated.

## 3. Findings Summary

| ID | Severity | Location | Title |
| -- | -------- | -------- | ----- |
| F-149 | HIGH | R-01, R-47, §3.1, E-30 | No rule for the state with zero document windows |
| F-151 | HIGH | R-09, R-46, R-49, C-06.5 | The web view's context menu, scroll, focus and selection are unspecified |
| F-150 | MEDIUM | C-20.1, E-32, D-48 | The YAML guard accepts an ATX heading as a comment and swallows a title |
| F-152 | MEDIUM | C-06.4, C-06.1, E-02, T-54 | A multi-line `%%{…}%%` directive dispatches native and then fails |
| F-153 | MEDIUM | R-08, R-50 | R-08 requires a `diff` fence to be plain; R-50 requires it tinted |
| F-154 | MEDIUM | R-06, R-47, §3.1 | R-06 persists a position on every file switch; R-47 forbids it on close |
| F-155 | MEDIUM | E-26, R-47, E-36 | E-26 says only the key window acts; *Close All* acts in every window |
| F-156 | MEDIUM | R-11, K-07, I-005, R-46 | The raster-width and zoom rules say "a diagram" without excluding the web path |
| F-157 | MEDIUM | R-16, C-22.2 | The inline blocked-remote `<img>` placeholder is required and ruled out in the same row |
| F-158 | MEDIUM | R-44, R-27, C-18.7, C-19.3, I-014 | Block 0 as a header: anchoring, title, flash, stripe, selection and spacing are unstated |
| F-159 | MEDIUM | R-24, R-44 | Find on a header can take the whole-block tint, which draws nothing when hidden |
| F-160 | MEDIUM | C-21.2, I-014, C-18.10 | Print does not say whether block-boundary rhythm is re-applied |
| F-161 | MEDIUM | R-45, C-21.4, T-53 | The inline-formula "vector" clause excuses itself and is not tested |
| F-162 | MEDIUM | T-53, C-17 | T-53's scripted oracles need data `--print-pdf` does not produce |
| F-163 | MEDIUM | §9.6, §9.7 | The v0.14 visual surfaces have no observed test and no reference image |
| F-164 | LOW | R-35, T-36, C-06.5 | mermaid.js console output in WebKit's processes is outside R-35 and T-36 |
| F-165 | LOW | C-13, §10, D-45 | No licence obligation stated for the bundled mermaid.js |
| F-166 | LOW | C-20.1, C-02 rule 9 | BOM before the fence is undefined; the old-bookmark compatibility claim is overstated |
| F-167 | LOW | C-09, C-09.1 | C-09.1 cites theme fields C-09 does not declare |
| F-168 | LOW | T-42, C-04, C-17 | T-42's key list and C-17's `expect` enum were not extended |
| F-169 | LOW | §12 D-46, D-50 | Two *Affects* cells omit ids their decisions constrain |
| F-170 | LOW | C-21.1, R-45 | The measure rationale mixes a padded frame with a content width; "empty" is ambiguous |
| F-171 | LOW | C-22.1, C-12 | `>` inside a quoted attribute ends the tag; `<img>` in a heading reaches the TOC raw |
| F-172 | LOW | T-53, C-21.3 | "No window flashes" holds only when the PDF route succeeds |

## 4. Detailed Findings

### F-149 — No rule for the state with zero document windows

**Severity:** HIGH

**Location:** R-01 (line 42), R-47 (line 48), §3.1 `CLOSED`, E-30 (line 790)

**Observation**

R-47 adds File · *Close Window* (⇧⌘W) and says "the application keeps running". The window's close button already allowed the same state. R-01's new target rule is "the key window when it is a document window, else the frontmost visible document window …, else any document window". It has no case for **no document window at all**. So in that state the spec does not say what happens on any of these:

- a Finder double-click or `bin/mdv6 FILE` (a LaunchServices open event);
- ⌘O, ⌘⇧O, ⌘P, ⌘0, ⌘1…⌘5 or ⌘?;
- a click on the Dock icon.

§3.1 makes `CLOSED` terminal for the window, and E-30 covers only launch.

**Why it matters**

This path is common: the reader closes the window, then double-clicks a `.md` file in Finder. One conforming build creates a window and loads the file. Another drops the event, because R-01 names no target. The original (a SwiftUI `WindowGroup`) creates a window on a Dock click, but its unaddressed notifications for ⌘O etc. reach no view.

**Potential consequence**

A Finder double-click silently does nothing, and T-03/T-61 pass or fail depending on whether a window happened to be open.

**Recommended resolution**

Add a clause to R-01, with E-38 and a T-61 case: when no document window exists, an open event, ⌘O, ⌘0, a bookmark slot and ⌘? MUST first create one window (as launch does, E-30), which then becomes the target. ⌘P, ⌘W and Next/Previous File are disabled. A Dock click with no window creates one that follows R-40.

### F-151 — The web view's context menu, scroll, focus and selection are unspecified

**Severity:** HIGH

**Location:** R-09 (line 56), R-46 (line 66), R-49 (line 81), C-06.5 (line 362)

**Observation**

R-09 says a web-path diagram's "hover toolbar and context menu" offer *Show Mermaid source* and copy. A `WKWebView` does four things by default that the spec never addresses:

1. It shows **WebKit's own** context menu (Reload and similar; *Inspect Element* when inspectable) on a right-click inside the web view, so the block menu R-09 describes never appears there.
2. It takes scroll-wheel events and rubber-bands, so the article stops scrolling while the pointer is over a diagram.
3. It becomes first responder when clicked. R-49 then hands every scroll key to the web view, because its first responder is neither nothing nor a read-only `NSText`.
4. It lets the reader select the SVG's text.

**Why it matters**

Each of these is visible to the reader, and two competent builds will differ. One suppresses WebKit's menu and forwards wheel events to the enclosing scroll view. The other leaves the defaults, and so fails R-09's menu requirement and makes the document un-scrollable under a gantt chart.

**Potential consequence**

T-21 and T-54 pass on one build and fail on another. After the reader clicks a diagram, keyboard scrolling (R-49) silently stops.

**Recommended resolution**

Add to C-06.5:

- the web view MUST NOT show WebKit's context menu; a right-click shows the R-09 block menu;
- scroll-wheel events MUST pass to the article's scroll view;
- the web view MUST NOT become first responder, so R-49 is unaffected;
- say whether text inside the diagram is selectable (recommended: not selectable, as with native diagrams).

Add T-54 clauses for each.

### F-150 — The YAML guard accepts an ATX heading as a comment and swallows a title

**Severity:** MEDIUM

**Location:** C-20.1 (line 538), E-32 (line 792), D-48

**Observation**

C-20.1 lets a YAML candidate line pass the guard when it "starts with `#` (a comment)". An ATX heading `# Title` starts with `#`. Take a document whose lines are `---`, blank, `# Title`, blank, `---`, then prose — a horizontal rule, a title, a rule. It passes the guard: the blank lines pass, `# Title` passes as a comment, and the second `---` closes the header. Everything down to the second rule becomes a header with **zero rows** (C-20.2 skips `#` lines), which C-20.3 draws as nothing. The title disappears from the page and from the TOC (C-02 rule 7 sees the header's first line, `---`). E-32 promises the opposite for documents that open with `---` and are not frontmatter.

**Why it matters**

The behaviour is deterministic, so two implementers agree. But it contradicts the stated intent ("false negatives are cheap and false positives are not") and E-32's claim, and a reader loses content without any signal.

**Potential consequence**

A document styled with rules around its title renders without its title.

**Recommended resolution**

Choose one and record it in D-48:

- **(a)** YAML comments must be `#` followed by a space **and** the header must contain at least one mapping or sequence line; or
- **(b)** a candidate that yields zero rows is not a header.

(b) is the smallest change and also covers `---`/`---` at the top of a file. Add the case to E-32 and T-52.

### F-152 — A multi-line `%%{…}%%` directive dispatches native and then fails

**Severity:** MEDIUM

**Location:** C-06.4 (line 360), C-06.1, E-02, T-54

**Observation**

C-06.4 skips a `%%{ … }%%` directive over several lines when choosing the path, so `%%{\n init: {…}\n}%%\nflowchart LR` dispatches **native**. On the native path, no C-06.1 rule removes directives. The library drops only lines that start with `%%` (`Parser.swift:14`), so the directive's middle and closing lines reach the parser, and a parse error follows. E-02 then forbids a retry on the web path. T-54 tests only the single-line form, which happens to work.

**Why it matters**

A dispatch rule that knows about a construct should not hand it to a parser that does not. Otherwise the rule's own test (T-54) covers only the forms that work.

**Potential consequence**

Diagrams that use multi-line `init` blocks, a common pattern in the wild, show the fallback even though both renderers could draw them.

**Recommended resolution**

Add a C-06.1 rule 0 that removes leading front-matter and `%%{…}%%` directive lines with exactly C-06.4's extent. Alternatively, dispatch any source whose preamble holds a directive to the web path, since only mermaid.js honours `init`. Add the multi-line case to T-54.

### F-153 — R-08 requires a `diff` fence to be plain; R-50 requires it tinted

**Severity:** MEDIUM

**Location:** R-08 (line 55), R-50 (line 67), C-05

**Observation**

R-08 says fenced code "MUST render as plain monospaced text — never an error — for any other or missing language hint". `diff` and `patch` are not K-05 languages, so R-08 requires them to be plain. R-50 requires line tinting. C-05's new bullet says `diff` bypasses tree-sitter, but R-08 was not amended.

**Why it matters**

Two `MUST`s at the same level conflict. A checker that walks R-08's test (T-06, "an unknown fence is plain") could flag R-50's behaviour.

**Potential consequence**

Conformance arguments over which row wins. No behavioural divergence is likely, but the spec is inconsistent.

**Recommended resolution**

Amend R-08 to "… for any other or missing language hint, **except the `diff`/`patch` fence words of R-50**".

### F-154 — R-06 persists a position on every file switch; R-47 forbids it on close

**Severity:** MEDIUM

**Location:** R-06 (line 47), R-47, §3.1 `LOADING` row

**Observation**

R-06 says the application "MUST persist the current position … before loading a different file into the window". R-47 says the closed file's position "MUST NOT be written back after its row is gone", and §3.1's `VIEWING` row was amended to match. However, R-06 and the `LOADING` row ("Outgoing document's scroll position persisted when one exists (R-06)") were not. The same gap already existed for swipe-delete of the displayed row, which v0.14 now shares.

**Why it matters**

An implementer who follows R-06 writes an orphan `scroll_positions` row for a file R-26 just removed. R-26's "the search population is exactly the current history" then silently has a scroll-table counterpart that is not exact.

**Potential consequence**

Re-opening a closed file restores a stale position, while T-25 expects "starts at the top".

**Recommended resolution**

Add to R-06: "…except when the outgoing file's history row is being removed (swipe-delete, ⌘W, *Close All*, cap eviction), which persists nothing." Mirror the exception in the `LOADING` row.

### F-155 — E-26 says only the key window acts; *Close All* acts in every window

**Severity:** MEDIUM

**Location:** E-26 (line 786), R-47, E-36

**Observation**

E-26: "a menu command … arrives. Only the key window acts". R-47 and E-36 make *Close All* put **every** window into `EMPTY`. E-26 has no exception. E-36 also does not say what happens to a window that is `LOADING` or `RELOADING` when *Close All* is confirmed. A load that completes afterwards would re-add its row through an adding route, so history would no longer be empty.

**Why it matters**

The exception is intended (D-50) but stated in only one of the two rows. The in-flight case is a real race with two plausible outcomes.

**Potential consequence**

One build cancels the in-flight load; another lets it finish and re-populate history.

**Recommended resolution**

Add "except *Close All* (R-47, E-36)" to E-26. In E-36, require an in-flight load in any window to be cancelled (as E-25 cancels renders) before history is cleared.

### F-156 — The raster-width and zoom rules say "a diagram" without excluding the web path

**Severity:** MEDIUM

**Location:** R-11 (line 58), K-07 (line 723), I-005 (line 698), R-46, C-06.5

**Observation**

R-11: "A diagram MUST be rasterised at the exact width from the §7.2 formula … MUST NOT be drawn wider than its natural width". K-07 caps the zoomed container at 540 pt. A web-path diagram is not rasterised. It is laid out by `max-width: 100%` inside 18 px padding, has no pinch zoom, and has no "natural width" the spec defines. Only R-09 says pinch zoom is native-only. R-11 and K-07 are unqualified, and I-005 speaks of "every mermaid raster" (which is at least literally true).

**Why it matters**

A verifier running T-18 across `mermaid-web-fallback.md` cannot tell whether a gantt chart drawn wider than its intrinsic SVG width is a violation.

**Potential consequence**

T-18 fails or passes arbitrarily on web diagrams.

**Recommended resolution**

Scope R-11 and K-07 to "a natively dispatched diagram". In C-06.5, state the web width rule: the SVG fills the column minus 36 px and scales down, never up, as `max-width: 100%` implies.

### F-157 — The inline blocked-remote `<img>` placeholder is required and ruled out in the same row

**Severity:** MEDIUM

**Location:** R-16 (line 62), C-22.2 (line 581)

**Observation**

C-22.2 says remote `src` shows "the blocked placeholder when *Load Remote Images* is off, on the inline path as on the block path". Two sentences later it says "on the inline path it is left out of the line (the renderer draws no inline placeholder)". R-16's placeholder is also **clickable** (it opens the View menu), and an image inside a `Text` line cannot carry its own click action. The same question applies to the amended R-16 for plain Markdown inline remote images.

**Why it matters**

The row contradicts itself, and the part that contradicts is not implementable as stated.

**Potential consequence**

Implementers pick either a silent omission or a non-clickable inline glyph.

**Recommended resolution**

State what an inline blocked remote image draws. The recommendation is an inline, non-clickable image of the text *Remote image blocked*, sized to the line height, with the View-menu reveal available only on the block path. Apply the same rule in R-16.

### F-158 — Block 0 as a header: anchoring, title, flash, stripe, selection and spacing are unstated

**Severity:** MEDIUM

**Location:** R-44, R-27, R-28, C-18.7 (line 682), C-19.3, I-014/K-16, C-02 rule 9 (line 243)

**Observation**

Rule 9 makes the header an ordinary block for anchoring, and I-018 says hiding it is view-only. With *Show Frontmatter* **off**, block 0 has zero height at the top of the article. The spec does not say:

1. whether ⌘D's "topmost block whose frame intersects the viewport" (R-27) can pick it;
2. what R-27 titles it — its stripped first line is `---`, which C-12 does not strip;
3. what a C-19 citation of `#L2` flashes (nothing visible);
4. whether it keeps the 6 pt block padding and the 8 pt stack spacing, which leave an empty band above the first heading.

With the table **shown**, the spec does not say:

5. whether the table carries the C-18.7 hover stripe;
6. whether its text is selectable (R-22 speaks of "prose blocks");
7. what gap separates it from the next block — I-014/K-16's rhythm band covers heading and paragraph pairs only.

**Why it matters**

Each item is observable, and the reference images show no header. The skill's §3.5 visibility test applies: a feature the reader can toggle must say how it looks in both states.

**Potential consequence**

Bookmarks titled `---`; a blank strip above the title when the header is hidden; inconsistent spacing across builds.

**Recommended resolution**

In R-44:

- a hidden header occupies no height and no stack spacing;
- it is never the ⌘D/⌘⇧0 anchor; the next block is;
- a bookmark or placeholder whose anchor is block 0 is titled `Frontmatter`;
- a citation into a hidden header flashes nothing and scrolls to the top.

For the shown table, state the stripe (yes), selection (values selectable, as prose), and the table-to-next-block gap (`paragraphBottomSpacing`, like a GFM table). Add a T-52 clause.

### F-159 — Find on a header can take the whole-block tint, which draws nothing when hidden

**Severity:** MEDIUM

**Location:** R-24 (line 87), R-44

**Observation**

R-24 now promises that a match inside a hidden header "shows the header's source with the match marked". But R-24's classifier sends a block to the **whole-block tint**, not to the inline path, when it contains `![` anywhere, or when its first line contains `|` and its second line is a table rule. A header can do either (`image: ![x](y)`, or a TOML value holding `|`). A tinted hidden header draws nothing, which breaks the promise. The inline path also "interprets inline Markdown", which contradicts R-44's "values are plain text" while find is open.

**Why it matters**

The one guarantee the new clause makes can be defeated by header content, and there is no test for it.

**Potential consequence**

A match counted in $m$ that is invisible on screen: ⌘G scrolls to an empty strip.

**Recommended resolution**

Say that a header block with a match always takes the inline path, rendered **verbatim** (no inline-Markdown interpretation), whatever R-24's tint tests would say. Add the `![` case to T-52.

### F-160 — Print does not say whether block-boundary rhythm is re-applied

**Severity:** MEDIUM

**Location:** C-21.2 (line 561), I-014, C-18.10, K-17

**Observation**

Print renders "each C-02 block on its own", from a tree that "mirrors the screen's block view", with $12\,s_p$ pt between blocks. C-18.10 and I-014 require a per-block renderer to **re-apply** the theme's heading top and bottom spacing at block boundaries, because MarkdownUI's margins act only between siblings. C-21 does not say whether print does the same, and I-014 is stated for the screen. The original prints without re-applying them, as its screen did before v0.9.

**Why it matters**

The same flush-heading failure D-40 recorded for the screen can recur on paper, and the spec neither requires nor excludes it.

**Potential consequence**

Two conforming builds print headings with visibly different spacing. One matches the screen; one reproduces `RECREATION-MDV7`'s defect.

**Recommended resolution**

State in C-21.2 that the C-18.10 boundary margins, multiplied by $s_p$, are applied between printed blocks **in place of** the flat $12\,s_p$ gap where they are larger (or in addition to it, whichever is intended). Extend T-53 with a K-16-style gap check on the printed rhythm document.

### F-161 — The inline-formula "vector" clause excuses itself and is not tested

**Severity:** MEDIUM

**Location:** R-45 (line 122), C-21.4 (line 565), T-53

**Observation**

R-45: "an inline formula as vector glyphs where C-21.4's overlay succeeds". C-21.4 then prescribes the mechanism in detail: invisible placeholders with a $1 \times (k+1)$ pixel signature, read back from the content stream. Because failure is permitted without limit, a build whose overlay **never** succeeds conforms. No test in T-53 checks inline formulas at all. The mechanism is also normative, although only the outcome is observable.

**Why it matters**

The requirement cannot fail, so it proves nothing. Meanwhile the prescribed mechanism rules out simpler designs, such as drawing formulas at positions reported by a layout callback, that meet the same outcome.

**Potential consequence**

A regression to all-bitmap inline math passes review.

**Recommended resolution**

State the observable outcome — e.g. "in `test-docs/math.md` every inline formula is drawn as vector glyphs (the block's page holds no image object inside that formula's rectangle)" — and keep the placeholder method as an informative *as built* note. Add the assertion to T-53. If the fallback must remain, make it an E-33 case with a count ceiling.

### F-162 — T-53's scripted oracles need data `--print-pdf` does not produce

**Severity:** MEDIUM

**Location:** T-53 (§9.7), C-17 (line 473)

**Observation**

T-53's scripted half has four problems:

1. It asserts "no image object for a standalone `$$…$$` block". `--print-pdf` reports block rectangles but not which image objects fall in them, and `math.md` legitimately contains baked bitmaps elsewhere (F-161). The checker must attribute images to blocks by geometry, and the spec does not say how.
2. "PDFKit extracts the document's words" does not say how the words are obtained. Smart typography changes quotes and dashes, math is not text, and `<img>` alt text is not printed.
3. It runs `--print-pdf` over "`test-docs/mermaid/` fixtures", but those are `.mmd` files and C-17's `--print-pdf` takes an `.md`.
4. "Byte-identical page content streams" at two zooms and themes is a strong claim. It depends on `ImageRenderer` emitting deterministic resource names, which is not established.

**Why it matters**

The skill's oracle test applies: the expected result must be computable from the spec. Here two testers would write different checkers.

**Potential consequence**

T-53 is flaky or vacuous.

**Recommended resolution**

- Extend the `--print-pdf` JSON with, per block, the image objects drawn in its rectangle (count and pixel size).
- Define the word oracle as the whitespace-split tokens of C-12-stripped prose blocks with smart typography off, excluding math and image blocks.
- Allow `.mmd` input (wrapped as one fence), or name a `.md` fixture.
- Weaken byte-identity to "identical extracted text and identical block rectangles within 0.5 pt".

### F-163 — The v0.14 visual surfaces have no observed test and no reference image

**Severity:** MEDIUM

**Location:** §9.6 (line 890), §9.7, C-18.0

**Observation**

§9.6 requires a conformance report to carry observed outcomes for T-44, T-47, T-48 and T-49. Several v0.14 features are visual deliverables, but none of them is in that set: the properties table (T-52), the printed page (T-53, manual half), web diagrams (T-54), diff tinting (T-58), `<img>` sizing (T-59) and find typography (T-60). None has a reference image either. This is the D-40 lesson: behaviour rows were satisfied by builds that looked nothing like the product.

**Why it matters**

A build can report these features as conforming with nobody having looked at a printed page or a gantt chart.

**Potential consequence**

The table styling, the printed type size and a web diagram's background drift unnoticed.

**Recommended resolution**

- Add T-52, T-53 (panel half), T-54 and T-58 to §9.6's observed set.
- Check in reference images from the original at `68aa008`: `frontmatter.md` rendered, one printed Letter page of `math.md` as PDF→PNG, `gantt.md` rendered, `diff.md` rendered.
- Cite them from C-20.3, C-21, C-06.5 and C-05.1 as normative for structure (D-42's rule).

### F-164 — mermaid.js console output in WebKit's processes is outside R-35 and T-36

**Severity:** LOW

**Location:** R-35 (line 109), T-36 (line 885), C-06.5

**Observation**

mermaid.js logs parse errors, including the offending source, to the JavaScript console. The console belongs to WebKit's web-content process. R-35 ("the application MUST NOT print document content … to any log") does not say whether that process counts. T-36 watches only `log stream --process mdv6`, so it would not see a leak there.

**Recommended resolution**

In C-06.5, set mermaid's `logLevel` to its quietest level (`'fatal'`) and keep the web view non-inspectable. Extend R-35/T-36 to cover WebKit's content process for the application's pages.

### F-165 — No licence obligation stated for the bundled mermaid.js

**Severity:** LOW

**Location:** C-13, §10, D-45

**Observation**

D-45 rejected Metal grammars because they ship no licence file, which shows the spec treats licensing as a gate. mermaid.js is MIT and its minified build bundles third-party code (d3, DOMPurify, and others). The spec pins the file but says nothing about shipping its licence notices, and the file is excluded from the repository.

**Recommended resolution**

Require the bundle to carry mermaid's licence and its dependencies' notices (e.g. `Resources/mermaid.LICENSE.txt`), fetched and SHA-pinned like the script, and list it in C-01/C-13.

### F-166 — BOM before the fence is undefined; the old-bookmark compatibility claim is overstated

**Severity:** LOW

**Location:** C-20.1, C-02 rule 9

**Observation**

1. C-20.1 requires line 1 to be exactly `---`. Whether a leading U+FEFF (a UTF-8 BOM) is removed by R-04's decode or by rule 6 is not stated, so a BOM-prefixed header is recognised by one build and not another.
2. Rule 9 claims pre-v0.14 bookmarks "still resolve" when the header has no blank lines of its own. That holds only when a blank line also **follows** the closing fence. With `---` immediately followed by `# Title`, the old split had one block and the new split has two, so every later index shifts by one and C-08's clamped-index fallback lands one block off.

**Recommended resolution**

State that R-04 strips one leading U+FEFF before C-02 runs. Qualify rule 9's claim with the following-blank-line condition.

### F-167 — C-09.1 cites theme fields C-09 does not declare

**Severity:** LOW

**Location:** C-09 (line 406), C-09.1 (line 424)

**Observation**

C-09.1 depends on `showH1Rule`, `showH2Rule`, `headingFontWeight`, `strongFontWeight` and `paragraphLineSpacingEm`. C-09's field list does not declare any of them. They exist in `TYPOGRAPHY.md` and in the code, and C-18.7 already cited `showH1Rule`. C-09 claims to list "the fields behaviour depends on".

**Recommended resolution**

Add the five fields to C-09's struct, with defaults from `TYPOGRAPHY.md`.

### F-168 — T-42's key list and C-17's `expect` enum were not extended

**Severity:** LOW

**Location:** T-42 (line 871), C-04, C-17

**Observation**

T-42 enumerates the preferences it covers and omits the new `mdv6_show_frontmatter`, so R-32/C-04 conformance is untested for it. C-17's manifest shape documents `"expect": "render-or-fallback"`, but the `--scan` statuses now include `web`, and the manifest's `expect` values are not updated to match.

**Recommended resolution**

Add the key to T-42's list. Extend the manifest's `expect` enumeration to `render`, `fallback` and `web`.

### F-169 — Two *Affects* cells omit ids their decisions constrain

**Severity:** LOW

**Location:** §12 D-50 (line 1146), D-46

**Observation**

D-50 decides that *Close All* acts in every window, which overrides E-26 and R-01's single-target rule. Its *Affects* cell lists R-47, §3.1, §5.1 and E-36, but neither E-26 nor R-01. D-46 does not list R-35 or T-36, which F-164 shows it touches. Change-impact tooling that reads the *Affects* cell will not see these edges.

**Recommended resolution**

Add E-26 and R-01 to D-50. After F-164 is resolved, add R-35 and T-36 to D-46.

### F-170 — The measure rationale mixes a padded frame with a content width; "empty" is ambiguous

**Severity:** LOW

**Location:** C-21.1 (line 553), R-45

**Observation**

1. $s_p = w_c / W$ divides the paper's **content** width by `articleMaxWidth`, which K-13 defines as the cap on the **padded** frame. The screen's content column is $860 - 80 - 12 = 768$ pt, so "keeps roughly its characters per line" is about 11 % optimistic. The formula is deterministic; only the rationale is off.
2. R-45 says ⌘P with "an empty" document beeps. R-04 defines an empty file as zero bytes **or** whitespace only; the original tests zero length.

**Recommended resolution**

Either keep the formula and correct the rationale, or use the content column ($W - 2p - 2b$) if matching the measure is the goal (record the choice in D-47). Say whether "empty" means zero blocks.

### F-171 — `>` inside a quoted attribute ends the tag; `<img>` in a heading reaches the TOC raw

**Severity:** LOW

**Location:** C-22.1, C-12, C-02 rule 7

**Observation**

1. The candidate tag ends at "the first following `>`", even inside a quoted `alt="a > b"`. The attributes after that point are lost, and the rest of the tag prints as text.
2. A heading such as `# Title <img src=logo.png width=20>` renders the image. But C-02 rule 7 takes TOC text from the raw heading, and C-12 does not strip HTML, so the TOC row and any ⌘D title show `<img src=logo.png width=20>`.

**Recommended resolution**

Skip quoted runs when looking for the closing `>`. Add "`<img …>` tags are removed" to C-12's order (as a new step before (2)).

### F-172 — "No window flashes" holds only when the PDF route succeeds

**Severity:** LOW

**Location:** T-53, C-21.3

**Observation**

T-53 asserts that `gantt.md` "prints its chart with no window flashing on screen". C-21.3's fallback route orders a window front in order to snapshot it. The assertion is therefore conditional on the first route succeeding, which T-53 does not establish.

**Recommended resolution**

Word T-53 as "no window flashes when the PDF route succeeds (the harness or log reports which route ran)", or require the snapshot fallback to use a window positioned entirely off every screen.

## 5. Requirements Review

The v0.14 requirements are observable and mostly precise. Each names its trigger, its effect, its disabled states and its source commits. The gaps are cross-rule contradictions, not vague rows: R-08/R-50 (F-153), R-06/R-47 (F-154), E-26/R-47 (F-155), and C-22.2 against itself (F-157). One requirement is unfalsifiable as written: R-45's inline-formula clause (F-161). The only requirement missing outright is the zero-window case (F-149).

## 6. Interface and Data-Contract Review

The new pure interfaces are implementation-grade:

- C-05.1's classifier is stated as a state machine with counters.
- C-06.4's dispatch names its keywords and its preamble grammar.
- C-20.1/C-20.2 give recognition and reduction exhaustively.
- C-22.1/C-22.2 give the URL encoding, attribute grammar and size function.
- The per-theme diff colour table gives exact values.

C-04 gained its key, but T-42 did not (F-168). C-17's `web` status and `--print-pdf` are defined; the latter's JSON output is too thin for the test that uses it (F-162).

**Visual surface.** C-18's structure-first discipline is not carried into the new surfaces. The properties table (C-20.3) has metrics but no reference image. The printed page, the web diagram and the diff block have neither a reference image nor an observed test (F-163). Every settable v0.14 feature has an affordance row in §5.1 — the visibility test passes — except the hidden-header states (F-158).

## 7. State and Failure Review

§3.1 was extended coherently: ⌘W, *Close All*, Next/Previous File and the totality note are all placed. Two gaps remain:

- The state with **no document window** is unreachable in §3.1's model but reachable in the product (F-149).
- *Close All* racing an in-flight load is unstated (F-155).

Failure semantics for the new renderers are good:

- **Web diagrams:** rejection, no SVG, no height, and no network are covered (E-34). The one deliberate gap — an on-screen spinner with no timeout — is stated.
- **Print:** an empty document, a second ⌘P, a too-tall block, a double diagram failure and remote images are covered (E-33).
- **`<img>`:** missing, empty, non-numeric sizes and odd schemes are covered (E-35).

## 8. Determinism and Algorithm Review

The v0.14 algorithms are deterministic and fully ordered:

- the §3.2 rewrite order (`<img>` → math → smart typography) is normative, and C-21 repeats it;
- C-05.1's counters define exactly when a `---` line is a header;
- C-20.2 fixes its dedent, fold and quote rules;
- C-22.2's size function covers all four attribute combinations;
- C-21.1's $s_p$ formula has its symbols defined and the degenerate case ($s_p = 1$ without a max width) stated;
- K-17 and K-18 pin every constant.

The two points of algorithmic doubt are print rhythm (F-160) and the YAML guard's treatment of `#` lines (F-150).

## 9. Edge-Case Review

E-32…E-37 are well chosen. The missing boundaries are:

- zero document windows (F-149);
- a BOM before the fence (F-166);
- a multi-line directive (F-152);
- `>` inside a quoted attribute (F-171);
- a header that is empty, hidden, or contains `![` (F-150, F-158, F-159);
- a `<img>` inside a heading (F-171).

## 10. Non-Functional Requirement Review

K-17…K-19 make the print, scrolling and web-diagram constants measurable. The print densities are justified by measurement in the source (432/864 ppi, edge-contrast figures). No performance bound is given for print pre-rendering or for a document with many web diagrams, each with its own `WKWebView`. That is acceptable implementation freedom for now, but a long `mermaid-web-fallback.md`-style document could stress memory. Consider a K-19 note on the maximum number of live web views, or lazy teardown.

## 11. Security and Trust-Boundary Review

This is the strongest part of the delta. The *Principle* and the §0 trust boundary are amended, not contradicted. I-001 and I-003 carry the exception explicitly. C-06.5 requires:

- `securityLevel: 'strict'`;
- no base URL;
- refusal of every non-page load;
- no private API.

C-13 pins mermaid.js by SHA-256 and hard-fails on a mismatch. D-51 closes a real privacy hole in the original (an inline remote `<img>` fetched outside C-16). Remaining: WebKit console logging (F-164) and licence notices (F-165), both LOW.

## 12. Observability and Provenance Review

C-13's failure message names both digests, and `--print-pdf` emits per-block placement. The print and web paths otherwise log nothing, which R-35 requires. The provenance of the v0.14 rows is exact: each cites the original's commits up to `68aa008`, and the fixtures were carried over with the path changes recorded.

## 13. Testing and Verification Review

Every v0.14 requirement has a test, and every pure contract has a unit half. The weaknesses:

- T-53's scripted oracles are under-defined (F-162).
- R-45's inline-formula clause is untested (F-161).
- The visual deliverables are not in the observed set and have no reference images (F-163).
- T-42 misses the new key (F-168).
- T-54 tests only the directive form that works (F-152).

Negative cases are well represented: `frontmatter-negative.md`, a broken gantt, a corrupted mermaid.js, literal `<img>` in code, and focus pass-through for scrolling.

## 14. Metrics and Evaluation Review

The only new formula is C-21.1's $s_p$, and it is well formed: symbols defined, a worked Letter value, and the degenerate case stated. Its **rationale** does not match K-13's definition of the column (F-170). No new aggregate metric is introduced.

## 15. Traceability Review

The chain is complete for the delta:

- every R-44…R-51 row has contracts, tests and a §11 row;
- every §11 row is marked *not yet realised*;
- D-46…D-53 cover every choice that departs from the original or has an alternative;
- the revision history lists every amended row.

Two *Affects* cells are incomplete (F-169).

## 16. Internal-Consistency Review

Four normative conflicts were introduced: F-153, F-154, F-155 and F-157. Three rules are unqualified where they now need scoping: R-11, K-07 and I-005 (F-156). §3.2's diagram agrees with the table rows and C-06.4. The §3.1 diagram's new edge ("last row deleted or closed, or Close All") is backed by R-47 and the `VIEWING`/`EMPTY` rows. The mermaid block in §3.2 declares `F` before its first edge, so it renders.

## 17. Architecture Review

The architecture supports the requirements:

- print reuses the screen pipeline, with a pre-pass for asynchronous content;
- the web path is a leaf renderer behind C-06.4's dispatch;
- frontmatter is a split-level concern with view-level display.

Vendoring MarkdownUI (D-49) is the minimum change that makes C-21.4 possible, and I-016/T-62 keep it auditable. The one architectural gap is the web view's integration with the host view hierarchy: events, focus and menus (F-151).

## 18. Implementation-Agent Readiness

**NO — MATERIAL QUESTIONS REMAIN** for the v0.14 rows. The pre-v0.14 document remains **YES — WITH MINOR CLARIFICATIONS**.

Minimum blocking questions:

1. With no document window, what do an open event, ⌘O and a Dock click do? (F-149)
2. Must a web-path diagram suppress WebKit's context menu, forward wheel events, and refuse first responder? (F-151)

Non-blocking but likely to be asked:

- print rhythm (F-160);
- hidden-header anchoring and title (F-158);
- multi-line directives (F-152);
- the inline blocked `<img>` (F-157).

## 19. Quality Scorecard

| Dimension | Score |
| --------- | ----: |
| Scope clarity | 5 |
| Terminology | 4 |
| Requirement precision | 4 |
| Interface completeness | 4 |
| Visual-surface completeness | 3 |
| Data-contract completeness | 4 |
| State/lifecycle definition | 3 |
| Algorithm precision | 4 |
| Failure semantics | 4 |
| Edge-case coverage | 4 |
| Non-functional requirements | 4 |
| Security specification | 5 |
| Observability/provenance | 4 |
| Testability | 3 |
| Evaluation/metrics | 5 |
| Traceability | 4 |
| Internal consistency | 3 |
| Architecture consistency | 4 |
| Implementation readiness | 3 |

Compared with the seventh review, terminology, data contracts and traceability recover to 4, since F-126…F-138 were applied. Visual-surface completeness drops from 5 to 3, because the new surfaces lack reference images and observed tests (F-163). State/lifecycle drops to 3 because of the zero-window gap (F-149). Testability stays at 3 because of F-161/F-162.

## 20. Remediation Plan

### P0 — Blocking

1. **F-149** — add the no-document-window clause to R-01, with E-38 and a T-61 case. *(one clause, one row, one test clause)*
2. **F-151** — add the web view's context-menu, wheel, first-responder and selection rules to C-06.5, with T-54 clauses. *(four bullets)*

### P1 — Important

3. **F-153, F-154, F-155** — add the three missing exceptions to R-08, R-06 (and the `LOADING` row), and E-26; cancel in-flight loads on *Close All*. *(four clauses)*
4. **F-157** — state the inline blocked-remote placeholder in C-22.2 and R-16. *(one sentence each)*
5. **F-156** — scope R-11/K-07 to native diagrams and state the web width rule in C-06.5. *(two clauses)*
6. **F-158, F-159** — the hidden-header rules in R-44 and the verbatim inline path in R-24; extend T-52. *(one paragraph, one clause)*
7. **F-150, F-152** — the zero-row rule in C-20.1 (record it in D-48), and a C-06.1 directive-stripping rule; extend T-52/T-54. *(two rules)*
8. **F-160, F-161, F-162** — print rhythm in C-21.2; restate R-45's inline clause as an outcome; enrich the `--print-pdf` JSON and T-53's oracles. *(one clause, one sentence, one C-17 row, T-53 rewrite)*
9. **F-163** — add the v0.14 visual tests to §9.6 and check in reference images from the original. *(one sentence, four images)*

### P2 — Improvement

10. **F-164…F-172** — mermaid `logLevel` and R-35/T-36 scope; licence notices; BOM and the rule 9 claim; C-09 fields; T-42 key and C-17 `expect`; the D-50/D-46 *Affects* cells; C-21.1's rationale and "empty"; quoted `>` and `<img>` in C-12; T-53's flash wording.

No redesign is recommended. Every finding is an edit to the v0.14 text, or to a pre-v0.14 row that the delta should have amended alongside it.

## 21. Final Verdict

```text
Specification maturity:
Level 3

Implementation readiness:
NOT READY

Primary blocker:
The spec gives no behaviour for open events and menu commands when no document window exists (F-149), and leaves the web view's context menu, scrolling and focus to WebKit's defaults (F-151).

Most important improvement:
Add the zero-window rule to R-01 and the web-view interaction rules to C-06.5, then carry the four missing exceptions into R-06, R-08, E-26 and C-22.2 — after which the v0.14 delta meets the implementation-grade bar of the rest of the document.
```
