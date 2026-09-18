#!/usr/bin/env bash
# Regenerates the pixel-case goldens under test-docs/goldens from the current pipeline (regression guards, not oracles).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$(mktemp -d -t mdv6-goldens)"
swift run --package-path tools/render-harness render-harness --check test-docs/render-cases.json --output-dir "$OUT" >/dev/null 2>&1 || true
mkdir -p test-docs/goldens
for id in $(python3 -c 'import json;[print(c["id"]) for c in json.load(open("test-docs/render-cases.json"))["cases"] if c.get("metric")=="pixel"]'); do
  cp "$OUT/$id.png" "test-docs/goldens/$id.png"
done
echo "goldens updated from $OUT"
