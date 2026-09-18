#!/usr/bin/env bash
# The speccheck gate (§9.0 stand-in name kept): fresh test results, then Phase A (mock judge) and,
# when SPECCHECK_JUDGE_URL is set, Phase B (LLM judge). Both must exit 0 for the build to be CONFORMING.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift test --parallel --xunit-output junit.xml || { echo "swift test failed"; exit 1; }
speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --strict --out build/speccheck
A=$?
if [ -n "${SPECCHECK_JUDGE_URL:-}" ]; then
  speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge llm --strict --out build/speccheck-llm
  B=$?
else
  echo "Phase B not run: SPECCHECK_JUDGE_URL unset"; B=0
fi
[ $A -eq 0 ] && [ $B -eq 0 ]
