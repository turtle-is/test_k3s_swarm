#!/usr/bin/env bash
set -euo pipefail

RUNS=${RUNS:-3}
VCPUS=${VCPUS:-3}
DURATION=${DURATION:-600s}
SWARM_NODE=${SWARM_NODE:-lpi4aServer}         # docker node ls → HOSTNAME (регистр важен!)
IMAGE=${IMAGE:-nctortue/riscv-stress-ng:latest}
RESULTS_ROOT=${RESULTS_ROOT:-/var/bench-results/swarm}
STACK_NAME=${STACK_NAME:-stressbench}

echo "Swarm bench: RUNS=$RUNS VCPUS=$VCPUS DURATION=$DURATION NODE=$SWARM_NODE"
echo "Results root: $RESULTS_ROOT"
sudo mkdir -p "$RESULTS_ROOT"

for i in $(seq 1 "$RUNS"); do
  TS=$(date +%Y%m%d-%H%M%S)
  OUT_HOST="$RESULTS_ROOT/swarm-$TS-run$i"                   # на хосте
  OUT_CONT="/var/bench-results/swarm/swarm-$TS-run$i"        # в контейнере
  echo "[$i/$RUNS] OUT_DIR=$OUT_HOST"

  # Сформируем одну длинную команду БЕЗ $ и перенаправлений многострочно
  CMD="mkdir -p '$OUT_CONT'; \
date +'%F %T %z' | tee -a '$OUT_CONT/meta.txt'; \
uname -a | tee -a '$OUT_CONT/meta.txt'; \
lscpu > '$OUT_CONT/lscpu.txt' 2>/dev/null || true; \
numactl --hardware > '$OUT_CONT/numa.txt' 2>/dev/null || true; \
/usr/bin/time -v -o '$OUT_CONT/time.txt' \
  stress-ng --cpu $VCPUS --cpu-method matrixprod \
            --metrics-brief --timeout $DURATION \
  1> '$OUT_CONT/stress.stdout' 2> '$OUT_CONT/stress.stderr' || true; \
[ -f /sys/fs/cgroup/cpu.stat ] && cp /sys/fs/cgroup/cpu.stat '$OUT_CONT/cpu.stat' || true; \
echo 'Done. Results in $OUT_CONT'"

  TMP=$(mktemp)
  cat >"$TMP" <<YAML
version: "3.8"
services:
  stress:
    image: $IMAGE
    deploy:
      replicas: 1
      restart_policy: { condition: none }
      resources:
        reservations: { cpus: "${VCPUS}.0", memory: 512M }
        limits:       { cpus: "${VCPUS}.0", memory: 1G }
      placement:
        constraints:
          - node.platform.arch == riscv64
          - node.hostname == $SWARM_NODE
    volumes:
      - $RESULTS_ROOT:/var/bench-results/swarm
    entrypoint: ["/bin/sh","-lc","$CMD"]
YAML

  docker stack rm "$STACK_NAME" >/dev/null 2>&1 || true
  for _ in {1..15}; do docker stack ls | grep -q "^$STACK_NAME " || break; sleep 1; done

  docker stack deploy -c "$TMP" "$STACK_NAME"

  # ждём завершения таска
  while :; do
    state=$(docker service ps ${STACK_NAME}_stress --no-trunc --format '{{.CurrentState}}' | head -n1 || true)
    [ -z "$state" ] && sleep 1 && continue
    echo "state: $state"
    echo "$state" | grep -q '^Complete' && break
    echo "$state" | grep -Eq '^(Failed|Rejected)' && {
      echo "Task failed:"; docker service ps ${STACK_NAME}_stress
      docker service logs ${STACK_NAME}_stress || true
      exit 1
    }
    sleep 3
  done

  echo ">> Results: $OUT_HOST"
  docker stack rm "$STACK_NAME" >/dev/null 2>&1 || true
  rm -f "$TMP"
done
