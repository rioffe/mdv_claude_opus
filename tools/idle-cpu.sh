#!/usr/bin/env bash
# T-32 / K-15: open test-docs/math.md, wait 5 s untouched, then take 30 one-second process-CPU samples (Δ cputime / 1 s)
# and report the median and the nearest-rank 95th percentile (must be ≤ 1 % and ≤ 3 % on an otherwise idle host).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
export MDV6_SUPPORT_DIR="${MDV6_SUPPORT_DIR:-$TMPDIR/mdv6-idle}" MDV6_DEFAULTS_SUITE="${MDV6_DEFAULTS_SUITE:-mdv6.idle}"
pkill -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6" 2>/dev/null; sleep 0.5
"$ROOT/build/mdv6.app/Contents/MacOS/mdv6" "$ROOT/test-docs/math.md" >/dev/null 2>&1 &
sleep 1
PID="$(pgrep -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6" | head -1)"
[ -n "$PID" ] || { echo "app did not start"; exit 2; }
cputime() { ps -o cputime= -p "$PID" | awk -F'[:.]' '{ if (NF==3) print $1*60+$2+$3/100; else print $1*3600+$2*60+$3+$4/100 }'; }
sleep 5
samples=()
prev="$(cputime)"
for i in $(seq 1 30); do
  sleep 1
  now="$(cputime)"
  samples+=("$(awk -v a="$prev" -v b="$now" 'BEGIN { printf "%.2f", (b-a)*100 }')")
  prev="$now"
done
pkill -f "$ROOT/build/mdv6.app/Contents/MacOS/mdv6"
sorted=($(printf '%s\n' "${samples[@]}" | sort -n))
median="$(awk -v a="${sorted[14]}" -v b="${sorted[15]}" 'BEGIN { printf "%.2f", (a+b)/2 }')"
p95="${sorted[28]}"          # nearest rank: ceil(0.95 × 30) = 29th value (1-based)
echo "samples: ${samples[*]}"
echo "median ${median} %  p95 ${p95} %  (K-15: median ≤ 1 %, p95 ≤ 3 %)"
awk -v m="$median" -v p="$p95" 'BEGIN { exit !(m <= 1.0 && p <= 3.0) }'
