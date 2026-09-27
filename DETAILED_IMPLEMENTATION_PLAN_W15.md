# Detailed implementation plan — W15: Prove it (v0.14)

> - **Wave:** W15 of W10–W15 (`IMPLEMENTATION_PLAN.md` §II.4 "W15 — Prove it").
> - **Spec basis:** `SPEC.md` v0.14.4, sha256 `2c193583…9fdc`. The wave edits `SPEC.md` only in a separate `fix(spec):` commit, and only for status markers.
> - **Gate:** `bash tools/speccheck.sh` → Phase A `CONFORMING 210/210`, Phase B recorded; every observed v0.14 clause has a recorded outcome, or is *verification pending*.
> - **Budget:** 0–50 production lines (defect fixes only).
> - **Depends on:** W10–W14.

## 1. Objective and spec obligations

| Spec id | Obligation | Discharge |
|---|---|---|
| §9.6 observed set (T-52, T-53 manual, T-54, T-58, T-59) and the manual clauses of T-55, T-56, T-57, T-60, T-61 | a person's look, against `reference/ORIGINAL-*.png` | `tools/observe.sh` captures in `build/observed/`, opened and compared |
| §11 | statuses match the tree, including the stale C-19/E-31/T-49/T-50 marker | a `fix(spec):` commit |
| README, Help | describe the built surface | `README.md`, `mdv6/Help.md` |
| Phase A / B | speccheck | `tools/speccheck.sh` |

## 2. Entry preconditions

- The W14 gate is green.
- `launchctl managername` prints `Aqua`.
- Screen recording works (`screencapture -l` succeeded on 2026-09-27).

## 3. Deliverables

- `build/observed/v014-*.png` (not committed).
- `README.md`: the Features, Getting around, Build (mermaid fetch) and Layout sections.
- `mdv6/Help.md`: printing, frontmatter, closing files, stepping, keyboard scrolling, diagrams.
- `SPEC_BUILD_REPORT.md`: the W10–W15 ledger, per-id evidence, the observed outcomes, both speccheck lines, and the verdict.
- The `fix(spec):` commit.

## 4. Work items

- **W15-01 — the observed pass.** Capture each case on an isolated store, then compare it with the reference.
  - `frontmatter.md` → `ORIGINAL-FRONTMATTER.png`.
  - `gantt.md` → `ORIGINAL-GANTT.png`, plus the right-click menu, a wheel scroll over the diagram, and a click followed by ↓.
  - `diff.md` → `ORIGINAL-DIFF.png`.
  - `raw-html-images.md` → `ORIGINAL-RAW-HTML-IMAGES.png`.
  - `PrintController.renderPDF(math.md)` rasterised → `ORIGINAL-PRINT-MATH.png` for block structure. The rhythm differs by design (F-160).
  - Two windows for *Close All*; ⌃⇥; End; find in Sevilla at 125 %; `open -g`; the zero-window reopen.

  Each outcome is one line in the report. A difference is an `F-nnn`.
- **W15-02 — the §11 walk** from `build/speccheck/speccheck.json`, then the `fix(spec):` commit for the status markers.
- **W15-03 — README and Help** from the built surface; run every README command as written.
- **W15-04 — speccheck Phase A, then Phase B.** Fix any `WEAKLY_PASSING` in the test.
- **W15-05 — `SPEC_BUILD_REPORT.md`.**

## 5. Test plan

No new test files; any defect found gets a regression test in the owning wave's file.

## 6. Gate

1. `make && bash tools/speccheck.sh` → Phase A prints `CONFORMING - 210/210`, exit 0.
2. Phase B through the configured judge → summary line recorded; exit code recorded.
3. `ls build/observed/v014-*.png | wc -l` → at least 10.

## 7. Traceability

Every v0.14 id moves from *not yet realised* to plain in §11, or to *verification pending* with a reason.

## 8. Traps

- **The downgrade rule** (§II.6): an unobserved clause is pending, never passed.
- **Accessibility permission is absent**, so drive through the app's hook, not System Events.
- **The print panel** needs a person. The stand-in is the `renderPDF` output opened by one.

## 9. Exit

The verdict block in `SPEC_BUILD_REPORT.md`, in `spec-build`'s format.
