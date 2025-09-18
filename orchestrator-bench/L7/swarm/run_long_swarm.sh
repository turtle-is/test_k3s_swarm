#!/usr/bin/env bash
set -euo pipefail
HOST=${HOST:-192.168.1.127}
PORT=${PORT:-30081}
DUR=${DUR:-1800}        # 30 минут

./../metrics/node_metrics.sh "../../results/node_server.csv" >/dev/null 2>&1 & MET_PID=$!

docker run --rm -i --network host \
  -e PYTHONUNBUFFERED=1 \
  -v "$PWD/../loadgen:/work" \
  -v "$PWD/../../results:/results" \
  python:3.12-slim python /work/longrun_mix.py \
    --host "$HOST" --port "$PORT" \
    --duration "$DUR" --concurrency 32 \
    --out-lat /results/swarm_long_lat.csv \
    --out-summary /results/swarm_long_summary.json
kill "$MET_PID" || true

