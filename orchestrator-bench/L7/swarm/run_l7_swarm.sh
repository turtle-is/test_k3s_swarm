#!/usr/bin/env bash
set -euo pipefail
HOST=${HOST:-192.168.1.127}
PORT=${PORT:-30081}
docker run --rm -i --network host \
  -e PYTHONUNBUFFERED=1 \
  -v "$PWD/../loadgen:/work" \
  -v "$PWD/../../results:/results" \
  python:3.12-slim python /work/http_loadgen.py \
    --host "$HOST" --port "$PORT" \
    --concurrency 32 --requests 5000 \
    --out-lat /results/swarm_l7_lat.csv \
    --out-summary /results/swarm_l7_summary.json

