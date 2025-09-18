#!/usr/bin/env bash
set -euo pipefail
HOST=${HOST:-192.168.1.127}
PORT=${PORT:-30081}
DUR=${DUR:-1800}        # 30 минут
FAIL_AT=${FAIL_AT:-900} # удалить pod через 15 минут, 0 = не удалять

# метрики ноды (сервер)
./../metrics/node_metrics.sh "../../results/node_server.csv" >/dev/null 2>&1 & MET_PID=$!

# длительная нагрузка
docker run --rm -i --network host \
  -e PYTHONUNBUFFERED=1 \
  -v "$PWD/../loadgen:/work" \
  -v "$PWD/../../results:/results" \
  python:3.12-slim python /work/longrun_mix.py \
    --host "$HOST" --port "$PORT" \
    --duration "$DUR" --concurrency 32 \
    --out-lat /results/k3s_long_lat.csv \
    --out-summary /results/k3s_long_summary.json \
    & LOAD_PID=$!

# отказ посередине (опционально)
if [ "$FAIL_AT" -gt 0 ]; then
  sleep "$FAIL_AT"
  POD=$(sudo k3s kubectl get pods -l app=micro-host -o jsonpath='{.items[0].metadata.name}')
  echo "[fault] deleting pod $POD"
  sudo k3s kubectl delete pod "$POD" --grace-period=0 --force || true
fi

wait "$LOAD_PID" || true
kill "$MET_PID" || true
echo "done"

