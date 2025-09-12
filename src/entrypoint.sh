#!/usr/bin/env bash
set -euo pipefail

OUT=${OUT_DIR:-/results}
mkdir -p "$OUT"

date +"%F %T %z" | tee -a "$OUT/meta.txt"
uname -a          | tee -a "$OUT/meta.txt"
lscpu            > "$OUT/lscpu.txt" || true
numactl --hardware > "$OUT/numa.txt" 2>/dev/null || true

echo "Running stress-ng: cpu=$STRESS_CPU method=$STRESS_CPU_METHOD duration=$STRESS_DURATION" | tee -a "$OUT/meta.txt"

if command -v perf >/dev/null 2>&1; then
  echo "perf found. events: $PERF_EVENTS" | tee -a "$OUT/meta.txt"
  /usr/bin/time -v -o "$OUT/time.txt" \
  perf stat -x, -o "$OUT/perf.csv" -e "${PERF_EVENTS}" \
    stress-ng --cpu "$STRESS_CPU" \
              --cpu-method "$STRESS_CPU_METHOD" \
              --metrics-brief \
              --timeout "$STRESS_DURATION" \
              1> "$OUT/stress.stdout" \
              2> "$OUT/stress.stderr" || true
else
  echo "perf NOT found; skipping perf stat" | tee -a "$OUT/meta.txt"
  /usr/bin/time -v -o "$OUT/time.txt" \
    stress-ng --cpu "$STRESS_CPU" \
              --cpu-method "$STRESS_CPU_METHOD" \
              --metrics-brief \
              --timeout "$STRESS_DURATION" \
              1> "$OUT/stress.stdout" \
              2> "$OUT/stress.stderr" || true
fi

# cgroup v2 metrics
[ -f /sys/fs/cgroup/cpu.stat ] && cp /sys/fs/cgroup/cpu.stat "$OUT/cpu.stat" || true

echo "Done. Results in $OUT"
tail -n +1 "$OUT"/stress.stdout || true
