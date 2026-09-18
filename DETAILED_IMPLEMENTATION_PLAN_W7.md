# Detailed implementation plan — W7: Prove it

> - **Wave:** W7 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 8 — "Prove it").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. `SPEC.md` is edited only by a `fix(spec):` commit for a recorded `F-nnn` defect, with its version header bumped.
> - **Gate:** the final `swift test --xunit-output junit.xml` is green; speccheck Phase A (`--judge mock --strict`) exits 0; Phase B (`--judge llm --strict`, OpenRouter `openai/gpt-4o-mini`) exits 0; every observed T-nn has a recorded outcome or the verdict is `VERIFICATION PENDING`; `README.md` command-verified; `SPEC_BUILD_REPORT.md` written.
> - **Budget:** 0 production lines by design (defect fixes only, each with a regression test); `README.md`, `Help.md` final text, `SPEC_BUILD_REPORT.md`, `test-docs/fixtures/`.
> - **Depends on:** W0–W6 all committed. **Unlocks:** nothing — terminal.

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| T-44, T-47, T-48, C-18, R-42, I-015, K-16, E-30 | observed on screen against `reference/*.png` on an isolated store | §4 live pass; screenshots under `build/observed/` opened by a person |
| T-05, T-08, T-09, T-10, T-11, T-12, T-18, T-21, T-31, T-35, T-36, T-38 | manual §9.2/§9.4 checks | driven in the same session, outcome per clause recorded |
| T-32, K-15, I-008 | idle-CPU protocol | `tools/idle-cpu.sh` (5 s warm-up, 30 × `ps -o %cpu`), median and nearest-rank p95 recorded with the host |
| T-43, K-11 | release provenance | *verification pending: no identity/profile/tag* + `make -n dist` chain recorded (plan §7 fork, as answered) |
| R-37, §9.0 | suite and speccheck join | `tools/speccheck.sh` both phases |
| §11 | matrix fully traced from `speccheck.json` | report §11 table |
| Phase 2 | README reflects the built system | `README.md` written from the tree; every command executed |

## 2. Entry preconditions

- W6 gate green; `git log` shows one commit per wave W0–W6.
- Console: `launchctl managername` prints `Aqua`; `screencapture -x "$TMPDIR/probe.png"` yields a non-black PNG (screen-recording permission). If either fails, the observed group is *pending* and the report says so (plan §6 downgrade rule).
- `OPENROUTER_API_KEY` set; `SPECCHECK_JUDGE_URL=https://openrouter.ai/api/v1/chat/completions`, `SPECCHECK_JUDGE_MODEL=openai/gpt-4o-mini`, `SPECCHECK_JUDGE_API_KEY=$OPENROUTER_API_KEY` exported for Phase B (the pre-existing `SPECCHECK_JUDGE_*` values in the shell are overridden explicitly).

## 3. Deliverables

- `test-docs/fixtures/seed-observed.sh` — creates `$MDV6_SUPPORT_DIR/mdv6.db` with four bookmarks (titles from `test-docs/math.md` headings) and writes `mdv6_history` (`math.md`, `syntax.md`, `tables.md`, `code.md`) + `mdv6_theme_id=sevilla` into the `MDV6_DEFAULTS_SUITE` domain using the app's own `Database`/`HistoryCodec` through a tiny `swift run`-able script target `tools/seed` (links `mdv6Core`; not part of the product).
- `tools/idle-cpu.sh`, `tools/observe.sh` (launches with the isolated store, waits, `screencapture -l $(windowid)` per theme).
- `build/observed/T-44-sevilla.png`, `T-44-charcoal.png`, `T-44-twilight.png`, `T-47-*.png`, `T-48-*.png` (not committed; paths recorded in the report).
- `README.md` (Phase 2 template: title + one line; Setup; Quick start with `test-docs/`; Usage per §5 surface; Artifacts and schemas with the C-03/C-08 SQL and the §7 formulas verbatim; Project layout generated with `find`; Verification with the exact gate commands incl. both speccheck phases; Scope/deferrals).
- `mdv6/Help.md` final text (sections cited by §2).
- `SPEC_BUILD_REPORT.md` — per-id evidence from `build/speccheck/speccheck.json`, the wave ledger (wave, gate command, exit code, commit sha), observed outcomes one line each with the screenshot path, `F-nnn` list with resolutions, both speccheck summary lines verbatim, Phase B model and `unknown_rate`, LOC measurement vs the §5 anchor, verdict block.

## 4. Work items, in order

- **W7-01** Preconditions check (console, capture, judge variables) — outcome recorded before anything else.
- **W7-02** Fresh gate: `swift test --xunit-output junit.xml`; Phase A `speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --strict --out build/speccheck`. Every non-`PASSING` id → `F-nnn`, fixed in code with a regression test (or recorded as a user-approved deferral), re-run until `CONFORMING`, 0 dangling, 0 stale.
- **W7-03** Phase B `… --judge llm --strict --out build/speccheck-llm`; every `WEAKLY_PASSING` → strengthen the test; re-run both phases.
- **W7-04** Live pass: `make`; seed; `tools/observe.sh`; walk T-44 clause by clause (title, toolbar, headers, history rows, reveal/Esc, TOC indent and accent selection, bookmark rows and badges, placeholder row first with `pin.fill`/`⌘0`, current row fill, count capsule and collapse, floating find button, Charcoal/Twilight title legibility, handle chevron), T-47 (titles across two windows and after deleting the last row), T-48 (stripe on paragraph / none on fences; placeholder menu; nine-entry bookmark menu; moves and slots; relaunch order). Each screenshot opened and compared region by region with `reference/MDV-ORIGINAL-SEVILLA.png` and `MDV-SCREEN.png`; every difference → `F-nnn`.
- **W7-05** Manual §9.2/§9.4 checks (T-05, T-08, T-09, T-10, T-11, T-12, T-18, T-21, T-31, T-35, T-36 via `log stream --process mdv6`, T-38) on the isolated store; outcomes recorded.
- **W7-06** T-32 idle CPU via `tools/idle-cpu.sh` on this host.
- **W7-07** Fix every `F-nnn` (code first; spec only when the spec is wrong, with `fix(spec):`), re-run W7-02/03 and the affected observations.
- **W7-08** `README.md` and `Help.md`; execute every README command; `docs(mdv6): README reflects built implementation`.
- **W7-09** `SPEC_BUILD_REPORT.md`; measure production/test LOC (`grep -cv '^\s*$\|^\s*//'` over `mdv6/Core`, `App`, `tools/render-harness/Sources`; tests over `Tests`); final commit `docs(mdv6): W7 — conformance report`.

## 5. Test plan

| group | spec ids | asserted | how |
|---|---|---|---|
| Final suite + speccheck A/B | all ids | `CONFORMING`, 0 dangling, 0 stale, 0 weak | `tools/speccheck.sh` |
| Observed | T-44, T-47, T-48 (+ manual §9.2/§9.4) | outcomes per clause | a person at the screen |
| Idle CPU | T-32 | median ≤ 1 %, p95 ≤ 3 % | `tools/idle-cpu.sh` |

## 6. Gate

1. `swift test --xunit-output junit.xml` — exit 0, 0 skipped.
2. `speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --strict --out build/speccheck` — exit 0; summary `speccheck: CONFORMING - N/N passing (100.0%) … 0 dangling, 0 stale; judge=mock`.
3. Same with `--judge llm --strict --out build/speccheck-llm` — exit 0; `judge=llm`; `unknown_rate ≤ 0.2` in `build/speccheck-llm/speccheck.json`.
4. `bash -n tools/*.sh`; every README command run with its printed exit code.
5. `build/observed/` contains the screenshots named in the report, each opened.
6. `git log --oneline` shows W0…W7 commits; the report's ledger matches it.

## 7. Traceability

Every §11 row → plain (realised and verified) or *verification pending* with the environmental reason (T-43; any observed clause the host could not show). No row is weakened.

## 8. Risks and traps

- **Self-certification (plan §6 row 1):** the report states, per visual claim, which oracle it rests on — reference image, measured quantity, or person. A harness golden is never one of them.
- **Phase B truncation:** `gpt-4o-mini` rarely truncates; if `unknown_rate` exceeds 0.2, inspect `build/speccheck-llm/SPEC_CONFORMANCE_REPORT.md` §8 and rerun with `--judge-concurrency 2` — never raise `--max-unknown`.
- **Isolated store:** every observed run sets `MDV6_SUPPORT_DIR` and `MDV6_DEFAULTS_SUITE`; the reader's own store is never touched (checked by `ls -la ~/Library/Application\ Support/mdv6` before/after).
- **T-43 remains pending** unless a Developer ID identity, a notary profile and a `v1.2.3` tag are supplied (plan §7).

## 9. Exit criteria and handoff contract

Terminal. The final verdict line block (`Spec coverage`, `speccheck (mock)`, `speccheck (llm)`, `Observed`, `Readiness`, `Conformance`) is printed once and recorded in `SPEC_BUILD_REPORT.md`.
