#!/usr/bin/env bash
set -euo pipefail
HOST=${HOST:-192.168.1.127}
PORT=${PORT:-30081}

# быстрый sanity-check: 5k запросов, conc=32
docker run --rm -i --network host \
  -e PYTHONUNBUFFERED=1 \
  -v "$(pwd)/../../results:/results" \
  python:3.12-slim python - <<PY
import sys, json, subprocess
from pathlib import Path
HOST="${HOST}"; PORT=${PORT}
LAT="/results/k3s_l7_lat.csv"; SUM="/results/k3s_l7_summary.json"
code = subprocess.call([
  "python","/work/http_loadgen.py",
  "--host",HOST,"--port",str(PORT),
  "--concurrency","32","--requests","5000",
  "--out-lat",LAT,"--out-summary",SUM
])
PY

